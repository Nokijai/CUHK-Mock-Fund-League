import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { interval: Number }

  connect() {
    this.intervalMs = this.intervalValue || 10000
    this.timer = window.setInterval(() => {
      if (document.visibilityState === "hidden") return

      Turbo.visit(window.location.href, { action: "replace" })
    }, this.intervalMs)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }
}