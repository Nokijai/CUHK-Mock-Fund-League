import { Controller } from "@hotwired/stimulus"

// Dismisses Turbo-streamed league notices: optional auto-hide (e.g. 10s) or manual close only.
export default class extends Controller {
  static values = {
    autoDismissMs: { type: Number, default: 0 },
  }

  connect() {
    const ms = this.autoDismissMsValue
    if (ms > 0) {
      this.timeoutId = window.setTimeout(() => this.dismiss(), ms)
    }
  }

  disconnect() {
    if (this.timeoutId) window.clearTimeout(this.timeoutId)
  }

  dismiss() {
    if (this.timeoutId) {
      window.clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
    this.element.remove()
  }
}
