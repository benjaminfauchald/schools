import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitButton", "facebookButton", "authSection", "messages", "successMessage", "errorMessage", "errorText"]
  static values = { schoolId: Number, userSignedIn: Boolean, facebookAuthenticated: Boolean }

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    
    // Check if user just returned from OAuth and restore form if needed
    this.restoreFormFromSession()
  }

  async submitForm(event) {
    event.preventDefault()
    
    if (!this.facebookAuthenticatedValue) {
      // User is not authenticated with Facebook, they need to authenticate first
      this.showMessage('Please sign in with Facebook to send your message.', 'error')
      return
    }

    // Client-side validation check
    const nameField = this.formTarget.querySelector('[name="school_inquiry[name]"]')
    const emailField = this.formTarget.querySelector('[name="school_inquiry[email]"]')
    const messageField = this.formTarget.querySelector('[name="school_inquiry[message]"]')
    
    if (!nameField?.value.trim()) {
      this.showMessage('Please enter your name.', 'error')
      nameField?.focus()
      return
    }
    
    if (!emailField?.value.trim()) {
      this.showMessage('Please enter your email address.', 'error')
      emailField?.focus()
      return
    }
    
    if (!messageField?.value.trim()) {
      this.showMessage('Please enter a message.', 'error')
      messageField?.focus()
      return
    }

    // Disable submit button during submission
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = 'Sending...'
    }

    // Use the form's natural FormData (Rails form helpers create correct parameter names)
    const formData = new FormData(this.formTarget)
    
    // Debug: Log form data before sending
    console.log('Form data being submitted:')
    for (let [key, value] of formData.entries()) {
      console.log(`${key}: ${value}`)
    }

    try {
      const response = await fetch(this.formTarget.action, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: formData
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const result = await response.json()

      if (result.success) {
        this.showMessage(result.message, 'success')
        this.formTarget.reset()
      } else {
        const errorMessage = result.errors ? result.errors.join(', ') : 'Failed to send message'
        console.error('Validation errors:', result.errors)
        this.showMessage(errorMessage, 'error')
      }
    } catch (error) {
      console.error('Contact form error:', error)
      this.showMessage('Network error. Please check your connection and try again.', 'error')
    } finally {
      // Re-enable submit button
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Send Message to School'
      }
    }
  }

  handleFacebookAuth(event) {
    // Store form data before redirect to Facebook
    const formData = new FormData(this.formTarget)
    const formValues = {}
    
    for (let [key, value] of formData.entries()) {
      if (key !== 'authenticity_token') {
        formValues[key] = value
      }
    }
    
    // Store in sessionStorage so we can restore after OAuth
    sessionStorage.setItem('pendingContactForm', JSON.stringify({
      schoolId: this.schoolIdValue,
      formData: formValues,
      returnUrl: window.location.href
    }))
    
    // Store school ID in session for server-side redirect
    fetch('/users/auth/facebook/store_school', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ school_id: this.schoolIdValue })
    }).catch(error => {
      console.warn('Failed to store school context:', error)
    })
    
    // Let the link proceed to Facebook OAuth
  }

  showMessage(message, type) {
    if (!this.hasMessagesTarget) return

    // Hide all messages first
    this.hideAllMessages()

    // Show the appropriate message
    if (type === 'success' && this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.remove('hidden')
    } else if (type === 'error' && this.hasErrorMessageTarget && this.hasErrorTextTarget) {
      this.errorTextTarget.textContent = message
      this.errorMessageTarget.classList.remove('hidden')
    }

    // Show the messages container
    this.messagesTarget.classList.remove('hidden')

    // Auto-hide success messages after 5 seconds
    if (type === 'success') {
      setTimeout(() => {
        this.hideAllMessages()
      }, 5000)
    }
  }

  hideAllMessages() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.classList.add('hidden')
    }
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.add('hidden')
    }
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('hidden')
    }
  }

  // Called when user returns from OAuth
  restoreFormFromSession() {
    const pendingForm = sessionStorage.getItem('pendingContactForm')
    if (!pendingForm) return

    try {
      const { schoolId, formData, returnUrl } = JSON.parse(pendingForm)
      
      // Only restore if we're on the right school page
      if (schoolId === this.schoolIdValue) {
        // Restore form values
        Object.entries(formData).forEach(([key, value]) => {
          const input = this.formTarget.querySelector(`[name="${key}"]`)
          if (input) {
            input.value = value
          }
        })

        // Show success message about authentication
        this.showMessage('Successfully signed in! You can now send your message.', 'success')
        
        // Clear the stored form data
        sessionStorage.removeItem('pendingContactForm')
        
        // Scroll to form
        this.element.scrollIntoView({ behavior: 'smooth' })
      }
    } catch (error) {
      console.error('Error restoring form from session:', error)
      sessionStorage.removeItem('pendingContactForm')
    }
  }
}