import { Controller } from "@hotwired/stimulus"

// OTP input helper:
// - forces numeric input
// - supports pasting a 6-digit code
// - enables form submit once code complete
export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { length: Number }

  connect() {
    this.codeLength = this.lengthValue || 6
    this.sanitizeAndToggle()
  }

  // Input handler: keep only digits and cap length.
  onInput() {
    this.sanitizeAndToggle()
  }

  // Paste handler: accept pasted codes with spaces/dashes.
  onPaste(event) {
    const raw = (event.clipboardData || window.clipboardData)?.getData("text") || ""
    const digits = raw.replace(/\D/g, "").slice(0, this.codeLength)
    if (!digits) return

    event.preventDefault()
    this.inputTarget.value = digits
    this.sanitizeAndToggle()
  }

  sanitizeAndToggle() {
    const before = this.inputTarget.value || ""
    const digits = before.replace(/\D/g, "").slice(0, this.codeLength)
    if (digits !== before) this.inputTarget.value = digits

    const ready = digits.length === this.codeLength
    if (this.hasSubmitTarget) this.submitTarget.disabled = !ready

    // Trigger browser OTP autofill to feel instant: submit only if user typed/pasted full code.
    if (ready && this.element.dataset.autoSubmit === "true") {
      const form = this.inputTarget.closest("form")
      if (form) form.requestSubmit()
    }
  }
}

