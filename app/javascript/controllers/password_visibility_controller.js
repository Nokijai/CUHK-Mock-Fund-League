import { Controller } from "@hotwired/stimulus"

// Toggle password ↔ text on one or more inputs (e.g. password + confirmation).
export default class extends Controller {
  static targets = [ "input", "statusLabel" ]

  connect() {
    this.toggleButton = this.element.querySelector(".terminal-password-toggle")
    this.syncLabel()
  }

  toggle(event) {
    event?.preventDefault()
    const nextHidden = this.inputTargets.some((el) => el.type === "password")
    this.inputTargets.forEach((el) => {
      el.type = nextHidden ? "text" : "password"
    })
    this.syncLabel()
  }

  syncLabel() {
    const hidden = this.inputTargets.every((el) => el.type === "password")
    if (this.hasStatusLabelTarget) {
      this.statusLabelTarget.textContent = hidden ? "Show" : "Hide"
    }
    if (this.toggleButton) {
      this.toggleButton.setAttribute("aria-pressed", hidden ? "false" : "true")
    }
  }
}
