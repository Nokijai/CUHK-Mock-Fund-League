import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { rootUrl: String }

  visit(event) {
    const id = event.target.value
    if (!id) return
    const url = `${this.rootUrlValue}?${new URLSearchParams({ league_id: id }).toString()}`
    if (window.Turbo?.visit) {
      window.Turbo.visit(url)
    } else {
      window.location.assign(url)
    }
  }
}
