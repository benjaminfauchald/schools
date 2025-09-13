import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="facebook-logout"
export default class extends Controller {
  connect() {
    // Check if we just logged out and need to clear Facebook session
    if (this.element.dataset.facebookLogout === "true") {
      this.handleFacebookLogout()
    }
  }

  handleFacebookLogout() {
    // Check if Facebook SDK is loaded
    if (typeof FB !== 'undefined') {
      FB.getLoginStatus((response) => {
        if (response.status === 'connected') {
          // User is logged into Facebook, log them out
          FB.logout((response) => {
            console.log('User logged out from Facebook')
          })
        }
      })
    }
  }

  // Manual logout button handler if needed
  logout(event) {
    event.preventDefault()
    
    // First check Facebook login status
    if (typeof FB !== 'undefined') {
      FB.getLoginStatus((response) => {
        if (response.status === 'connected') {
          // Log out from Facebook first
          FB.logout(() => {
            // Then submit the logout form
            this.element.closest('form')?.submit() || 
            window.location.href = this.element.href
          })
        } else {
          // Not logged into Facebook, just do regular logout
          this.element.closest('form')?.submit() || 
          window.location.href = this.element.href
        }
      })
    } else {
      // Facebook SDK not loaded, just do regular logout
      this.element.closest('form')?.submit() || 
      window.location.href = this.element.href
    }
  }
}