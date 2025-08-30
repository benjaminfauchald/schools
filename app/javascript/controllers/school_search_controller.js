import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="school-search"
export default class extends Controller {
  static targets = ["searchInput", "searchResults", "searchLoading"]
  static values = { 
    homeLat: Number, 
    homeLng: Number 
  }

  connect() {
    this.debounceTimer = null
    this.currentRequest = null
    this.selectedIndex = -1
    
    // Close dropdown when clicking outside
    this.boundCloseDropdown = this.closeDropdown.bind(this)
    document.addEventListener('click', this.boundCloseDropdown)
    
    // Try to get location from localStorage if values not provided
    if (!this.homeLatValue || !this.homeLngValue) {
      this.updateLocationFromStorage()
    }
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.currentRequest) {
      this.currentRequest.abort()
    }
    document.removeEventListener('click', this.boundCloseDropdown)
  }

  updateLocationFromStorage() {
    try {
      const stored = localStorage.getItem('homeLocation')
      if (stored) {
        const location = JSON.parse(stored)
        this.homeLatValue = location.lat
        this.homeLngValue = location.lng
      }
    } catch (error) {
      console.error('Error reading stored location:', error)
    }
  }

  search() {
    const query = this.searchInputTarget.value.trim()
    
    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // If query is empty, hide results
    if (query.length === 0) {
      this.hideResults()
      return
    }

    // Check if we have location
    if (!this.homeLatValue || !this.homeLngValue) {
      this.showError('Location required for search. Please set your location first.')
      return
    }

    // Debounce at 300ms
    this.debounceTimer = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  async performSearch(query) {
    // Cancel previous request if still pending
    if (this.currentRequest) {
      this.currentRequest.abort()
    }

    // Show loading indicator
    this.showLoading()

    try {
      // Create new AbortController for this request
      const controller = new AbortController()
      this.currentRequest = controller

      const url = new URL('/schools/search', window.location.origin)
      url.searchParams.set('q', query)
      url.searchParams.set('home_lat', this.homeLatValue)
      url.searchParams.set('home_lng', this.homeLngValue)

      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()
      this.displayResults(data.schools, query)
      
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Search error:', error)
        this.showError('Search failed. Please try again.')
      }
    } finally {
      this.hideLoading()
      this.currentRequest = null
    }
  }

  displayResults(schools, query) {
    const resultsContainer = this.searchResultsTarget
    
    if (schools.length === 0) {
      resultsContainer.innerHTML = this.noResultsHTML(query)
    } else {
      resultsContainer.innerHTML = this.resultsHTML(schools)
    }
    
    this.showResults()
    this.selectedIndex = -1
  }

  resultsHTML(schools) {
    return schools.map((school, index) => `
      <a href="${school.url}" 
         class="block px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700 border-b border-gray-100 dark:border-gray-600 last:border-b-0 result-item"
         data-index="${index}">
        <div class="flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <h4 class="text-sm font-medium text-gray-900 dark:text-white truncate">
              ${this.highlightMatch(school.name)}
            </h4>
            <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 truncate">
              ${school.address}
            </p>
          </div>
          <div class="ml-4 flex-shrink-0">
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
              ${school.distance_km}km
            </span>
          </div>
        </div>
      </a>
    `).join('')
  }

  noResultsHTML(query) {
    return `
      <div class="px-4 py-6 text-center">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">No schools found</h3>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          No schools match "${query}". Try a different search term.
        </p>
      </div>
    `
  }

  highlightMatch(text) {
    const query = this.searchInputTarget.value.trim()
    if (!query) return text
    
    const regex = new RegExp(`(${query})`, 'gi')
    return text.replace(regex, '<mark class="bg-yellow-200 dark:bg-yellow-800 px-1 rounded">$1</mark>')
  }

  handleKeydown(event) {
    const resultsVisible = !this.searchResultsTarget.classList.contains('hidden')
    
    if (!resultsVisible) return

    const items = this.searchResultsTarget.querySelectorAll('.result-item')
    
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.updateSelection(items)
        break
        
      case 'ArrowUp':
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
        this.updateSelection(items)
        break
        
      case 'Enter':
        event.preventDefault()
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          items[this.selectedIndex].click()
        }
        break
        
      case 'Escape':
        this.hideResults()
        this.searchInputTarget.blur()
        break
    }
  }

  updateSelection(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('bg-gray-50', 'dark:bg-gray-700')
        item.scrollIntoView({ block: 'nearest' })
      } else {
        item.classList.remove('bg-gray-50', 'dark:bg-gray-700')
      }
    })
  }

  showResults() {
    this.searchResultsTarget.classList.remove('hidden')
  }

  hideResults() {
    this.searchResultsTarget.classList.add('hidden')
    this.selectedIndex = -1
  }

  showLoading() {
    this.searchLoadingTarget.classList.remove('hidden')
  }

  hideLoading() {
    this.searchLoadingTarget.classList.add('hidden')
  }

  showError(message) {
    this.searchResultsTarget.innerHTML = `
      <div class="px-4 py-6 text-center">
        <svg class="mx-auto h-12 w-12 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-red-900 dark:text-red-100">Search Error</h3>
        <p class="mt-1 text-sm text-red-700 dark:text-red-200">${message}</p>
      </div>
    `
    this.showResults()
  }

  closeDropdown(event) {
    // Close dropdown if clicking outside of search area
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }
}