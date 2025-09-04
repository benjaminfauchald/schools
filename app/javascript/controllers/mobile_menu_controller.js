import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.preventDefault()
    
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.style.display = "block"
    this.isOpen = true
  }

  close() {
    this.menuTarget.style.display = "none"
    this.isOpen = false
  }
}