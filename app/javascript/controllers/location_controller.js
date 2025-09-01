import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "addressInput", "errorMessage", "successMessage", "confirmAddress", "confirmButton"]
  static values = { 
    googleApiKey: String,
    hasLocation: Boolean 
  }

  connect() {
    this.checkHomeLocation()
  }

  checkHomeLocation() {
    // First check if server provided Puppeteer location
    const puppeteerLocation = this.getPuppeteerLocation()
    if (puppeteerLocation) {
      this.hasLocationValue = true
      this.enableAppFeatures()
      return
    }

    const homeLocation = this.getStoredLocation()
    
    if (!homeLocation) {
      // Redirect to onboarding page instead of showing modal
      window.location.href = '/onboarding'
    } else {
      this.hasLocationValue = true
      // Enable app features
      this.enableAppFeatures()
    }
  }

  showModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      this.modalTarget.classList.add("flex")
      document.body.classList.add("overflow-hidden")
    }
  }

  hideModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      this.modalTarget.classList.remove("flex")
      document.body.classList.remove("overflow-hidden")
    }
  }

  async geocodeAddress(event) {
    event.preventDefault()
    
    const address = this.addressInputTarget.value.trim()
    if (!address) {
      this.showError("Please enter an address")
      return
    }

    this.clearMessages()
    this.showLoading()

    try {
      const coordinates = await this.fetchCoordinates(address)
      
      if (coordinates) {
        this.showConfirmation(coordinates, address)
      } else {
        this.showError("Could not find coordinates for that address. Please try again.")
      }
    } catch (error) {
      console.error("Geocoding error:", error)
      this.showError("Error finding location. Please check your internet connection and try again.")
    } finally {
      this.hideLoading()
    }
  }

  async fetchCoordinates(address) {
    // First try Google Geocoding API if available
    if (this.googleApiKeyValue) {
      try {
        const response = await fetch(
          `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${this.googleApiKeyValue}`
        )
        const data = await response.json()
        
        if (data.status === 'OK' && data.results.length > 0) {
          const location = data.results[0].geometry.location
          return {
            lat: location.lat,
            lng: location.lng,
            formatted_address: data.results[0].formatted_address
          }
        }
      } catch (error) {
        console.warn("Google Geocoding failed, trying fallback:", error)
      }
    }

    // Fallback to Nominatim (OpenStreetMap)
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}&limit=1&addressdetails=1`
      )
      const data = await response.json()
      
      if (data.length > 0) {
        return {
          lat: parseFloat(data[0].lat),
          lng: parseFloat(data[0].lon),
          formatted_address: data[0].display_name
        }
      }
    } catch (error) {
      console.error("Nominatim geocoding failed:", error)
    }
    
    return null
  }

  showConfirmation(coordinates, originalAddress) {
    this.tempCoordinates = coordinates
    
    if (this.hasConfirmAddressTarget) {
      this.confirmAddressTarget.textContent = coordinates.formatted_address || originalAddress
    }
    
    // Show confirmation section
    const confirmationSection = this.element.querySelector('[data-location-confirmation]')
    if (confirmationSection) {
      confirmationSection.classList.remove('hidden')
    }
    
    // Hide input section
    const inputSection = this.element.querySelector('[data-location-input]')
    if (inputSection) {
      inputSection.classList.add('hidden')
    }
  }

  confirmLocation() {
    if (!this.tempCoordinates) return
    
    try {
      // Store location in localStorage
      this.storeLocation(this.tempCoordinates)
      
      // Mark as having location
      this.hasLocationValue = true
      
      // Show success message
      this.showSuccess("Home location set successfully!")
      
      // Hide modal after a short delay
      setTimeout(() => {
        this.hideModal()
        this.enableAppFeatures()
        // Reload the page to show location-aware content
        window.location.reload()
      }, 1500)
      
    } catch (error) {
      console.error("Error storing location:", error)
      this.showError("Failed to save location. Please try again.")
    }
  }

  editLocation() {
    // Show input section
    const inputSection = this.element.querySelector('[data-location-input]')
    if (inputSection) {
      inputSection.classList.remove('hidden')
    }
    
    // Hide confirmation section
    const confirmationSection = this.element.querySelector('[data-location-confirmation]')
    if (confirmationSection) {
      confirmationSection.classList.add('hidden')
    }
    
    this.clearMessages()
  }

  storeLocation(coordinates) {
    const locationData = {
      lat: coordinates.lat,
      lng: coordinates.lng,
      formatted_address: coordinates.formatted_address,
      timestamp: new Date().toISOString()
    }
    
    localStorage.setItem('homeLocation', JSON.stringify(locationData))
    
    // Also dispatch a custom event for other parts of the app
    window.dispatchEvent(new CustomEvent('homeLocationSet', { 
      detail: locationData 
    }))
  }

  getStoredLocation() {
    try {
      const stored = localStorage.getItem('homeLocation')
      if (stored) {
        const location = JSON.parse(stored)
        // Check if location is not too old (optional: expire after 30 days)
        const thirtyDaysAgo = new Date()
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
        
        if (new Date(location.timestamp) > thirtyDaysAgo) {
          return location
        }
      }
    } catch (error) {
      console.error("Error reading stored location:", error)
    }
    return null
  }

  getPuppeteerLocation() {
    // Check if server set a Puppeteer location in a data attribute or global variable
    // This would be set server-side for headless browser testing
    const puppeteerData = document.querySelector('[data-puppeteer-location]')
    if (puppeteerData) {
      try {
        const locationData = JSON.parse(puppeteerData.getAttribute('data-puppeteer-location'))
        return locationData
      } catch (error) {
        console.error("Error parsing Puppeteer location data:", error)
      }
    }

    // Also check for a global variable that might be set by the server
    if (window.puppeteerLocation) {
      return window.puppeteerLocation
    }

    return null
  }

  clearStoredLocation() {
    localStorage.removeItem('homeLocation')
    this.hasLocationValue = false
    window.dispatchEvent(new CustomEvent('homeLocationCleared'))
  }

  enableAppFeatures() {
    // Remove any disabled state from the app
    const disabledElements = document.querySelectorAll('[data-location-required]')
    disabledElements.forEach(element => {
      element.classList.remove('opacity-50', 'pointer-events-none')
      element.removeAttribute('disabled')
    })
    
    // Show location-aware content
    const locationContent = document.querySelectorAll('[data-location-content]')
    locationContent.forEach(element => {
      element.classList.remove('hidden')
    })
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove("hidden")
    }
  }

  showSuccess(message) {
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.textContent = message
      this.successMessageTarget.classList.remove("hidden")
    }
  }

  clearMessages() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add("hidden")
    }
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.add("hidden")
    }
  }

  showLoading() {
    const submitButton = this.element.querySelector('[data-location-submit]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Finding location...
      `
    }
  }

  hideLoading() {
    const submitButton = this.element.querySelector('[data-location-submit]')
    if (submitButton) {
      submitButton.disabled = false
      submitButton.innerHTML = 'Find My Location'
    }
  }

  // Method to get current location (for use by other controllers)
  getCurrentLocation() {
    return this.getStoredLocation()
  }

  // Method to calculate distance between two points (Haversine formula)
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371 // Radius of the Earth in kilometers
    const dLat = this.deg2rad(lat2 - lat1)
    const dLon = this.deg2rad(lon2 - lon1)
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(this.deg2rad(lat1)) * Math.cos(this.deg2rad(lat2)) * 
      Math.sin(dLon/2) * Math.sin(dLon/2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    const d = R * c // Distance in kilometers
    return d
  }

  deg2rad(deg) {
    return deg * (Math.PI/180)
  }
}