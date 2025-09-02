import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["videosContainer", "videoGrid", "loadingState", "errorState", "emptyState", "refreshButton", "cacheInfo", "cacheAge", "pollingIndicator"]
  static values = { 
    schoolId: Number,
    fetchUrl: String,
    toggleUrl: String
  }

  async connect() {
    console.log('🔌 CONNECT: Starting YouTube videos controller')
    this.lastReloadTime = 0 // Prevent rapid successive reloads
    
    // Load videos first, then start polling
    await this.loadVideos()
    this.startPolling()
    console.log('🔌 CONNECT: Initial load complete, polling started')
    
    // Set up the "Generate All Transcripts" button
    this.setupBulkTranscriptButton()
  }
  
  disconnect() {
    this.stopPolling()
  }

  async loadVideos(forceRefresh = false) {
    this.showLoadingState()
    
    try {
      const url = forceRefresh ? `${this.fetchUrlValue}?refresh=true` : this.fetchUrlValue
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        this.renderVideos(data.videos)
        this.updateCacheInfo(data)
        this.showVideosContainer()
        
        if (data.was_refreshed) {
          this.showTemporaryMessage('Videos refreshed successfully!', 'success')
        }
      } else {
        this.showErrorState(data.message || 'Failed to load videos')
      }
    } catch (error) {
      console.error('Error loading videos:', error)
      this.showErrorState('Network error occurred while loading videos')
    }
  }

  renderVideos(videos) {
    console.log(`🎬 RENDER: renderVideos called with ${videos.length} videos`)
    if (videos.length === 0) {
      this.showEmptyState()
      return
    }

    // Log transcript statuses from server
    videos.forEach((video, index) => {
      if (index < 5) { // Log first 5 videos
        console.log(`🎬 RENDER: Video ${video.video_key || video.video_id} transcript_status:`, video.transcript_status)
      }
    })

    const videosHtml = videos.map(video => this.renderVideoCard(video)).join('')
    if (this.hasVideoGridTarget) {
      this.videoGridTarget.innerHTML = videosHtml
    } else {
      this.videosContainerTarget.innerHTML = videosHtml
    }
    console.log(`🎬 RENDER: Finished rendering ${videos.length} video cards`)
  }

  renderVideoCard(video) {
    const visibilityClass = video.visible ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
    const visibilityText = video.visible ? 'Visible' : 'Hidden'
    const opacityClass = video.visible ? '' : 'opacity-50'
    
    return `
      <div class="relative group bg-white rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow"
           data-video-key="${video.video_key}">
        <!-- Video Thumbnail -->
        <div class="relative aspect-video bg-gray-100">
          <img src="${video.thumbnail_url}" 
               alt="${this.escapeHtml(video.title)}"
               class="w-full h-full object-cover ${opacityClass} transition-opacity duration-200"
               loading="lazy">
          
          <!-- Duration Badge -->
          ${video.duration_formatted ? `
            <div class="absolute bottom-1 right-1 bg-black bg-opacity-75 text-white text-xs px-1.5 py-0.5 rounded text-xs">
              ${video.duration_formatted}
            </div>
          ` : ''}
          
          <!-- Transcript Status Badge -->
          ${this.renderTranscriptBadge(video)}
          
          <!-- Play Button Overlay -->
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="w-12 h-12 bg-red-600 bg-opacity-80 rounded-full flex items-center justify-center group-hover:bg-opacity-100 transition-all">
              <svg class="w-4 h-4 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </div>
          </div>
        </div>
        
        <!-- Video Info -->
        <div class="p-3">
          <h3 class="font-medium text-gray-900 text-xs line-clamp-2 mb-1.5" title="${this.escapeHtml(video.title)}">
            ${this.escapeHtml(video.title)}
          </h3>
          
          <div class="flex items-center justify-between text-xs text-gray-500 mb-2">
            <span class="truncate mr-2">${video.view_count_formatted || '0 views'}</span>
            <span class="text-xs">${this.formatDate(video.published_at)}</span>
          </div>
          
          <!-- Action Buttons -->
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-2">
              <!-- View on YouTube -->
              <a href="https://www.youtube.com/watch?v=${video.video_id}" 
                 target="_blank"
                 class="inline-flex items-center text-xs text-gray-600 hover:text-red-600 transition-colors">
                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.30 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
                </svg>
                View
              </a>
              
              ${this.renderTranscriptButton(video)}
            </div>
            
            <!-- Toggle Visibility -->
            <button type="button"
                    class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded transition-colors ${video.visible ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-red-100 text-red-700 hover:bg-red-200'}"
                    data-action="click->youtube-videos#toggleVisibility"
                    data-video-key="${video.video_key}"
                    data-current-visibility="${video.visible}"
                    title="${video.visible ? 'Click to hide this video' : 'Click to show this video'}">
              <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                ${video.visible ? 
                  '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>' :
                  '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>'
                }
              </svg>
              ${video.visible ? 'Showing' : 'Hidden'}
            </button>
          </div>
        </div>
      </div>
    `
  }

  async toggleVisibility(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const videoKey = button.dataset.videoKey
    const currentVisibility = button.dataset.currentVisibility === 'true'
    
    // Disable button during request
    button.disabled = true
    button.classList.add('opacity-50', 'cursor-not-allowed')
    
    try {
      const response = await fetch(this.toggleUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ video_key: videoKey })
      })

      const data = await response.json()

      if (data.success) {
        // Update the video card UI
        this.updateVideoVisibility(videoKey, data.visible)
        
        // Show success message briefly
        this.showTemporaryMessage(data.message, 'success')
      } else {
        this.showTemporaryMessage(data.message || 'Failed to update video visibility', 'error')
      }
    } catch (error) {
      console.error('Error toggling video visibility:', error)
      this.showTemporaryMessage('Network error occurred', 'error')
    } finally {
      // Re-enable button
      button.disabled = false
      button.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  updateVideoVisibility(videoKey, isVisible) {
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    const videoCard = container.querySelector(`[data-video-key="${videoKey}"]`)
    if (!videoCard) return

    const img = videoCard.querySelector('img')
    const button = videoCard.querySelector('[data-action*="toggleVisibility"]')
    
    // Update image opacity
    if (isVisible) {
      img.classList.remove('opacity-50')
    } else {
      img.classList.add('opacity-50')
    }
    
    // Update button
    if (button) {
      button.dataset.currentVisibility = isVisible
      button.className = `inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded transition-colors ${isVisible ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-red-100 text-red-700 hover:bg-red-200'}`
      button.title = isVisible ? 'Click to hide this video' : 'Click to show this video'
      
      const icon = button.querySelector('svg')
      const text = button.querySelector('svg + *') || button.lastChild
      
      if (icon) {
        icon.innerHTML = isVisible ? 
          '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>' :
          '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>'
      }
      
      // Update button text
      if (text && text.nodeType === Node.TEXT_NODE) {
        text.textContent = isVisible ? 'Showing' : 'Hidden'
      } else {
        // Find text node
        const textNodes = Array.from(button.childNodes).filter(node => node.nodeType === Node.TEXT_NODE)
        if (textNodes.length > 0) {
          textNodes[textNodes.length - 1].textContent = isVisible ? 'Showing' : 'Hidden'
        }
      }
    }
  }

  showLoadingState() {
    this.hideAllStates()
    if (this.hasLoadingStateTarget) {
      this.loadingStateTarget.classList.remove('hidden')
    }
  }

  showErrorState(message) {
    this.hideAllStates()
    if (this.hasErrorStateTarget) {
      this.errorStateTarget.classList.remove('hidden')
      const messageElement = this.errorStateTarget.querySelector('.error-message')
      if (messageElement) {
        messageElement.textContent = message
      }
    }
  }

  showEmptyState() {
    this.hideAllStates()
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove('hidden')
    }
  }

  showVideosContainer() {
    this.hideAllStates()
    if (this.hasVideosContainerTarget) {
      this.videosContainerTarget.classList.remove('hidden')
    }
    
    // Show refresh button and cache info when videos are displayed
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.classList.remove('hidden')
    }
    if (this.hasCacheInfoTarget) {
      this.cacheInfoTarget.classList.remove('hidden')
    }
  }

  async refreshVideos(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const originalContent = button.innerHTML
    
    // Stop all polling first
    this.stopPolling()
    
    // Disable button and show loading state
    button.disabled = true
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
      </svg>
      Refreshing...
    `
    
    try {
      await this.loadVideos(true) // Force refresh from API
      
      // Restart polling if needed after refresh
      const processingVideos = this.getProcessingVideos()
      if (processingVideos.length > 0 && processingVideos.length <= 10) {
        setTimeout(() => {
          this.startPolling()
        }, 2000)
      }
    } finally {
      // Restore button state
      button.disabled = false
      button.innerHTML = originalContent
    }
  }

  updateCacheInfo(data) {
    if (!this.hasCacheAgeTarget) return
    
    let ageText = 'Updated recently'
    if (data.cache_age_days > 0) {
      if (data.cache_age_days === 1) {
        ageText = 'Updated 1 day ago'
      } else if (data.cache_age_days < 7) {
        ageText = `Updated ${data.cache_age_days} days ago`
      } else {
        const weeks = Math.floor(data.cache_age_days / 7)
        ageText = weeks === 1 ? 'Updated 1 week ago' : `Updated ${weeks} weeks ago`
      }
    }
    
    this.cacheAgeTarget.textContent = ageText
    
    // Add warning if data is old
    if (data.cache_age_days >= 7) {
      this.cacheAgeTarget.parentElement.classList.add('text-amber-600')
      this.cacheAgeTarget.parentElement.classList.remove('text-gray-500')
    } else {
      this.cacheAgeTarget.parentElement.classList.remove('text-amber-600')
      this.cacheAgeTarget.parentElement.classList.add('text-gray-500')
    }
  }

  hideAllStates() {
    [this.loadingStateTarget, this.errorStateTarget, this.emptyStateTarget, this.videosContainerTarget].forEach(target => {
      if (target) {
        target.classList.add('hidden')
      }
    })
  }

  showTemporaryMessage(message, type = 'info') {
    // Create a temporary message element
    const messageDiv = document.createElement('div')
    messageDiv.className = `fixed top-4 right-4 px-4 py-2 rounded-md shadow-lg z-50 transition-opacity duration-300 ${
      type === 'success' ? 'bg-green-500 text-white' :
      type === 'error' ? 'bg-red-500 text-white' :
      'bg-blue-500 text-white'
    }`
    messageDiv.textContent = message
    
    document.body.appendChild(messageDiv)
    
    // Remove after 3 seconds with safety check
    setTimeout(() => {
      if (messageDiv.parentNode) {
        messageDiv.style.opacity = '0'
        setTimeout(() => {
          if (messageDiv.parentNode) {
            messageDiv.parentNode.removeChild(messageDiv)
          }
        }, 300)
      }
    }, 3000)
  }

  formatDate(dateString) {
    if (!dateString) return ''
    
    const date = new Date(dateString)
    const now = new Date()
    const diffTime = Math.abs(now - date)
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))
    
    if (diffDays === 0) return 'Today'
    if (diffDays === 1) return '1 day ago'
    if (diffDays < 7) return `${diffDays} days ago`
    if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`
    if (diffDays < 365) return `${Math.floor(diffDays / 30)} months ago`
    return `${Math.floor(diffDays / 365)} years ago`
  }

  renderTranscriptBadge(video) {
    if (!video.transcript_status) {
      console.log(`🔴 BADGE: No transcript_status for video ${video.video_key || video.video_id}`)
      return ''
    }
    
    const status = video.transcript_status
    console.log(`🎯 BADGE: Rendering badge for video ${video.video_key || video.video_id} with status:`, status)
    
    let badgeClass, icon, text
    
    switch (status.status) {
      case 'completed':
        badgeClass = 'bg-green-100 text-green-800 cursor-pointer hover:bg-green-200 border border-green-300'
        icon = '☑️'
        text = 'Transcript used for AI'
        break
      case 'completed_disabled':
        badgeClass = 'bg-gray-100 text-gray-600 cursor-pointer hover:bg-gray-200 border border-gray-300'
        icon = '☐'
        text = 'Transcript not used for AI'
        break
      case 'processing':
        badgeClass = 'bg-yellow-100 text-yellow-800'
        icon = '🔄'
        text = 'Processing'
        break
      case 'pending':
        badgeClass = 'bg-blue-100 text-blue-800'
        icon = '⏳'
        text = 'Queued'
        break
      case 'failed':
        badgeClass = 'bg-red-100 text-red-800'
        icon = '❌'
        text = 'Failed'
        break
      case 'no_transcript':
        badgeClass = 'bg-gray-100 text-gray-600'
        icon = '🚫'
        text = 'No Transcript'
        break
      default:
        console.log(`🔴 BADGE: Unknown status "${status.status}" for video ${video.video_key || video.video_id}`)
        return '' // Don't show badge for not_started
    }
    
    // Make completed badges clickable for AI toggle
    const isClickable = status.status === 'completed' || status.status === 'completed_disabled'
    const clickAction = isClickable ? `data-action="click->youtube-videos#toggleTranscriptAI" data-video-key="${video.video_key}"` : ''
    
    const badgeHtml = `
      <div class="absolute top-1 left-1 ${badgeClass} text-xs px-1.5 py-0.5 rounded text-xs font-medium z-10" 
           data-transcript-status="${status.status}" 
           ${clickAction}
           ${isClickable ? 'title="Click to toggle AI usage"' : ''}>
        ${icon} ${text}
      </div>
    `
    console.log(`✅ BADGE: Generated badge for ${video.video_key || video.video_id}: ${icon} ${text}`)
    console.log(`🔧 BADGE: Is clickable: ${isClickable}, Click action: ${clickAction}`)
    console.log(`🔧 BADGE: Full HTML:`, badgeHtml)
    return badgeHtml
  }
  
  renderTranscriptButton(video) {
    if (!video.transcript_status) return ''
    
    const status = video.transcript_status
    
    switch (status.status) {
      case 'completed':
        return `
          <span class="inline-flex items-center text-xs text-green-600 font-medium">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            Transcribed
          </span>
        `
      case 'processing':
        return `
          <span class="inline-flex items-center text-xs text-yellow-600 font-medium">
            <svg class="w-3 h-3 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
            Processing
          </span>
        `
      case 'pending':
        return `
          <span class="inline-flex items-center text-xs text-blue-600 font-medium">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            Queued
          </span>
        `
      case 'failed':
        return `
          <button type="button"
                  class="inline-flex items-center text-xs text-red-600 hover:text-red-800 transition-colors"
                  data-action="click->youtube-videos#retryTranscript"
                  data-video-key="${video.video_key}"
                  title="Retry transcript generation">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
            Retry
          </button>
        `
      case 'no_transcript':
        return `
          <span class="inline-flex items-center text-xs text-gray-500 font-medium">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636a9 9 0 00-12.728 12.728"></path>
            </svg>
            No Speech
          </span>
        `
      default:
        // not_started
        return `
          <button type="button"
                  class="inline-flex items-center text-xs text-blue-600 hover:text-blue-800 transition-colors"
                  data-action="click->youtube-videos#generateTranscript"
                  data-video-key="${video.video_key}"
                  title="Generate transcript for AI chat">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
            </svg>
            Get Transcript
          </button>
        `
    }
  }
  
  async generateTranscript(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const videoKey = button.dataset.videoKey
    
    // Disable button during request
    button.disabled = true
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
      </svg>
      Processing...
    `
    
    try {
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/youtube_videos/${videoKey}/generate_transcript`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (!response.ok) {
        // Handle HTTP error responses
        let errorMessage = 'Failed to start transcript generation'
        
        // Special handling for 404 - video doesn't exist anymore
        if (response.status === 404) {
          console.log('🔴 GENERATE: Video not found (404) - removing from UI')
          this.removeVideoFromUI(videoKey)
          this.showTemporaryMessage('Video no longer exists. Please refresh the video list.', 'error')
          return
        }
        
        try {
          const errorData = await response.json()
          errorMessage = errorData.message || errorMessage
        } catch (parseError) {
          console.error('Failed to parse error response:', parseError)
        }
        this.showTemporaryMessage(errorMessage, 'error')
        return
      }
      
      const data = await response.json()
      
      if (data.success) {
        this.showTemporaryMessage(data.message || 'Transcript generation started!', 'success')
        
        // Immediately update the UI to show processing status
        this.updateVideoWithProcessingStatus(videoKey)
        
        // Start polling if not already running
        if (!this.pollingInterval) {
          this.startPolling()
        }
      } else {
        this.showTemporaryMessage(data.message || 'Failed to start transcript generation', 'error')
      }
    } catch (error) {
      console.error('Error generating transcript:', error)
      this.showTemporaryMessage('Network error occurred', 'error')
    } finally {
      // Re-enable button
      button.disabled = false
      button.innerHTML = `
        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
        </svg>
        Get Transcript
      `
    }
  }
  
  async toggleTranscriptAI(event) {
    event.preventDefault()
    
    const badge = event.currentTarget
    const videoKey = badge.dataset.videoKey
    
    console.log('🔄 TOGGLE_AI: Starting toggle for video:', videoKey)
    console.log('🔄 TOGGLE_AI: Badge element:', badge)
    console.log('🔄 TOGGLE_AI: Badge dataset:', badge.dataset)
    
    // Store original state for potential rollback
    const originalClass = badge.className
    const originalHTML = badge.innerHTML
    
    // Show loading state
    badge.classList.add('opacity-50')
    badge.innerHTML = `🔄 Updating...`
    
    try {
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/youtube_videos/${videoKey}/toggle_transcript_ai`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      
      const data = await response.json()
      
      if (data.success) {
        console.log('✅ TOGGLE_AI: Successfully toggled AI status')
        
        // Update only the badge, not the entire video status
        this.updateTranscriptBadgeOnly(videoKey, data.transcript_status)
        
        // Show success message
        const action = data.ai_enabled ? 'enabled' : 'disabled'
        this.showTemporaryMessage(`Transcript ${action} for AI use`, 'success')
      } else {
        throw new Error(data.message || 'Toggle failed')
      }
      
    } catch (error) {
      console.error('🚨 TOGGLE_AI: Error toggling transcript AI:', error)
      
      // Rollback to original state
      badge.className = originalClass
      badge.innerHTML = originalHTML
      
      this.showTemporaryMessage('Failed to toggle transcript AI status', 'error')
    }
  }
  
  async retryTranscript(event) {
    // Same as generateTranscript but with different messaging
    event.preventDefault()
    
    const button = event.currentTarget
    const videoKey = button.dataset.videoKey
    
    console.log('🔵 RETRY: Starting retry for video:', videoKey)
    console.log('🔵 RETRY: Button element:', button)
    
    // Disable button during request
    button.disabled = true
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
      </svg>
      Retrying...
    `
    
    try {
      console.log('🔵 RETRY: Making API request to:', `/school_owner/schools/${this.schoolIdValue}/youtube_videos/${videoKey}/generate_transcript`)
      
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/youtube_videos/${videoKey}/generate_transcript`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      console.log('🔵 RETRY: API response status:', response.status)
      console.log('🔵 RETRY: API response ok:', response.ok)
      
      if (!response.ok) {
        // Handle HTTP error responses  
        let errorMessage = 'Failed to retry transcript generation'
        
        // Special handling for 404 - video doesn't exist anymore
        if (response.status === 404) {
          console.log('🔴 RETRY: Video not found (404) - removing from UI')
          this.removeVideoFromUI(videoKey)
          this.showTemporaryMessage('Video no longer exists. Please refresh the video list.', 'error')
          return
        }
        
        try {
          const errorData = await response.json()
          errorMessage = errorData.message || errorMessage
          console.log('🔴 RETRY: Error response data:', errorData)
        } catch (parseError) {
          console.error('Failed to parse error response:', parseError)
        }
        this.showTemporaryMessage(errorMessage, 'error')
        return
      }
      
      const data = await response.json()
      console.log('🔵 RETRY: Success response data:', data)
      
      if (data.success) {
        console.log('🔵 RETRY: Server says success, updating UI')
        this.showTemporaryMessage(data.message || 'Transcript retry started!', 'success')
        
        // Immediately update the UI to show processing status
        console.log('🔵 RETRY: Calling updateVideoWithProcessingStatus for:', videoKey)
        this.updateVideoWithProcessingStatus(videoKey)
        
        // Start polling if not already running
        if (!this.pollingInterval) {
          console.log('🔵 RETRY: Starting polling (no existing interval)')
          this.startPolling()
        } else {
          console.log('🔵 RETRY: Polling already running, interval exists')
        }
      } else {
        console.log('🔴 RETRY: Server says failure:', data.message)
        this.showTemporaryMessage(data.message || 'Failed to retry transcript generation', 'error')
      }
    } catch (error) {
      console.error('Error retrying transcript:', error)
      this.showTemporaryMessage('Network error occurred', 'error')
    } finally {
      // Re-enable button with retry text
      button.disabled = false
      button.innerHTML = `
        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        Retry
      `
    }
  }

  // Polling methods for transcript status updates
  
  startPolling() {
    console.log('🔄 POLLING: Starting transcript status polling')
    
    // Stop any existing polling first
    this.stopPolling()
    
    this.pollingAttempts = 0
    this.maxPollingAttempts = 180 // 30 minutes max (10s intervals)
    
    // Check if we actually need to poll
    const processingVideos = this.getProcessingVideos()
    console.log(`🔄 POLLING: Found ${processingVideos.length} videos that need polling`)
    
    if (processingVideos.length === 0) {
      console.log('🔄 POLLING: No processing videos found, not starting polling')
      return
    }
    
    this.showPollingIndicator()
    this.scheduleNextPoll()
  }
  
  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
      this.pollingInterval = null
    }
    this.hidePollingIndicator()
  }
  
  scheduleNextPoll() {
    // Only poll if we have processing videos and haven't exceeded max attempts
    const processingVideos = this.getProcessingVideos()
    
    // If we have too many processing videos, it's likely a UI sync issue - stop polling
    if (processingVideos.length === 0 || 
        this.pollingAttempts >= this.maxPollingAttempts || 
        processingVideos.length > 10) {
      console.log(`Stopping polling: processingVideos=${processingVideos.length}, attempts=${this.pollingAttempts}`)
      this.stopPolling()
      return
    }
    
    // Exponential backoff: start at 5s, max at 30s
    const baseInterval = 5000 // 5 seconds
    const maxInterval = 30000 // 30 seconds
    const backoffMultiplier = Math.min(1.5 ** Math.floor(this.pollingAttempts / 5), 6)
    const interval = Math.min(baseInterval * backoffMultiplier, maxInterval)
    
    this.pollingInterval = setTimeout(() => {
      this.pollTranscriptStatus()
    }, interval)
  }
  
  async pollTranscriptStatus() {
    this.pollingAttempts++
    console.log(`🔵 POLL: Starting polling attempt ${this.pollingAttempts}`)
    
    // Only poll if we have videos with processing/pending transcripts
    const processingVideos = this.getProcessingVideos()
    console.log(`🔵 POLL: Found ${processingVideos.length} processing videos in UI`)
    if (processingVideos.length === 0) {
      console.log('🔵 POLL: No processing videos found, stopping polling')
      this.stopPolling()
      return
    }
    
    try {
      console.log('🔵 POLL: Making polling request to:', `${this.fetchUrlValue}?poll_only=true`)
      const response = await fetch(`${this.fetchUrlValue}?poll_only=true`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      console.log('🔵 POLL: Response status:', response.status)
      const data = await response.json()
      console.log('🔵 POLL: Response data:', data)
      
      if (data.success && data.videos) {
        console.log(`🔵 POLL: Server returned ${data.videos.length} videos`)
        
        // Log the statuses from server
        data.videos.forEach(video => {
          console.log(`🔵 POLL: Server video ${video.video_key}: ${video.transcript_status?.status}`)
        })
        
        console.log('🔵 POLL: Calling updateVideoStatuses with videos')
        this.updateVideoStatuses(data.videos)
      } else {
        console.log('🔴 POLL: Server response not successful or no videos')
      }
      
      // Schedule next poll
      this.scheduleNextPoll()
      
    } catch (error) {
      console.log('🔴 POLL: Polling error (non-critical):', error)
      // Don't show error messages for polling failures - they're non-critical
      // Still schedule next poll on error
      this.scheduleNextPoll()
    }
  }
  
  getProcessingVideos() {
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    if (!container) return []
    
    const processingCards = container.querySelectorAll('[data-video-key]')
    const processingVideos = []
    
    processingCards.forEach(card => {
      const badge = card.querySelector('.absolute.top-1.left-1')
      if (badge) {
        const badgeText = badge.textContent.trim()
        // Only count as processing if it explicitly says "Processing" or "Queued"
        if (badgeText.includes('Processing') || badgeText.includes('Queued')) {
          processingVideos.push({
            videoKey: card.dataset.videoKey,
            element: card,
            currentStatus: badgeText
          })
          console.log(`Found processing video: ${card.dataset.videoKey} - ${badgeText}`)
        }
      }
    })
    
    console.log(`Total processing videos found: ${processingVideos.length}`)
    return processingVideos
  }
  
  updateVideoStatuses(videos) {
    console.log('🔵 UPDATE: updateVideoStatuses called with', videos.length, 'videos')
    // Just update individual elements without full page reloads
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    if (!container) {
      console.log('🔴 UPDATE: No container found!')
      return
    }
    
    let hasUpdates = false
    let newlyCompletedCount = 0
    
    videos.forEach(video => {
      const videoCard = container.querySelector(`[data-video-key="${video.video_key}"]`)
      if (videoCard) {
        console.log(`🔵 UPDATE: Processing video ${video.video_key} with server status:`, video.transcript_status)
        
        // Check current status before updating
        const currentBadge = videoCard.querySelector('.absolute.top-1.left-1')
        const currentStatus = currentBadge ? currentBadge.getAttribute('data-transcript-status') || 'unknown' : 'none'
        const currentText = currentBadge ? currentBadge.textContent.trim() : 'none'
        console.log(`🔵 UPDATE: Video ${video.video_key} current badge status: ${currentStatus} (text: "${currentText}")`)
        
        const wasProcessing = currentBadge && currentBadge.textContent.includes('Processing')
        console.log(`🔵 UPDATE: Video ${video.video_key} wasProcessing: ${wasProcessing}`)
        
        // Update badge
        const newBadgeHtml = this.renderTranscriptBadge(video)
        console.log(`🔵 UPDATE: New badge HTML for ${video.video_key}:`, newBadgeHtml ? 'generated' : 'empty')
        
        if (currentBadge) {
          console.log(`🗑️ UPDATE: Removing current badge for ${video.video_key}`)
          currentBadge.remove()
        }
        
        if (newBadgeHtml) {
          const badgeContainer = videoCard.querySelector('.relative.aspect-video')
          if (badgeContainer) {
            console.log(`✅ UPDATE: Inserting new badge for ${video.video_key}`)
            badgeContainer.insertAdjacentHTML('beforeend', newBadgeHtml)
            hasUpdates = true
            
            // Verify the badge was actually inserted
            const verifyBadge = videoCard.querySelector('.absolute.top-1.left-1')
            if (verifyBadge) {
              console.log(`✅ UPDATE: Badge verified for ${video.video_key}: "${verifyBadge.textContent.trim()}"`)
            } else {
              console.log(`🔴 UPDATE: Badge insertion failed for ${video.video_key}`)
            }
          } else {
            console.log(`🔴 UPDATE: No badge container found for ${video.video_key}`)
          }
        } else {
          console.log(`🔴 UPDATE: No badge HTML generated for ${video.video_key}`)
        }
        
        // Update button - look for any transcript-related button or span
        const currentButton = videoCard.querySelector('[data-action*="generateTranscript"], [data-action*="retryTranscript"], span[class*="text-green-600"], span[class*="text-yellow-600"], span[class*="text-blue-600"]')
        const newButtonHtml = this.renderTranscriptButton(video)
        
        console.log(`🔧 UPDATE: Button update for ${video.video_key} - current:`, currentButton ? 'found' : 'not found', 'new:', newButtonHtml ? 'generated' : 'empty')
        
        if (currentButton) {
          const buttonContainer = currentButton.parentElement
          console.log(`🔧 UPDATE: Removing current button for ${video.video_key}`)
          currentButton.remove()
          if (newButtonHtml && buttonContainer) {
            console.log(`🔧 UPDATE: Inserting new button for ${video.video_key}`)
            buttonContainer.insertAdjacentHTML('beforeend', newButtonHtml)
            
            // Verify the button was actually inserted
            const verifyButton = buttonContainer.querySelector('[data-action*="Transcript"], span[class*="text-green-600"], span[class*="text-yellow-600"], span[class*="text-blue-600"], span[class*="text-red-600"]')
            if (verifyButton) {
              console.log(`✅ UPDATE: Button verified for ${video.video_key}: "${verifyButton.textContent.trim()}"`)
            } else {
              console.log(`🔴 UPDATE: Button insertion failed for ${video.video_key}`)
            }
          }
        } else if (newButtonHtml) {
          // Try to find the button container even if no existing button
          console.log(`🔧 UPDATE: No current button found for ${video.video_key}, looking for button container`)
          const actionButtonsContainer = videoCard.querySelector('.flex.items-center.space-x-2')
          if (actionButtonsContainer) {
            console.log(`🔧 UPDATE: Found action buttons container for ${video.video_key}, inserting new button`)
            actionButtonsContainer.insertAdjacentHTML('beforeend', newButtonHtml)
          } else {
            console.log(`🔴 UPDATE: No action buttons container found for ${video.video_key}`)
          }
        }
        
        // Only count as newly completed if it was processing before and is completed now
        if (wasProcessing && video.transcript_status?.status === 'completed') {
          newlyCompletedCount++
        }
      }
    })
    
    // Show notification only for newly completed transcripts
    if (hasUpdates && newlyCompletedCount > 0) {
      this.showTemporaryMessage(`${newlyCompletedCount} transcript${newlyCompletedCount > 1 ? 's' : ''} completed!`, 'success')
    }
  }
  
  showPollingIndicator() {
    if (this.hasPollingIndicatorTarget) {
      this.pollingIndicatorTarget.classList.remove('hidden')
    }
  }
  
  updateVideoWithProcessingStatus(videoKey) {
    console.log(`🔧 UPDATE_PROCESSING: Updating ${videoKey} to processing status`)
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    const videoCard = container.querySelector(`[data-video-key="${videoKey}"]`)
    if (!videoCard) {
      console.log(`🔴 UPDATE_PROCESSING: No video card found for ${videoKey}`)
      return
    }
    
    // Create a mock video object with processing status
    const mockVideo = {
      video_key: videoKey,
      video_id: videoKey,
      transcript_status: {
        status: 'processing',
        message: 'Processing transcript...',
        badge_class: 'warning'
      }
    }
    
    console.log(`🔧 UPDATE_PROCESSING: Created mock video object for ${videoKey}:`, mockVideo)
    
    // Use the same updateVideoStatuses method to ensure consistency
    this.updateVideoStatuses([mockVideo])
    
    console.log(`✅ UPDATE_PROCESSING: Finished updating ${videoKey} to processing status`)
  }
  
  hidePollingIndicator() {
    if (this.hasPollingIndicatorTarget) {
      this.pollingIndicatorTarget.classList.add('hidden')
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Bulk Transcript Generation Methods
  
  setupBulkTranscriptButton() {
    const button = document.getElementById('generateAllTranscriptsBtn')
    if (button) {
      button.addEventListener('click', this.generateAllTranscripts.bind(this))
    }
  }

  async generateAllTranscripts() {
    const button = document.getElementById('generateAllTranscriptsBtn')
    if (!button) return

    console.log('🔵 BULK: Generate all transcripts clicked')

    // Get all videos that don't have transcripts
    const videosNeedingTranscripts = this.getVideosNeedingTranscripts()
    console.log(`🔵 BULK: Found ${videosNeedingTranscripts.length} videos needing transcripts`)

    if (videosNeedingTranscripts.length === 0) {
      this.showTemporaryMessage('All videos already have transcripts or are processing', 'info')
      return
    }

    // Confirm with user
    const confirmed = confirm(`Generate transcripts for ${videosNeedingTranscripts.length} videos? This may take several minutes.`)
    if (!confirmed) return

    // Set button to loading state
    this.setBulkButtonLoading(button, true)

    let successCount = 0
    let failedCount = 0
    
    try {
      // Process videos one by one to avoid overwhelming the server
      for (const videoKey of videosNeedingTranscripts) {
        try {
          console.log(`🔵 BULK: Processing video ${videoKey}`)
          
          const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/youtube_videos/${videoKey}/generate_transcript`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Requested-With': 'XMLHttpRequest',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
            }
          })

          if (response.ok) {
            const data = await response.json()
            if (data.success) {
              successCount++
              console.log(`✅ BULK: Successfully queued transcript for ${videoKey}`)
              
              // Update the UI immediately to show processing
              this.updateVideoWithProcessingStatus(videoKey)
            } else {
              failedCount++
              console.log(`❌ BULK: Failed to queue transcript for ${videoKey}: ${data.message}`)
            }
          } else {
            // Special handling for 404 - video doesn't exist anymore
            if (response.status === 404) {
              console.log(`🔴 BULK: Video not found (404) - removing from UI: ${videoKey}`)
              this.removeVideoFromUI(videoKey)
              // Don't count as failed since we cleaned it up
            } else {
              failedCount++
              console.log(`❌ BULK: HTTP error for ${videoKey}: ${response.status}`)
            }
          }

          // Add a small delay between requests to be nice to the server
          await new Promise(resolve => setTimeout(resolve, 500))
          
        } catch (error) {
          failedCount++
          console.error(`🚨 BULK: Error processing video ${videoKey}:`, error)
        }
      }

      // Show results
      if (successCount > 0) {
        this.showTemporaryMessage(
          `Started transcript generation for ${successCount} video${successCount > 1 ? 's' : ''}${failedCount > 0 ? ` (${failedCount} failed)` : ''}`,
          successCount > failedCount ? 'success' : 'error'
        )
        
        // Start polling if not already running
        if (!this.pollingInterval && successCount > 0) {
          this.startPolling()
        }
      } else {
        this.showTemporaryMessage('Failed to start transcript generation for any videos', 'error')
      }

    } catch (error) {
      console.error('🚨 BULK: Critical error in bulk transcript generation:', error)
      this.showTemporaryMessage('An error occurred while generating transcripts', 'error')
    } finally {
      this.setBulkButtonLoading(button, false)
    }
  }

  getVideosNeedingTranscripts() {
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    if (!container) return []

    const videoCards = container.querySelectorAll('[data-video-key]')
    const videosNeeding = []

    videoCards.forEach(card => {
      const videoKey = card.dataset.videoKey
      const badge = card.querySelector('.absolute.top-1.left-1')
      const hasTranscriptButton = card.querySelector('[data-action*="generateTranscript"]')
      
      // Need transcript if:
      // 1. No badge (means no transcript status)
      // 2. Has a "Get Transcript" button (means not started)
      // 3. Badge shows "Failed" (can retry)
      // 4. Exclude "No Transcript" (videos with no speech/captions)
      const badgeText = badge ? badge.textContent.trim() : ''
      const isNoTranscript = badgeText.includes('No Transcript')
      
      if (!isNoTranscript && (!badge || hasTranscriptButton || badgeText.includes('Failed'))) {
        videosNeeding.push(videoKey)
        console.log(`🔍 BULK: Video ${videoKey} needs transcript - badge: ${badgeText || 'none'}, hasButton: ${!!hasTranscriptButton}`)
      } else if (isNoTranscript) {
        console.log(`🔍 BULK: Skipping video ${videoKey} - no speech/captions available`)
      }
    })

    return videosNeeding
  }

  setBulkButtonLoading(button, loading) {
    if (loading) {
      button.disabled = true
      button.innerHTML = `
        <svg class="w-4 h-4 mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        Generating Transcripts...
      `
      button.classList.add('opacity-75')
    } else {
      button.disabled = false
      button.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
        </svg>
        Generate All Transcripts
      `
      button.classList.remove('opacity-75')
    }
  }

  removeVideoFromUI(videoKey) {
    console.log(`🗑️ REMOVE: Removing video ${videoKey} from UI`)
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    if (!container) {
      console.log('🔴 REMOVE: No container found')
      return
    }

    const videoCard = container.querySelector(`[data-video-key="${videoKey}"]`)
    if (videoCard) {
      console.log(`🗑️ REMOVE: Found and removing video card for ${videoKey}`)
      videoCard.remove()
      
      // Check if we need to show empty state
      const remainingVideos = container.querySelectorAll('[data-video-key]')
      if (remainingVideos.length === 0) {
        console.log('🗑️ REMOVE: No videos remaining, showing empty state')
        this.showEmptyState()
      }
    } else {
      console.log(`🔴 REMOVE: Video card not found for ${videoKey}`)
    }
  }

  updateTranscriptBadgeOnly(videoKey, transcriptStatus) {
    console.log(`🔄 UPDATE_BADGE_ONLY: Updating badge for ${videoKey}`)
    const container = this.hasVideoGridTarget ? this.videoGridTarget : this.videosContainerTarget
    if (!container) {
      console.log('🔴 UPDATE_BADGE_ONLY: No container found')
      return
    }

    const videoCard = container.querySelector(`[data-video-key="${videoKey}"]`)
    if (!videoCard) {
      console.log(`🔴 UPDATE_BADGE_ONLY: Video card not found for ${videoKey}`)
      return
    }

    // Remove the current badge
    const currentBadge = videoCard.querySelector('.absolute.top-1.left-1')
    if (currentBadge) {
      console.log(`🗑️ UPDATE_BADGE_ONLY: Removing current badge for ${videoKey}`)
      currentBadge.remove()
    }

    // Create new badge HTML with the updated status
    const mockVideo = { video_key: videoKey, transcript_status: transcriptStatus }
    const newBadgeHtml = this.renderTranscriptBadge(mockVideo)
    
    if (newBadgeHtml) {
      const badgeContainer = videoCard.querySelector('.relative.aspect-video')
      if (badgeContainer) {
        console.log(`✅ UPDATE_BADGE_ONLY: Inserting new badge for ${videoKey}`)
        badgeContainer.insertAdjacentHTML('beforeend', newBadgeHtml)
      } else {
        console.log(`🔴 UPDATE_BADGE_ONLY: No badge container found for ${videoKey}`)
      }
    } else {
      console.log(`🔴 UPDATE_BADGE_ONLY: No badge HTML generated for ${videoKey}`)
    }
  }
}