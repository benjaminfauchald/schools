import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.isOpen = true
    
    // Close dropdown when clicking outside
    this.clickOutsideHandler = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.isOpen = false
    
    // Remove event listener
    if (this.clickOutsideHandler) {
      document.removeEventListener("click", this.clickOutsideHandler)
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    if (this.clickOutsideHandler) {
      document.removeEventListener("click", this.clickOutsideHandler)
    }
  }
}