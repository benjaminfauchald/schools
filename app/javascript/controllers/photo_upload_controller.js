import { Controller } from "@hotwired/stimulus"

// Photo upload controller with drag & drop, preview, and validation
export default class extends Controller {
  static targets = ["input", "preview", "uploadSection", "uploadStatus"]
  static values = { 
    maxFiles: Number,
    maxSize: Number,
    schoolId: Number
  }

  connect() {
    this.setupDropZone()
  }

  setupDropZone() {
    const dropZone = this.element
    
    // Prevent default drag behaviors
    ;['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.preventDefaults.bind(this), false)
    })

    // Highlight drop zone when item is dragged over it
    ;['dragenter', 'dragover'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.highlight.bind(this), false)
    })

    ;['dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.unhighlight.bind(this), false)
    })

    // Handle dropped files
    dropZone.addEventListener('drop', this.handleDrop.bind(this), false)
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight() {
    this.element.classList.add('border-blue-400', 'bg-blue-50')
  }

  unhighlight() {
    this.element.classList.remove('border-blue-400', 'bg-blue-50')
  }

  handleDrop(e) {
    const files = e.dataTransfer.files
    this.handleFiles({ target: { files } })
  }

  handleFiles(event) {
    const files = Array.from(event.target.files)
    
    // Validate files
    const validFiles = this.validateFiles(files)
    if (validFiles.length === 0) return
    
    // Show previews
    this.showPreviews(validFiles)
    
    // Update the file input with valid files
    this.updateFileInput(validFiles)
  }

  validateFiles(files) {
    const validFiles = []
    const maxFiles = this.maxFilesValue || 10
    const maxSize = this.maxSizeValue || 5242880 // 5MB
    
    if (files.length > maxFiles) {
      this.showError(`Maximum ${maxFiles} files allowed`)
      return []
    }
    
    files.forEach(file => {
      // Check file type
      if (!file.type.startsWith('image/')) {
        this.showError(`${file.name} is not a valid image file`)
        return
      }
      
      // Check file size
      if (file.size > maxSize) {
        this.showError(`${file.name} is too large. Maximum size is ${this.formatFileSize(maxSize)}`)
        return
      }
      
      validFiles.push(file)
    })
    
    return validFiles
  }

  showPreviews(files) {
    this.previewTarget.classList.remove('hidden')
    this.previewTarget.innerHTML = ''
    
    // Show upload button when files are selected
    if (this.hasUploadSectionTarget) {
      this.uploadSectionTarget.classList.remove('hidden')
    }
    
    files.forEach((file, index) => {
      const reader = new FileReader()
      reader.onload = (e) => {
        const preview = this.createPreviewElement(e.target.result, file.name, index)
        this.previewTarget.appendChild(preview)
      }
      reader.readAsDataURL(file)
    })
  }

  createPreviewElement(src, fileName, index) {
    const div = document.createElement('div')
    div.className = 'relative aspect-square bg-gray-100 rounded-lg overflow-hidden group'
    
    div.innerHTML = `
      <img src="${src}" 
           alt="Preview of ${fileName}" 
           class="w-full h-full object-cover">
      
      <button type="button" 
              data-action="click->photo-upload#removePreview" 
              data-index="${index}"
              class="absolute top-2 right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity text-sm font-bold hover:bg-red-600"
              title="Remove photo">
        ×
      </button>
      
      <div class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-50 text-white text-xs p-2 truncate">
        ${fileName}
      </div>
    `
    
    return div
  }

  removePreview(event) {
    event.preventDefault()
    const index = parseInt(event.currentTarget.dataset.index)
    const previewElement = event.currentTarget.closest('.group')
    
    // Remove preview element
    previewElement.remove()
    
    // Update file input by removing the file at this index
    this.removeFileAtIndex(index)
    
    // Hide preview container and upload button if no more previews
    if (this.previewTarget.children.length === 0) {
      this.previewTarget.classList.add('hidden')
      if (this.hasUploadSectionTarget) {
        this.uploadSectionTarget.classList.add('hidden')
      }
    }
  }

  removeFileAtIndex(indexToRemove) {
    const input = this.inputTarget
    const files = Array.from(input.files)
    
    // Create new FileList without the removed file
    const dt = new DataTransfer()
    files.forEach((file, index) => {
      if (index !== indexToRemove) {
        dt.items.add(file)
      }
    })
    
    input.files = dt.files
  }

  updateFileInput(files) {
    const input = this.inputTarget
    const dt = new DataTransfer()
    
    files.forEach(file => {
      dt.items.add(file)
    })
    
    input.files = dt.files
  }

  showError(message) {
    // Create or update error message
    let errorElement = this.element.querySelector('.photo-upload-error')
    
    if (!errorElement) {
      errorElement = document.createElement('div')
      errorElement.className = 'photo-upload-error mt-4 p-3 bg-red-50 border border-red-200 rounded-md'
      this.element.appendChild(errorElement)
    }
    
    errorElement.innerHTML = `
      <div class="flex">
        <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        <div class="ml-3">
          <p class="text-sm text-red-800">${message}</p>
        </div>
      </div>
    `
    
    // Auto-remove error after 5 seconds
    setTimeout(() => {
      if (errorElement.parentNode) {
        errorElement.remove()
      }
    }, 5000)
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
  
  uploadPhotos(event) {
    event.preventDefault()
    
    const files = this.inputTarget.files
    if (files.length === 0) {
      this.showError('No files selected')
      return
    }
    
    // Get school ID from the page URL or data attribute
    const schoolId = window.location.pathname.match(/schools\/(\d+)/)?.[1]
    if (!schoolId) {
      this.showError('Unable to determine school ID')
      return
    }
    
    // Update status
    if (this.hasUploadStatusTarget) {
      this.uploadStatusTarget.textContent = 'Uploading...'
    }
    
    // Create FormData
    const formData = new FormData()
    Array.from(files).forEach(file => {
      formData.append('school[photos][]', file)
    })
    
    // Get CSRF token
    const csrfToken = document.querySelector('[name="csrf-token"]')?.content
    
    // Upload photos
    fetch(`/school_owner/schools/${schoolId}`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        // Show success message
        if (this.hasUploadStatusTarget) {
          this.uploadStatusTarget.textContent = 'Photos uploaded successfully!'
          this.uploadStatusTarget.classList.add('text-green-600')
        }
        
        // Reload page to show new photos
        setTimeout(() => {
          window.location.reload()
        }, 1500)
      } else {
        this.showError(data.error || 'Upload failed')
        if (this.hasUploadStatusTarget) {
          this.uploadStatusTarget.textContent = ''
        }
      }
    })
    .catch(error => {
      console.error('Upload error:', error)
      this.showError('Upload failed: ' + error.message)
      if (this.hasUploadStatusTarget) {
        this.uploadStatusTarget.textContent = ''
      }
    })
  }
}