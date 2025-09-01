import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["videosContainer", "videoGrid", "loadingState", "errorState", "emptyState", "refreshButton", "cacheInfo", "cacheAge"]
  static values = { 
    schoolId: Number,
    fetchUrl: String,
    toggleUrl: String
  }

  connect() {
    this.loadVideos()
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
    
    // Disable button and show loading state
    button.disabled = true
    button.innerHTML = `
      <svg class="w-3 h-3 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
      </svg>
      Refreshing...
    `
    
    try {
      await this.loadVideos(true) // Force refresh
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
}