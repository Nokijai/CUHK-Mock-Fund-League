import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// While the user is on the signup OTP page, an admin may approve them.
// We poll by re-visiting the same URL so the server can redirect/sign-in once approved.
export default class extends Controller {
  static values = { interval: Number }

  connect() {
    this.intervalMs = (this.intervalValue || 2000)
    this.timer = window.setInterval(() => {
      // Do not refresh while the user is typing; Turbo replace would clear the form state.
      if (document.visibilityState === "hidden") return

      const otpInput = this.element.querySelector('input[name="otp_code"]')
      const userIsTyping = otpInput && (document.activeElement === otpInput || (otpInput.value || "").trim().length > 0)
      if (userIsTyping) return

      Turbo.visit(window.location.href, { action: "replace" })
    }, this.intervalMs)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }
}

