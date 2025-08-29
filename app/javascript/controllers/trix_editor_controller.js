import { Controller } from "@hotwired/stimulus"
import "trix"

// Trix rich text editor controller
export default class extends Controller {
  static targets = ["editor"]

  connect() {
    // Add custom CSS for Trix editor
    this.loadTrixStyles()
    
    // Listen for Trix events
    this.element.addEventListener("trix-change", this.handleContentChange.bind(this))
    this.element.addEventListener("trix-selection-change", this.handleSelectionChange.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("trix-change", this.handleContentChange.bind(this))
    this.element.removeEventListener("trix-selection-change", this.handleSelectionChange.bind(this))
  }

  handleContentChange(event) {
    // Content has changed - you can add auto-save logic here if needed
    console.log("Trix content changed")
  }

  handleSelectionChange(event) {
    // Selection has changed - for toolbar state updates
  }

  loadTrixStyles() {
    // Load Trix CSS if not already loaded
    if (!document.querySelector('link[href*="trix"]')) {
      const link = document.createElement('link')
      link.rel = 'stylesheet'
      link.href = 'https://unpkg.com/trix@2.0.8/dist/trix.css'
      document.head.appendChild(link)
    }
  }
}