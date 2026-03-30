import { Controller } from "@hotwired/stimulus"

// Client-side candle chart with poll-refresh, grid, pan/zoom, and fullscreen.
// Data from GET /stocks/:symbol.json (see StocksController#show).
export default class extends Controller {
  static values = {
    symbol: String,
    interval: String,
    revision: String,
    pollInterval: { type: Number, default: 30000 }
  }

  static targets = [
    "canvas",
    "lastPrice",
    "updatedAt",
    "statOpen",
    "statHigh",
    "statLow",
    "statClose",
    "statChg",
    "statVol",
    "statHiLo",
    "statBars",
    "chartShell",
    "empty",
    "fsHint",
    "svgFallback",
    "candleTooltip",
    "gridButton"
  ]

  connect () {
    // Candles live in <script type="application/json"> so we avoid huge escaped data-* JSON
    // (Stimulus Array values + HTML attributes often break parsing and the chart never draws).
    this._rows = this.loadCandlesFromJsonScript()
    this._lastRevision = this.revisionValue || ""
    this._view = { start: 0, count: 0 }
    this._showGrid = true
    this._panning = false
    this._panStartX = 0
    this._viewStartAtPan = 0
    this._pollTimer = null
    this._onKey = this.onKeydown.bind(this)
    this._lastGeom = null
    this._fullscreenBodyOverflow = null

    this.bindCanvasInteractions()
    this.syncGridButtonPressed()

    // Wait one frame so flex/grid layout has real widths (fixes invisible canvas at first paint).
    requestAnimationFrame(() => {
      this.resizeCanvas()
      this.resetView()
      this.syncFallbackVisibility()
    })

    this._resizeObserver = new ResizeObserver(() => {
      this.resizeCanvas()
      this.draw()
      this.syncFallbackVisibility()
    })
    // Observe the shell so EXPAND (fullscreen) relayout triggers a resize, not only the inner wrap.
    if (this.hasChartShellTarget) {
      this._resizeObserver.observe(this.chartShellTarget)
    } else if (this.hasCanvasTarget) {
      this._resizeObserver.observe(this.canvasTarget.parentElement)
    }

    if (this.pollIntervalValue > 0) {
      this._pollTimer = window.setInterval(() => this.pollRevision(), this.pollIntervalValue)
    }
  }

  // Reads OHLCV from embedded JSON; falls back to empty series on parse errors.
  loadCandlesFromJsonScript () {
    const el = this.element.querySelector("script[type=\"application/json\"][data-trading-quote-candles-json]")
    if (!el || !el.textContent) return []
    try {
      const raw = JSON.parse(el.textContent.trim())
      return this.normalizeCandles(Array.isArray(raw) ? raw : [])
    } catch (err) {
      console.error("[trading-quote] bad candle JSON", err)
      return []
    }
  }

  bindCanvasInteractions () {
    if (!this.hasCanvasTarget) return
    this.canvasTarget.addEventListener("wheel", this.onWheel.bind(this), { passive: false })
    this.canvasTarget.addEventListener("pointerdown", this.onPointerDown.bind(this))
    this.canvasTarget.addEventListener("pointermove", this.onPointerMove.bind(this))
    this.canvasTarget.addEventListener("pointerup", this.onPointerUp.bind(this))
    this.canvasTarget.addEventListener("pointerleave", this.onPointerLeaveCanvas.bind(this))
    this.canvasTarget.addEventListener("dblclick", this.resetView.bind(this))
  }

  syncGridButtonPressed () {
    if (this.hasGridButtonTarget) {
      this.gridButtonTarget.setAttribute("aria-pressed", this._showGrid ? "true" : "false")
    }
  }

  // Prefer visibility over [hidden] for the “canvas wins” state: hidden uses display:none and
  // collapses the stack, so the absolutely positioned canvas loses height and disappears.
  syncFallbackVisibility () {
    if (!this.hasSvgFallbackTarget) return
    const hasDraw = this._rows.length > 0 && this.visibleRows().length > 0
    this.svgFallbackTarget.hidden = this._rows.length === 0
    this.svgFallbackTarget.classList.toggle("terminal-quote-svg-fallback--covered", hasDraw)
    this.svgFallbackTarget.setAttribute("aria-hidden", hasDraw ? "true" : "false")
  }

