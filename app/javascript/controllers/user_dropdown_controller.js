import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "button"]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const dropdown = this.dropdownTarget
    const isHidden = dropdown.classList.contains("hidden")
    
    if (isHidden) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    this.dropdownTarget.classList.remove("hidden")
    document.addEventListener("click", this.boundClickOutside)
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
    document.removeEventListener("click", this.boundClickOutside)
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}