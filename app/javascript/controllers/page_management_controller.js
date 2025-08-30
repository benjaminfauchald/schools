import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "modalTitle", "pageId", "formMethod"]

  connect() {
    console.log("Page management controller connected")
    this.bindEvents()
    this.initializeTrix()
  }

  initializeTrix() {
    // Ensure Trix is loaded and initialized
    document.addEventListener('trix-initialize', (e) => {
      console.log('Trix editor initialized:', e.target)
      this.ensureProperToolbar(e.target)
    })
    
    // Listen for content changes
    document.addEventListener('trix-change', (e) => {
      console.log('Trix content changed')
    })
    
    // Force Trix to reinitialize after a delay
    setTimeout(() => {
      const trixEditors = document.querySelectorAll('trix-editor')
      console.log('Found trix editors:', trixEditors.length)
      trixEditors.forEach(editor => {
        console.log('Trix editor:', editor)
        this.ensureProperToolbar(editor)
      })
    }, 1000)
  }

  ensureProperToolbar(trixEditor) {
    const toolbarId = trixEditor.getAttribute('toolbar')
    let toolbar = document.getElementById(toolbarId)
    
    console.log('Ensuring proper toolbar for:', toolbarId)
    console.log('Toolbar element:', toolbar)
    
    if (!toolbar) {
      console.log('No toolbar found, creating one')
      // Create toolbar element
      toolbar = document.createElement('trix-toolbar')
      toolbar.id = toolbarId
      
      // Insert toolbar before the editor
      trixEditor.parentNode.insertBefore(toolbar, trixEditor)
    }
    
    // Check if toolbar has proper content
    const hasButtons = toolbar.querySelector('button')
    const toolbarContent = toolbar.innerHTML
    console.log('Toolbar has buttons:', !!hasButtons)
    console.log('Toolbar content:', toolbarContent.substring(0, 200))
    
    // Always recreate toolbar to ensure icons
    if (true) {
      console.log('Recreating toolbar with icons')
      
      // Create proper toolbar HTML with SVG icons
      toolbar.innerHTML = `
        <div class="trix-button-row">
          <span class="trix-button-group trix-button-group--text-tools" data-trix-button-group="text-tools">
            <button type="button" class="trix-button trix-button--icon trix-button--icon-bold" data-trix-attribute="bold" data-trix-key="b" title="Bold" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M15.6 10.79c.97-.67 1.65-1.77 1.65-2.79 0-2.26-1.75-4-4-4H7v14h7.04c2.09 0 3.71-1.7 3.71-3.79 0-1.52-.86-2.82-2.15-3.42zM10 6.5h3c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-3v-3zm3.5 9H10v-3h3.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-italic" data-trix-attribute="italic" data-trix-key="i" title="Italic" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M10 4v3h2.21l-3.42 8H6v3h8v-3h-2.21l3.42-8H18V4z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-strike" data-trix-attribute="strike" title="Strikethrough" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M10 19h4v-3h-4v3zM5 4v3h5v3h4V7h5V4H5zM3 14h18v-2H3v2z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-link" data-trix-attribute="href" data-trix-action="link" data-trix-key="k" title="Link" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z"/></svg>
            </button>
          </span>
          <span class="trix-button-group trix-button-group--block-tools" data-trix-button-group="block-tools">
            <button type="button" class="trix-button trix-button--icon trix-button--icon-heading-1" data-trix-attribute="heading1" title="Heading" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M5 4v3h5.5v12h3V7H19V4z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-quote" data-trix-attribute="quote" title="Quote" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M6 17h3l2-4V7H5v6h3zm8 0h3l2-4V7h-6v6h3z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-code" data-trix-attribute="code" title="Code" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-bullet-list" data-trix-attribute="bullet" title="Bullets" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M4 10.5c-.83 0-1.5.67-1.5 1.5s.67 1.5 1.5 1.5 1.5-.67 1.5-1.5-.67-1.5-1.5-1.5zm0-6c-.83 0-1.5.67-1.5 1.5S3.17 7.5 4 7.5 5.5 6.83 5.5 6 4.83 4.5 4 4.5zm0 12c-.83 0-1.5.68-1.5 1.5s.68 1.5 1.5 1.5 1.5-.68 1.5-1.5-.67-1.5-1.5-1.5zM7 19h14v-2H7v2zm0-6h14v-2H7v2zm0-8v2h14V5H7z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-number-list" data-trix-attribute="number" title="Numbers" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M2 17h2v.5H3v1h1v.5H2v1h3v-4H2v1zm1-9h1V4H2v1h1v3zm-1 3h1.8L2 13.1v.9h3v-1H3.2L5 10.9V10H2v1zm5-6v2h14V5H7zm0 14h14v-2H7v2zm0-6h14v-2H7v2z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-decrease-nesting-level" data-trix-action="decreaseNestingLevel" title="Decrease Level" tabindex="-1" disabled="">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M11 17h10v-2H11v2zm-8-5l4 4V8l-4 4zm0 9h18v-2H3v2zM3 3v2h18V3H3zm8 6h10V7H11v2zm0 4h10v-2H11v2z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-increase-nesting-level" data-trix-action="increaseNestingLevel" title="Increase Level" tabindex="-1" disabled="">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M3 21h18v-2H3v2zM3 8v8l4-4-4-4zm8 9h10v-2H11v2zM3 3v2h18V3H3zm8 6h10V7H11v2zm0 4h10v-2H11v2z"/></svg>
            </button>
          </span>
          <span class="trix-button-group trix-button-group--file-tools" data-trix-button-group="file-tools">
            <button type="button" class="trix-button trix-button--icon trix-button--icon-attach" data-trix-action="attachFiles" title="Attach Files" tabindex="-1">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M16.5 6v11.5c0 2.21-1.79 4-4 4s-4-1.79-4-4V5c0-1.38 1.12-2.5 2.5-2.5s2.5 1.12 2.5 2.5v10.5c0 .55-.45 1-1 1s-1-.45-1-1V6H10v9.5c0 1.38 1.12 2.5 2.5 2.5s2.5-1.12 2.5-2.5V5c0-2.21-1.79-4-4-4S7 2.79 7 5v12.5c0 3.04 2.46 5.5 5.5 5.5s5.5-2.46 5.5-5.5V6h-1.5z"/></svg>
            </button>
          </span>
          <span class="trix-button-group-spacer"></span>
          <span class="trix-button-group trix-button-group--history-tools" data-trix-button-group="history-tools">
            <button type="button" class="trix-button trix-button--icon trix-button--icon-undo" data-trix-action="undo" data-trix-key="z" title="Undo" tabindex="-1" disabled="">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z"/></svg>
            </button>
            <button type="button" class="trix-button trix-button--icon trix-button--icon-redo" data-trix-action="redo" data-trix-key="shift+z" title="Redo" tabindex="-1" disabled="">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M18.4 10.6C16.55 8.99 14.15 8 11.5 8c-4.65 0-8.58 3.03-9.96 7.22L3.9 16c1.05-3.19 4.05-5.5 7.6-5.5 1.95 0 3.73.72 5.12 1.88L13 16h9V7l-3.6 3.6z"/></svg>
            </button>
          </span>
        </div>
        <div class="trix-dialogs" data-trix-dialogs>
          <div class="trix-dialog trix-dialog--link" data-trix-dialog="href" data-trix-dialog-attribute="href">
            <div class="trix-dialog__link-fields">
              <input type="url" name="href" class="trix-input trix-input--dialog" placeholder="Enter a URL…" aria-label="URL" data-trix-input>
              <div class="flex gap-2 mt-2">
                <input type="button" class="trix-button trix-button--dialog" value="Link" data-trix-method="setAttribute">
                <input type="button" class="trix-button trix-button--dialog" value="Unlink" data-trix-method="removeAttribute">
              </div>
            </div>
          </div>
        </div>
      `
    }
    
    // Apply styling
    this.styleToolbar(toolbar)
  }
  
  styleToolbar(toolbar) {
    // Apply toolbar styling
    toolbar.style.cssText = 'display: block !important; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 0.375rem 0.375rem 0 0; padding: 0.5rem;'
    
    // Style buttons
    const buttons = toolbar.querySelectorAll('button')
    buttons.forEach(button => {
      // Base button styles - smaller padding for icon buttons
      button.style.cssText = 'padding: 0.375rem; background: white; border: 1px solid #d1d5db; border-radius: 0.25rem; cursor: pointer; transition: all 0.15s; margin: 0 0.0625rem; color: #374151; display: inline-flex; align-items: center; justify-content: center;'
      
      // Ensure SVGs are visible
      const svg = button.querySelector('svg')
      if (svg) {
        svg.style.cssText = 'width: 1rem; height: 1rem; pointer-events: none;'
      }
      
      // Disabled state
      if (button.disabled) {
        button.style.opacity = '0.5'
        button.style.cursor = 'not-allowed'
      }
      
      // Active state
      if (button.hasAttribute('data-trix-active')) {
        button.style.background = '#dbeafe'
        button.style.borderColor = '#3b82f6'
        button.style.color = '#1e40af'
      }
      
      // Hover effects
      button.addEventListener('mouseenter', function() {
        if (!this.disabled && !this.hasAttribute('data-trix-active')) {
          this.style.background = '#f3f4f6'
          this.style.borderColor = '#9ca3af'
        }
      })
      
      button.addEventListener('mouseleave', function() {
        if (!this.disabled && !this.hasAttribute('data-trix-active')) {
          this.style.background = 'white'
          this.style.borderColor = '#d1d5db'
        }
      })
    })
    
    // Style button groups
    const buttonGroups = toolbar.querySelectorAll('.trix-button-group')
    buttonGroups.forEach(group => {
      group.style.cssText = 'display: inline-flex; gap: 0.125rem; margin-right: 0.75rem;'
    })
    
    // Style button row
    const buttonRow = toolbar.querySelector('.trix-button-row')
    if (buttonRow) {
      buttonRow.style.cssText = 'display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center;'
    }
    
    // Style dialogs
    const dialogs = toolbar.querySelectorAll('.trix-dialog')
    dialogs.forEach(dialog => {
      dialog.style.cssText = 'position: absolute; top: 100%; left: 0; background: white; border: 1px solid #e5e7eb; border-radius: 0.375rem; padding: 1rem; margin-top: 0.5rem; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);'
    })
    
    // Style dialog input
    const dialogInputs = toolbar.querySelectorAll('.trix-input--dialog')
    dialogInputs.forEach(input => {
      input.style.cssText = 'padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 0.25rem; width: 100%; font-size: 0.875rem;'
    })
    
    // Style dialog buttons
    const dialogButtons = toolbar.querySelectorAll('.trix-button--dialog')
    dialogButtons.forEach(button => {
      button.style.cssText = 'padding: 0.5rem 1rem; border-radius: 0.25rem; font-size: 0.875rem; cursor: pointer; transition: all 0.15s;'
      if (button.value === 'Link') {
        button.style.background = '#3b82f6'
        button.style.color = 'white'
        button.style.border = 'none'
      } else {
        button.style.background = '#ef4444'
        button.style.color = 'white'
        button.style.border = 'none'
      }
    })
  }

  fixTrixToolbar(trixEditor) {
    const toolbarId = trixEditor.getAttribute('toolbar')
    const toolbar = document.getElementById(toolbarId)
    
    if (!toolbar) {
      console.log('No toolbar found for', toolbarId)
      return
    }
    
    console.log('Fixing toolbar:', toolbar)
    
    // Don't replace the toolbar if it already has buttons
    if (toolbar.querySelector('button')) {
      console.log('Toolbar already has buttons')
      return
    }
    
    // Apply styling to the existing toolbar
    toolbar.style.cssText = 'display: block !important; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 0.375rem 0.375rem 0 0; padding: 0.5rem;'
    
    // Style all buttons in the toolbar
    setTimeout(() => {
      const buttons = toolbar.querySelectorAll('button')
      buttons.forEach(button => {
        button.style.cssText = 'padding: 0.25rem 0.5rem; background: white; border: 1px solid #d1d5db; border-radius: 0.25rem; font-size: 0.875rem; cursor: pointer; transition: all 0.15s; margin: 0 0.125rem;'
        
        // Add hover effects
        button.addEventListener('mouseenter', function() {
          this.style.background = '#f3f4f6'
          this.style.borderColor = '#9ca3af'
        })
        button.addEventListener('mouseleave', function() {
          this.style.background = 'white'
          this.style.borderColor = '#d1d5db'
        })
        
        // Make button text more readable
        if (!button.querySelector('span') && button.textContent) {
          button.style.fontWeight = '500'
        }
      })
      
      // Style button groups
      const buttonGroups = toolbar.querySelectorAll('.trix-button-group')
      buttonGroups.forEach(group => {
        group.style.cssText = 'display: inline-flex; gap: 0.25rem; margin-right: 0.5rem;'
      })
      
      // Style the button row
      const buttonRow = toolbar.querySelector('.trix-button-row')
      if (buttonRow) {
        buttonRow.style.cssText = 'display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center;'
      }
    }, 100)
  }

  ensureTrixInitialized() {
    const trixEditor = document.querySelector('#page-content-input')
    if (trixEditor) {
      // Dispatch a custom event to force Trix to initialize
      const event = new CustomEvent('trix-before-initialize')
      trixEditor.dispatchEvent(event)
      
      console.log('Trix editor element found:', trixEditor)
      console.log('Trix editor object:', trixEditor.editor)
      
      // Find and log toolbar info
      const toolbar = document.querySelector(`#${trixEditor.getAttribute('toolbar')}`)
      console.log('Trix toolbar element:', toolbar)
      
      // Check if toolbar is hidden and force it visible
      if (toolbar) {
        toolbar.style.display = 'block'
        toolbar.style.visibility = 'visible'
        console.log('Forced toolbar visible')
        
        // Check if it's the text showing instead of buttons
        const toolbarContent = toolbar.innerHTML
        console.log('Toolbar content:', toolbarContent.substring(0, 200) + '...')
      }
    } else {
      console.log('Trix editor element not found')
    }
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
    
    // Clear the Trix editor content
    const trixEditor = document.querySelector('trix-editor#page-content-input')
    if (trixEditor && trixEditor.editor) {
      trixEditor.editor.loadHTML('')
    }
    
    // Update modal title
    modalTitle.textContent = 'Create New Page'
    
    // Show modal
    modal.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    
    // Focus first input and ensure Trix is ready
    setTimeout(() => {
      const firstInput = document.getElementById('page-title-input')
      if (firstInput) firstInput.focus()
      
      // Force Trix to reinitialize if needed
      this.ensureTrixInitialized()
      
      // Re-bind the generate article button event in case it was lost
      const generateBtn = document.getElementById('generate-article-btn')
      if (generateBtn) {
        generateBtn.removeEventListener('click', this.handleGenerateArticle)
        generateBtn.addEventListener('click', (e) => this.handleGenerateArticle(e))
      }
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
    
    console.log('Opening edit modal with content:', content)
    console.log('Content length:', content.length)
    
    // Populate form
    document.getElementById('page-id').value = pageId
    // Don't set form method - let it stay as POST since controller handles both
    document.getElementById('page-title-input').value = title
    document.getElementById('page-description-input').value = description
    
    // For rich text content, we need to handle it differently
    const trixEditor = document.querySelector('trix-editor#page-content-input')
    if (trixEditor) {
      const unescapedContent = this.unescapeHtml(content)
      console.log('Unescaped content:', unescapedContent)
      console.log('Trix editor found:', trixEditor)
      console.log('Trix editor.editor:', trixEditor.editor)
      
      // If editor is already initialized, load content immediately
      if (trixEditor.editor) {
        console.log('Loading content immediately')
        trixEditor.editor.loadHTML(unescapedContent)
      } else {
        console.log('Waiting for Trix to initialize')
        // Wait for Trix to initialize before loading content
        const loadContent = () => {
          console.log('Trix initialized, loading content')
          if (trixEditor.editor) {
            trixEditor.editor.loadHTML(unescapedContent)
          }
        }
        
        // Try multiple approaches to ensure content loads
        trixEditor.addEventListener('trix-initialize', loadContent, { once: true })
        
        // Also try after a delay as a fallback
        setTimeout(() => {
          console.log('Fallback content loading attempt')
          if (trixEditor.editor && !trixEditor.editor.getDocument().toString().trim()) {
            console.log('Loading content via fallback')
            trixEditor.editor.loadHTML(unescapedContent)
          }
        }, 500)
      }
    } else {
      console.log('Trix editor not found!')
    }
    
    document.getElementById('page-status-input').value = status
    document.getElementById('page-type-input').value = pageType
    
    // Update modal title
    modalTitle.textContent = `Edit: ${title}`
    
    // Show modal
    modal.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    
    // Focus title input
    setTimeout(() => {
      const titleInput = document.getElementById('page-title-input')
      if (titleInput) {
        titleInput.focus()
        titleInput.select()
      }
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
    // Close any open Trix dialogs before submitting
    const trixDialogs = document.querySelectorAll('.trix-dialog--link')
    trixDialogs.forEach(dialog => {
      dialog.style.display = 'none'
    })
    
    // Remove required attribute from any dialog inputs
    const dialogInputs = document.querySelectorAll('.trix-input--dialog')
    dialogInputs.forEach(input => {
      input.removeAttribute('required')
      input.value = '' // Clear any partial input
    })
    
    // The form will always submit to the same URL (create action)
    // The controller will determine if it's create or update based on page_id
    console.log('Form submitted')
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
        // Set the generated content in the Trix editor
        const trixEditor = document.querySelector('trix-editor#page-content-input')
        if (trixEditor && trixEditor.editor) {
          trixEditor.editor.loadHTML(data.content)
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