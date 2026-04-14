import { Controller } from "@hotwired/stimulus"

// Refreshes only when a league transition occurs (start / 15m-before-end / end).
// Preserves expanded cards, scrolls moved cards to past section, and emits client notifications.
export default class extends Controller {
  connect() {
    this.lastCheckedAtMs = Date.now() - 1200
    this.isRefreshing = false
    this.pendingExpandedLeagueId = null
    this.heartbeatTimer = window.setInterval(() => this.checkAndRefresh(), 5000)
    this.visibilityHandler = () => {
      if (document.visibilityState === "visible") this.checkAndRefresh()
    }
    document.addEventListener("visibilitychange", this.visibilityHandler)
    this.scheduleExactTransitionCheck()
    this.checkAndRefresh()
  }

  disconnect() {
    if (this.heartbeatTimer) window.clearInterval(this.heartbeatTimer)
    if (this.transitionTimer) window.clearTimeout(this.transitionTimer)
    if (this.visibilityHandler) document.removeEventListener("visibilitychange", this.visibilityHandler)
  }

  scheduleExactTransitionCheck() {
    if (this.transitionTimer) {
      window.clearTimeout(this.transitionTimer)
      this.transitionTimer = null
    }

    const now = Date.now()
    const transitions = this.collectTransitions(this.topLeagueCards()).map((event) => event.timeMs).filter((ms) => ms > now)
    if (transitions.length === 0) return

    const nextTransitionMs = Math.min(...transitions)
    const delayMs = Math.max(nextTransitionMs - now + 20, 20)
    this.transitionTimer = window.setTimeout(() => this.checkAndRefresh(), delayMs)
  }

