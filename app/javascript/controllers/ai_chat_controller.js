import { Controller } from "@hotwired/stimulus"

// AI Chat controller for real-time chat functionality
// Handles message sending, suggested questions, and data analysis
export default class extends Controller {
  static targets = [
    "messagesContainer",
    "messageInput", 
    "sendButton",
    "loadingMessage",
    "completenessScore",
    "analysisButton",
    "suggestedQuestions",
    "sourcesSidebar",
    "sourceCount",
    "sourceCountNumber"
  ]

  static values = {
    schoolId: String,
    conversationId: String,
    messagesUrl: String,
    suggestionsUrl: String,
    analysisUrl: String,
    existingSources: Array
  }

  connect() {
    this.scrollToBottom()
    this.loadSuggestions()
    this.allSources = new Map() // Track all sources used in conversation
    this.loadingButtons = new Set() // Track buttons in loading state
    
    // Load existing sources from the JSON script tag
    this.loadExistingSources()
    this.updateSourcesSidebar() // Initialize sidebar
    
    // Format existing messages with markdown
    this.formatExistingMessages()
    
    // Load total available sources count
    this.loadTotalSourcesCount()
  }

  // Send a user message to the AI
  async sendMessage(event) {
    console.log('🔵 sendMessage called')
    event.preventDefault()
    
    const message = this.messageInputTarget.value.trim()
    console.log('🔵 Message to send:', message)
    if (!message) {
      console.log('🔴 No message to send, returning early')
      return
    }

    // Disable input while processing
    console.log('🔵 Setting loading to true')
    this.setLoading(true)
    
    // Add user message to UI immediately
    console.log('🔵 Adding user message to UI')
    this.addUserMessageToUI(message)
    
    // Clear input
    this.messageInputTarget.value = ""
    
    try {
      console.log('🔵 About to call postMessage')
      const response = await this.postMessage(message)
      console.log('🔵 postMessage response:', response)
      
      if (response.success) {
        console.log('🔵 Response successful, adding assistant message')
        // Add assistant message to UI
        this.addAssistantMessageToUI(response.assistant_message)
        
        // Update conversation ID if needed
        if (response.conversation_id && !this.conversationIdValue) {
          this.conversationIdValue = response.conversation_id
        }
        
        // Refresh suggestions after first message
        if (this.suggestedQuestionsTarget.children.length === 0) {
          this.refreshSuggestions()
        }
      } else {
        console.log('🔴 Response failed:', response.error)
        this.showErrorMessage(response.error)
        
        // Add error message to UI if available
        if (response.assistant_message) {
          this.addAssistantMessageToUI(response.assistant_message)
        }
      }
      
    } catch (error) {
      console.error('🔴 AI Chat Error:', error)
      this.showErrorMessage('Failed to send message. Please try again.')
    } finally {
      console.log('🔵 sendMessage finally block - setting loading to false')
      this.setLoading(false)
      this.scrollToBottom()
      this.messageInputTarget.focus()
      console.log('🔵 sendMessage completed')
    }
  }

