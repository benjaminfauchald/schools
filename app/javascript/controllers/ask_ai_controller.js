import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionForm", "questionInput", "submitButton", "messages", "messagesContainer", "loadingMessage"]
  static values = { 
    schoolId: Number,
    askUrl: String
  }

  connect() {
    this.scrollToBottom()
  }

  async askQuestion(event) {
    event.preventDefault()
    
    const question = this.questionInputTarget.value.trim()
    if (!question) return
    
    // Add user message to chat
    this.addUserMessage(question)
    
    // Clear input and disable form
    this.questionInputTarget.value = ""
    this.setFormDisabled(true)
    
    // Show loading message
    this.showLoading()
    
    try {
      const response = await fetch(this.askUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: new URLSearchParams({
          question: question
        })
      })

      const data = await response.json()
      
      // Hide loading message
      this.hideLoading()
      
      if (data.success) {
        this.addAiMessage(data.answer, data.sources, data.context_stats)
      } else {
        this.addErrorMessage(data.message || 'An error occurred while processing your question.')
      }
      
    } catch (error) {
      console.error('Ask AI Error:', error)
      this.hideLoading()
      this.addErrorMessage('Failed to get response from AI. Please try again.')
    }
    
    // Re-enable form
    this.setFormDisabled(false)
    this.questionInputTarget.focus()
  }

  useExample(event) {
    const question = event.currentTarget.dataset.question
    this.questionInputTarget.value = question
    this.questionInputTarget.focus()
  }

  addUserMessage(question) {
    const messageHtml = `
      <div class="flex items-start justify-end mb-6">
        <div class="flex-1 max-w-xs sm:max-w-md">
          <div class="bg-blue-600 text-white rounded-lg p-4">
            <div class="text-sm text-blue-100 mb-1">
              <span class="font-medium">You</span>
            </div>
            <div class="text-white">${this.escapeHtml(question)}</div>
          </div>
        </div>
        <div class="flex-shrink-0 ml-3">
          <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center">
            <svg class="w-4 h-4 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd"></path>
            </svg>
          </div>
        </div>
      </div>
    `
    
    this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
    this.scrollToBottom()
  }

  addAiMessage(answer, sources, contextStats) {
    const sourcesHtml = this.buildSourcesHtml(sources)
    const statsHtml = this.buildStatsHtml(contextStats)
    
    const messageHtml = `
      <div class="flex items-start mb-6">
        <div class="flex-shrink-0">
          <div class="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center">
            <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z" clip-rule="evenodd"></path>
            </svg>
          </div>
        </div>
        <div class="ml-3 flex-1">
          <div class="bg-gray-50 rounded-lg p-4">
            <div class="text-sm text-gray-600 mb-2">
              <span class="font-medium text-blue-600">AI Assistant</span>
            </div>
            <div class="text-gray-900 mb-3">${this.formatAnswer(answer)}</div>
            ${sourcesHtml}
            ${statsHtml}
          </div>
        </div>
      </div>
    `
    
    this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
    this.scrollToBottom()
  }

  addErrorMessage(error) {
    const messageHtml = `
      <div class="flex items-start mb-6">
        <div class="flex-shrink-0">
          <div class="w-8 h-8 bg-red-600 rounded-full flex items-center justify-center">
            <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
            </svg>
          </div>
        </div>
        <div class="ml-3 flex-1">
          <div class="bg-red-50 border border-red-200 rounded-lg p-4">
            <div class="text-sm text-red-600 mb-2">
              <span class="font-medium">Error</span>
            </div>
            <div class="text-red-800">${this.escapeHtml(error)}</div>
          </div>
        </div>
      </div>
    `
    
    this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
    this.scrollToBottom()
  }

  buildSourcesHtml(sources) {
    if (!sources || sources.length === 0) {
      return `
        <div class="mt-3 p-2 bg-amber-50 border border-amber-200 rounded text-sm text-amber-700">
          <span class="font-medium">⚠️ No sources found</span> - This response may not be based on your school's content.
        </div>
      `
    }

    const sourcesItems = sources.map(source => {
      const typeIcon = this.getSourceIcon(source.type)
      const relevanceColor = this.getRelevanceColor(source.relevance_score)
      
      return `
        <div class="flex items-center justify-between py-1">
          <div class="flex items-center flex-1">
            ${typeIcon}
            <span class="text-sm text-gray-700 truncate">${this.escapeHtml(source.title)}</span>
          </div>
          <div class="ml-2 flex-shrink-0">
            <span class="text-xs px-2 py-1 ${relevanceColor} rounded-full">
              ${Math.round((1 - source.relevance_score) * 100)}% match
            </span>
          </div>
        </div>
      `
    }).join('')

    return `
      <div class="mt-3 p-3 bg-blue-50 border border-blue-200 rounded">
        <div class="flex items-center mb-2">
          <svg class="w-4 h-4 text-blue-600 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-sm font-medium text-blue-800">Sources (${sources.length})</span>
        </div>
        <div class="space-y-1">
          ${sourcesItems}
        </div>
      </div>
    `
  }

  buildStatsHtml(contextStats) {
    if (!contextStats || !contextStats.content_found) {
      return ''
    }

    return `
      <div class="mt-2 text-xs text-gray-500">
        Searched ${contextStats.sources_found} sources • ${contextStats.tokens_used} tokens used
      </div>
    `
  }

  getSourceIcon(type) {
    switch (type) {
      case 'transcript':
        return `<svg class="w-4 h-4 text-red-500 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm3 2h6v4H7V5zm8 8v2h1v-2h-1zm-2-2H7v4h6v-4z" clip-rule="evenodd"></path>
        </svg>`
      case 'transcript_segment':
        return `<svg class="w-4 h-4 text-orange-500 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"></path>
        </svg>`
      case 'document':
        return `<svg class="w-4 h-4 text-blue-500 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd"></path>
        </svg>`
      default:
        return `<svg class="w-4 h-4 text-gray-500 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4z" clip-rule="evenodd"></path>
        </svg>`
    }
  }

  getRelevanceColor(score) {
    const percentage = (1 - score) * 100
    if (percentage >= 80) return 'bg-green-100 text-green-800'
    if (percentage >= 60) return 'bg-yellow-100 text-yellow-800'
    return 'bg-gray-100 text-gray-800'
  }

  formatAnswer(answer) {
    // Convert line breaks to paragraphs and preserve formatting
    return answer
      .split('\n\n')
      .map(paragraph => `<p class="mb-2 last:mb-0">${this.escapeHtml(paragraph).replace(/\n/g, '<br>')}</p>`)
      .join('')
  }

  showLoading() {
    this.loadingMessageTarget.classList.remove('hidden')
    this.scrollToBottom()
  }

  hideLoading() {
    this.loadingMessageTarget.classList.add('hidden')
  }

  setFormDisabled(disabled) {
    this.questionInputTarget.disabled = disabled
    this.submitButtonTarget.disabled = disabled
    
    if (disabled) {
      this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  scrollToBottom() {
    // Use setTimeout to ensure DOM updates are complete
    setTimeout(() => {
      this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
    }, 100)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}