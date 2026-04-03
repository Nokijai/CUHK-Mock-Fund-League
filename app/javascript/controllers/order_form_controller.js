import { Controller } from "@hotwired/stimulus"

// Trade form UX:
// - market order uses latest price and read-only price field
// - limit order allows manual price input
// - submit opens a confirmation modal with estimated transaction totals
export default class extends Controller {
  static targets = [
    "orderType",
    "tradeType",
    "symbol",
    "quantity",
    "price",
    "confirmOverlay",
    "confirmSide",
    "confirmSymbol",
    "confirmQuantity",
    "confirmPrice",
    "confirmAmount",
    "confirmFee",
    "confirmBalance"
  ]

  static values = {
    marketPrice: Number,
    feeRate: Number,
    cashBalance: Number
  }

  connect () {
    // Guard to allow one real submit after user confirms in the modal.
    this.confirmedSubmit = false
    // Force closed state on connect (helps with Turbo cache restores).
    this.closeConfirmModal()
    this.syncPriceInputMode()
  }

  onOrderTypeChange () {
    this.syncPriceInputMode()
  }

  onSubmit (event) {
    // Second pass (after modal confirmation): let Rails submit normally.
    if (this.confirmedSubmit) {
      this.confirmedSubmit = false
      return
    }

    // Only open confirmation for the real order submit button.
    if (this.hasSubmitButtonTarget && event.submitter && event.submitter !== this.submitButtonTarget) return

    // Respect browser native validity checks before opening modal.
    if (!this.formReadyForConfirmation() || !this.element.checkValidity()) {
      this.element.reportValidity()
      return
    }

    if (!this.modalTargetsReady()) {
      // Safety fallback: if modal targets are missing, proceed with direct submit.
      this.confirmedSubmit = true
      this.element.requestSubmit()
      return
    }

    event.preventDefault()
    this.fillConfirmationPreview()
    this.openConfirmModal()
  }

  onEscape () {
    if (this.modalOpen()) this.closeConfirmModal()
  }

  confirmSubmit () {
    // Mark next submit event as trusted final submission.
    this.confirmedSubmit = true
    this.closeConfirmModal()
    this.element.requestSubmit()
  }

  closeConfirmModal () {
    if (!this.hasConfirmOverlayTarget) return
    this.confirmOverlayTarget.hidden = true
    document.body.classList.remove("terminal-modal-open")
  }

  syncPriceInputMode () {
    if (!this.hasOrderTypeTarget || !this.hasPriceTarget) return

    const isMarket = this.orderTypeTarget.value === "market"
    const marketPrice = Number(this.marketPriceValue)

    // Market order: lock to latest quote to mirror immediate execution behavior.
    if (isMarket) {
      if (Number.isFinite(marketPrice) && marketPrice > 0) {
        this.priceTarget.value = marketPrice.toFixed(4)
      }
      this.priceTarget.readOnly = true
      this.priceTarget.setAttribute("aria-readonly", "true")
    } else {
      this.priceTarget.readOnly = false
      this.priceTarget.removeAttribute("aria-readonly")
    }
  }

  fillConfirmationPreview () {
    const tradeType = this.hasTradeTypeTarget ? this.tradeTypeTarget.value.toUpperCase() : "-"
    const symbol = this.hasSymbolTarget ? this.symbolTarget.value.toUpperCase() : "-"
    const quantity = this.hasQuantityTarget ? Number(this.quantityTarget.value) : 0
    const price = this.hasPriceTarget ? Number(this.priceTarget.value) : 0

    const safeQty = Number.isFinite(quantity) ? quantity : 0
    const safePrice = Number.isFinite(price) ? price : 0
    const grossAmount = safeQty * safePrice
    const feeRate = Number.isFinite(this.feeRateValue) ? this.feeRateValue : 0
    const feeAmount = grossAmount * feeRate
    const currentCash = Number.isFinite(this.cashBalanceValue) ? this.cashBalanceValue : 0
    const estimatedCash = tradeType === "BUY"
      ? currentCash - grossAmount - feeAmount
      : currentCash + grossAmount - feeAmount

    this.confirmSideTarget.textContent = tradeType
    this.confirmSymbolTarget.textContent = symbol || "-"
    this.confirmQuantityTarget.textContent = safeQty.toString()
    this.confirmPriceTarget.textContent = this.formatCurrency(safePrice)
    this.confirmAmountTarget.textContent = this.formatCurrency(grossAmount)
    this.confirmFeeTarget.textContent = this.formatCurrency(feeAmount)
    this.confirmBalanceTarget.textContent = this.formatCurrency(estimatedCash)
  }

  openConfirmModal () {
    if (!this.hasConfirmOverlayTarget) return
    this.confirmOverlayTarget.hidden = false
    document.body.classList.add("terminal-modal-open")
  }

  modalOpen () {
    return this.hasConfirmOverlayTarget && !this.confirmOverlayTarget.hidden
  }

  modalTargetsReady () {
    return this.hasConfirmOverlayTarget &&
      this.hasConfirmSideTarget &&
      this.hasConfirmSymbolTarget &&
      this.hasConfirmQuantityTarget &&
      this.hasConfirmPriceTarget &&
      this.hasConfirmAmountTarget &&
      this.hasConfirmFeeTarget &&
      this.hasConfirmBalanceTarget
  }

  formReadyForConfirmation () {
    // Extra guard so modal never appears with partially entered trade data.
    if (!this.hasTradeTypeTarget || !this.hasOrderTypeTarget || !this.hasSymbolTarget || !this.hasQuantityTarget || !this.hasPriceTarget) {
      return false
    }

    const symbol = this.symbolTarget.value.trim()
    const quantity = Number(this.quantityTarget.value)
    const price = Number(this.priceTarget.value)
    const tradeType = this.tradeTypeTarget.value
    const orderType = this.orderTypeTarget.value

    return symbol.length > 0 &&
      Number.isFinite(quantity) &&
      quantity > 0 &&
      Number.isFinite(price) &&
      price > 0 &&
      ["buy", "sell"].includes(tradeType) &&
      ["market", "limit"].includes(orderType)
  }

  formatCurrency (value) {
    // Keep UI formatting consistent with Rails currency style for quick verification.
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(Number.isFinite(value) ? value : 0)
  }
}
