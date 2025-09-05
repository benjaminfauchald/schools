import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="claim-submission"
export default class extends Controller {
  static targets = []

  connect() {
    console.log("🎯 ClaimSubmissionController connected")
  }

  // Handle form submission manually
  handleSubmit(event) {
    event.preventDefault()
    console.log("🎯 Form submit intercepted", event)
    
    const form = event.target
    const formData = new FormData(form)
    
    // Get CSRF token
    const csrfToken = document.querySelector('[name="csrf-token"]').content
    
    console.log("🎯 Form action URL:", form.action)
    console.log("🎯 Form method:", form.method)
    console.log("🎯 CSRF Token:", csrfToken)
    console.log("🎯 Submitting form data:", Object.fromEntries(formData))
    
    fetch(form.action, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      }
    })
    .then(response => {
      console.log("🎯 Response received", response, "Status:", response.status)
      console.log("🎯 Response headers:", response.headers)
      console.log("🎯 Response ok:", response.ok)
      
      // Check if response is JSON
      const contentType = response.headers.get('content-type')
      console.log("🎯 Content-Type:", contentType)
      
      if (!contentType || !contentType.includes('application/json')) {
        // Not JSON, let's read as text to see what we got
        return response.text().then(text => {
          console.log("🎯 Non-JSON response text:", text)
          throw new Error(`Expected JSON response but got: ${contentType}. Response: ${text.substring(0, 200)}...`)
        })
      }
      
      return response.json().then(data => ({ 
        ok: response.ok, 
        status: response.status, 
        data 
      }))
    })
    .then(({ ok, status, data }) => {
      console.log("🎯 Response data:", data)
      if (ok && data.success) {
        this.showSuccessModal(data)
      } else {
        this.showErrorModal(data.errors || [data.message || 'An error occurred'])
      }
    })
    .catch(error => {
      console.error("🎯 Fetch error:", error)
      this.showErrorModal([`Network error: ${error.message}`])
    })
  }


  // Show success modal with claim details
  showSuccessModal(data) {
    const modal = this.createModal({
      title: data.title || 'Claim Submitted Successfully!',
      content: this.buildSuccessContent(data),
      primaryButtonText: 'Continue to School',
      primaryButtonAction: () => {
        window.location.href = data.school_url
      },
      type: 'success'
    })
    
    this.showModal(modal)
  }

  // Show error modal with error messages
  showErrorModal(errors) {
    const modal = this.createModal({
      title: 'Submission Failed',
      content: this.buildErrorContent(errors),
      primaryButtonText: 'Try Again',
      primaryButtonAction: () => {
        this.hideModal()
      },
      type: 'error'
    })
    
    this.showModal(modal)
  }

  // Build success modal content
  buildSuccessContent(data) {
    return `
      <div class="text-center mb-6">
        <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4">
          <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
        </div>
        <h3 class="text-lg font-medium text-gray-900 mb-2">
          ${data.title || 'Claim Submitted Successfully!'}
        </h3>
        <p class="text-sm text-gray-600 mb-4">
          Your claim for <strong>${data.school_name}</strong> has been submitted for review.
        </p>
        <div class="bg-green-50 border border-green-200 rounded-lg p-4">
          <p class="text-sm text-green-800">
            ${data.message}
          </p>
        </div>
      </div>
      
      <div class="space-y-3 text-sm text-gray-600">
        ${data.created_user ? `
          <div class="flex items-start">
            <div class="flex-shrink-0 w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center mr-3">
              <span class="text-xs font-medium text-blue-600">1</span>
            </div>
            <div>
              <p class="font-medium text-gray-900">Check Your Email</p>
              <p class="text-gray-600">We've sent a verification email. Click the link to verify your account.</p>
            </div>
          </div>
          <div class="flex items-start">
            <div class="flex-shrink-0 w-6 h-6 bg-gray-100 rounded-full flex items-center justify-center mr-3">
              <span class="text-xs font-medium text-gray-600">2</span>
            </div>
            <div>
              <p class="font-medium text-gray-900">Admin Review</p>
              <p class="text-gray-600">Our team will review your claim within 3-5 business days.</p>
            </div>
          </div>
        ` : `
          <div class="flex items-start">
            <div class="flex-shrink-0 w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center mr-3">
              <span class="text-xs font-medium text-blue-600">1</span>
            </div>
            <div>
              <p class="font-medium text-gray-900">Admin Review</p>
              <p class="text-gray-600">Our team will review your new claim within 3-5 business days.</p>
            </div>
          </div>
        `}
      </div>
    `
  }

  // Build error modal content
  buildErrorContent(errors) {
    const errorList = errors.map(error => `<li>${error}</li>`).join('')
    
    return `
      <div class="text-center mb-6">
        <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100 mb-4">
          <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 15.5c-.77.833.192 2.5 1.732 2.5z"></path>
          </svg>
        </div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">
          Submission Failed
        </h3>
      </div>
      
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <div class="text-sm text-red-800">
          <p class="font-medium mb-2">Please fix the following issues:</p>
          <ul class="list-disc list-inside space-y-1">
            ${errorList}
          </ul>
        </div>
      </div>
    `
  }

  // Create modal element
  createModal({ title, content, primaryButtonText, primaryButtonAction, type }) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.setAttribute('aria-labelledby', 'modal-title')
    modal.setAttribute('role', 'dialog')
    modal.setAttribute('aria-modal', 'true')
    
    const buttonColorClass = type === 'error' 
      ? 'bg-red-600 hover:bg-red-700 focus:ring-red-500' 
      : 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-500'
    
    modal.innerHTML = `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity modal-backdrop"></div>

        <!-- Center modal -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
        
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6 modal-content">
          ${content}
          
          <div class="mt-6 flex items-center justify-end space-x-3">
            <button type="button" class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 cancel-button">
              Cancel
            </button>
            <button type="button" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white shadow-sm ${buttonColorClass} focus:outline-none focus:ring-2 focus:ring-offset-2 primary-button">
              ${primaryButtonText}
            </button>
          </div>
        </div>
      </div>
    `

    // Add event listeners
    const primaryButton = modal.querySelector('.primary-button')
    const cancelButton = modal.querySelector('.cancel-button')
    const backdrop = modal.querySelector('.modal-backdrop')

    primaryButton.addEventListener('click', () => {
      this.hideModal()
      if (primaryButtonAction) {
        primaryButtonAction()
      }
    })

    cancelButton.addEventListener('click', () => {
      this.hideModal()
    })

    backdrop.addEventListener('click', () => {
      this.hideModal()
    })

    // Close modal on Escape key
    modal.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.hideModal()
      }
    })

    return modal
  }

  // Show modal
  showModal(modal) {
    // Store reference to current modal
    this.currentModal = modal
    
    // Append to body
    document.body.appendChild(modal)
    
    // Prevent body scroll
    document.body.style.overflow = 'hidden'
    
    // Focus the modal for accessibility
    modal.focus()
    
    // Add show class for animation
    requestAnimationFrame(() => {
      modal.classList.add('show')
    })
  }

  // Hide modal
  hideModal() {
    if (this.currentModal) {
      // Remove modal
      this.currentModal.remove()
      this.currentModal = null
      
      // Restore body scroll
      document.body.style.overflow = ''
    }
  }

  // Cleanup on disconnect
  disconnect() {
    this.hideModal()
  }
}