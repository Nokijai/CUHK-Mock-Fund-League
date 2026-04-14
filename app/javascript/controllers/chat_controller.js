import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fab", "chatBox", "chatContent", "channelTabs", "messagesContainer", "messageForm", "messageInput", "emojiPicker", "stickerPicker"]
  static values = { currentUserId: Number }

  connect() {
    this._dragging = false
    this._wasDragged = false
    this._offsetX = 0
    this._offsetY = 0
    this._currentChannel = "world"

    this._onMouseMove = this._onMouseMove.bind(this)
    this._onMouseUp = this._onMouseUp.bind(this)
    this._onTouchMove = this._onTouchMove.bind(this)
    this._onTouchEnd = this._onTouchEnd.bind(this)

    this._mutationObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === 1) {
            this._applyMessageAlignment(node)
            this._scrollToBottom()
          }
        }
      }
    })
  }

  disconnect() {
    document.removeEventListener("mousemove", this._onMouseMove)
    document.removeEventListener("mouseup", this._onMouseUp)
    document.removeEventListener("touchmove", this._onTouchMove)
    document.removeEventListener("touchend", this._onTouchEnd)
    if (this._mutationObserver) this._mutationObserver.disconnect()
  }

  // ── Drag logic ──

  startDrag(event) {
    if (event.type === "mousedown" && event.button !== 0) return

    const fab = this.fabTarget
    const rect = fab.getBoundingClientRect()
    const clientX = event.type === "touchstart" ? event.touches[0].clientX : event.clientX
    const clientY = event.type === "touchstart" ? event.touches[0].clientY : event.clientY

    this._offsetX = clientX - rect.left
    this._offsetY = clientY - rect.top
    this._startX = clientX
    this._startY = clientY
    this._dragging = true
    this._wasDragged = false

    if (event.type === "touchstart") {
      document.addEventListener("touchmove", this._onTouchMove, { passive: false })
      document.addEventListener("touchend", this._onTouchEnd)
    } else {
      document.addEventListener("mousemove", this._onMouseMove)
      document.addEventListener("mouseup", this._onMouseUp)
    }
  }

  _onMouseMove(event) { this._moveFab(event.clientX, event.clientY) }
  _onTouchMove(event) { event.preventDefault(); this._moveFab(event.touches[0].clientX, event.touches[0].clientY) }

  _moveFab(clientX, clientY) {
    if (!this._dragging) return
    if (Math.abs(clientX - this._startX) > 4 || Math.abs(clientY - this._startY) > 4) this._wasDragged = true

    const fab = this.fabTarget
    const maxX = window.innerWidth - fab.offsetWidth
    const maxY = window.innerHeight - fab.offsetHeight
    fab.style.left = Math.max(0, Math.min(clientX - this._offsetX, maxX)) + "px"
    fab.style.top = Math.max(0, Math.min(clientY - this._offsetY, maxY)) + "px"
    fab.style.right = "auto"
    fab.style.bottom = "auto"
  }

  _onMouseUp() { this._dragging = false; document.removeEventListener("mousemove", this._onMouseMove); document.removeEventListener("mouseup", this._onMouseUp) }
  _onTouchEnd() { this._dragging = false; document.removeEventListener("touchmove", this._onTouchMove); document.removeEventListener("touchend", this._onTouchEnd) }

  // ── Toggle chat box ──

  toggleBox(event) {
    if (this._wasDragged) { this._wasDragged = false; return }

    const box = this.chatBoxTarget
    if (box.style.display === "none") {
      box.style.display = "flex"
      this._loadChannel(this._currentChannel)
    } else {
      box.style.display = "none"
    }
  }

  // ── Channel switching ──

  switchChannel(event) {
    const channel = event.currentTarget.dataset.channel
    this._currentChannel = channel

    // Update active tab
    this.channelTabsTarget.querySelectorAll(".terminal-chat-channel-tab").forEach(btn => {
      btn.classList.toggle("terminal-chat-channel-tab--active", btn.dataset.channel === channel)
    })

    this._loadChannel(channel)
  }

  _loadChannel(channel) {
    this._closePickers()
    this.chatContentTarget.innerHTML = '<div class="terminal-chat-loading">LOADING...</div>'

    switch (channel) {
      case "world":
        this._loadWorld()
        break
      case "team":
        this._loadTeamList()
        break
      case "individual":
        this._loadFriendsList()
        break
    }
  }

  // ── World chat ──

  _loadWorld() {
    fetch("/messages/world", {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.text())
      .then(html => {
        this.chatContentTarget.innerHTML = html
        this._alignAllMessages()
        this._scrollToBottom()
        this._observeMessages()
      })
  }

  // ── Team chat ──

  _loadTeamList() {
    fetch("/messages/team_list", {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.text())
      .then(html => {
        this.chatContentTarget.innerHTML = html
      })
  }

  openTeamConversation(event) {
    const teamId = event.currentTarget.dataset.teamId
    this._currentTeamId = teamId

    this.chatContentTarget.innerHTML = '<div class="terminal-chat-loading">LOADING...</div>'

    fetch(`/messages/team_conversation/${teamId}`, {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.text())
      .then(html => {
        this.chatContentTarget.innerHTML = html
        this._alignAllMessages()
        this._scrollToBottom()
        this._observeMessages()
        const input = this.chatContentTarget.querySelector("[data-chat-target='messageInput']")
        if (input) input.focus()
      })
  }

  backToTeamList() {
    this._currentTeamId = null
    this._loadTeamList()
  }

  // ── Individual (friends) chat ──

  _loadFriendsList() {
    fetch("/messages/friends_list", {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.text())
      .then(html => {
        this.chatContentTarget.innerHTML = html
      })
  }

  openConversation(event) {
    const friendId = event.currentTarget.dataset.friendId
    this._currentFriendId = friendId

    this.chatContentTarget.innerHTML = '<div class="terminal-chat-loading">LOADING...</div>'

    fetch(`/messages/conversation/${friendId}`, {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.text())
      .then(html => {
        this.chatContentTarget.innerHTML = html
        this._alignAllMessages()
        this._scrollToBottom()
        this._observeMessages()
        const input = this.chatContentTarget.querySelector("[data-chat-target='messageInput']")
        if (input) input.focus()
      })
  }

  backToFriendsList() {
    this._currentFriendId = null
    this._loadFriendsList()
  }

  // ── Emoji & sticker pickers ──

  toggleEmojiPicker() {
    if (this.hasStickerPickerTarget) this.stickerPickerTarget.style.display = "none"
    if (this.hasEmojiPickerTarget) {
      const picker = this.emojiPickerTarget
      picker.style.display = picker.style.display === "none" ? "flex" : "none"
    }
  }

  toggleStickerPicker() {
    if (this.hasEmojiPickerTarget) this.emojiPickerTarget.style.display = "none"
    if (this.hasStickerPickerTarget) {
      const picker = this.stickerPickerTarget
      picker.style.display = picker.style.display === "none" ? "flex" : "none"
    }
  }

  insertEmoji(event) {
    const emoji = event.currentTarget.dataset.emoji
    const input = this.chatContentTarget.querySelector("[data-chat-target='messageInput']")
    if (input) {
      input.value += emoji
      input.focus()
    }
  }

  insertSticker(event) {
    const sticker = event.currentTarget.dataset.sticker
    const input = this.chatContentTarget.querySelector("[data-chat-target='messageInput']")
    if (input) {
      input.value = `sticker:${sticker}`
      // Auto-send sticker
      const form = this.chatContentTarget.querySelector("[data-chat-target='messageForm']")
      if (form) form.requestSubmit()
    }
    if (this.hasStickerPickerTarget) this.stickerPickerTarget.style.display = "none"
  }

  // ── Send message (all channel types) ──

  sendMessage(event) {
    event.preventDefault()

    const form = event.currentTarget
    const channelType = form.dataset.channelType
    const input = form.querySelector("[data-chat-target='messageInput']")
    const body = input.value.trim()

    if (!body) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const payload = { channel_type: channelType, body: body }

    if (channelType === "individual") {
      payload.receiver_id = form.dataset.friendId
    } else if (channelType === "team") {
      payload.team_id = form.dataset.teamId
    }

    fetch("/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify(payload)
    })
      .then(response => {
        if (response.ok) {
          input.value = ""
          input.focus()
          setTimeout(() => this._scrollToBottom(), 150)
        }
      })
  }

  // ── Message alignment ──

  _scrollToBottom() {
    const container = this.chatContentTarget.querySelector("[data-chat-target='messagesContainer']")
    if (container) container.scrollTop = container.scrollHeight
  }

  _applyMessageAlignment(el) {
    const userId = this.currentUserIdValue
    const msgs = el.dataset && el.dataset.senderId ? [el] : el.querySelectorAll ? el.querySelectorAll("[data-sender-id]") : []

    for (const msg of msgs) {
      const senderId = parseInt(msg.dataset.senderId, 10)
      msg.classList.remove("terminal-chat-msg--mine", "terminal-chat-msg--theirs")
      if (senderId === userId) {
        msg.classList.add("terminal-chat-msg--mine")
        const authorEl = msg.querySelector(".terminal-chat-msg-author")
        if (authorEl) authorEl.textContent = "YOU"
      } else {
        msg.classList.add("terminal-chat-msg--theirs")
      }
    }
  }

  _alignAllMessages() {
    const container = this.chatContentTarget.querySelector("[data-chat-target='messagesContainer']")
    if (!container) return
    container.querySelectorAll("[data-sender-id]").forEach(msg => this._applyMessageAlignment(msg))
  }

  _observeMessages() {
    if (this._mutationObserver) this._mutationObserver.disconnect()
    const container = this.chatContentTarget.querySelector("[data-chat-target='messagesContainer']")
    if (container) this._mutationObserver.observe(container, { childList: true, subtree: true })
  }

  _closePickers() {
    if (this.hasEmojiPickerTarget) this.emojiPickerTarget.style.display = "none"
    if (this.hasStickerPickerTarget) this.stickerPickerTarget.style.display = "none"
  }
}
