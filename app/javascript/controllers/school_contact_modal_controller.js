import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "submitButton"]
  static values = { 
    schoolId: Number,
    userSignedIn: Boolean,
    facebookAuthenticated: Boolean
  }

  connect() {
    this.boundHandleEscape = this.handleEscape.bind(this)
    
    // Check if we need to restore form data after Facebook authentication
    if (this.facebookAuthenticatedValue) {
      setTimeout(() => this.restoreFormData(), 100)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleEscape)
  }

  openModal() {
    // Find the modal in the document
    const modal = document.querySelector('[data-school-contact-modal-target="modal"]')
    
    if (modal) {
      modal.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
      document.addEventListener("keydown", this.boundHandleEscape)
      
      // Focus first input
      const firstInput = modal.querySelector("input[type='text']")
      if (firstInput) {
        setTimeout(() => firstInput.focus(), 100)
      }
    } else {
      console.error("Modal not found")
    }
  }

  closeModal() {
    const modal = document.querySelector('[data-school-contact-modal-target="modal"]')
    
    if (modal) {
      modal.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
      document.removeEventListener("keydown", this.boundHandleEscape)
      
      // Reset form
      const form = modal.querySelector('[data-school-contact-modal-target="form"]')
      if (form) {
        form.reset()
      }
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.closeModal()
    }
  }

  submitForm(event) {
    event.preventDefault()
    console.log("Submitting form...")
    
    // Check Facebook authentication before proceeding
    if (!this.facebookAuthenticatedValue) {
      this.handleFacebookAuthRequired()
      return
    }
    
    const form = event.target
    const formData = new FormData(form)
    
    // Basic validation
    const name = formData.get('name')?.trim()
    const email = formData.get('email')?.trim()
    const message = formData.get('message')?.trim()
    const childrenCount = formData.get('children_count')
    
    if (!name) {
      this.showErrorMessage('Please enter your name')
      return
    }
    
    if (!email || !this.isValidEmail(email)) {
      this.showErrorMessage('Please enter a valid email address')
      return
    }
    
    if (!message) {
      this.showErrorMessage('Please enter a message')
      return
    }
    
    const childrenCountNum = parseInt(childrenCount)
    if (!childrenCount || isNaN(childrenCountNum) || childrenCountNum < 1 || childrenCountNum > 20) {
      this.showErrorMessage('Please enter a valid number of children (1-20)')
      return
    }
    
    // Get submit button and show loading
    const submitButton = form.querySelector('[data-school-contact-modal-target="submitButton"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Sending...
      `
    }

    // Add school_inquiry wrapper to form data
    const wrappedData = new FormData()
    for (let [key, value] of formData.entries()) {
      wrappedData.append(`school_inquiry[${key}]`, value)
    }

    // Submit via fetch
    fetch(form.action, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      body: wrappedData
    })
    .then(response => {
      if (response.status === 403 || response.status === 401) {
        // Handle authentication required response
        return response.json().then(data => {
          this.handleFacebookAuthRequired()
          throw new Error('Authentication required')
        })
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        this.showSuccessMessage(data.message)
        this.closeModal()
      } else if (data.requires_facebook_auth) {
        this.handleFacebookAuthRequired()
      } else {
        this.showErrorMessage(data.errors ? data.errors.join(', ') : 'An error occurred')
        this.resetSubmitButton(submitButton)
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showErrorMessage('An error occurred while sending your message')
      this.resetSubmitButton(submitButton)
    })
  }

  resetSubmitButton(submitButton = null) {
    if (!submitButton) {
      submitButton = document.querySelector('[data-school-contact-modal-target="submitButton"]')
    }
    if (submitButton) {
      submitButton.disabled = false
      submitButton.innerHTML = 'Send Message'
    }
  }

  showSuccessMessage(message) {
    this.showToast('success', message)
  }

  showErrorMessage(message) {
    this.showToast('error', message)
  }

  showToast(type, message) {
    // Remove any existing toasts
    const existingToasts = document.querySelectorAll('.contact-toast')
    existingToasts.forEach(toast => toast.remove())

    // Create toast element
    const toast = document.createElement('div')
    toast.className = `contact-toast fixed top-4 right-4 max-w-sm w-full z-50 transform transition-transform duration-300 translate-x-full`
    
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
        <button type="button" class="flex-shrink-0 text-white hover:text-gray-200" onclick="this.closest('.contact-toast').remove()">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `

    // Add to page
    document.body.appendChild(toast)

    // Animate in
    setTimeout(() => {
      toast.classList.remove('translate-x-full')
      toast.classList.add('translate-x-0')
    }, 100)

    // Auto remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.classList.remove('translate-x-0')
        toast.classList.add('translate-x-full')
        setTimeout(() => toast.remove(), 300)
      }
    }, 5000)
  }

  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  handleFacebookAuthRequired() {
    // Store form data in session storage for restoration after Facebook login
    const form = document.querySelector('[data-school-contact-modal-target="form"]')
    if (form) {
      const formData = new FormData(form)
      const formObject = {}
      for (let [key, value] of formData.entries()) {
        formObject[key] = value
      }
      sessionStorage.setItem('pendingModalContactForm', JSON.stringify(formObject))
    }
    
    // Store school context for Facebook OAuth callback
    fetch(`/users/auth/facebook/store_school`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ school_id: this.schoolIdValue })
    }).then(() => {
      // Close the modal before Facebook login
      this.closeModal()
      
      // Use Facebook JavaScript SDK for authentication
      if (typeof window.loginWithFacebook === 'function') {
        window.loginWithFacebook()
      } else {
        // Fallback to OAuth redirect if SDK not available
        window.location.href = '/users/auth/facebook'
      }
    }).catch(error => {
      console.error('Error storing school context:', error)
      this.showErrorMessage('Please sign in with Facebook to contact schools.')
    })
  }

  // Method to restore form data after Facebook authentication
  restoreFormData() {
    const savedData = sessionStorage.getItem('pendingModalContactForm')
    if (savedData) {
      try {
        const formObject = JSON.parse(savedData)
        const form = document.querySelector('[data-school-contact-modal-target="form"]')
        if (form) {
          Object.keys(formObject).forEach(key => {
            const input = form.querySelector(`[name="${key}"]`)
            if (input) {
              input.value = formObject[key]
            }
          })
          // Auto-open modal and submit if data was restored
          this.openModal()
          setTimeout(() => {
            form.dispatchEvent(new Event('submit'))
          }, 500)
        }
        sessionStorage.removeItem('pendingModalContactForm')
      } catch (error) {
        console.error('Error restoring form data:', error)
        sessionStorage.removeItem('pendingModalContactForm')
      }
    }
  }
}