import { Controller } from "@hotwired/stimulus"

// Layout navigation controller handles mobile menu toggle for main navigation
export default class extends Controller {
  static targets = ["mobileMenu"]

  // Toggle mobile menu
  toggleMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.toggle('hidden')
    }
  }

  // Close mobile menu
  closeMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.add('hidden')
    }
  }
}