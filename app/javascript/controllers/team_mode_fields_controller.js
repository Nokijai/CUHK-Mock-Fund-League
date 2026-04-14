import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "fields"]

  connect() {
    this.refresh()
  }

  toggle() {
    this.refresh()
  }

  refresh() {
    if (!this.hasFieldsTarget) return
    if (!this.hasToggleTarget) {
      this.fieldsTarget.hidden = false
      return
    }

    this.fieldsTarget.hidden = !this.toggleTarget.checked
  }
}