  disconnect () {
    if (this._pollTimer) window.clearInterval(this._pollTimer)
    if (this._resizeObserver) this._resizeObserver.disconnect()
    document.removeEventListener("keydown", this._onKey)
    if (this.hasChartShellTarget) {
      this.chartShellTarget.classList.remove("terminal-quote-chart-shell--fullscreen")
    }
    if (this.hasFsHintTarget) this.fsHintTarget.hidden = true
    this.restoreBodyScrollAfterFullscreen()
  }

  restoreBodyScrollAfterFullscreen () {
    if (this._fullscreenBodyOverflow !== null) {
      document.body.style.overflow = this._fullscreenBodyOverflow
      this._fullscreenBodyOverflow = null
    }
  }

  normalizeCandles (raw) {
    const num = (x) => {
      if (x == null || x === "") return null
      const n = Number(x)
      return Number.isFinite(n) ? n : null
    }
    const rows = (raw || [])
      .map((r) => ({
        t: r.t,
        o: num(r.o),
        h: num(r.h),
        l: num(r.l),
        c: num(r.c),
        v: num(r.v)
      }))
      .filter((r) => r.h != null && r.l != null)
      .sort((a, b) => new Date(a.t) - new Date(b.t))
    return rows
  }

  visibleRows () {
    const rows = this._rows
    if (!rows.length) return []
    const { start, count } = this._view
    const end = Math.min(start + count, rows.length)
    return rows.slice(start, end)
  }

  resetView () {
    const n = this._rows.length
    this._view = { start: 0, count: n > 0 ? n : 0 }
    this.draw()
    this.syncFallbackVisibility()
  }

  resizeCanvas () {
    if (!this.hasCanvasTarget) return
    const parent = this.canvasTarget.parentElement
    let w = parent.clientWidth || 600
    let h = parent.clientHeight
    // Fullscreen: parent may not have laid out yet; derive height from the fixed shell minus toolbar/hint.
    if (this.hasChartShellTarget && this.chartShellTarget.classList.contains("terminal-quote-chart-shell--fullscreen")) {
      const shell = this.chartShellTarget.getBoundingClientRect()
      const toolbar = this.chartShellTarget.querySelector(".terminal-quote-chart-toolbar")
      const th = toolbar ? toolbar.getBoundingClientRect().height : 0
      const hintEl = this.hasFsHintTarget && !this.fsHintTarget.hidden ? this.fsHintTarget : null
      const hh = hintEl ? hintEl.getBoundingClientRect().height : 0
      w = Math.max(320, shell.width - 16)
      h = Math.max(220, shell.height - th - hh - 24)
    }
    if (!h || h < 48) {
      h = Math.min(260, Math.max(180, Math.floor(w * 0.22)))
    }
    const dpr = window.devicePixelRatio || 1
    this.canvasTarget.width = Math.floor(w * dpr)
    this.canvasTarget.height = Math.floor(h * dpr)
    this.canvasTarget.style.width = `${w}px`
    this.canvasTarget.style.height = `${h}px`
    const ctx = this.canvasTarget.getContext("2d")
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  }

