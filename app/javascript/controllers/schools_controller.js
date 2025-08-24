import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radiusSlider", "radiusDisplay", "showAllCheckbox", "schoolsList", "loadingIndicator", "resultsTitle", "resultsSummary", "pagination"]
  static values = { 
    homeLat: Number,
    homeLng: Number,
    hasRealLocation: Boolean
  }

  connect() {
    console.log("Schools controller connected")
    this.debounceTimer = null
    this.currentRadius = 50
    this.currentShowAll = false
    this.currentPage = 1
    
    // Initialize display
    this.updateRadiusDisplay()
    
    // Load real location from localStorage if available and not already set
    this.loadLocationFromStorage()
  }

  loadLocationFromStorage() {
    if (this.hasRealLocationValue) {
      // Already have real location from server, no need to load from storage
      return
    }
    
    try {
      const stored = localStorage.getItem('homeLocation')
      if (stored) {
        const location = JSON.parse(stored)
        const thirtyDaysAgo = new Date()
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
        
        if (new Date(location.timestamp) > thirtyDaysAgo) {
          // Update the location values
          this.homeLatValue = location.lat
          this.homeLngValue = location.lng
          this.hasRealLocationValue = true
          
          // Trigger initial filter with real location
          this.debouncedFilter()
        }
      }
    } catch (error) {
      console.error("Error loading location from storage:", error)
    }
  }

  updateRadius(event) {
    this.currentRadius = parseInt(event.target.value)
    this.updateRadiusDisplay()
    this.debouncedFilter()
  }

  toggleShowAll(event) {
    this.currentShowAll = event.target.checked
    this.currentPage = 1 // Reset to first page
    this.debouncedFilter()
  }

  showAll() {
    this.showAllCheckboxTarget.checked = true
    this.currentShowAll = true
    this.currentPage = 1
    this.debouncedFilter()
  }

  updateRadiusDisplay() {
    this.radiusDisplayTarget.textContent = `${this.currentRadius} km`
  }

  debouncedFilter() {
    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    // Set new timer for 300ms debounce
    this.debounceTimer = setTimeout(() => {
      this.filterSchools()
    }, 300)
  }

  async filterSchools(page = 1) {
    this.currentPage = page
    this.showLoading()
    
    try {
      const params = new URLSearchParams({
        radius: this.currentRadius,
        show_all: this.currentShowAll,
        page: this.currentPage,
        home_lat: this.homeLatValue,
        home_lng: this.homeLngValue
      })

      const response = await fetch(`/schools/filtered?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()
      this.updateUI(data)
      this.updateURL(params)
      
    } catch (error) {
      console.error('Error filtering schools:', error)
      this.showError('Failed to load schools. Please try again.')
    } finally {
      this.hideLoading()
    }
  }

  updateUI(data) {
    // Update results title and summary
    const title = data.meta.showing_all ? 'All Schools' : `Schools within ${data.meta.radius_km}km`
    this.resultsTitleTarget.textContent = title
    this.resultsSummaryTarget.textContent = `Showing ${data.meta.filtered_count} of ${data.meta.total_schools} schools`

    // Update schools list
    this.schoolsListTarget.innerHTML = this.buildSchoolsHTML(data)
  }

  buildSchoolsHTML(data) {
    if (data.schools.length === 0) {
      return this.buildEmptyStateHTML(data.meta.showing_all)
    }

    const schoolsGrid = data.schools.map(school => this.buildSchoolCardHTML(school, data.meta.showing_all)).join('')
    const pagination = this.buildPaginationHTML(data.pagination)

    return `
      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 mb-8">
        ${schoolsGrid}
      </div>
      
      <!-- Pagination -->
      <div class="flex items-center justify-between">
        <div class="flex items-center text-sm text-gray-700 dark:text-gray-300">
          <span>
            Showing 
            <span class="font-medium">${Math.min((data.pagination.current_page - 1) * data.pagination.per_page + 1, data.pagination.total_count)}</span>
            to 
            <span class="font-medium">${Math.min(data.pagination.current_page * data.pagination.per_page, data.pagination.total_count)}</span>
            of 
            <span class="font-medium">${data.pagination.total_count}</span>
            results
          </span>
        </div>
        
        <div>
          ${pagination}
        </div>
      </div>
    `
  }

  buildSchoolCardHTML(school, showingAll) {
    const distanceBadge = showingAll || !school.distance_km ? '' : 
      `<span class="inline-flex items-center px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full">
        ${school.distance_km}km
      </span>`

    const distanceFooter = showingAll || !school.distance_km ? '' :
      `<span class="text-xs text-gray-500">
        ${school.distance_km} km away
      </span>`

    return `
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-300">
        <div class="p-6">
          <div class="flex items-start justify-between mb-4">
            <h3 class="text-lg font-bold text-gray-900 dark:text-white leading-tight">
              <a href="/schools/${school.slug}" class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 transition-colors">
                ${this.escapeHtml(school.name)}
              </a>
            </h3>
            ${distanceBadge}
          </div>
          
          ${school.address ? `
            <div class="flex items-start mb-4">
              <svg class="w-4 h-4 text-gray-400 mr-2 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd"></path>
              </svg>
              <p class="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                ${this.escapeHtml(school.address)}
              </p>
            </div>
          ` : ''}
          
          <div class="flex items-center justify-between pt-4 border-t border-gray-100 dark:border-gray-700">
            <a href="/schools/${school.slug}" class="inline-flex items-center text-sm font-medium text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 transition-colors">
              View Details
              <svg class="w-4 h-4 ml-1" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
              </svg>
            </a>
            ${distanceFooter}
          </div>
        </div>
      </div>
    `
  }

  buildEmptyStateHTML(showingAll) {
    const title = showingAll ? 'No schools found' : 'No schools match your filters'
    const message = showingAll ? 
      'There are currently no schools in our database.' :
      'Try increasing your search radius or check "Show all schools" to see all available options.'
    
    const showAllButton = showingAll ? '' :
      `<button data-action="click->schools#showAll" 
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-yellow-600 hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500 transition-colors">
        Show All Schools
      </button>`

    return `
      <div class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-8 text-center">
        <svg class="mx-auto h-12 w-12 text-yellow-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <h3 class="text-lg font-medium text-yellow-900 dark:text-yellow-100 mb-2">
          ${title}
        </h3>
        <p class="text-yellow-700 dark:text-yellow-200 mb-4">
          ${message}
        </p>
        ${showAllButton}
      </div>
    `
  }

  buildPaginationHTML(pagination) {
    if (pagination.total_pages <= 1) return ''

    let html = '<nav class="flex items-center space-x-1">'
    
    // Previous button
    if (pagination.has_prev) {
      html += `<button data-action="click->schools#goToPage" data-page="${pagination.current_page - 1}" 
                      class="px-3 py-2 text-sm text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
                Previous
              </button>`
    } else {
      html += `<span class="px-3 py-2 text-sm text-gray-300 bg-gray-100 border border-gray-300 rounded-md cursor-not-allowed">
                Previous
              </span>`
    }

    // Page numbers (simplified - show current page and a few around it)
    const startPage = Math.max(1, pagination.current_page - 2)
    const endPage = Math.min(pagination.total_pages, pagination.current_page + 2)

    if (startPage > 1) {
      html += `<button data-action="click->schools#goToPage" data-page="1" 
                      class="px-3 py-2 text-sm text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
                1
              </button>`
      if (startPage > 2) {
        html += '<span class="px-2 text-gray-400">...</span>'
      }
    }

    for (let i = startPage; i <= endPage; i++) {
      if (i === pagination.current_page) {
        html += `<span class="px-3 py-2 text-sm text-white bg-blue-600 border border-blue-600 rounded-md">
                  ${i}
                </span>`
      } else {
        html += `<button data-action="click->schools#goToPage" data-page="${i}" 
                        class="px-3 py-2 text-sm text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
                  ${i}
                </button>`
      }
    }

    if (endPage < pagination.total_pages) {
      if (endPage < pagination.total_pages - 1) {
        html += '<span class="px-2 text-gray-400">...</span>'
      }
      html += `<button data-action="click->schools#goToPage" data-page="${pagination.total_pages}" 
                      class="px-3 py-2 text-sm text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
                ${pagination.total_pages}
              </button>`
    }

    // Next button
    if (pagination.has_next) {
      html += `<button data-action="click->schools#goToPage" data-page="${pagination.current_page + 1}" 
                      class="px-3 py-2 text-sm text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
                Next
              </button>`
    } else {
      html += `<span class="px-3 py-2 text-sm text-gray-300 bg-gray-100 border border-gray-300 rounded-md cursor-not-allowed">
                Next
              </span>`
    }

    html += '</nav>'
    return html
  }

  goToPage(event) {
    const page = parseInt(event.target.dataset.page)
    if (page && page !== this.currentPage) {
      this.filterSchools(page)
    }
  }

  updateURL(params) {
    // Update browser URL without reloading page
    const newURL = new URL(window.location)
    newURL.search = params.toString()
    window.history.pushState({}, '', newURL)
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
  }

  showError(message) {
    // Simple error display - could be enhanced with a dedicated error target
    console.error(message)
    alert(message)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Handle page refresh/back button with current filters
  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }
}