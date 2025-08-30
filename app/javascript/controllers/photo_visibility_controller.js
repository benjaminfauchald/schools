import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { schoolId: String }
  static targets = []
  
  async toggle(event) {
    const photoContainer = event.currentTarget
    const photoKey = photoContainer.dataset.photoKey
    const currentVisibility = photoContainer.dataset.visible === 'true'
    
    // Prevent multiple simultaneous clicks
    if (photoContainer.dataset.updating === 'true') {
      return
    }
    
    photoContainer.dataset.updating = 'true'
    
    try {
      // Show loading state
      this.showLoadingState(photoContainer)
      
      // Make the API request
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/toggle_photo_visibility`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          photo_key: photoKey
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Update the UI based on new visibility state
        this.updatePhotoVisibility(photoContainer, data.visible)
        
        // Show success message briefly
        this.showSuccessMessage(photoContainer, data.message)
        
      } else {
        // Handle error
        console.error('Error toggling photo visibility:', data.message)
        this.showErrorMessage(photoContainer, data.message || 'Failed to update photo visibility')
      }
      
    } catch (error) {
      console.error('Network error:', error)
      this.showErrorMessage(photoContainer, 'Network error. Please try again.')
      
    } finally {
      photoContainer.dataset.updating = 'false'
    }
  }
  
  showLoadingState(photoContainer) {
    const overlay = photoContainer.querySelector('.absolute.inset-0')
    if (overlay) {
      overlay.classList.remove('bg-opacity-0', 'group-hover:bg-opacity-20')
      overlay.classList.add('bg-opacity-40')
      
      const iconContainer = overlay.querySelector('.opacity-0')
      if (iconContainer) {
        iconContainer.classList.remove('opacity-0')
        iconContainer.classList.add('opacity-100')
        iconContainer.innerHTML = `
          <svg class="w-6 h-6 text-white animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        `
      }
    }
  }
  
  updatePhotoVisibility(photoContainer, isVisible) {
    // Update data attribute
    photoContainer.dataset.visible = isVisible.toString()
    
    // Update the photo image appearance
    const photoImage = photoContainer.querySelector('img')
    if (photoImage) {
      if (isVisible) {
        photoImage.classList.remove('opacity-50')
      } else {
        photoImage.classList.add('opacity-50')
      }
    }
    
    // Update the visibility badge
    const badge = photoContainer.querySelector('.absolute.top-2.right-2')
    if (badge) {
      badge.className = `absolute top-2 right-2 px-2 py-1 rounded-full text-xs font-medium ${
        isVisible 
          ? 'bg-green-100 text-green-800' 
          : 'bg-red-100 text-red-800'
      }`
      badge.textContent = isVisible ? 'Showing' : 'Hidden'
    }
    
    // Update the overlay icon
    const overlay = photoContainer.querySelector('.absolute.inset-0')
    const iconContainer = overlay?.querySelector('.opacity-0, .opacity-100')
    if (iconContainer) {
      // Reset overlay state
      overlay.classList.remove('bg-opacity-40')
      overlay.classList.add('bg-opacity-0', 'group-hover:bg-opacity-20')
      iconContainer.classList.remove('opacity-100')
      iconContainer.classList.add('opacity-0', 'group-hover:opacity-100')
      
      // Update icon based on visibility
      const iconSvg = isVisible 
        ? `<svg class="w-6 h-6 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>
           </svg>`
        : `<svg class="w-6 h-6 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
           </svg>`
      
      iconContainer.innerHTML = iconSvg
    }
  }
  
  showSuccessMessage(photoContainer, message) {
    // Could implement a toast notification here
    console.log('Success:', message)
  }
  
  showErrorMessage(photoContainer, message) {
    // Show error briefly in the overlay
    const overlay = photoContainer.querySelector('.absolute.inset-0')
    const iconContainer = overlay?.querySelector('.opacity-0, .opacity-100')
    
    if (iconContainer) {
      iconContainer.classList.remove('opacity-0')
      iconContainer.classList.add('opacity-100')
      iconContainer.innerHTML = `
        <div class="bg-red-500 text-white px-2 py-1 rounded text-xs text-center">
          ${message}
        </div>
      `
      
      // Reset after 3 seconds
      setTimeout(() => {
        overlay.classList.remove('bg-opacity-40')
        overlay.classList.add('bg-opacity-0', 'group-hover:bg-opacity-20')
        iconContainer.classList.remove('opacity-100')
        iconContainer.classList.add('opacity-0', 'group-hover:opacity-100')
      }, 3000)
    }
  }
}