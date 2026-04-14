import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: Number,
    targetSelector: String
  }

  connect() {
    this.debounceMs = this.delayValue || 100
  }

  queueSearch() {
    if (this.timer) window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.search(), this.debounceMs)
  }

  async search() {
    const targetSelector = this.targetSelectorValue
    if (!targetSelector) return

    const formData = new FormData(this.element)
    const query = new URLSearchParams(formData).toString()
    const url = `${this.element.action}?${query}`

    const response = await fetch(url, {
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })

    if (!response.ok) return

    const html = await response.text()
    const parser = new DOMParser()
    const doc = parser.parseFromString(html, "text/html")
    const nextTarget = doc.querySelector(targetSelector)
    const currentTarget = document.querySelector(targetSelector)

    if (nextTarget && currentTarget) {
      currentTarget.outerHTML = nextTarget.outerHTML
    }
  }

  disconnect() {
    if (this.timer) window.clearTimeout(this.timer)
  }
}
