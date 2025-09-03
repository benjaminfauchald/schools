// Google Maps Service - Centralized Google Maps API loading and management
export class GoogleMapsService {
  static instance = null;
  static loadingPromise = null;
  static isLoaded = false;
  
  constructor() {
    if (GoogleMapsService.instance) {
      return GoogleMapsService.instance;
    }
    GoogleMapsService.instance = this;
    this.callbacks = new Map();
  }
  
  static getInstance() {
    if (!GoogleMapsService.instance) {
      GoogleMapsService.instance = new GoogleMapsService();
    }
    return GoogleMapsService.instance;
  }
  
  // Load Google Maps API if not already loaded
  async loadGoogleMaps() {
    // Return existing promise if already loading
    if (GoogleMapsService.loadingPromise) {
      return GoogleMapsService.loadingPromise;
    }
    
    // Return immediately if already loaded
    if (GoogleMapsService.isLoaded || (window.google && window.google.maps)) {
      GoogleMapsService.isLoaded = true;
      return Promise.resolve();
    }
    
    // Create loading promise
    GoogleMapsService.loadingPromise = new Promise((resolve, reject) => {
      try {
        // Get API key from meta tag
        const apiKeyMeta = document.querySelector('meta[name="google-maps-api-key"]');
        const apiKey = apiKeyMeta ? apiKeyMeta.content : '';
        
        if (!apiKey) {
          console.warn('Google Maps API key not found. Looking for GOOGLE_MAPS_API_KEY in meta tags.');
        }
        
        // Create callback function name
        const callbackName = 'googleMapsCallback_' + Date.now();
        
        // Set up global callback
        window[callbackName] = () => {
          GoogleMapsService.isLoaded = true;
          delete window[callbackName]; // Clean up
          resolve();
          
          // Dispatch custom event for components
          window.dispatchEvent(new CustomEvent('google-maps-loaded'));
        };
        
        // Create and inject script
        const script = document.createElement('script');
        script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&callback=${callbackName}&libraries=geometry,places,marker&loading=async`;
        script.async = true;
        script.defer = true;
        script.onerror = () => {
          delete window[callbackName];
          reject(new Error('Failed to load Google Maps API'));
        };
        
        document.head.appendChild(script);
        
      } catch (error) {
        reject(error);
      }
    });
    
    return GoogleMapsService.loadingPromise;
  }
  
  // Initialize a map with the given options
  async initializeMap(containerId, options = {}) {
    await this.loadGoogleMaps();
    
    const container = document.getElementById(containerId);
    if (!container) {
      throw new Error(`Map container with ID "${containerId}" not found`);
    }
    
    const defaultOptions = {
      zoom: 15,
      center: { lat: 13.7563, lng: 100.5018 }, // Bangkok center
      mapTypeControl: true,
      streetViewControl: true,
      fullscreenControl: true,
      zoomControl: true,
      ...options
    };
    
    const map = new google.maps.Map(container, defaultOptions);
    return map;
  }
  
  // Register a callback to run when Google Maps is ready
  onReady(callback) {
    if (GoogleMapsService.isLoaded) {
      callback();
    } else {
      window.addEventListener('google-maps-loaded', callback, { once: true });
    }
  }
  
  // Check if Google Maps is available
  isReady() {
    return GoogleMapsService.isLoaded && window.google && window.google.maps;
  }
}

// Export singleton instance
export const googleMapsService = GoogleMapsService.getInstance();

// Auto-load Google Maps on page load if not already loaded
document.addEventListener('DOMContentLoaded', () => {
  // Only auto-load if there are map containers on the page
  const mapContainers = document.querySelectorAll('[data-google-map]');
  if (mapContainers.length > 0) {
    googleMapsService.loadGoogleMaps().catch(error => {
      console.error('Failed to auto-load Google Maps:', error);
    });
  }
});