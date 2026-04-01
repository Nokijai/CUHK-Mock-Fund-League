import { Controller } from "@hotwired/stimulus"

// Trade form UX:
// - market order uses latest price and read-only price field
// - limit order allows manual price input
export default class extends Controller {
  static targets = ["orderType", "price"]
  static values = { marketPrice: Number }

  connect () {
    this.syncPriceInputMode()
  }

  onOrderTypeChange () {
    this.syncPriceInputMode()
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
}
