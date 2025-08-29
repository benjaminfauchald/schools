import { Controller } from "@hotwired/stimulus"

// School form controller handles AJAX form submission and toast notifications
export default class extends Controller {
  static targets = ["submitButton"]

  handleSubmit(event) {
    event.preventDefault()
    
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

    // Get form data
    const form = event.target
    const formData = new FormData(form)

    // Submit via fetch
    fetch(form.action, {
      method: form.method,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showToast('success', data.message)
      } else {
        this.showToast('error', data.errors ? data.errors.join(', ') : 'An error occurred')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showToast('error', 'An error occurred while saving')
    })
    .finally(() => {
      // Re-enable submit button
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.innerHTML = 'Save School Information'
      }
    })
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