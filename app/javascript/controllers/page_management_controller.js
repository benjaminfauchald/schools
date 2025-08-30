import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "modalTitle", "pageId", "formMethod"]

  connect() {
    console.log("Page management controller connected")
    this.bindEvents()
    this.initializeTinyMCE()
  }

  initializeTinyMCE() {
    // Wait for modal to be shown before initializing TinyMCE
    document.addEventListener('DOMContentLoaded', () => {
      this.setupTinyMCEWhenModalOpens()
    })
  }

  setupTinyMCEWhenModalOpens() {
    // We'll initialize TinyMCE when the modal is opened
    // This prevents issues with TinyMCE initializing on hidden elements
  }

  createTinyMCEEditor() {
    const editorContainer = document.getElementById('page-content-input')
    if (!editorContainer || this.tinymce) return

    // Wait for TinyMCE to be available
    if (typeof window.tinymce === 'undefined') {
      console.log('TinyMCE not yet loaded, waiting...')
      setTimeout(() => this.createTinyMCEEditor(), 100)
      return
    }

    // Configure TinyMCE to preserve all HTML and CSS classes
    const tinymceOptions = {
      target: editorContainer,
      height: 400,
      menubar: false,
      plugins: [
        'advlist', 'autolink', 'lists', 'link', 'image', 'charmap', 'preview',
        'anchor', 'searchreplace', 'visualblocks', 'code', 'fullscreen',
        'insertdatetime', 'media', 'table', 'help', 'wordcount'
      ],
      toolbar: 'undo redo | blocks | bold italic underline strikethrough | ' +
               'alignleft aligncenter alignright alignjustify | ' +
               'bullist numlist outdent indent | removeformat | code | help',
      content_style: `
        body { 
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
          font-size: 14px;
        }
        /* Import Tailwind CSS into TinyMCE editor */
        @import url("/assets/tailwind.css");
        
        /* Key Tailwind classes for our AI-generated content */
        .max-w-4xl { max-width: 56rem; }
        .mx-auto { margin-left: auto; margin-right: auto; }
        .px-4 { padding-left: 1rem; padding-right: 1rem; }
        .py-8 { padding-top: 2rem; padding-bottom: 2rem; }
        .mb-12 { margin-bottom: 3rem; }
        .text-4xl { font-size: 2.25rem; line-height: 2.5rem; }
        .font-bold { font-weight: 700; }
        .text-gray-900 { color: rgb(17 24 39); }
        .mb-4 { margin-bottom: 1rem; }
        .text-xl { font-size: 1.25rem; line-height: 1.75rem; }
        .text-gray-600 { color: rgb(75 85 99); }
        .leading-relaxed { line-height: 1.625; }
        .text-3xl { font-size: 1.875rem; line-height: 2.25rem; }
        .font-semibold { font-weight: 600; }
        .text-gray-800 { color: rgb(31 41 55); }
        .mt-8 { margin-top: 2rem; }
        .text-gray-700 { color: rgb(55 65 81); }
        .grid { display: grid; }
        .md\\:grid-cols-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .gap-6 { gap: 1.5rem; }
        .my-8 { margin-top: 2rem; margin-bottom: 2rem; }
        .bg-blue-50 { background-color: rgb(239 246 255); }
        .rounded-lg { border-radius: 0.5rem; }
        .p-6 { padding: 1.5rem; }
        .border { border-width: 1px; }
        .border-blue-100 { border-color: rgb(219 234 254); }
        .text-blue-900 { color: rgb(30 58 138); }
        .mb-2 { margin-bottom: 0.5rem; }
        .text-blue-800 { color: rgb(30 64 175); }
        .bg-gradient-to-r { background-image: linear-gradient(to right, var(--tw-gradient-stops)); }
        .from-blue-50 { --tw-gradient-from: rgb(239 246 255); --tw-gradient-to: rgb(239 246 255 / 0); }
        .to-indigo-50 { --tw-gradient-to: rgb(238 242 255); }
        .border-l-4 { border-left-width: 4px; }
        .border-blue-500 { border-color: rgb(59 130 246); }
        .rounded-r-lg { border-top-right-radius: 0.5rem; border-bottom-right-radius: 0.5rem; }
        .text-lg { font-size: 1.125rem; line-height: 1.75rem; }
        .bg-gray-100 { background-color: rgb(243 244 246); }
        .rounded-xl { border-radius: 0.75rem; }
        .p-8 { padding: 2rem; }
        .text-center { text-align: center; }
        .text-2xl { font-size: 1.5rem; line-height: 2rem; }
        .mb-6 { margin-bottom: 1.5rem; }
        .text-blue-600 { color: rgb(37 99 235); }
        .font-medium { font-weight: 500; }
      `,
      // More balanced approach - preserve HTML while avoiding TinyMCE errors
      forced_root_block: 'div',
      verify_html: false,
      cleanup: false,
      convert_urls: false,
      relative_urls: false,
      entity_encoding: 'raw',
      // Allow common HTML5 elements with all attributes
      valid_elements: 'article[*],section[*],div[*],span[*],p[*],h1[*],h2[*],h3[*],h4[*],h5[*],h6[*],ul[*],ol[*],li[*],a[*],strong[*],em[*],img[*],blockquote[*],header[*],footer[*],nav[*],aside[*],main[*],figure[*],figcaption[*],table[*],thead[*],tbody[*],tr[*],th[*],td[*],br,hr[*]',
      // Allow all attributes on valid elements
      valid_children: '+article[div|section|p|h1|h2|h3|h4|h5|h6|ul|ol|header|footer],+section[div|p|h1|h2|h3|h4|h5|h6|ul|ol],+div[div|section|p|h1|h2|h3|h4|h5|h6|ul|ol|img|a|span|strong|em]',
      // Extended elements for better compatibility
      extended_valid_elements: 'article[*],section[*],div[*],span[*],header[*],footer[*],nav[*],aside[*],main[*]',
      // Keep all styles and classes
      keep_styles: true,
      setup: (editor) => {
        editor.on('change', () => {
          // Update hidden input when content changes
          const hiddenInput = document.getElementById('page-content-hidden')
          if (hiddenInput) {
            hiddenInput.value = editor.getContent()
          }
        })
      }
    }

    window.tinymce.init(tinymceOptions).then((editors) => {
      this.tinymce = editors[0]
      console.log('TinyMCE editor initialized:', this.tinymce)
    })

    return this.tinymce
  }

  bindEvents() {
    // Create new page button
    const createBtn = document.getElementById('create-new-page-btn')
    if (createBtn) {
      createBtn.addEventListener('click', () => this.openCreateModal())
    }

    // Edit page buttons
    const editButtons = document.querySelectorAll('.edit-page-btn')
    editButtons.forEach(btn => {
      btn.addEventListener('click', (e) => this.openEditModal(e))
    })

    // Close modal buttons
    const closeBtn = document.getElementById('close-page-modal')
    const cancelBtn = document.getElementById('cancel-page-btn')
    
    if (closeBtn) closeBtn.addEventListener('click', () => this.closeModal())
    if (cancelBtn) cancelBtn.addEventListener('click', () => this.closeModal())

    // Modal background click
    const modal = document.getElementById('page-editor-modal')
    if (modal) {
      modal.addEventListener('click', (e) => {
        if (e.target === modal) this.closeModal()
      })
    }

    // Form submission - handle AJAX response
    const form = document.getElementById('page-form')
    if (form) {
      form.addEventListener('ajax:success', (e) => this.handleFormSuccess(e))
      form.addEventListener('ajax:error', (e) => this.handleFormError(e))
      form.addEventListener('submit', (e) => this.handleFormSubmit(e))
    }

    // Generate article button
    const generateBtn = document.getElementById('generate-article-btn')
    if (generateBtn) {
      generateBtn.addEventListener('click', (e) => this.handleGenerateArticle(e))
    }
  }

  openCreateModal() {
    const modal = document.getElementById('page-editor-modal')
    const form = document.getElementById('page-form')
    const modalTitle = document.getElementById('modal-title')
    
    // Reset form
    form.reset()
    document.getElementById('page-id').value = ''
    
    // Update modal title
    modalTitle.textContent = 'Create New Page'
    
    // Show modal
    modal.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    
    // Initialize or clear TinyMCE editor with better timing
    setTimeout(() => {
      const waitForElements = () => {
        const hiddenInput = document.getElementById('page-content-hidden')
        const editorContainer = document.getElementById('page-content-input')
        
        if (!hiddenInput || !editorContainer) {
          console.log('Waiting for DOM elements to be ready for create modal...')
          setTimeout(waitForElements, 50)
          return
        }
        
        if (!this.tinymce) {
          this.createTinyMCEEditor()
        } else {
          this.tinymce.setContent('')
        }
        
        const firstInput = document.getElementById('page-title-input')
        if (firstInput) firstInput.focus()
        
        // Re-bind the generate article button event in case it was lost
        const generateBtn = document.getElementById('generate-article-btn')
        if (generateBtn) {
          generateBtn.removeEventListener('click', this.handleGenerateArticle)
          generateBtn.addEventListener('click', (e) => this.handleGenerateArticle(e))
        }
      }
      
      waitForElements()
    }, 100)
  }

  openEditModal(event) {
    const button = event.target.closest('.edit-page-btn')
    const modal = document.getElementById('page-editor-modal')
    const form = document.getElementById('page-form')
    const modalTitle = document.getElementById('modal-title')
    
    // Get page data from button attributes
    const pageId = button.dataset.pageId
    const title = button.dataset.pageTitle
    const description = button.dataset.pageDescription || ''
    const content = button.dataset.pageContent || ''
    const status = button.dataset.pageStatus
    const pageType = button.dataset.pageType
    
    console.log('Opening edit modal with content:', content.substring(0, 200) + '...')
    console.log('Content length:', content.length)
    
    // Populate form
    document.getElementById('page-id').value = pageId
    document.getElementById('page-title-input').value = title
    document.getElementById('page-description-input').value = description
    document.getElementById('page-status-input').value = status
    document.getElementById('page-type-input').value = pageType
    
    // Update modal title
    modalTitle.textContent = `Edit: ${title}`
    
    // Show modal
    modal.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    
    // Load content into TinyMCE editor with better timing
    setTimeout(() => {
      // Wait for DOM elements to be fully available
      const waitForElements = () => {
        const hiddenInput = document.getElementById('page-content-hidden')
        const editorContainer = document.getElementById('page-content-input')
        
        if (!hiddenInput || !editorContainer) {
          console.log('Waiting for DOM elements to be ready...')
          setTimeout(waitForElements, 50)
          return
        }
        
        if (!this.tinymce) {
          this.createTinyMCEEditor()
          // Wait for TinyMCE to initialize before setting content
          setTimeout(() => {
            if (this.tinymce && content) {
              console.log('Loading content into TinyMCE editor')
              this.tinymce.setContent(content)
              hiddenInput.value = content
              console.log('Content loaded successfully')
            }
          }, 500)
        } else if (content) {
          console.log('Loading content into existing TinyMCE editor')
          this.tinymce.setContent(content)
          hiddenInput.value = content
          console.log('Content loaded successfully')
        }
        
        const titleInput = document.getElementById('page-title-input')
        if (titleInput) {
          titleInput.focus()
          titleInput.select()
        }
      }
      
      waitForElements()
    }, 100)
  }

  closeModal() {
    const modal = document.getElementById('page-editor-modal')
    modal.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
    
    // Reset form
    const form = document.getElementById('page-form')
    form.reset()
    document.getElementById('page-id').value = ''
  }

  handleFormSubmit(event) {
    // Ensure TinyMCE content is saved to hidden input
    if (this.tinymce) {
      const hiddenInput = document.getElementById('page-content-hidden')
      if (hiddenInput) {
        hiddenInput.value = this.tinymce.getContent()
      }
    }
    
    // Log form data being submitted
    const form = event.target
    const pageId = document.getElementById('page-id').value
    const contentField = document.getElementById('page-content-hidden')
    
    console.log('Form submitted')
    console.log('Page ID:', pageId)
    console.log('Content being submitted:', contentField.value.substring(0, 300) + '...')
    console.log('Content length:', contentField.value.length)
    
    // Log the TinyMCE editor state
    if (this.tinymce) {
      console.log('TinyMCE editor HTML before submit:', this.tinymce.getContent().substring(0, 300) + '...')
    }
  }

  handleFormSuccess(event) {
    console.log('Form submitted successfully')
    this.closeModal()
    
    // Show success notification
    this.showNotification('Page saved successfully!', 'success')
    
    // Reload the page to show updated pages list
    setTimeout(() => {
      window.location.href = window.location.href + '#pages'
      window.location.reload()
    }, 1500)
  }

  handleFormError(event) {
    console.error('Form submission error:', event.detail)
    
    // Show error notification
    this.showNotification('Error saving page. Please try again.', 'error')
  }

  unescapeHtml(str) {
    const div = document.createElement('div')
    div.innerHTML = str
    return div.textContent || div.innerText || ''
  }

  async handleGenerateArticle(event) {
    event.preventDefault()
    
    const button = event.target.closest('button')
    const titleInput = document.getElementById('page-title-input')
    const descriptionInput = document.getElementById('page-description-input')
    
    // Validate title is present
    if (!titleInput.value.trim()) {
      alert('Please enter a title for the article before generating content.')
      titleInput.focus()
      return
    }
    
    // Create and show loading overlay
    const loadingOverlay = this.createLoadingOverlay()
    document.body.appendChild(loadingOverlay)
    
    // Show loading state on button too
    const originalText = button.textContent
    button.disabled = true
    button.textContent = 'Generating...'
    button.classList.add('opacity-50', 'cursor-not-allowed')
    
    try {
      // Get the school ID from the form action
      const form = document.getElementById('page-form')
      const schoolId = form.action.match(/schools\/(\d+)/)[1]
      
      // Make the API call
      const response = await fetch(`/school_owner/schools/${schoolId}/pages/generate_content`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          title: titleInput.value,
          description: descriptionInput.value || ''
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        console.log('AI Generated content received:', data.content)
        console.log('Content length:', data.content.length)
        
        // Initialize TinyMCE if not already done
        if (!this.tinymce) {
          this.createTinyMCEEditor()
          // Wait for initialization
          setTimeout(() => {
            if (this.tinymce) {
              console.log('Setting generated content in TinyMCE')
              try {
                this.tinymce.setContent(data.content)
                console.log('Content successfully set in new TinyMCE instance')
              } catch (error) {
                console.error('Error setting content in new TinyMCE:', error)
                // Fallback: try setting content directly in the DOM
                console.log('Attempting fallback: direct DOM content setting')
                const editorBody = this.tinymce.getBody()
                if (editorBody) {
                  editorBody.innerHTML = data.content
                  console.log('Content set via direct DOM manipulation')
                }
              }
              
              // Update the hidden input
              const hiddenInput = document.getElementById('page-content-hidden')
              if (hiddenInput) {
                hiddenInput.value = data.content
              }
            }
          }, 500)
        } else {
          // Set the generated content in the TinyMCE editor
          console.log('Setting generated content in existing TinyMCE')
          try {
            this.tinymce.setContent(data.content)
            console.log('Content successfully set in TinyMCE')
          } catch (error) {
            console.error('Error setting content in TinyMCE:', error)
            // Fallback: try setting content directly in the DOM
            console.log('Attempting fallback: direct DOM content setting')
            const editorBody = this.tinymce.getBody()
            if (editorBody) {
              editorBody.innerHTML = data.content
              console.log('Content set via direct DOM manipulation')
            }
          }
          
          // Update the hidden input
          const hiddenInput = document.getElementById('page-content-hidden')
          if (hiddenInput) {
            hiddenInput.value = data.content
            console.log('Hidden input updated with generated content')
          }
        }
        
        // Update the description if one was generated
        if (data.meta_description && !descriptionInput.value) {
          descriptionInput.value = data.meta_description
        }
        
        // Show success message
        this.showNotification('Article generated successfully!', 'success')
      } else {
        // Show error message
        this.showNotification(data.error || 'Failed to generate content', 'error')
      }
    } catch (error) {
      console.error('Error generating article:', error)
      this.showNotification('An error occurred while generating content', 'error')
    } finally {
      // Remove loading overlay
      if (loadingOverlay && loadingOverlay.parentNode) {
        loadingOverlay.remove()
      }
      
      // Restore button state
      button.disabled = false
      button.textContent = originalText
      button.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  createLoadingOverlay() {
    const overlay = document.createElement('div')
    overlay.className = 'fixed inset-0 bg-gray-900 bg-opacity-50 z-[100] flex items-center justify-center'
    overlay.style.backdropFilter = 'blur(2px)'
    
    const loadingContainer = document.createElement('div')
    loadingContainer.className = 'bg-white rounded-lg p-8 max-w-sm w-full mx-4 shadow-2xl'
    
    loadingContainer.innerHTML = `
      <div class="text-center">
        <!-- Animated spinner -->
        <div class="inline-flex items-center justify-center w-16 h-16 mb-4">
          <svg class="animate-spin h-16 w-16 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </div>
        
        <!-- Loading text -->
        <h3 class="text-lg font-medium text-gray-900 mb-2">Generating Article</h3>
        <p class="text-sm text-gray-600 mb-4">Our AI is crafting your content...</p>
        
        <!-- Progress bar -->
        <div class="relative pt-1">
          <div class="overflow-hidden h-2 mb-4 text-xs flex rounded bg-gray-200">
            <div class="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-blue-600 animate-pulse" style="width: 100%"></div>
          </div>
        </div>
        
        <!-- Rotating messages -->
        <div class="text-xs text-gray-500" data-loading-messages>
          <p class="loading-message">Analyzing your school's information...</p>
        </div>
      </div>
    `
    
    overlay.appendChild(loadingContainer)
    
    // Start rotating messages
    const messages = [
      "Analyzing your school's information...",
      "Crafting engaging content...",
      "Applying your tone of voice...",
      "Formatting the article...",
      "Almost ready..."
    ]
    
    let messageIndex = 0
    const messageElement = overlay.querySelector('.loading-message')
    
    const messageInterval = setInterval(() => {
      messageIndex = (messageIndex + 1) % messages.length
      messageElement.style.opacity = '0'
      setTimeout(() => {
        messageElement.textContent = messages[messageIndex]
        messageElement.style.opacity = '1'
      }, 300)
    }, 3000)
    
    // Store the interval ID so we can clear it later
    overlay.dataset.messageInterval = messageInterval
    
    // Add fade-in animation
    overlay.style.opacity = '0'
    setTimeout(() => {
      overlay.style.transition = 'opacity 0.3s ease-in-out'
      overlay.style.opacity = '1'
    }, 10)
    
    // Clean up interval when overlay is removed
    const originalRemove = overlay.remove.bind(overlay)
    overlay.remove = function() {
      clearInterval(parseInt(this.dataset.messageInterval))
      originalRemove()
    }
    
    return overlay
  }

  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 px-6 py-4 rounded-lg shadow-lg text-white z-[110] transform transition-transform duration-300 translate-x-full`
    
    // Set background color based on type
    const bgColor = type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500'
    notification.classList.add(bgColor)
    
    notification.innerHTML = `
      <div class="flex items-center space-x-3">
        <div class="flex-1">
          <p class="text-sm font-medium">${message}</p>
        </div>
        <button type="button" class="flex-shrink-0 text-white hover:text-gray-200" onclick="this.closest('div').remove()">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full')
      notification.classList.add('translate-x-0')
    }, 100)
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      notification.classList.remove('translate-x-0')
      notification.classList.add('translate-x-full')
      setTimeout(() => notification.remove(), 300)
    }, 5000)
  }
}