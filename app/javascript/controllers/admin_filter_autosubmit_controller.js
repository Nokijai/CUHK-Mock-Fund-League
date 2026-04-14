import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: Number }

  connect() {
    this.debounceMs = this.delayValue || 100
  }

  queueSubmit() {
    if (this.timer) window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => {
      this.element.requestSubmit()
    }, this.debounceMs)
  }

  disconnect() {
    if (this.timer) window.clearTimeout(this.timer)
  }
}