  draw () {
    if (!this.hasCanvasTarget) return
    const ctx = this.canvasTarget.getContext("2d")
    const w = this.canvasTarget.clientWidth
    const h = this.canvasTarget.clientHeight
    ctx.clearRect(0, 0, w, h)

    const vis = this.visibleRows()
    this._lastGeom = null
    this.hideCandleTooltip()
    if (!vis.length) {
      if (this.hasEmptyTarget) this.emptyTarget.hidden = this._rows.length > 0
      if (this.hasSvgFallbackTarget) {
        this.svgFallbackTarget.hidden = this._rows.length === 0
        this.svgFallbackTarget.classList.remove("terminal-quote-svg-fallback--covered")
      }
      return
    }
    if (this.hasEmptyTarget) this.emptyTarget.hidden = true

    const padL = 52
    const padR = 8
    const padT = 10
    const padB = 22
    const plotW = w - padL - padR
    const plotH = h - padT - padB

    let minP = Infinity
    let maxP = -Infinity
    vis.forEach((c) => {
      minP = Math.min(minP, c.l, c.h)
      maxP = Math.max(maxP, c.l, c.h)
    })
    if (minP === maxP) {
      minP -= 1
      maxP += 1
    }
    const padPct = 0.04
    const range = maxP - minP
    minP -= range * padPct
    maxP += range * padPct
    const rng = maxP - minP

    const yPrice = (p) => padT + plotH - ((p - minP) / rng) * plotH

    ctx.fillStyle = "#1c1c1e"
    ctx.fillRect(padL, padT, plotW, plotH)

    if (this._showGrid) {
      ctx.lineWidth = 1
      const gridN = 5
      for (let i = 0; i <= gridN; i++) {
        const y = padT + (plotH * i) / gridN
        ctx.strokeStyle = "rgba(160, 160, 168, 0.55)"
        ctx.beginPath()
        ctx.moveTo(padL, y)
        ctx.lineTo(padL + plotW, y)
        ctx.stroke()
        const price = maxP - (rng * i) / gridN
        ctx.fillStyle = "#8e8e93"
        ctx.font = "10px ui-monospace, monospace"
        ctx.textAlign = "right"
        ctx.fillText(price.toFixed(2), padL - 4, y + 3)
      }
      const vLines = Math.min(8, vis.length)
      for (let i = 0; i <= vLines; i++) {
        const x = padL + (plotW * i) / vLines
        ctx.strokeStyle = "rgba(120, 120, 125, 0.4)"
        ctx.beginPath()
        ctx.moveTo(x, padT)
        ctx.lineTo(x, padT + plotH)
        ctx.stroke()
      }
    }

    const n = vis.length
    const slotW = plotW / n
    const bodyW = Math.max(2, slotW * 0.55)
    const up = "#30d158"
    const down = "#ff453a"
    const wick = "#8e8e93"

    vis.forEach((c, i) => {
      const o = Number(c.o != null ? c.o : c.c)
      const cl = Number(c.c != null ? c.c : c.o)
      const cx = padL + i * slotW + slotW / 2
      const yh = yPrice(c.h)
      const yl = yPrice(c.l)
      const yo = yPrice(o)
      const yc = yPrice(cl)
      const top = Math.min(yo, yc)
      const bot = Math.max(yo, yc)
      const col = cl >= o ? up : down

      ctx.strokeStyle = wick
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(cx, yh)
      ctx.lineTo(cx, yl)
      ctx.stroke()

      ctx.fillStyle = col
      ctx.fillRect(cx - bodyW / 2, top, bodyW, Math.max(1, bot - top))
    })

    this._lastGeom = {
      vis,
      padL,
      padT,
      padR,
      padB,
      plotW,
      plotH,
      slotW,
      n,
      minP,
      maxP,
      rng
    }
    this.syncFallbackVisibility()
  }

  hideCandleTooltip () {
    if (this.hasCandleTooltipTarget) {
      this.candleTooltipTarget.hidden = true
      this.candleTooltipTarget.style.visibility = ""
    }
  }

  formatCandleTooltip (c) {
    const fmt = (n) =>
      n != null && Number.isFinite(Number(n)) ? Number(n).toFixed(2) : "—"
    const t = c.t ? new Date(c.t).toLocaleString() : "—"
    const vol = c.v != null && Number.isFinite(Number(c.v)) ? Number(c.v).toLocaleString() : "—"
    return `${t}\nO ${fmt(c.o)}  H ${fmt(c.h)}\nL ${fmt(c.l)}  C ${fmt(c.c)}\nVol ${vol}`
  }

  updateCandleHover (clientX, clientY) {
    if (!this.hasCandleTooltipTarget || !this.hasCanvasTarget || !this._lastGeom) return
    const geom = this._lastGeom
    const rect = this.canvasTarget.getBoundingClientRect()
    const x = clientX - rect.left
    const y = clientY - rect.top
    const { padL, padT, plotW, plotH, slotW, n, vis } = geom
    if (x < padL || x > padL + plotW || y < padT || y > padT + plotH) {
      this.hideCandleTooltip()
      return
    }
    let i = Math.floor((x - padL) / slotW)
    if (i < 0 || i >= n || !vis[i]) {
      this.hideCandleTooltip()
      return
    }
    const tip = this.candleTooltipTarget
    tip.textContent = this.formatCandleTooltip(vis[i])
    tip.hidden = false
    const wrap = this.canvasTarget.parentElement
    const wr = wrap.getBoundingClientRect()
    const mx = clientX - wr.left
    const my = clientY - wr.top
    // Measure then position so the box does not flash at (0,0) before clamping.
    tip.style.visibility = "hidden"
    tip.style.left = "0"
    tip.style.top = "0"
    const tw = tip.offsetWidth
    const th = tip.offsetHeight
    const pad = 8
    let left = mx + 12
    let top = my + 12
    if (left + tw > wrap.clientWidth - pad) left = Math.max(pad, mx - tw - 12)
    if (top + th > wrap.clientHeight - pad) top = Math.max(pad, my - th - 12)
    tip.style.left = `${left}px`
    tip.style.top = `${top}px`
    tip.style.visibility = "visible"
  }

