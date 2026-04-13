import { Controller } from "@hotwired/stimulus"

// Opens the matching <details id="league-123"> when the URL hash is #league-123
// (redirects from leagues#show, join flows, and realtime "View" links).
export default class extends Controller {
  connect() {
    this.openFromHash()
    this.boundHashChange = () => this.openFromHash()
    window.addEventListener("hashchange", this.boundHashChange)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.boundHashChange)
  }

  openFromHash() {
    const raw = window.location.hash?.replace(/^#/, "") || ""
    if (!raw.startsWith("league-")) return

    const el = document.getElementById(raw)
    if (!el) return

    if (el.tagName === "DETAILS") el.open = true
    el.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }
}
