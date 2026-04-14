import { Controller } from "@hotwired/stimulus"

// Opens the matching <details id="league-123"> when the URL hash is #league-123
// (redirects from leagues#show, join flows, and realtime "View" links).
export default class extends Controller {
  connect() {
    this.openFromHash()
    this.boundHashChange = () => this.openFromHash()
    window.addEventListener("hashchange", this.boundHashChange)

    this.detailsElements = Array.from(this.element.querySelectorAll("details.terminal-league-card"))
    this.boundToggle = (event) => this.handleToggle(event)
    this.detailsElements.forEach((details) => details.addEventListener("toggle", this.boundToggle))
  }

  disconnect() {
    window.removeEventListener("hashchange", this.boundHashChange)
    if (this.detailsElements) {
      this.detailsElements.forEach((details) => details.removeEventListener("toggle", this.boundToggle))
    }
  }

  handleToggle(event) {
    const opened = event.currentTarget
    if (!opened?.open) return

    document.querySelectorAll("details.terminal-league-card[open]").forEach((details) => {
      if (details !== opened) details.open = false
    })
  }

  openFromHash() {
    const raw = window.location.hash?.replace(/^#/, "") || ""
    if (!raw.startsWith("league-")) return

    const el = document.getElementById(raw)
    if (!el) return

    if (el.tagName === "DETAILS") {
      document.querySelectorAll("details.terminal-league-card[open]").forEach((details) => {
        if (details !== el) details.open = false
      })
      el.open = true
    }
    el.scrollIntoView({ behavior: "smooth", block: "nearest" })

    // Consume the hash once so replaced sections do not re-open this card repeatedly.
    history.replaceState(null, "", `${window.location.pathname}${window.location.search}`)
  }
}