  onWheel (e) {
    e.preventDefault()
    const rows = this._rows
    if (rows.length < 2) return
    const dir = e.deltaY > 0 ? 1 : -1
    let { start, count } = this._view
    const rect = this.canvasTarget.getBoundingClientRect()
    const x = e.clientX - rect.left
    const w = rect.width
    const padL = 52
    const plotW = w - 52 - 8
    const fx = plotW > 0 ? Math.max(0, Math.min(1, (x - padL) / plotW)) : 0.5
    const anchorIdx = start + Math.floor(fx * Math.max(0, count - 1))

    const minBars = Math.min(5, rows.length)
    let newCount = Math.round(count * (1 + dir * 0.12))
    newCount = Math.max(minBars, Math.min(rows.length, newCount))
    const maxStart = Math.max(0, rows.length - newCount)
    let newStart = Math.round(anchorIdx - fx * (newCount - 1))
    newStart = Math.max(0, Math.min(maxStart, newStart))
    this._view = { start: newStart, count: Math.min(newCount, rows.length - newStart) }
    this.draw()
  }

  onPointerDown (e) {
    if (e.button !== 0) return
    this.hideCandleTooltip()
    this._panning = true
    this._panStartX = e.clientX
    this._viewStartAtPan = this._view.start
    this.canvasTarget.setPointerCapture(e.pointerId)
  }

  onPointerMove (e) {
    // Hover only when no primary button is pressed (drag = pan).
    if ((e.buttons & 1) === 0) {
      this.updateCandleHover(e.clientX, e.clientY)
      return
    }
    if (!this._panning) return
    const rows = this._rows
    if (rows.length <= this._view.count) return
    const dx = e.clientX - this._panStartX
    const slot = this.canvasTarget.clientWidth - 60
    const bars = this._view.count
    const barPx = slot / bars
    const shift = Math.round(-dx / Math.max(barPx, 1))
    const maxStart = Math.max(0, rows.length - this._view.count)
    const start = Math.max(0, Math.min(maxStart, this._viewStartAtPan + shift))
    this._view.start = start
    this.draw()
  }

  onPointerUp (e) {
    this._panning = false
    try {
      this.canvasTarget.releasePointerCapture(e.pointerId)
    } catch (_) {}
  }

  onPointerLeaveCanvas (e) {
    this.hideCandleTooltip()
    this.onPointerUp(e)
  }

  toggleGrid (event) {
    event?.preventDefault()
    this._showGrid = !this._showGrid
    this.syncGridButtonPressed()
    this.draw()
  }

