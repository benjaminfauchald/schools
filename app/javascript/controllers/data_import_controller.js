import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="data-import"
export default class extends Controller {
  static targets = [
    "statusModal", "modalTitle", "modalMessage",
    "loadingIcon", "successIcon", "errorIcon",
    "closeButton"
  ]
  
  static values = {
    schoolId: Number,
    url: String
  }
  
  connect() {
    this.pollInterval = null
  }
  
  disconnect() {
    this.stopPolling()
  }
  
  importWebsite() {
    // Disable the import button
    const importButton = event.target
    const originalText = importButton.innerHTML
    importButton.disabled = true
    importButton.innerHTML = `
      <svg class="-ml-0.5 mr-2 h-4 w-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
      </svg>
      Starting...
    `
    
    // Show the modal
    this.showModal("Importing Data...", "Preparing to import data from your website. This may take a few minutes.")
    
    // Start the import
    const importUrl = `/school_owner/schools/${this.schoolIdValue}/import_website_data`
    
    fetch(importUrl, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Start polling for status updates
        this.startPolling()
      } else {
        this.showError(data.message || 'Failed to start import')
        this.resetImportButton(importButton, originalText)
      }
    })
    .catch(error => {
      console.error('Import request failed:', error)
      this.showError('Failed to start import. Please try again.')
      this.resetImportButton(importButton, originalText)
    })
  }
  
  startPolling() {
    // Poll every 5 seconds for status updates
    this.pollInterval = setInterval(() => {
      this.checkImportStatus()
    }, 5000)
    
    // Check immediately
    this.checkImportStatus()
  }
  
  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }
  
  checkImportStatus() {
    const statusUrl = `/school_owner/schools/${this.schoolIdValue}/import_status`
    
    fetch(statusUrl, {
      headers: {
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      switch(data.status) {
        case 'crawling':
          // Still in progress
          this.updateModalMessage("Import in progress... Please wait while we process your website data.")
          break
          
        case 'completed':
          // Success
          this.stopPolling()
          this.showSuccess(`Import completed successfully! Found ${data.pages_found || 0} pages.`)
          setTimeout(() => {
            this.closeModal()
            // Refresh the page to show updated data
            window.location.reload()
          }, 3000)
          break
          
        case 'failed':
          // Error
          this.stopPolling()
          this.showError(data.error || 'Import failed')
          break
          
        default:
          // Unknown status
          this.stopPolling()
          this.showError('Unknown import status')
          break
      }
    })
    .catch(error => {
      console.error('Status check failed:', error)
      this.stopPolling()
      this.showError('Failed to check import status')
    })
  }
  
  showModal(title, message) {
    this.modalTitleTarget.textContent = title
    this.modalMessageTarget.textContent = message
    this.statusModalTarget.classList.remove('hidden')
    
    // Reset icon states
    this.loadingIconTarget.classList.remove('hidden')
    this.successIconTarget.classList.add('hidden')
    this.errorIconTarget.classList.add('hidden')
    
    // Disable close button initially
    this.closeButtonTarget.disabled = true
  }
  
  showSuccess(message) {
    this.modalTitleTarget.textContent = "Import Completed"
    this.modalMessageTarget.textContent = message
    
    // Show success icon
    this.loadingIconTarget.classList.add('hidden')
    this.successIconTarget.classList.remove('hidden')
    this.errorIconTarget.classList.add('hidden')
    
    // Enable close button
    this.closeButtonTarget.disabled = false
  }
  
  showError(message) {
    this.modalTitleTarget.textContent = "Import Failed"
    this.modalMessageTarget.textContent = message
    
    // Show error icon
    this.loadingIconTarget.classList.add('hidden')
    this.successIconTarget.classList.add('hidden')
    this.errorIconTarget.classList.remove('hidden')
    
    // Enable close button
    this.closeButtonTarget.disabled = false
  }
  
  updateModalMessage(message) {
    this.modalMessageTarget.textContent = message
  }
  
  closeModal() {
    this.statusModalTarget.classList.add('hidden')
    this.stopPolling()
    
    // Reset all import buttons
    const importButtons = document.querySelectorAll('[data-action*="data-import#importWebsite"]')
    importButtons.forEach(button => {
      this.resetImportButton(button, `
        <svg class="-ml-0.5 mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
        </svg>
        Import
      `)
    })
  }
  
  resetImportButton(button, originalHTML) {
    button.disabled = false
    button.innerHTML = originalHTML
  }
}