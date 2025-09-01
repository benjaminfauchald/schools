import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["videosContainer", "videoGrid", "loadingState", "errorState", "emptyState"]
  static values = { 
    schoolId: Number,
    fetchUrl: String,
    toggleUrl: String,
    transcriptUrl: String,
    transcriptStatusUrl: String
  }

  connect() {
    this.loadVideos()
  }

  async loadVideos() {
    this.showLoadingState()
    
    try {
      const response = await fetch(this.fetchUrlValue, {
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
        this.showVideosContainer()
      } else {
        this.showErrorState(data.message || 'Failed to load videos')
      }
    } catch (error) {
      console.error('Error loading videos:', error)
      this.showErrorState('Network error occurred while loading videos')
    }
  }

  renderVideos(videos) {
    if (videos.length === 0) {
      this.showEmptyState()
      return
    }

    const videosHtml = videos.map(video => this.renderVideoCard(video)).join('')
    if (this.hasVideoGridTarget) {
      this.videoGridTarget.innerHTML = videosHtml
    } else {
      this.videosContainerTarget.innerHTML = videosHtml
    }
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
          <div class="flex flex-col space-y-2">
            <!-- Top row: View and Visibility -->
            <div class="flex items-center justify-between">
              <!-- View on YouTube -->
              <a href="https://www.youtube.com/watch?v=${video.video_id}" 
                 target="_blank"
                 class="inline-flex items-center text-xs text-gray-600 hover:text-red-600 transition-colors">
                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
                </svg>
                View
              </a>
              
              <!-- Toggle Visibility -->
              <button type="button"
                      class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded transition-colors ${video.visible ? 'bg-red-100 text-red-700 hover:bg-red-200' : 'bg-green-100 text-green-700 hover:bg-green-200'}"
                      data-action="click->youtube-videos#toggleVisibility"
                      data-video-key="${video.video_key}"
                      data-current-visibility="${video.visible}">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  ${video.visible ? 
                    '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>' :
                    '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>'
                  }
                </svg>
                ${video.visible ? 'Hide' : 'Show'}
              </button>
            </div>
            
            <!-- Bottom row: Get Transcript Button -->
            <button type="button"
                    class="w-full inline-flex items-center justify-center px-2 py-1.5 text-xs font-medium rounded transition-colors bg-blue-100 text-blue-700 hover:bg-blue-200 border border-blue-200"
                    data-action="click->youtube-videos#extractTranscript"
                    data-video-id="${video.video_id}"
                    data-video-title="${this.escapeHtml(video.title)}">
              <svg class="w-3 h-3 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              </svg>
              GET TRANSCRIPT
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
  
  async extractTranscript(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const videoId = button.dataset.videoId
    const videoTitle = button.dataset.videoTitle
    
    // Disable button during request and show loading state
    button.disabled = true
    button.classList.add('opacity-50', 'cursor-not-allowed')
    const originalContent = button.innerHTML
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1.5 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      EXTRACTING...
    `
    
    try {
      const url = this.transcriptUrlValue.replace(':video_id', videoId)
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        // Update button to show success state
        button.innerHTML = `
          <svg class="w-3 h-3 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
          EXTRACTING...
        `
        button.classList.remove('bg-blue-100', 'text-blue-700', 'hover:bg-blue-200', 'border-blue-200')
        button.classList.add('bg-green-100', 'text-green-700', 'border-green-200')
        
        // Show success message
        this.showTemporaryMessage(`✅ Transcript extraction started for "${videoTitle}". Processing in background...`, 'success')
        
        // Start polling for completion
        this.startTranscriptPolling(videoId, button, videoTitle)
      } else {
        // Restore original button state on error
        button.innerHTML = originalContent
        button.disabled = false
        button.classList.remove('opacity-50', 'cursor-not-allowed')
        
        if (response.status === 409) {
          // Transcript already exists
          this.showTemporaryMessage(`ℹ️ Transcript already exists for this video`, 'info')
        } else {
          this.showTemporaryMessage(data.message || 'Failed to start transcript extraction', 'error')
        }
      }
    } catch (error) {
      console.error('Error extracting transcript:', error)
      
      // Restore original button state on error
      button.innerHTML = originalContent
      button.disabled = false
      button.classList.remove('opacity-50', 'cursor-not-allowed')
      
      this.showTemporaryMessage('Network error occurred while starting transcript extraction', 'error')
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
      button.className = `inline-flex items-center px-2 py-1 text-xs font-medium rounded transition-colors ${isVisible ? 'bg-red-100 text-red-700 hover:bg-red-200' : 'bg-green-100 text-green-700 hover:bg-green-200'}`
      
      const icon = button.querySelector('svg')
      const text = button.querySelector('svg + *') || button.lastChild
      
      if (icon) {
        icon.innerHTML = isVisible ? 
          '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>' :
          '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>'
      }
      
      // Update button text
      if (text && text.nodeType === Node.TEXT_NODE) {
        text.textContent = isVisible ? 'Hide' : 'Show'
      } else {
        // Find text node
        const textNodes = Array.from(button.childNodes).filter(node => node.nodeType === Node.TEXT_NODE)
        if (textNodes.length > 0) {
          textNodes[textNodes.length - 1].textContent = isVisible ? 'Hide' : 'Show'
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
    
    // Remove after 3 seconds
    setTimeout(() => {
      messageDiv.style.opacity = '0'
      setTimeout(() => {
        document.body.removeChild(messageDiv)
      }, 300)
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

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  startTranscriptPolling(videoId, button, videoTitle) {
    let attempts = 0
    const maxAttempts = 30  // Poll for up to 5 minutes (10-second intervals)
    
    const poll = async () => {
      attempts++
      
      try {
        const url = this.transcriptStatusUrlValue.replace(':video_id', videoId)
        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        })

        const data = await response.json()

        if (data.success) {
          if (data.exists && data.processed) {
            // Transcript is complete!
            button.innerHTML = `
              <svg class="w-3 h-3 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
              </svg>
              TRANSCRIPT READY
            `
            button.classList.remove('bg-green-100', 'text-green-700', 'border-green-200')
            button.classList.add('bg-blue-100', 'text-blue-700', 'border-blue-200')
            
            this.showTemporaryMessage(`🎉 Transcript ready for "${videoTitle}"! ${data.segment_count} segments extracted.`, 'success')
            return // Stop polling
          }
          
          // Still processing, continue polling if within limits
          if (attempts < maxAttempts) {
            setTimeout(poll, 10000) // Poll every 10 seconds
          } else {
            // Timeout - stop polling but don't change button state
            console.warn(`Transcript polling timeout for video ${videoId}`)
          }
        } else {
          console.error('Transcript status check failed:', data.message)
        }
      } catch (error) {
        console.error('Error checking transcript status:', error)
        // Continue polling unless we've exceeded attempts
        if (attempts < maxAttempts) {
          setTimeout(poll, 10000)
        }
      }
    }
    
    // Start polling after 15 seconds (give the job time to start)
    setTimeout(poll, 15000)
  }
}