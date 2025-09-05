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
    this.debugMode = this.isDebugModeEnabled();
    
    if (this.debugMode) {
      console.log('🗺️ [DEBUG] GoogleMapsService constructor called');
      console.log('🗺️ [DEBUG] Debug mode enabled');
    }
  }
  
  // Check if debug mode is enabled via environment variable
  isDebugModeEnabled() {
    // Check for DEBUG_MODE in document body data attribute (set by Rails)
    const debugMode = document.body?.dataset?.debugMode === 'true' || 
                     document.querySelector('meta[name="debug-mode"]')?.content === 'true';
    return debugMode;
  }
  
  // Debug logging helper
  log(message, ...args) {
    if (this.debugMode) {
      console.log(`🗺️ [DEBUG] ${message}`, ...args);
    }
  }
  
  // Error logging (always shown)
  error(message, ...args) {
    console.error(`🗺️ [ERROR] ${message}`, ...args);
  }
  
  // Warning logging (always shown)  
  warn(message, ...args) {
    console.warn(`🗺️ [WARN] ${message}`, ...args);
  }
  
  static getInstance() {
    if (!GoogleMapsService.instance) {
      GoogleMapsService.instance = new GoogleMapsService();
    }
    return GoogleMapsService.instance;
  }
  
  // Load Google Maps API if not already loaded
  async loadGoogleMaps() {
    this.log('loadGoogleMaps() called');
    
    // Return immediately if already loaded (check for existing scripts too)
    if (GoogleMapsService.isLoaded || (window.google && window.google.maps)) {
      this.log('Google Maps already loaded');
      GoogleMapsService.isLoaded = true;
      return Promise.resolve();
    }
    
    // Check if Google Maps script is already in the DOM
    const existingScript = document.querySelector('script[src*="maps.googleapis.com"]');
    if (existingScript) {
      this.log('Google Maps script already exists in DOM, waiting for it to load');
      
      // Wait for existing script to load if it hasn't yet
      if (window.google && window.google.maps) {
        GoogleMapsService.isLoaded = true;
        return Promise.resolve();
      }
      
      // Wait for the existing script's callback
      return new Promise((resolve) => {
        const checkLoaded = () => {
          if (window.google && window.google.maps) {
            GoogleMapsService.isLoaded = true;
            this.log('Google Maps loaded from existing script');
            resolve();
          } else {
            setTimeout(checkLoaded, 100);
          }
        };
        checkLoaded();
      });
    }
    
    // Return existing promise if already loading
    if (GoogleMapsService.loadingPromise) {
      this.log('Already loading, returning existing promise');
      return GoogleMapsService.loadingPromise;
    }
    
    this.log('Starting Google Maps API load process');
    
    // Create loading promise
    GoogleMapsService.loadingPromise = new Promise((resolve, reject) => {
      try {
        // Get API key from meta tag
        const apiKeyMeta = document.querySelector('meta[name="google-maps-api-key"]');
        const apiKey = apiKeyMeta ? apiKeyMeta.content : '';
        
        this.log('API Key meta tag found:', !!apiKeyMeta);
        this.log('API Key length:', apiKey ? apiKey.length : 0);
        this.log('API Key (first 10 chars):', apiKey ? apiKey.substring(0, 10) + '...' : 'MISSING');
        
        if (!apiKey) {
          this.error('Google Maps API key not found. Check meta tag "google-maps-api-key"');
          reject(new Error('Google Maps API key not found'));
          return;
        }
        
        // Create callback function name
        const callbackName = 'googleMapsCallback_' + Date.now();
        this.log('Callback function name:', callbackName);
        
        // Set up global callback
        window[callbackName] = () => {
          this.log('Google Maps API loaded successfully via callback');
          GoogleMapsService.isLoaded = true;
          delete window[callbackName]; // Clean up
          
          // Verify Google Maps objects are available
          this.log('window.google available:', !!window.google);
          this.log('window.google.maps available:', !!(window.google && window.google.maps));
          this.log('google.maps.Map available:', !!(window.google && window.google.maps && window.google.maps.Map));
          
          resolve();
          
          // Dispatch custom event for components
          window.dispatchEvent(new CustomEvent('google-maps-loaded'));
          this.log('google-maps-loaded event dispatched');
        };
        
        // Create and inject script
        const script = document.createElement('script');
        const scriptUrl = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&callback=${callbackName}&libraries=geometry,places,marker&loading=async`;
        script.src = scriptUrl;
        script.async = true;
        script.defer = true;
        
        this.log('Script URL:', scriptUrl);
        this.log('Loading Google Maps script...');
        
        script.onerror = (error) => {
          this.error('Failed to load Google Maps script:', error);
          delete window[callbackName];
          reject(new Error('Failed to load Google Maps API - script error'));
        };
        
        // Add load event listener for additional debugging
        script.onload = () => {
          this.log('Google Maps script loaded (onload event)');
        };
        
        document.head.appendChild(script);
        this.log('Script element added to document head');
        
        // Add timeout to catch loading issues
        setTimeout(() => {
          if (!GoogleMapsService.isLoaded) {
            this.error('Google Maps API loading timeout after 10 seconds');
            delete window[callbackName];
            reject(new Error('Google Maps API loading timeout'));
          }
        }, 10000);
        
      } catch (error) {
        this.error('Exception in loadGoogleMaps:', error);
        reject(error);
      }
    });
    
    return GoogleMapsService.loadingPromise;
  }
  
  // Initialize a map with the given options
  async initializeMap(containerId, options = {}) {
    this.log(`initializeMap() called for container: ${containerId}`);
    
    try {
      await this.loadGoogleMaps();
      this.log('Google Maps API loaded, proceeding with map initialization');
    } catch (error) {
      this.error('Failed to load Google Maps API before map initialization:', error);
      throw error;
    }
    
    const container = document.getElementById(containerId);
    if (!container) {
      this.error(`Map container with ID "${containerId}" not found in DOM`);
      throw new Error(`Map container with ID "${containerId}" not found`);
    }
    
    this.log('Map container found:', container);
    this.log('Container dimensions:', {
      width: container.offsetWidth,
      height: container.offsetHeight,
      display: getComputedStyle(container).display,
      visibility: getComputedStyle(container).visibility
    });
    
    const defaultOptions = {
      zoom: 15,
      center: { lat: 13.7563, lng: 100.5018 }, // Bangkok center
      mapTypeControl: true,
      streetViewControl: true,
      fullscreenControl: true,
      zoomControl: true,
      ...options
    };
    
    this.log('Map options:', defaultOptions);
    
    try {
      const map = new google.maps.Map(container, defaultOptions);
      this.log('Map created successfully:', map);
      return map;
    } catch (error) {
      this.error('Failed to create Google Maps instance:', error);
      throw error;
    }
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
  const service = GoogleMapsService.getInstance();
  service.log('DOMContentLoaded event fired');
  
  // Only auto-load if there are map containers on the page
  const mapContainers = document.querySelectorAll('[data-google-map]');
  service.log(`Found ${mapContainers.length} map containers with [data-google-map] attribute`);
  
  if (mapContainers.length > 0) {
    service.log('Auto-loading Google Maps API...');
    googleMapsService.loadGoogleMaps().catch(error => {
      service.error('Failed to auto-load Google Maps:', error);
    });
  } else {
    service.log('No map containers found, skipping auto-load');
  }
});