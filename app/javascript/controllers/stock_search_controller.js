import { Controller } from "@hotwired/stimulus"

// Real-time stock search controller with debouncing
export default class extends Controller {
  static targets = ["input", "results", "emptyMessage"]
  static values = {
    portfolioId: Number,
    query: String,
    quoteInterval: String
  }

  connect() {
    // Debounce timeout reference
    this._debounceTimer = null
    this._lastQuery = this.queryValue || ""
    
    // Initialize with current query if present
    if (this._lastQuery) {
      this.search()
    }
  }

  disconnect() {
    // Clean up debounce timer on disconnect
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer)
    }
  }

  // Handle input changes with debouncing (300ms delay)
  onInput() {
    const query = this.inputTarget.value.trim()
    
    // Clear existing timer
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer)
    }
    
    // Don't search if query hasn't changed
    if (query === this._lastQuery) {
      return
    }
    
    // Debounce: wait 300ms after user stops typing
    this._debounceTimer = setTimeout(() => {
      this._lastQuery = query
      this.search()
    }, 300)
  }

  // Perform the search
  async search() {
    const query = this.inputTarget.value.trim()
    
    try {
      // Build search URL with query parameter
      const url = `/portfolios/${this.portfolioIdValue}/trades/new?q=${encodeURIComponent(query)}`
      const quoteInterval = this.quoteIntervalValue
      const fullUrl = quoteInterval ? `${url}&quote_interval=${encodeURIComponent(quoteInterval)}` : url
      
      // Fetch HTML partial with Turbo
      const response = await fetch(fullUrl, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        console.error('[stock-search] Search failed:', response.status)
        return
      }
      
      // Parse response and extract stock table
      const html = await response.text()
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      
      // Extract the stock table tbody
      const newTbody = doc.querySelector('.terminal-available-stocks tbody')
      if (newTbody && this.resultsTarget) {
        this.resultsTarget.innerHTML = newTbody.innerHTML
      }
      
      // Update URL without page reload (for bookmarking/sharing)
      window.history.replaceState({}, '', fullUrl)
      
    } catch (error) {
      console.error('[stock-search] Search error:', error)
    }
  }

  // Clear search and reload all stocks
  clear(event) {
    event?.preventDefault()
    this.inputTarget.value = ""
    this._lastQuery = ""
    
    const url = `/portfolios/${this.portfolioIdValue}/trades/new`
    const quoteInterval = this.quoteIntervalValue
    const fullUrl = quoteInterval ? `${url}?quote_interval=${encodeURIComponent(quoteInterval)}` : url
    
    // Navigate to clear URL
    window.location.href = fullUrl
  }
}
