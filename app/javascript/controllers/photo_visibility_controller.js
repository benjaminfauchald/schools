import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["photoContainer"]
  
  async toggleVisibility(event) {
    const button = event.currentTarget
    const photoKey = button.dataset.photoKey
    const photoContainer = this.photoContainers.find(container => 
      container.dataset.photoKey === photoKey
    )
    
    if (!photoContainer) {
      console.error("Photo container not found for key:", photoKey)
      return
    }
    
    // Disable button during request
    button.disabled = true
    const originalText = button.innerHTML
    
    try {
      // Show loading state
      button.innerHTML = `
        <svg class="w-3 h-3 inline mr-1 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Updating...
      `
      
      // Get the school ID from the URL
      const schoolId = window.location.pathname.split('/')[3]
      
      // Make the API request
      const response = await fetch(`/school_owner/schools/${schoolId}/toggle_photo_visibility`, {
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
        
        // Show success message (optional - you could add a toast notification)
        console.log(data.message)
        
      } else {
        // Handle error
        console.error('Error toggling photo visibility:', data.message)
        alert(data.message || 'Failed to update photo visibility')
      }
      
    } catch (error) {
      console.error('Network error:', error)
      alert('Network error. Please try again.')
      
    } finally {
      // Re-enable button
      button.disabled = false
    }
  }
  
  updatePhotoVisibility(photoContainer, isVisible) {
    // Update the photo image appearance
    const photoImage = photoContainer.querySelector('.transition-all')
    if (isVisible) {
      photoImage.classList.remove('opacity-50', 'grayscale')
    } else {
      photoImage.classList.add('opacity-50', 'grayscale')
    }
    
    // Update the visibility badge
    const badge = photoContainer.querySelector('.absolute.top-2.right-2 span')
    if (badge) {
      badge.className = `text-xs px-2 py-1 rounded-full font-medium ${
        isVisible 
          ? 'bg-green-100 text-green-800' 
          : 'bg-red-100 text-red-800'
      }`
      badge.textContent = isVisible ? 'Visible' : 'Hidden'
    }
    
    // Update the toggle button
    const button = photoContainer.querySelector('button[data-action*="toggleVisibility"]')
    if (button) {
      button.className = `text-white px-3 py-1 rounded-md text-xs font-medium shadow-lg transition-colors ${
        isVisible 
          ? 'bg-red-600 hover:bg-red-700' 
          : 'bg-green-600 hover:bg-green-700'
      }`
      
      const icon = isVisible 
        ? `<svg class="w-3 h-3 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L12 12m-2.122-2.122L7.757 7.757M12 12l2.122 2.122m0 0L16.243 16.243M12 12l-2.122-2.122"></path>
           </svg>
           Hide`
        : `<svg class="w-3 h-3 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
           </svg>
           Show`
      
      button.innerHTML = icon
    }
  }
  
  get photoContainers() {
    return this.photoContainerTargets
  }
}