  toggleFullscreen (event) {
    event?.preventDefault()
    if (!this.hasChartShellTarget) return
    const el = this.chartShellTarget
    const on = el.classList.toggle("terminal-quote-chart-shell--fullscreen")
    if (this.hasFsHintTarget) this.fsHintTarget.hidden = !on
    if (on) {
      document.addEventListener("keydown", this._onKey)
      this._fullscreenBodyOverflow = document.body.style.overflow
      document.body.style.overflow = "hidden"
    } else {
      document.removeEventListener("keydown", this._onKey)
      this.restoreBodyScrollAfterFullscreen()
    }
    // Layout after class toggle so clientWidth/height are correct (fullscreen was ~280px tall before).
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.resizeCanvas()
        this.draw()
      })
    })
  }

  onKeydown (e) {
    if (e.key === "Escape" && this.hasChartShellTarget) {
      this.chartShellTarget.classList.remove("terminal-quote-chart-shell--fullscreen")
      if (this.hasFsHintTarget) this.fsHintTarget.hidden = true
      document.removeEventListener("keydown", this._onKey)
      this.restoreBodyScrollAfterFullscreen()
      requestAnimationFrame(() => {
        this.resizeCanvas()
        this.draw()
      })
    }
  }

  async pollRevision () {
    const sym = encodeURIComponent(this.symbolValue)
    try {
      const r = await fetch(`/stocks/${sym}.json?meta=true`, { headers: { Accept: "application/json" } })
      if (!r.ok) return
      const j = await r.json()
      const rev = j.revision || ""
      if (rev && rev !== this._lastRevision) {
        await this.refreshFull()
        this._lastRevision = rev
      }
    } catch (_) {
      /* ignore transient network errors */
    }
  }

  async refreshFull () {
    const sym = encodeURIComponent(this.symbolValue)
    const iv = encodeURIComponent(this.intervalValue)
    const r = await fetch(`/stocks/${sym}.json?interval=${iv}`, { headers: { Accept: "application/json" } })
    if (!r.ok) return
    const j = await r.json()
    this._rows = this.normalizeCandles(j.candles || [])
    if (j.revision) this._lastRevision = j.revision
    this.updateDomFromPayload(j)
    this.resetView()
  }

  updateDomFromPayload (j) {
    const fmtMoney = (n) =>
      typeof n === "number" && !Number.isNaN(n)
        ? new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(n)
        : "—"
    const fmt = (n) =>
      typeof n === "number" && !Number.isNaN(n)
        ? n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
        : "—"
    if (this.hasLastPriceTarget && j.price != null) {
      this.lastPriceTarget.textContent = fmtMoney(j.price)
    }
    if (this.hasUpdatedAtTarget && j.updated_at) {
      const d = new Date(j.updated_at)
      this.updatedAtTarget.textContent = `As of ${d.toLocaleString()}`
    }
    const rows = this.normalizeCandles(j.candles || [])
    const stats = this.computeStats(rows)
    if (this.hasStatOpenTarget) this.statOpenTarget.textContent = stats.open != null ? fmt(stats.open) : "—"
    if (this.hasStatHighTarget) this.statHighTarget.textContent = stats.high != null ? fmt(stats.high) : "—"
    if (this.hasStatLowTarget) this.statLowTarget.textContent = stats.low != null ? fmt(stats.low) : "—"
    if (this.hasStatCloseTarget) this.statCloseTarget.textContent = stats.close != null ? fmt(stats.close) : "—"
    if (this.hasStatChgTarget) {
      this.statChgTarget.textContent = stats.chgPct != null ? `${stats.chgPct >= 0 ? "+" : ""}${stats.chgPct.toFixed(2)}` : "—"
      this.statChgTarget.classList.toggle("terminal-text-up", stats.chgPct != null && stats.chgPct >= 0)
      this.statChgTarget.classList.toggle("terminal-text-down", stats.chgPct != null && stats.chgPct < 0)
    }
    if (this.hasStatVolTarget) this.statVolTarget.textContent = stats.vol != null ? Number(stats.vol).toLocaleString() : "—"
    if (this.hasStatHiLoTarget) {
      this.statHiLoTarget.textContent =
        stats.periodHigh != null && stats.periodLow != null ? `${fmt(stats.periodHigh)} / ${fmt(stats.periodLow)}` : "—"
    }
    if (this.hasStatBarsTarget) this.statBarsTarget.textContent = String(rows.length)
  }

  computeStats (rows) {
    if (!rows.length) {
      return { open: null, high: null, low: null, close: null, chgPct: null, vol: null, periodHigh: null, periodLow: null }
    }
    const last = rows[rows.length - 1]
    const prev = rows.length >= 2 ? rows[rows.length - 2] : null
    const pc = prev && prev.c != null && prev.c !== 0 ? ((last.c - prev.c) / prev.c) * 100 : null
    let hi = -Infinity
    let lo = Infinity
    rows.forEach((c) => {
      if (c.h != null) hi = Math.max(hi, c.h)
      if (c.l != null) lo = Math.min(lo, c.l)
    })
    return {
      open: last.o,
      high: last.h,
      low: last.l,
      close: last.c,
      chgPct: pc,
      vol: last.v,
      periodHigh: Number.isFinite(hi) ? hi : null,
      periodLow: Number.isFinite(lo) ? lo : null
    }
  }
}
