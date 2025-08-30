import { Controller } from "@hotwired/stimulus"

// School form controller handles AJAX form submission and toast notifications
export default class extends Controller {
  static targets = ["submitButton"]

  handleSubmit(event) {
    console.log('handleSubmit called, event type:', event.type)
    
    // Ensure we're handling the right form
    const form = event.target
    if (!form || !form.action) {
      console.error('No form or action found')
      return false
    }
    
    // Only handle school update forms
    if (!form.action.includes('/school_owner/schools/')) {
      console.log('Not a school form, ignoring')
      return true // Let other forms handle normally
    }
    
    // Only handle PATCH requests (school updates), not DELETE requests (photo deletion)
    const methodField = form.querySelector('input[name="_method"]')
    const actualMethod = methodField ? methodField.value : form.method
    if (actualMethod && actualMethod.toLowerCase() === 'delete') {
      console.log('Delete request detected, allowing normal form submission')
      return true // Let delete forms submit normally
    }
    
    console.log('Handling school form submission')
    event.preventDefault()
    event.stopPropagation()
    
    console.log('Form action URL:', form.action)
    console.log('Form method:', form.method)
    console.log('Actual method (from _method field):', actualMethod)
    
    // Add .json to URL to force JSON response
    let actionUrl = form.action
    if (!actionUrl.includes('.json')) {
      actionUrl += '.json'
    }
    console.log('Modified action URL:', actionUrl)
    
    // Disable submit button to prevent double submission
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Saving...
      `
    }

    // Create form data
    const formData = new FormData(form)
    
    // Debug: log form data
    console.log('Form data entries:')
    for (let [key, value] of formData.entries()) {
      console.log(`  ${key}: ${value}`)
    }

    // Submit via fetch
    fetch(actionUrl, {
      method: 'POST', // Always use POST for Rails forms
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: formData
    })
    .then(response => {
      console.log('Response status:', response.status)
      console.log('Response headers:', response.headers)
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      return response.json()
    })
    .then(data => {
      console.log('Server response:', data)
      if (data.success) {
        this.showToast('success', data.message)
      } else {
        console.error('Server errors:', data.errors)
        if (data.debug) {
          console.error('Debug info:', data.debug)
        }
        this.showToast('error', data.errors ? data.errors.join(', ') : 'An error occurred')
      }
    })
    .catch(error => {
      console.error('Network/Parse error:', error)
      this.showToast('error', 'An error occurred while saving')
    })
    .finally(() => {
      // Re-enable submit button
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.innerHTML = 'Save School Information'
      }
    })
    
    return false // Prevent default form submission
  }

  showToast(type, message) {
    // Remove any existing toasts
    const existingToasts = document.querySelectorAll('.toast-notification')
    existingToasts.forEach(toast => toast.remove())

    // Create toast element
    const toast = document.createElement('div')
    toast.className = `toast-notification slide-in fixed top-4 right-4 max-w-sm w-full`
    toast.style.zIndex = '99999'
    toast.style.position = 'fixed'
    
    const bgColor = type === 'success' ? 'bg-green-500' : 'bg-red-500'
    const icon = type === 'success' ? 
      `<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
       </svg>` :
      `<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
       </svg>`

    toast.innerHTML = `
      <div class="${bgColor} text-white px-6 py-4 rounded-lg shadow-lg flex items-center space-x-3">
        <div class="flex-shrink-0">
          ${icon}
        </div>
        <div class="flex-1">
          <p class="text-sm font-medium">${message}</p>
        </div>
        <button type="button" class="flex-shrink-0 text-white hover:text-gray-200" onclick="this.closest('.toast-notification').remove()">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `

    // Add to page
    document.body.appendChild(toast)

    // Auto remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.classList.remove('slide-in')
        toast.classList.add('slide-out')
        setTimeout(() => toast.remove(), 300)
      }
    }, 5000)
  }
}