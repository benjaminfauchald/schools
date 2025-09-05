import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "modal", "modalBody", "messages", "sendButton", "inputField"]
  static values = { schoolId: Number, schoolName: String }

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  }

  openModal(event) {
    event.preventDefault()
    let query = this.inputTarget.value.trim()
    
    // Use placeholder text if input is empty
    if (!query) {
      query = this.inputTarget.placeholder
    }

    // Show modal
    this.modalTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    
    // Always clear previous messages for new questions
    this.messagesTarget.innerHTML = ''
    
    // Add user message
    this.addMessage(query, 'user')
    
    // Clear input
    this.inputTarget.value = ''
    
    // Send query to AI
    this.sendToAI(query)
  }

  closeModal(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }

  sendMessage(event) {
    event.preventDefault()
    const query = this.inputFieldTarget.value.trim()
    
    if (!query) return
    
    // Clear previous messages for new questions
    this.messagesTarget.innerHTML = ''
    
    // Add user message
    this.addMessage(query, 'user')
    
    // Clear input
    this.inputFieldTarget.value = ''
    
    // Send to AI
    this.sendToAI(query)
  }

  async sendToAI(query) {
    // Show typing indicator
    this.addTypingIndicator()
    
    try {
      const locale = document.body.dataset.locale || 'en'
      const response = await fetch(`/${locale}/schools/${this.schoolIdValue}/ai_chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          message: query,
          school_id: this.schoolIdValue
        })
      })

      const data = await response.json()
      
      // Remove typing indicator
      this.removeTypingIndicator()
      
      if (response.ok) {
        this.addMessage(data.response, 'ai')
      } else {
        // Get error message from data attributes or use fallback
      const errorMessage = this.element.dataset.errorMessage || 'Sorry, I encountered an error. Please try again.'
      this.addMessage(errorMessage, 'ai')
      }
    } catch (error) {
      console.error('AI Chat error:', error)
      this.removeTypingIndicator()
      // Get error message from data attributes or use fallback
      const errorMessage = this.element.dataset.errorMessage || 'Sorry, I encountered an error. Please try again.'
      this.addMessage(errorMessage, 'ai')
    }
  }

  addMessage(content, type) {
    const messageDiv = document.createElement('div')
    messageDiv.className = `mb-4 ${type === 'user' ? 'text-right' : 'text-left'}`
    
    const messageContent = document.createElement('div')
    messageContent.className = type === 'user' 
      ? 'inline-block max-w-2xl lg:max-w-4xl px-4 py-2 rounded-lg bg-blue-600 text-white rounded-br-none'
      : 'block w-full px-4 py-2 rounded-lg bg-gray-100 text-gray-900 rounded-bl-none'
    
    if (type === 'ai') {
      // Render markdown for AI responses
      messageContent.innerHTML = this.renderMarkdown(content)
      messageContent.className += ' prose prose-sm max-w-none'
    } else {
      messageContent.textContent = content
    }
    
    messageDiv.appendChild(messageContent)
    this.messagesTarget.appendChild(messageDiv)
    
    // Scroll to bottom
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  addTypingIndicator() {
    const typingDiv = document.createElement('div')
    typingDiv.id = 'typing-indicator'
    typingDiv.className = 'mb-4 text-left'
    typingDiv.innerHTML = `
      <div class="inline-block bg-gray-100 px-4 py-2 rounded-lg rounded-bl-none">
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
        </div>
      </div>
    `
    this.messagesTarget.appendChild(typingDiv)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  removeTypingIndicator() {
    const typingIndicator = document.getElementById('typing-indicator')
    if (typingIndicator) {
      typingIndicator.remove()
    }
  }

  renderMarkdown(text) {
    // Enhanced markdown rendering
    let html = text
      // Bold text
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      // Italic text
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      // Headers
      .replace(/^### (.*$)/gm, '<h3 class="text-lg font-semibold text-gray-900 mb-2">$1</h3>')
      .replace(/^## (.*$)/gm, '<h2 class="text-xl font-semibold text-gray-900 mb-3">$1</h2>')
      // List items
      .replace(/^• (.+)/gm, '<li class="ml-4">$1</li>')
      .replace(/^- (.+)/gm, '<li class="ml-4">$1</li>')
      // Paragraphs
      .replace(/\n\n/g, '</p><p class="mb-3">')
      .replace(/\n/g, '<br>')
      
    // Wrap in paragraphs if not already wrapped
    if (!html.includes('<p') && !html.includes('<h') && !html.includes('<li')) {
      html = `<p class="mb-3">${html}</p>`
    } else {
      html = `<div>${html}</div>`
    }
    
    // Wrap consecutive list items in ul tags
    html = html.replace(/(<li[^>]*>.*?<\/li>)(\s*<li[^>]*>.*?<\/li>)*/gs, '<ul class="list-disc list-inside mb-3 space-y-1">$&</ul>')
    
    return html
  }

  handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      if (event.target === this.inputTarget) {
        // From the hero input - open modal
        this.openModal(event)
      } else {
        // From the modal input - send message
        this.sendMessage(event)
      }
    }
  }
}