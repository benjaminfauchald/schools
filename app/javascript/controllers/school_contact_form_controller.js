import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitButton", "facebookButton", "authSection", "messages", "successMessage", "errorMessage", "errorText"]
  static values = { schoolId: Number, userSignedIn: Boolean, facebookAuthenticated: Boolean, debugMode: Boolean }

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    
    // Check if user just returned from OAuth and restore form if needed
    this.restoreFormFromSession()
    
    // Check for Facebook auth complete flag (set by server after OAuth)
    // This is an additional check to ensure auto-submission happens
    if (this.checkFacebookAuthComplete()) {
      if (this.debugModeValue) {
        console.log('Facebook auth complete flag detected')
      }
      // Ensure form is restored and submitted
      this.restoreFormFromSession()
    }
    
    // Load previously saved form data from cookies
    this.loadFormDataFromCookies()
  }
  
  checkFacebookAuthComplete() {
    // Check for flash message or meta tag that indicates Facebook auth just completed
    const flashNotice = document.querySelector('.flash-notice, .alert-notice')
    if (flashNotice && flashNotice.textContent.includes('Successfully signed in with Facebook')) {
      return true
    }
    
    // Also check sessionStorage for pending form data
    const pendingForm = sessionStorage.getItem('pendingContactForm')
    return pendingForm && this.facebookAuthenticatedValue
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
    if (this.debugModeValue) {
      console.log('Form data being submitted:')
      for (let [key, value] of formData.entries()) {
        console.log(`${key}: ${value}`)
      }
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
        // Save form data to cookies for next time
        this.saveFormDataToCookies()
        
        // Show success modal instead of inline message
        this.showSuccessModal(result.message)
        this.formTarget.reset()
      } else {
        const errorMessage = result.errors ? result.errors.join(', ') : 'Failed to send message'
        if (this.debugModeValue) {
          console.error('Validation errors:', result.errors)
        }
        this.showMessage(errorMessage, 'error')
      }
    } catch (error) {
      if (this.debugModeValue) {
        console.error('Contact form error:', error)
      }
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
    event.preventDefault()
    
    // Store form data before Facebook authentication
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
      returnUrl: window.location.href,
      autoSubmit: true  // Flag to auto-submit after auth
    }))
    
    // Store school ID in session for server-side context
    fetch('/users/auth/facebook/store_school', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ school_id: this.schoolIdValue })
    }).then(() => {
      // Use Facebook JavaScript SDK for authentication
      if (typeof window.loginWithFacebook === 'function') {
        // Set up a callback for when SDK auth completes
        window.facebookAuthCallback = () => {
          if (this.debugModeValue) {
            console.log('Facebook SDK auth completed, reloading page')
          }
          // Reload the page to get updated auth status
          window.location.reload()
        }
        window.loginWithFacebook()
      } else {
        // Fallback to OAuth redirect if SDK not available
        window.location.href = '/users/auth/facebook'
      }
    }).catch(error => {
      if (this.debugModeValue) {
        console.warn('Failed to store school context:', error)
      }
      // Still try Facebook auth even if storing context fails
      if (typeof window.loginWithFacebook === 'function') {
        window.facebookAuthCallback = () => {
          window.location.reload()
        }
        window.loginWithFacebook()
      } else {
        window.location.href = '/users/auth/facebook'
      }
    })
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
      const { schoolId, formData, returnUrl, autoSubmit } = JSON.parse(pendingForm)
      
      // Only restore if we're on the right school page
      if (schoolId === this.schoolIdValue) {
        // Restore form values
        Object.entries(formData).forEach(([key, value]) => {
          const input = this.formTarget.querySelector(`[name="${key}"]`)
          if (input) {
            input.value = value
          }
        })

        // Clear the stored form data
        sessionStorage.removeItem('pendingContactForm')
        
        // Check if user is now authenticated with Facebook and autoSubmit flag is set
        if (this.facebookAuthenticatedValue && autoSubmit) {
          // Show brief status message
          this.showMessage('Authentication successful! Sending your message...', 'success')
          
          // Wait a brief moment for the user to see the status, then submit
          setTimeout(() => {
            if (this.debugModeValue) {
              console.log('Auto-submitting form after successful Facebook authentication')
            }
            // Programmatically submit the form
            this.submitFormAfterAuth()
          }, 500) // Short delay to let the page fully load
        } else if (this.facebookAuthenticatedValue) {
          // User is authenticated but didn't come from the form
          this.showMessage('Successfully signed in! You can now send your message.', 'success')
        } else {
          // If not authenticated, show error
          this.showMessage('Please sign in with Facebook to send your message.', 'error')
        }
      }
    } catch (error) {
      if (this.debugModeValue) {
        console.error('Error restoring form from session:', error)
      }
      sessionStorage.removeItem('pendingContactForm')
    }
  }
  
  // New method to handle auto-submission after Facebook auth
  async submitFormAfterAuth() {
    // Validate that we have all required fields
    const nameField = this.formTarget.querySelector('[name="school_inquiry[name]"]')
    const emailField = this.formTarget.querySelector('[name="school_inquiry[email]"]')
    const messageField = this.formTarget.querySelector('[name="school_inquiry[message]"]')
    
    if (!nameField?.value.trim() || !emailField?.value.trim() || !messageField?.value.trim()) {
      if (this.debugModeValue) {
        console.log('Missing required fields, not auto-submitting')
      }
      this.showMessage('Please complete all required fields.', 'error')
      return
    }
    
    // Show sending status
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = 'Sending...'
    }

    // Use the form's natural FormData
    const formData = new FormData(this.formTarget)
    
    if (this.debugModeValue) {
      console.log('Auto-submitting form data after Facebook auth:')
      for (let [key, value] of formData.entries()) {
        console.log(`${key}: ${value}`)
      }
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
        // Save form data to cookies for next time
        this.saveFormDataToCookies()
        
        // Show success modal
        this.showSuccessModal(result.message || 'Your message has been sent successfully! The school will contact you soon.')
        this.formTarget.reset()
      } else {
        const errorMessage = result.errors ? result.errors.join(', ') : 'Failed to send message'
        if (this.debugModeValue) {
          console.error('Validation errors:', result.errors)
        }
        this.showMessage(errorMessage, 'error')
      }
    } catch (error) {
      if (this.debugModeValue) {
        console.error('Contact form error:', error)
      }
      this.showMessage('Network error. Please check your connection and try again.', 'error')
    } finally {
      // Re-enable submit button
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Send Message to School'
      }
    }
  }

  // Show success modal
  showSuccessModal(message) {
    // Create modal HTML
    const modalHTML = `
      <div id="success-modal" class="fixed inset-0 z-50 overflow-y-auto" style="background-color: rgba(0, 0, 0, 0.75);" onclick="if(event.target === this) { this.remove(); document.body.classList.remove('overflow-hidden'); }">
        <div class="flex items-center justify-center min-h-screen p-4">
          <div class="relative bg-white rounded-lg shadow-xl w-full max-w-md">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center">
                <div class="flex-shrink-0 w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                  <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-lg font-semibold text-gray-900">Message Sent Successfully!</h3>
                </div>
              </div>
              <button type="button" onclick="document.getElementById('success-modal').remove(); document.body.classList.remove('overflow-hidden');" 
                      class="text-gray-400 hover:text-gray-600 transition-colors">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>

            <!-- Modal Body -->
            <div class="p-6">
              <p class="text-gray-700 mb-4">${message}</p>
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-3">
                <p class="text-sm text-blue-800">
                  <strong>What's next?</strong> The school will review your inquiry and contact you directly via email or phone.
                </p>
              </div>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 border-t border-gray-200">
              <button type="button" onclick="document.getElementById('success-modal').remove(); document.body.classList.remove('overflow-hidden');" 
                      class="w-full bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500">
                Continue Exploring Schools
              </button>
            </div>
          </div>
        </div>
      </div>
    `

    // Remove any existing modal
    const existingModal = document.getElementById('success-modal')
    if (existingModal) {
      existingModal.remove()
    }

    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHTML)
    document.body.classList.add('overflow-hidden')

    // Auto-remove modal after 8 seconds
    setTimeout(() => {
      const modal = document.getElementById('success-modal')
      if (modal) {
        modal.remove()
        document.body.classList.remove('overflow-hidden')
      }
    }, 8000)

    // Also clear any inline messages
    this.hideAllMessages()
  }

  // Load form data from cookies if available
  loadFormDataFromCookies() {
    const savedData = this.getCookie('contactFormData')
    if (this.debugModeValue) {
      console.log('Saved cookie data:', savedData)
    }
    
    if (!savedData) {
      if (this.debugModeValue) {
        console.log('No saved form data found in cookies')
      }
      return
    }

    try {
      const formData = JSON.parse(savedData)
      if (this.debugModeValue) {
        console.log('Parsed form data:', formData)
      }
      
      // Only populate non-message fields (name, email, phone)
      const fieldsToRestore = ['school_inquiry[name]', 'school_inquiry[email]', 'school_inquiry[phone]']
      
      fieldsToRestore.forEach(fieldName => {
        if (this.debugModeValue) {
          console.log('Looking for field:', fieldName)
        }
        if (formData[fieldName]) {
          const input = this.formTarget.querySelector(`[name="${fieldName}"]`)
          if (this.debugModeValue) {
            console.log('Found input:', input, 'Current value:', input?.value)
          }
          if (input && !input.value) { // Only fill if field is empty
            input.value = formData[fieldName]
            if (this.debugModeValue) {
              console.log('Set value:', formData[fieldName])
            }
          }
        }
      })
    } catch (error) {
      if (this.debugModeValue) {
        console.error('Error loading form data from cookies:', error)
      }
      // Clear corrupted cookie
      this.setCookie('contactFormData', '', -1)
    }
  }

  // Save form data to cookies (excluding message and sensitive fields)
  saveFormDataToCookies() {
    if (this.debugModeValue) {
      console.log('Saving form data to cookies...')
    }
    const formData = new FormData(this.formTarget)
    const dataToSave = {}
    
    // Only save name, email, and phone (not message or children count)
    const fieldsToSave = ['school_inquiry[name]', 'school_inquiry[email]', 'school_inquiry[phone]']
    
    fieldsToSave.forEach(fieldName => {
      const value = formData.get(fieldName)
      if (this.debugModeValue) {
        console.log('Field:', fieldName, 'Value:', value)
      }
      if (value && value.trim()) {
        dataToSave[fieldName] = value.trim()
      }
    })
    
    if (this.debugModeValue) {
      console.log('Data to save:', dataToSave)
    }
    // Save to cookie for 90 days
    this.setCookie('contactFormData', JSON.stringify(dataToSave), 90)
    if (this.debugModeValue) {
      console.log('Cookie saved successfully')
    }
  }

  // Helper method to set cookies
  setCookie(name, value, days) {
    let expires = ''
    if (days) {
      const date = new Date()
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
      expires = '; expires=' + date.toUTCString()
    }
    document.cookie = name + '=' + encodeURIComponent(value) + expires + '; path=/; SameSite=Lax'
  }

  // Helper method to get cookies
  getCookie(name) {
    const nameEQ = name + '='
    const ca = document.cookie.split(';')
    for (let i = 0; i < ca.length; i++) {
      let c = ca[i]
      while (c.charAt(0) === ' ') c = c.substring(1, c.length)
      if (c.indexOf(nameEQ) === 0) {
        return decodeURIComponent(c.substring(nameEQ.length, c.length))
      }
    }
    return null
  }

}