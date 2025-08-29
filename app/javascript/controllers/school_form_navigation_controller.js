import { Controller } from "@hotwired/stimulus"

// School form navigation controller handles sidebar section switching
export default class extends Controller {
  static targets = ["section", "navItem", "mobileMenu"]
  static values = { 
    currentSection: String,
    completedSections: Array
  }

  connect() {
    // Set initial section from URL hash or default to first section
    const hash = window.location.hash.replace('#', '')
    const initialSection = hash || 'basic-information'
    this.showSection(initialSection)
    this.updateURL(initialSection)
    
    // Handle browser back/forward navigation
    window.addEventListener('popstate', this.handlePopState.bind(this))
  }

  disconnect() {
    window.removeEventListener('popstate', this.handlePopState.bind(this))
  }

  // Navigate to a specific section
  navigateToSection(event) {
    event.preventDefault()
    const sectionId = event.currentTarget.dataset.section
    this.showSection(sectionId)
    this.updateURL(sectionId)
    this.closeMobileMenu()
  }

  // Show specific section and update navigation
  showSection(sectionId) {
    // Hide all sections
    this.sectionTargets.forEach(section => {
      section.classList.add('hidden')
    })

    // Show target section
    const targetSection = this.sectionTargets.find(
      section => section.dataset.section === sectionId
    )
    if (targetSection) {
      targetSection.classList.remove('hidden')
      this.currentSectionValue = sectionId
    }

    // Update navigation active states
    this.updateNavigationState(sectionId)
    
    // Scroll to top of content area
    this.scrollToTop()
  }

  // Update navigation active states
  updateNavigationState(activeSectionId) {
    this.navItemTargets.forEach(navItem => {
      const isActive = navItem.dataset.section === activeSectionId
      
      if (isActive) {
        navItem.classList.add('bg-blue-50', 'border-blue-500', 'text-blue-700')
        navItem.classList.remove('border-transparent', 'text-gray-600', 'hover:bg-gray-50', 'hover:text-gray-900')
        
        // Update icon color
        const icon = navItem.querySelector('svg')
        if (icon) {
          icon.classList.add('text-blue-500')
          icon.classList.remove('text-gray-400')
        }
      } else {
        navItem.classList.remove('bg-blue-50', 'border-blue-500', 'text-blue-700')
        navItem.classList.add('border-transparent', 'text-gray-600', 'hover:bg-gray-50', 'hover:text-gray-900')
        
        // Update icon color
        const icon = navItem.querySelector('svg')
        if (icon) {
          icon.classList.remove('text-blue-500')
          icon.classList.add('text-gray-400')
        }
      }
    })
  }

  // Update browser URL without page reload
  updateURL(sectionId) {
    const newURL = `${window.location.pathname}#${sectionId}`
    window.history.pushState({ section: sectionId }, '', newURL)
  }

  // Handle browser back/forward navigation
  handlePopState(event) {
    const sectionId = event.state?.section || window.location.hash.replace('#', '') || 'basic-information'
    this.showSection(sectionId)
  }

  // Toggle mobile menu
  toggleMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.toggle('hidden')
    }
  }

  // Close mobile menu
  closeMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.add('hidden')
    }
  }

  // Scroll to top of content area
  scrollToTop() {
    const contentArea = document.querySelector('.form-content')
    if (contentArea) {
      contentArea.scrollTop = 0
    } else {
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  // Mark section as completed
  markSectionCompleted(sectionId) {
    if (!this.completedSectionsValue.includes(sectionId)) {
      this.completedSectionsValue = [...this.completedSectionsValue, sectionId]
      this.updateCompletionIndicators()
    }
  }

  // Update completion indicators in navigation
  updateCompletionIndicators() {
    this.navItemTargets.forEach(navItem => {
      const sectionId = navItem.dataset.section
      const isCompleted = this.completedSectionsValue.includes(sectionId)
      const indicator = navItem.querySelector('.completion-indicator')
      
      if (indicator) {
        if (isCompleted) {
          indicator.classList.add('bg-green-100', 'text-green-600')
          indicator.classList.remove('bg-gray-100', 'text-gray-400')
          indicator.innerHTML = '✓'
        } else {
          indicator.classList.remove('bg-green-100', 'text-green-600') 
          indicator.classList.add('bg-gray-100', 'text-gray-400')
          indicator.innerHTML = ''
        }
      }
    })
  }

  // Validate current section
  validateCurrentSection() {
    const currentSection = this.sectionTargets.find(
      section => section.dataset.section === this.currentSectionValue
    )
    
    if (currentSection) {
      const inputs = currentSection.querySelectorAll('input, select, textarea')
      let isValid = true
      
      inputs.forEach(input => {
        if (input.hasAttribute('required') && !input.value.trim()) {
          isValid = false
        }
      })
      
      if (isValid) {
        this.markSectionCompleted(this.currentSectionValue)
      }
      
      return isValid
    }
    
    return true
  }

  // Auto-save section data
  autoSaveSection() {
    // Implementation for auto-saving section data
    // This could make AJAX calls to save individual sections
    console.log('Auto-saving section:', this.currentSectionValue)
  }
}