  // Send a suggested question
  async sendSuggestedQuestion(event) {
    const message = event.currentTarget.dataset.message
    const button = event.currentTarget
    
    console.log('🔵 sendSuggestedQuestion called', {
      message: message,
      button: button,
      buttonText: button.textContent.trim(),
      isQuickAction: !this.suggestedQuestionsTarget.contains(button)
    })
    
    if (message) {
      // Add immediate visual feedback to the clicked button
      console.log('🔵 Setting button loading to true')
      this.setButtonLoading(button, true)
      
      // Set the message and send it
      this.messageInputTarget.value = message
      
      // Call sendMessage and wait for completion
      try {
        console.log('🔵 About to call sendMessage')
        await this.sendMessage(event)
        console.log('🔵 sendMessage completed successfully')
      } catch (error) {
        console.error('🔴 Error sending suggested question:', error)
      } finally {
        // Always reset the button after completion
        console.log('🔵 Finally block - resetting button', button)
        this.setButtonLoading(button, false)
        console.log('🔵 Button reset completed')
      }
    }
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    // Send message on Ctrl+Enter or Cmd+Enter
    if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  // Refresh suggested questions
  async refreshSuggestions(event) {
    if (event) event.preventDefault()
    
    try {
      const response = await fetch(this.suggestionsUrlValue, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      const data = await response.json()
      
      if (data.success && data.questions) {
        this.updateSuggestedQuestions(data.questions)
      }
    } catch (error) {
      console.error('Failed to refresh suggestions:', error)
    }
  }

  // Run data analysis
  async runAnalysis(event) {
    if (event) event.preventDefault()
    
    // Store button reference FIRST before any DOM changes
    const clickedButton = event ? event.currentTarget : null
    const isQuickActionButton = clickedButton && clickedButton !== this.analysisButtonTarget
    
    if (isQuickActionButton) {
      this.setButtonLoading(clickedButton, true)
    }
    
    // Disable analysis button
    this.analysisButtonTarget.disabled = true
    this.analysisButtonTarget.textContent = 'Analyzing...'
    
    try {
      const response = await fetch(this.analysisUrlValue, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Add analysis message to chat if provided
        if (data.message) {
          this.addAssistantMessageToUI(data.message)
        }
        
        // Update completeness score if provided
        if (data.analysis && data.analysis.completeness_score) {
          this.updateCompletenessScore(data.analysis.completeness_score)
        }
        
        this.scrollToBottom()
      } else {
        this.showErrorMessage(data.error || 'Analysis failed')
      }
      
    } catch (error) {
      console.error('Analysis error:', error)
      this.showErrorMessage('Failed to analyze data. Please try again.')
    } finally {
      // Re-enable analysis button
      this.analysisButtonTarget.disabled = false
      this.analysisButtonTarget.innerHTML = `
        <svg class="w-4 h-4 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
        </svg>
        Analyze Data
      `
      
      // Reset any Quick Action buttons that might have triggered this
      if (isQuickActionButton) {
        this.setButtonLoading(clickedButton, false)
      }
    }
  }

  // Private methods

  async postMessage(message) {
    const response = await fetch(this.messagesUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({ message: message })
    })

    return await response.json()
  }

  async loadSuggestions() {
    // Only load suggestions if container is empty
    if (this.suggestedQuestionsTarget.children.length === 0) {
      this.refreshSuggestions()
    }
  }

  addUserMessageToUI(messageText) {
    const messageHTML = this.createUserMessageHTML(messageText)
    // Add new messages at the top (newest first)
    this.messagesContainerTarget.querySelector('.space-y-6').insertAdjacentHTML('afterbegin', messageHTML)
  }

  addAssistantMessageToUI(messageData) {
    const messageHTML = this.createAssistantMessageHTML(messageData)
    // Add new messages at the top (newest first)
    this.messagesContainerTarget.querySelector('.space-y-6').insertAdjacentHTML('afterbegin', messageHTML)
    
    // Add sources to sidebar
    if (messageData.sources && messageData.sources.length > 0) {
      this.addSourcesToSidebar(messageData.sources)
    }
  }

  createUserMessageHTML(messageText) {
    const now = new Date()
    const timeDisplay = this.formatTimeDisplay(now)
    
    return `
      <div class="flex items-start space-x-3 flex-row-reverse space-x-reverse">
        <div class="bg-gray-100 rounded-full p-2 flex-shrink-0">
          <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
          </svg>
        </div>
        <div class="flex-1">
          <div class="bg-gray-50 text-right rounded-lg p-4">
            <div class="text-gray-800">
              ${this.escapeHtml(messageText)}
            </div>
            <div class="text-xs text-gray-500 mt-2 text-right">
              ${timeDisplay}
            </div>
          </div>
        </div>
      </div>
    `
  }

  createAssistantMessageHTML(messageData) {
    const content = this.formatMessageContent(messageData.content)
    const sources = this.formatSources(messageData.sources || [])
    const timeDisplay = messageData.age_display || this.formatTimeDisplay(new Date())
    
    return `
      <div class="flex items-start space-x-3">
        <div class="bg-blue-100 rounded-full p-2 flex-shrink-0">
          <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
          </svg>
        </div>
        <div class="flex-1">
          <div class="bg-blue-50 rounded-lg p-4">
            <div class="text-gray-800">
              ${content}
            </div>
            ${sources}
            <div class="text-xs text-gray-500 mt-2">
              ${timeDisplay}
            </div>
          </div>
        </div>
      </div>
    `
  }

  formatMessageContent(content) {
    // Basic markdown formatting with softer gray colors
    let formatted = content
    
    // Headers (### becomes h3, ## becomes h2, # becomes h1)
    formatted = formatted.replace(/^### (.+)$/gm, '<h3 class="text-lg font-semibold text-gray-700 mt-4 mb-2">$1</h3>')
    formatted = formatted.replace(/^## (.+)$/gm, '<h2 class="text-xl font-semibold text-gray-700 mt-4 mb-2">$1</h2>')
    formatted = formatted.replace(/^# (.+)$/gm, '<h1 class="text-2xl font-semibold text-gray-700 mt-4 mb-2">$1</h1>')
    
    // Bold text (**text** becomes <strong>)
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong class="font-semibold text-gray-700">$1</strong>')
    
    // Italic text (*text* becomes <em>)
    formatted = formatted.replace(/\*([^*]+)\*/g, '<em class="italic text-gray-600">$1</em>')
    
    // Unordered list items (- item becomes <li>)
    formatted = formatted.replace(/^- (.+)$/gm, '<li class="ml-4 mb-1 text-gray-600">• $1</li>')
    
    // Wrap consecutive list items in <ul>
    formatted = formatted.replace(/(<li[^>]*>.*<\/li>\s*)+/gs, '<ul class="list-none space-y-1 mb-3">$&</ul>')
    
    // Code blocks (```code``` becomes <pre><code>)
    formatted = formatted.replace(/```([^`]+)```/gs, '<pre class="bg-gray-100 p-3 rounded text-sm font-mono overflow-x-auto mb-3 text-gray-700"><code>$1</code></pre>')
    
    // Inline code (`code` becomes <code>)
    formatted = formatted.replace(/`([^`]+)`/g, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm font-mono text-gray-700">$1</code>')
    
    // Paragraphs (double line breaks)
    formatted = formatted.replace(/\n\n/g, '</p><p class="mb-3 text-gray-600">')
    
    // Single line breaks
    formatted = formatted.replace(/\n/g, '<br>')
    
    // Wrap in paragraph if not already wrapped
    if (!formatted.startsWith('<')) {
      formatted = '<p class="mb-3 text-gray-600">' + formatted + '</p>'
    }
    
    return formatted
  }

  formatSources(sources) {
    if (!sources || sources.length === 0) return ''
    
    const sourceItems = sources.map(source => {
      let icon = '📄'
      let url = ''
      
      switch (source.type) {
        case 'document':
          icon = '📄'
          break
        case 'transcript':
        case 'transcript_segment':
          icon = '🎥'
          url = source.youtube_url
          break
        case 'school_data':
          icon = '🏫'
          break
        case 'place_data':
          icon = '📍'
          break
      }
      
      const linkHTML = url 
        ? `<a href="${url}" target="_blank" class="text-blue-500 hover:text-blue-700">
             <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
               <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
             </svg>
           </a>`
        : ''
      
      return `
        <div class="flex items-center space-x-2 text-xs text-blue-700">
          <span>${icon}</span>
          <span class="font-medium">${source.type}:</span>
          <span>${this.escapeHtml(source.title || source.description || 'Unknown')}</span>
          ${linkHTML}
        </div>
      `
    }).join('')
    
    return `
      <div class="mt-3 pt-3 border-t border-blue-200">
        <div class="text-xs text-blue-600 font-medium mb-2">Sources used:</div>
        <div class="space-y-1">
          ${sourceItems}
        </div>
      </div>
    `
  }

  updateSuggestedQuestions(questions) {
    const questionsHTML = questions.map(question => `
      <button
        type="button"
        class="w-full text-left p-3 bg-gray-50 hover:bg-blue-50 rounded-md text-sm transition-colors"
        data-action="click->ai-chat#sendSuggestedQuestion"
        data-message="${this.escapeHtml(question.text)}">
        <div class="flex items-start">
          <svg class="w-4 h-4 text-blue-500 mr-2 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <span class="text-gray-700">${this.escapeHtml(question.text)}</span>
        </div>
      </button>
    `).join('')

    this.suggestedQuestionsTarget.innerHTML = questionsHTML
  }

  updateCompletenessScore(score) {
    if (this.hasCompletenessScoreTarget) {
      this.completenessScoreTarget.textContent = `${score}%`
    }
  }

  updateSourceCount(count) {
    console.log('🔵 updateSourceCount called with:', count)
    console.log('🔵 hasSourceCountTarget:', this.hasSourceCountTarget)
    console.log('🔵 hasSourceCountNumberTarget:', this.hasSourceCountNumberTarget)
    
    if (this.hasSourceCountTarget && this.hasSourceCountNumberTarget) {
      this.sourceCountNumberTarget.textContent = count
      console.log('🔵 Updated source count text to:', count)
      
      if (count > 0) {
        this.sourceCountTarget.style.display = 'block'
        console.log('🔵 Showing source count box')
      } else {
        this.sourceCountTarget.style.display = 'none'
        console.log('🔵 Hiding source count box')
      }
    } else {
      console.log('🔴 Source count targets not found!')
    }
  }

  setLoading(loading) {
    console.log('🔵 setLoading called', { 
      loading: loading, 
      loadingButtonsCount: this.loadingButtons.size 
    })
    
    this.sendButtonTarget.disabled = loading
    this.messageInputTarget.disabled = loading
    
    // Disable/enable all suggested question buttons
    this.setSuggestedQuestionsLoading(loading)
    
    if (loading) {
      this.loadingMessageTarget.classList.remove('hidden')
      this.sendButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      this.loadingMessageTarget.classList.add('hidden')
      this.sendButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
      // Reset all suggested question buttons
      console.log('🔵 About to reset all buttons')
      this.resetAllSuggestedButtons()
      // Reset all quick action buttons
      this.resetAllQuickActionButtons()
      console.log('🔵 All buttons reset completed')
    }
  }

  setButtonLoading(button, loading) {
    console.log('🔵 setButtonLoading called', { 
      loading: loading, 
      button: button,
      buttonText: button.textContent.trim(),
      hasOriginalContent: button.hasAttribute('data-original-content')
    })
    
    if (loading) {
      // Track this button as loading
      this.loadingButtons.add(button)
      console.log('🔵 Added button to tracking, total:', this.loadingButtons.size)
      
      button.disabled = true
      button.classList.add('opacity-75', 'cursor-not-allowed')
      
      // Add a loading spinner to the button
      const originalContent = button.innerHTML
      button.setAttribute('data-original-content', originalContent)
      console.log('🔵 Stored original content:', originalContent.substring(0, 100))
      
      button.innerHTML = `
        <div class="flex items-start">
          <svg class="w-4 h-4 text-blue-500 mr-3 mt-0.5 flex-shrink-0 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          <span class="text-gray-600">Sending question...</span>
        </div>
      `
      console.log('🔵 Button loading state applied')
    } else {
      // Remove from tracking
      this.loadingButtons.delete(button)
      console.log('🔵 Removed button from tracking, remaining:', this.loadingButtons.size)
      
      button.disabled = false
      button.classList.remove('opacity-75', 'cursor-not-allowed')
      
      // Restore original content
      const originalContent = button.getAttribute('data-original-content')
      console.log('🔵 Restoring original content:', originalContent ? originalContent.substring(0, 100) : 'NONE')
      
      if (originalContent) {
        button.innerHTML = originalContent
        button.removeAttribute('data-original-content')
        console.log('🔵 Original content restored')
      } else {
        console.log('🔴 No original content found!')
      }
    }
  }

  setSuggestedQuestionsLoading(loading) {
    const suggestedButtons = this.suggestedQuestionsTarget.querySelectorAll('button')
    suggestedButtons.forEach(button => {
      button.disabled = loading
      if (loading) {
        button.classList.add('opacity-50', 'cursor-not-allowed')
      } else {
        button.classList.remove('opacity-50', 'cursor-not-allowed')
      }
    })
  }

  resetAllSuggestedButtons() {
    const suggestedButtons = this.suggestedQuestionsTarget.querySelectorAll('button')
    suggestedButtons.forEach(button => {
      this.setButtonLoading(button, false)
    })
  }

  resetAllQuickActionButtons() {
    console.log('🔵 resetAllQuickActionButtons called, buttons to reset:', this.loadingButtons.size)
    
    // Reset all buttons that are currently being tracked as loading
    this.loadingButtons.forEach((button, index) => {
      console.log(`🔵 Resetting button ${index + 1}:`, button.textContent.trim())
      this.setButtonLoading(button, false)
    })
    
    // Also clear the set
    this.loadingButtons.clear()
    console.log('🔵 All loading buttons cleared')
  }

  showErrorMessage(message) {
    // Create a temporary error message
    const errorHTML = `
      <div class="flex items-start space-x-3">
        <div class="bg-red-100 rounded-full p-2 flex-shrink-0">
          <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <div class="flex-1">
          <div class="bg-red-50 rounded-lg p-4">
            <p class="text-red-800">${this.escapeHtml(message)}</p>
          </div>
        </div>
      </div>
    `
    
    this.messagesContainerTarget.insertAdjacentHTML('beforeend', errorHTML)
  }

  scrollToBottom() {
    // Since messages are now ordered newest first (top), scroll to top for new messages
    this.messagesContainerTarget.scrollTop = 0
  }

  formatTimeDisplay(date) {
    const now = new Date()
    const diffMs = now - date
    const diffMins = Math.floor(diffMs / 60000)
    
    if (diffMins < 1) return 'just now'
    if (diffMins < 60) return `${diffMins}m ago`
    
    const diffHours = Math.floor(diffMins / 60)
    if (diffHours < 24) return `${diffHours}h ago`
    
    return date.toLocaleDateString()
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  addSourcesToSidebar(sources) {
    if (!sources || sources.length === 0) {
      return
    }
    
    sources.forEach(source => {
      // Create a unique key for each source
      const sourceKey = this.createSourceKey(source)
      
      if (!this.allSources.has(sourceKey)) {
        this.allSources.set(sourceKey, {
          ...source,
          usageCount: 1,
          firstUsed: new Date(),
          messageIds: [Date.now()]
        })
      } else {
        // Increment usage count
        const existingSource = this.allSources.get(sourceKey)
        existingSource.usageCount += 1
        existingSource.messageIds.push(Date.now())
      }
    })
    
    this.updateSourcesSidebar()
  }

  createSourceKey(source) {
    // Create a unique key based on source type and identifier
    const type = source.type || source['type']
    switch (type) {
      case 'document':
      case 'Document':
        return `doc_${source.id || source['id'] || source.title || source['title']}`
      case 'transcript':
      case 'Video Transcript':
        return `video_${source.video_id || source['video_id']}`
      case 'transcript_segment':
        return `segment_${source.video_id || source['video_id']}_${source.start_time || source['start_time']}`
      case 'school_data':
      case 'School Information':
        return `school_${source.field_name || source['field_name']}`
      case 'place_data':
      case 'Location Data':
        return `place_${source.field_name || source['field_name']}`
      default:
        return `generic_${source.title || source['title'] || source.description || source['description']}`
    }
  }

  updateSourcesSidebar() {
    if (!this.hasSourcesSidebarTarget) {
      return
    }
    
    const sortedSources = Array.from(this.allSources.entries())
      .sort(([,a], [,b]) => b.usageCount - a.usageCount) // Sort by usage count
    
    if (sortedSources.length === 0) {
      this.sourcesSidebarTarget.innerHTML = `
        <div class="text-sm text-gray-500 italic">
          Sources will appear here as the AI references them in responses.
        </div>
      `
      return
    }

    const sourcesHTML = sortedSources.map(([key, source]) => {
      return this.createSourceItemHTML(source)
    }).join('')

    this.sourcesSidebarTarget.innerHTML = `
      <div class="text-xs text-gray-500 mb-3">
        ${sortedSources.length} unique source${sortedSources.length !== 1 ? 's' : ''} referenced in conversation
      </div>
      ${sourcesHTML}
    `
  }

  async loadTotalSourcesCount() {
    try {
      // Create URL for sources count endpoint
      const sourcesCountUrl = this.messagesUrlValue.replace('/ai_chat_message', '/sources_count')
      
      const response = await fetch(sourcesCountUrl, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        const totalCount = data.total_sources || 0
        
        // Update header with total available sources
        this.updateSourceCount(totalCount)
      } else {
        // Fallback: hide the counter
        this.updateSourceCount(0)
      }
    } catch (error) {
      console.error('Failed to load total sources count:', error)
      // Fallback: hide the counter
      this.updateSourceCount(0)
    }
  }

  createSourceItemHTML(source) {
    let icon = '📄'
    let typeLabel = 'Document'
    let title = source.title || source['title'] || source.description || source['description'] || 'Unknown'
    let subtitle = ''
    let url = source.url || source['url']
    
    const type = source.type || source['type']
    switch (type) {
      case 'document':
      case 'Document':
        icon = source.icon || source['icon'] || '📄'
        typeLabel = 'Document'
        subtitle = source.filename || source['filename'] ? `File: ${source.filename || source['filename']}` : ''
        break
      case 'transcript':
      case 'Video Transcript':
        icon = source.icon || source['icon'] || '🎥'
        typeLabel = 'Video'
        title = source.video_title || source['video_title'] || `Video ${source.video_id || source['video_id']}`
        subtitle = 'Full transcript'
        url = source.youtube_url || source['youtube_url']
        break
      case 'transcript_segment':
        icon = source.icon || source['icon'] || '🎥'
        typeLabel = 'Video Segment'
        title = source.video_title || source['video_title'] || `Video ${source.video_id || source['video_id']}`
        subtitle = this.formatVideoTimestamp(
          source.start_time || source['start_time'], 
          source.end_time || source['end_time']
        )
        url = source.youtube_url || source['youtube_url']
        break
      case 'school_data':
      case 'School Information':
        icon = source.icon || source['icon'] || '🏫'
        typeLabel = 'School Data'
        title = source.field_name || source['field_name'] || title
        subtitle = 'Profile information'
        break
      case 'place_data':
      case 'Location Data':
        icon = source.icon || source['icon'] || '📍'
        typeLabel = 'Location Data'
        title = source.field_name || source['field_name'] || title
        subtitle = 'Google Places info'
        url = source.google_maps_url || source['google_maps_url']
        break
    }

    const linkHTML = url 
      ? `<a href="${url}" target="_blank" class="text-blue-500 hover:text-blue-600 text-xs">
           <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
           </svg>
         </a>`
      : ''

    const usageBadge = source.usageCount > 1 
      ? `<span class="bg-blue-100 text-blue-800 text-xs px-1.5 py-0.5 rounded-full">${source.usageCount}x</span>`
      : ''

    return `
      <div class="border border-gray-200 rounded-lg p-3 hover:bg-gray-50 transition-colors">
        <div class="flex items-start justify-between">
          <div class="flex items-start space-x-2 flex-1">
            <span class="text-lg flex-shrink-0">${icon}</span>
            <div class="flex-1 min-w-0">
              <div class="flex items-center space-x-2">
                <div class="text-xs font-medium text-gray-900 break-words break-all">
                  ${this.escapeHtml(title)}
                </div>
                ${usageBadge}
              </div>
              <div class="text-xs text-gray-500">${typeLabel}</div>
              ${subtitle ? `<div class="text-xs text-gray-400 mt-1 break-words">${subtitle}</div>` : ''}
            </div>
          </div>
          ${linkHTML}
        </div>
      </div>
    `
  }

  formatVideoTimestamp(startTime, endTime) {
    const formatTime = (seconds) => {
      const mins = Math.floor(seconds / 60)
      const secs = seconds % 60
      return `${mins}:${secs.toString().padStart(2, '0')}`
    }

    if (startTime && endTime) {
      return `${formatTime(startTime)} - ${formatTime(endTime)}`
    } else if (startTime) {
      return `from ${formatTime(startTime)}`
    }
    return 'Video segment'
  }

  loadExistingSources() {
    try {
      const scriptElement = document.getElementById('ai-chat-existing-sources')
      if (scriptElement && scriptElement.textContent.trim()) {
        const existingSources = JSON.parse(scriptElement.textContent.trim())
        
        if (existingSources && existingSources.length > 0) {
          this.addSourcesToSidebar(existingSources)
        }
      }
    } catch (error) {
      console.error('Error loading existing sources:', error)
    }
  }

  formatExistingMessages() {
    // Find all existing message content elements and format them
    const messageElements = document.querySelectorAll('[data-ai-chat-target="messageContent"]')
    messageElements.forEach(element => {
      const rawContent = element.textContent
      const formattedContent = this.formatMessageContent(rawContent)
      element.innerHTML = formattedContent
    })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
}