  async checkAndRefresh() {
    if (this.isRefreshing) return

    const topCards = this.topLeagueCards()
    const expandedTopId = this.currentExpandedTopId()
    const now = Date.now()
    const dueEvents = this.collectTransitions(topCards).filter((event) => this.crossedBoundary(this.lastCheckedAtMs, now, event.timeMs))
    const immediate = this.enforceImmediateLeagueState(topCards, now, expandedTopId)
    const movedLeagueIds = new Set([...(immediate.endedLeagueIds || [])])
    const stateChanged = immediate.changed
    const uniqueEvents = this.uniqueEventsByBoundary(dueEvents)
    this.lastCheckedAtMs = now

    if (uniqueEvents.length === 0 && !stateChanged) {
      this.scheduleExactTransitionCheck()
      return
    }

    this.isRefreshing = true
    if (expandedTopId && movedLeagueIds.has(expandedTopId)) {
      this.pendingExpandedLeagueId = expandedTopId
    }

    const requiresServerSync = movedLeagueIds.size > 0

    try {
      if (!requiresServerSync) {
        this.emitNotifications(uniqueEvents)
        return
      }

      const refreshUrl = new URL(window.location.href)
      refreshUrl.pathname = "/leagues/refresh"

      const response = await fetch(refreshUrl.toString(), {
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) return

      const html = await response.text()
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")

      this.replaceSectionFromDoc(doc, "#current-upcoming-leagues-results")
      this.replaceSectionFromDoc(doc, "#past-leagues-results")

      this.closeAllLeagueCards()
      this.restorePendingExpandedLeague()
      this.emitNotifications(uniqueEvents)
    } finally {
      this.isRefreshing = false
      this.scheduleExactTransitionCheck()
    }
  }

  topLeagueCards() {
    const topSection = this.element.querySelector("#current-upcoming-leagues-results")
    if (!topSection) return []
    return Array.from(topSection.querySelectorAll("details[data-league-start-at-ms][data-league-end-at-ms]"))
  }

  collectTransitions(details) {
    if (!details || details.length === 0) return []

    return details.flatMap((el) => {
      const id = el.id
      const startMs = Number(el.dataset.leagueStartAtMs)
      const endMs = Number(el.dataset.leagueEndAtMs)
      const userRegistered = el.dataset.userRegistered === "true"
      const leagueName = (el.querySelector("summary strong")?.textContent || "League").trim()

      const events = []
      if (Number.isFinite(startMs)) {
        events.push({ type: "start", id, leagueName, timeMs: startMs, userRegistered })
      }
      if (Number.isFinite(endMs)) {
        events.push({ type: "end", id, leagueName, timeMs: endMs, userRegistered })
      }

      if (Number.isFinite(startMs) && Number.isFinite(endMs) && (endMs - startMs) > 30 * 60 * 1000) {
        events.push({ type: "warn15", id, leagueName, timeMs: endMs - (15 * 60 * 1000), userRegistered })
      }

      return events
    })
  }

  crossedBoundary(fromMs, toMs, boundaryMs) {
    return Number.isFinite(boundaryMs) && boundaryMs > fromMs && boundaryMs <= toMs
  }

  enforceImmediateLeagueState(cards, nowMs, keepOpenId = null) {
    let changed = false
    if (!cards || cards.length === 0) return { changed, endedLeagueIds: [] }

    const endedIds = []
    cards.forEach((card) => {
      const id = card.id
      const startMs = Number(card.dataset.leagueStartAtMs)
      const endMs = Number(card.dataset.leagueEndAtMs)

      if (!Number.isFinite(startMs) || !Number.isFinite(endMs)) return

      if (nowMs >= endMs) {
        endedIds.push(id)
        changed = true
        return
      }

      if (nowMs >= startMs) {
        const dotAdded = this.showImmediateLiveDot(id)
        if (dotAdded) changed = true
      }
    })

    this.moveCardsToPastImmediately(endedIds, keepOpenId)

    return { changed, endedLeagueIds: endedIds }
  }

  showImmediateLiveDot(leagueId) {
    const card = document.getElementById(leagueId)
    if (!card) return false

    const summaryMain = card.querySelector(".terminal-league-summary-main")
    if (!summaryMain) return false
    if (summaryMain.querySelector(".terminal-live-indicator")) return false

    const indicator = document.createElement("span")
    indicator.className = "terminal-live-indicator terminal-live-indicator--icon"
    indicator.setAttribute("aria-label", "League started")
    indicator.setAttribute("title", "League started")

    const dot = document.createElement("span")
    dot.className = "terminal-live-dot"
    dot.setAttribute("aria-hidden", "true")
    indicator.appendChild(dot)
    summaryMain.appendChild(indicator)
    return true
  }

  moveCardsToPastImmediately(leagueIds, keepOpenId = null) {
    if (!leagueIds || leagueIds.length === 0) return

    const topSection = this.element.querySelector("#current-upcoming-leagues-results")
    const pastSection = this.element.querySelector("#past-leagues-results")
    if (!topSection || !pastSection) return

    let pastCards = pastSection.querySelector(".terminal-league-cards")
    if (!pastCards) {
      const empty = pastSection.querySelector(".terminal-empty-state")
      if (empty) empty.remove()
      pastCards = document.createElement("div")
      pastCards.className = "terminal-league-cards"
      pastCards.setAttribute("data-controller", "leagues-deep-link")
      pastSection.prepend(pastCards)
    }

    const fragment = document.createDocumentFragment()
    leagueIds.forEach((leagueId) => {
      const card = document.getElementById(leagueId)
      if (!card) return
      if (!topSection.contains(card)) return

      if (leagueId === keepOpenId) {
        card.setAttribute("open", "open")
        this.pendingExpandedLeagueId = leagueId
      } else {
        card.removeAttribute("open")
      }

      const liveIndicator = card.querySelector(".terminal-live-indicator")
      if (liveIndicator) liveIndicator.remove()
      fragment.appendChild(card)
    })

    if (fragment.childNodes.length > 0) {
      pastCards.prepend(fragment)
    }
  }

  replaceSectionFromDoc(doc, selector) {
    const nextSection = doc.querySelector(selector)
    const currentSection = document.querySelector(selector)
    if (nextSection && currentSection) {
      currentSection.outerHTML = nextSection.outerHTML
    }
  }

  currentExpandedTopId() {
    const topSection = this.element.querySelector("#current-upcoming-leagues-results")
    if (!topSection) return null

    const details = topSection.querySelector("details[open][id]")
    return details?.id || null
  }

  restorePendingExpandedLeague() {
    if (!this.pendingExpandedLeagueId) return

    const movedLeague = document.getElementById(this.pendingExpandedLeagueId)
    if (!movedLeague) {
      this.pendingExpandedLeagueId = null
      return
    }

    movedLeague.setAttribute("open", "open")
    movedLeague.scrollIntoView({ behavior: "smooth", block: "center" })
    this.pendingExpandedLeagueId = null
  }

  closeAllLeagueCards() {
    this.element.querySelectorAll("details.terminal-league-card[open]").forEach((details) => {
      details.removeAttribute("open")
    })
  }

  emitNotifications(events) {
    const container = document.getElementById("realtime-notifications")
    if (!container) return

    events
      .filter((event) => event.userRegistered)
      .sort((a, b) => a.timeMs - b.timeMs)
      .forEach((event) => {
        const card = this.buildNotificationCard(event)
        container.prepend(card)
      })
  }

  uniqueEventsByBoundary(events) {
    if (!events || events.length === 0) return []

    const deduped = new Map()
    events.forEach((event) => {
      const key = `${event.type}:${event.id}:${event.timeMs}`
      deduped.set(key, event)
    })
    return Array.from(deduped.values())
  }

  buildNotificationCard(event) {
    const card = document.createElement("div")
    const title = document.createElement("div")
    const body = document.createElement("div")
    const main = document.createElement("div")
    const close = document.createElement("button")
    const link = document.createElement("a")

    card.className = "terminal-realtime-notif-card terminal-realtime-notif-card--accent terminal-realtime-notif-card--persistent"
    main.className = "terminal-realtime-notif-main"
    title.className = "terminal-realtime-notif-title"
    body.className = "terminal-realtime-notif-body"
    close.className = "terminal-realtime-notif-close"
    link.className = "terminal-realtime-notif-view"

    if (event.type === "start") {
      title.textContent = "League started"
      body.textContent = `"${event.leagueName}" is now open for trading.`
    } else if (event.type === "warn15") {
      title.textContent = "League ending soon"
      body.textContent = `League "${event.leagueName}" — 15 minutes left until the end.`
    } else {
      title.textContent = "League ended"
      body.textContent = `"${event.leagueName}" has ended. Final standings are now available.`
    }

    link.textContent = "View league"
    link.href = `/leagues#${event.id}`

    close.type = "button"
    close.setAttribute("aria-label", "Dismiss notification")
    close.textContent = "×"
    close.addEventListener("click", () => this.dismissCardWithFade(card))

    card.addEventListener("contextmenu", (evt) => {
      evt.preventDefault()
      this.dismissCardWithFade(card)
    })

    card.addEventListener("click", (evt) => {
      if (evt.target.closest("a, button")) return
      this.dismissCardWithFade(card)
    })

    main.appendChild(title)
    main.appendChild(body)
    main.appendChild(link)
    card.appendChild(main)
    card.appendChild(close)
    return card
  }

  dismissCardWithFade(card) {
    card.classList.add("terminal-realtime-notif-card--closing")
    window.setTimeout(() => card.remove(), 180)
  }
}
