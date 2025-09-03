import { Controller } from "@hotwired/stimulus"

// Enhanced Pagination Controller
// Provides smooth interactions and loading states for pagination
export default class extends Controller {
  static targets = ["pageJump", "perPageSelect", "paginationContainer"]
  static values = { 
    currentPage: Number,
    totalPages: Number,
    baseUrl: String
  }

  connect() {
    // Add loading state management
    this.setupLoadingStates()
    
    // Enhance page jump functionality
    if (this.hasPageJumpTarget) {
      this.setupPageJump()
    }
    
    // Enhance per-page selector
    if (this.hasPerPageSelectTarget) {
      this.setupPerPageSelect()
    }
    
    console.log("Enhanced pagination controller connected")
  }

  setupLoadingStates() {
    // Add loading states to all pagination links
    const paginationLinks = this.element.querySelectorAll('a[href*="page="]')
    
    paginationLinks.forEach(link => {
      link.addEventListener('click', (event) => {
        this.showLoadingState(event.target.closest('a'))
      })
    })
  }

  setupPageJump() {
    this.pageJumpTarget.addEventListener('keypress', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault()
        this.handlePageJump(event)
      }
    })

    // Auto-select on focus for easy replacement
    this.pageJumpTarget.addEventListener('focus', (event) => {
      event.target.select()
    })

    // Validate on blur
    this.pageJumpTarget.addEventListener('blur', (event) => {
      this.validatePageNumber(event.target)
    })
  }

  setupPerPageSelect() {
    this.perPageSelectTarget.addEventListener('change', (event) => {
      this.handlePerPageChange(event)
    })
  }

  handlePageJump(event) {
    const pageNum = parseInt(event.target.value)
    
    if (this.isValidPageNumber(pageNum)) {
      this.showLoadingState(event.target)
      this.navigateToPage(pageNum)
    } else {
      this.showPageError(event.target, `Enter a page between 1 and ${this.totalPagesValue}`)
    }
  }

  handlePerPageChange(event) {
    const perPage = event.target.value
    this.showLoadingState(event.target)
    this.updatePerPage(perPage)
  }

  navigateToPage(pageNumber) {
    const url = new URL(window.location)
    url.searchParams.set('page', pageNumber)
    
    // Add a smooth transition
    this.addTransitionClass()
    
    window.location.href = url.toString()
  }

  updatePerPage(value) {
    const url = new URL(window.location)
    url.searchParams.set('per_page', value)
    url.searchParams.set('page', '1') // Reset to first page
    
    this.addTransitionClass()
    
    window.location.href = url.toString()
  }

  isValidPageNumber(pageNum) {
    return !isNaN(pageNum) && pageNum >= 1 && pageNum <= this.totalPagesValue
  }

  validatePageNumber(input) {
    const pageNum = parseInt(input.value)
    
    if (input.value && !this.isValidPageNumber(pageNum)) {
      this.showPageError(input, `Enter a page between 1 and ${this.totalPagesValue}`)
    } else {
      this.clearPageError(input)
    }
  }

  showPageError(input, message) {
    input.classList.add('border-red-300', 'text-red-900', 'focus:border-red-500', 'focus:ring-red-500')
    input.classList.remove('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    
    // Create or update error message
    let errorEl = input.parentNode.querySelector('.pagination-error')
    if (!errorEl) {
      errorEl = document.createElement('div')
      errorEl.className = 'pagination-error text-xs text-red-600 mt-1'
      input.parentNode.appendChild(errorEl)
    }
    errorEl.textContent = message
    
    // Clear error after 3 seconds
    setTimeout(() => this.clearPageError(input), 3000)
  }

  clearPageError(input) {
    input.classList.remove('border-red-300', 'text-red-900', 'focus:border-red-500', 'focus:ring-red-500')
    input.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    
    const errorEl = input.parentNode.querySelector('.pagination-error')
    if (errorEl) {
      errorEl.remove()
    }
  }

  showLoadingState(element) {
    // Add loading class to the element
    element.classList.add('pagination-loading')
    
    // Add loading spinner or text change
    if (element.tagName === 'A') {
      element.style.opacity = '0.6'
      element.style.pointerEvents = 'none'
      
      // Add spinner
      const spinner = this.createSpinner()
      element.appendChild(spinner)
    } else if (element.tagName === 'SELECT' || element.tagName === 'INPUT') {
      element.disabled = true
      element.style.opacity = '0.6'
    }
    
    // Add global loading class
    this.addTransitionClass()
  }

  addTransitionClass() {
    document.body.classList.add('pagination-transitioning')
    
    // Remove after a reasonable time
    setTimeout(() => {
      document.body.classList.remove('pagination-transitioning')
    }, 2000)
  }

  createSpinner() {
    const spinner = document.createElement('div')
    spinner.className = 'inline-block ml-2 pagination-spinner'
    spinner.innerHTML = `
      <svg class="animate-spin h-3 w-3 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    `
    return spinner
  }

  // Quick navigation methods
  goToFirstPage() {
    if (this.currentPageValue > 1) {
      this.navigateToPage(1)
    }
  }

  goToLastPage() {
    if (this.currentPageValue < this.totalPagesValue) {
      this.navigateToPage(this.totalPagesValue)
    }
  }

  goToPreviousPage() {
    if (this.currentPageValue > 1) {
      this.navigateToPage(this.currentPageValue - 1)
    }
  }

  goToNextPage() {
    if (this.currentPageValue < this.totalPagesValue) {
      this.navigateToPage(this.currentPageValue + 1)
    }
  }
}