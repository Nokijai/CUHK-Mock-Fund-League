import { Controller } from "@hotwired/stimulus"

// Resend cooldown UI:
// - disables the button until cooldown completes
// - updates button label and optional helper text
export default class extends Controller {
  static targets = ["button", "help"]
  static values = { secondsLeft: Number }

  connect() {
    this.seconds = Number.isFinite(this.secondsLeftValue) ? this.secondsLeftValue : 0
    this.render()
  }

  disconnect() {
    if (this.timer) window.clearTimeout(this.timer)
  }

  render() {
    if (!this.hasButtonTarget) return

    if (this.seconds <= 0) {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = this.buttonTarget.dataset.readyLabel || "Resend verification code"
      if (this.hasHelpTarget) this.helpTarget.textContent = ""
      return
    }

    this.buttonTarget.disabled = true
    const base = this.buttonTarget.dataset.baseLabel || "Resend verification code"
    this.buttonTarget.textContent = `${base} (wait ${this.seconds}s)`
    if (this.hasHelpTarget) {
      const plural = this.seconds === 1 ? "" : "s"
      this.helpTarget.textContent = `You can resend a new code in ${this.seconds} second${plural}.`
    }

    this.seconds -= 1
    this.timer = window.setTimeout(() => this.render(), 1000)
  }
}

