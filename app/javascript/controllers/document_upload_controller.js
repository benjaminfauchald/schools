import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dropzone", "fileInput", "progressContainer", "progressBar", "progressText",
    "errorContainer", "errorMessage", "successContainer", "successMessage", 
    "documentsList"
  ]
  
  static values = { 
    schoolId: String,
    maxSize: Number
  }
  
  connect() {
    this.isUploading = false
    this.maxSizeBytes = this.maxSizeValue || 10485760 // 10MB default
    this.allowedExtensions = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx']
    this.allowedTypes = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation'
    ]
  }
  
  // Drag and drop handlers
  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.add('border-indigo-400', 'bg-indigo-50')
  }
  
  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    // Only remove styles if we're actually leaving the dropzone
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove('border-indigo-400', 'bg-indigo-50')
    }
  }
  
  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove('border-indigo-400', 'bg-indigo-50')
    
    const files = Array.from(event.dataTransfer.files)
    this.processFiles(files)
  }
  
  // File dialog handlers
  openFileDialog(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
  
  handleFileSelect(event) {
    const files = Array.from(event.target.files)
    this.processFiles(files)
    // Clear the input so the same file can be selected again
    event.target.value = ''
  }
  
  // File processing
  async processFiles(files) {
    if (this.isUploading) {
      this.showError('Upload already in progress. Please wait.')
      return
    }
    
    if (files.length === 0) {
      return
    }
    
    // Validate files
    const validFiles = []
    const errors = []
    
    for (const file of files) {
      const validation = this.validateFile(file)
      if (validation.valid) {
        validFiles.push(file)
      } else {
        errors.push(`${file.name}: ${validation.error}`)
      }
    }
    
    if (errors.length > 0) {
      this.showError(`File validation errors:\n${errors.join('\n')}`)
      return
    }
    
    if (validFiles.length === 0) {
      this.showError('No valid files to upload.')
      return
    }
    
    // Upload files
    await this.uploadFiles(validFiles)
  }
  
  validateFile(file) {
    // Check file size
    if (file.size > this.maxSizeBytes) {
      return {
        valid: false,
        error: `File too large (${this.formatFileSize(file.size)}). Maximum size is ${this.formatFileSize(this.maxSizeBytes)}.`
      }
    }
    
    // Check file extension
    const extension = this.getFileExtension(file.name).toLowerCase()
    if (!this.allowedExtensions.includes(extension)) {
      return {
        valid: false,
        error: `File type not supported (${extension}). Supported types: ${this.allowedExtensions.join(', ')}`
      }
    }
    
    // Check MIME type as backup
    if (file.type && !this.allowedTypes.includes(file.type)) {
      console.warn(`MIME type mismatch for ${file.name}: ${file.type}`)
      // Don't fail on MIME type mismatch, as it can be unreliable
    }
    
    return { valid: true }
  }
  
  async uploadFiles(files) {
    this.isUploading = true
    this.hideMessages()
    this.showProgress(0)
    
    let successCount = 0
    let errorCount = 0
    const errors = []
    
    try {
      for (let i = 0; i < files.length; i++) {
        const file = files[i]
        const progress = ((i + 1) / files.length) * 100
        
        this.updateProgress(progress, `Uploading ${file.name}...`)
        
        try {
          await this.uploadSingleFile(file)
          successCount++
        } catch (error) {
          console.error(`Failed to upload ${file.name}:`, error)
          errors.push(`${file.name}: ${error.message}`)
          errorCount++
        }
      }
      
      // Show results
      if (successCount > 0) {
        const message = `Successfully uploaded ${successCount} document${successCount > 1 ? 's' : ''}.`
        this.showSuccess(message)
        await this.refreshDocumentList()
      }
      
      if (errorCount > 0) {
        const message = `Failed to upload ${errorCount} document${errorCount > 1 ? 's' : ''}:\n${errors.join('\n')}`
        this.showError(message)
      }
      
    } catch (error) {
      console.error('Upload process failed:', error)
      this.showError('Upload failed. Please try again.')
    } finally {
      this.isUploading = false
      this.hideProgress()
    }
  }
  
  async uploadSingleFile(file) {
    const formData = new FormData()
    formData.append('document', file)
    
    const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/upload_document`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ errors: ['Network error'] }))
      throw new Error(errorData.errors ? errorData.errors.join(', ') : `HTTP ${response.status}`)
    }
    
    const data = await response.json()
    if (!data.success) {
      throw new Error(data.errors ? data.errors.join(', ') : 'Upload failed')
    }
    
    return data
  }
  
  // Document actions
  async deleteDocument(event) {
    const documentId = event.currentTarget.dataset.documentId
    const documentName = event.currentTarget.dataset.documentName
    
    if (!confirm(`Are you sure you want to delete "${documentName}"? This action cannot be undone.`)) {
      return
    }
    
    try {
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/delete_document`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ document_id: documentId })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.showSuccess(data.message)
        await this.refreshDocumentList()
      } else {
        this.showError(data.errors ? data.errors.join(', ') : 'Failed to delete document')
      }
    } catch (error) {
      console.error('Delete failed:', error)
      this.showError('Failed to delete document. Please try again.')
    }
  }
  
  async toggleAI(event) {
    const documentId = event.currentTarget.dataset.documentId
    
    try {
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/toggle_document_ai`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ document_id: documentId })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.showSuccess(data.message)
        await this.refreshDocumentList()
      } else {
        this.showError(data.errors ? data.errors.join(', ') : 'Failed to toggle AI setting')
      }
    } catch (error) {
      console.error('Toggle AI failed:', error)
      this.showError('Failed to update AI setting. Please try again.')
    }
  }
  
  async reprocessDocument(event) {
    const documentId = event.currentTarget.dataset.documentId
    
    if (!confirm('Are you sure you want to reprocess this document? This will overwrite existing extracted text and embeddings.')) {
      return
    }
    
    try {
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/reprocess_document`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ document_id: documentId })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.showSuccess(data.message)
        await this.refreshDocumentList()
      } else {
        this.showError(data.errors ? data.errors.join(', ') : 'Failed to reprocess document')
      }
    } catch (error) {
      console.error('Reprocess failed:', error)
      this.showError('Failed to reprocess document. Please try again.')
    }
  }
  
  async refreshDocumentList() {
    try {
      const response = await fetch(`/school_owner/schools/${this.schoolIdValue}/edit`, {
        headers: {
          'Accept': 'text/html',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')
        const newDocumentsList = doc.querySelector('[data-document-upload-target="documentsList"]')
        
        if (newDocumentsList && this.hasDocumentsListTarget) {
          this.documentsListTarget.innerHTML = newDocumentsList.innerHTML
        }
      }
    } catch (error) {
      console.error('Failed to refresh documents list:', error)
    }
  }
  
  // UI helper methods
  showProgress(percent) {
    this.hideMessages()
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.remove('hidden')
      this.updateProgress(percent, 'Preparing upload...')
    }
  }
  
  updateProgress(percent, message) {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percent}%`
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${Math.round(percent)}% - ${message}`
    }
  }
  
  hideProgress() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.add('hidden')
    }
  }
  
  showError(message) {
    this.hideMessages()
    if (this.hasErrorContainerTarget && this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorContainerTarget.classList.remove('hidden')
      
      // Auto-hide after 10 seconds
      setTimeout(() => this.hideMessages(), 10000)
    }
  }
  
  showSuccess(message) {
    this.hideMessages()
    if (this.hasSuccessContainerTarget && this.hasSuccessMessageTarget) {
      this.successMessageTarget.textContent = message
      this.successContainerTarget.classList.remove('hidden')
      
      // Auto-hide after 5 seconds
      setTimeout(() => this.hideMessages(), 5000)
    }
  }
  
  hideMessages() {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.classList.add('hidden')
    }
    if (this.hasSuccessContainerTarget) {
      this.successContainerTarget.classList.add('hidden')
    }
  }
  
  // Utility methods
  getFileExtension(filename) {
    return filename.substring(filename.lastIndexOf('.'))
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
}