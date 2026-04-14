import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "tabContent", "searchInput", "searchResults"]

  toggle() {
    const panel = this.panelTarget
    if (panel.style.display === "none") {
      panel.style.display = "block"
    } else {
      panel.style.display = "none"
    }
  }

  close() {
    this.panelTarget.style.display = "none"
  }

  showTab(event) {
    const tab = event.params.tab

    // Update tab buttons
    this.element.querySelectorAll(".terminal-friends-tab").forEach(btn => {
      btn.classList.remove("terminal-friends-tab--active")
    })
    event.currentTarget.classList.add("terminal-friends-tab--active")

    // Show/hide tab content
    this.tabContentTargets.forEach(el => {
      el.style.display = el.dataset.tab === tab ? "block" : "none"
    })

    // Focus search input when switching to search tab
    if (tab === "search" && this.hasSearchInputTarget) {
      this.searchInputTarget.focus()
    }
  }

  search() {
    const query = this.searchInputTarget.value.trim()
    if (query.length < 2) {
      this.searchResultsTarget.innerHTML = ""
      return
    }

    clearTimeout(this._searchTimeout)
    this._searchTimeout = setTimeout(() => {
      fetch(`/friendships/search?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
        .then(response => response.text())
        .then(html => {
          this.searchResultsTarget.innerHTML = html
        })
    }, 300)
  }

  // Close panel when clicking outside
  connect() {
    this._outsideClick = (event) => {
      if (!this.element.contains(event.target) && this.panelTarget.style.display !== "none") {
        this.panelTarget.style.display = "none"
      }
    }
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
    clearTimeout(this._searchTimeout)
  }
}
