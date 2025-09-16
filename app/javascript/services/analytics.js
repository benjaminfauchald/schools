// Analytics Service - Client-side wrapper for Mixpanel
// Provides a clean interface for tracking events and user properties

class AnalyticsService {
  constructor() {
    this.mixpanel = window.mixpanel;
    this.debugMode = document.querySelector('meta[name="debug-mode"]')?.content === 'true';
    this.setupTurboTracking();
    this.setupLocationTracking();
  }

  // Track generic event with properties
  track(eventName, properties = {}) {
    if (!this.mixpanel) return;
    
    // Enrich properties with default values
    const enrichedProperties = {
      ...properties,
      path: window.location.pathname,
      url: window.location.href,
      timestamp: new Date().toISOString()
    };

    // Add user location if available
    const userLocation = this.getUserLocation();
    if (userLocation) {
      enrichedProperties.user_lat = userLocation.lat;
      enrichedProperties.user_lng = userLocation.lng;
      enrichedProperties.user_area = userLocation.area;
    }

    if (this.debugMode) {
      console.log(`📊 [Analytics] Tracking: ${eventName}`, enrichedProperties);
    }

    this.mixpanel.track(eventName, enrichedProperties);
  }

  // Track page views on Turbo navigation
  setupTurboTracking() {
    document.addEventListener('turbo:load', () => {
      // Skip initial page load (already tracked in layout)
      if (window.turboNavigated) {
        this.trackPageView();
      }
      window.turboNavigated = true;
    });

    // Track before navigation for exit tracking
    document.addEventListener('turbo:before-visit', (event) => {
      const exitUrl = event.detail.url;
      this.track('Page Exit', {
        exit_url: exitUrl,
        time_on_page: this.getTimeOnPage()
      });
    });
  }

  // Track page view
  trackPageView() {
    this.track('Page Viewed', {
      title: document.title,
      referrer: document.referrer
    });
  }

  // Track school view
  trackSchoolView(schoolId, schoolName, source = 'direct') {
    this.track('School Viewed', {
      school_id: schoolId,
      school_name: schoolName,
      view_source: source
    });
    
    // Track in Hotjar to see session recordings of school views
    if (typeof hj !== 'undefined') {
      hj('event', 'school_viewed');
      hj('vpv', '/virtual/school/' + schoolId); // Virtual page view for funnel tracking
    }
  }

  // Track inquiry form submission
  trackInquiry(schoolId, schoolName, childrenCount) {
    this.track('Inquiry Sent', {
      school_id: schoolId,
      school_name: schoolName,
      children_count: childrenCount
    });
    
    // Also track in Hotjar
    if (typeof hj !== 'undefined') {
      hj('event', 'inquiry_sent');
    }
  }

  // Track search
  trackSearch(query, filters = {}, resultsCount = 0) {
    this.track('School Search', {
      query: query,
      filters: JSON.stringify(filters),
      results_count: resultsCount,
      has_filters: Object.keys(filters).length > 0
    });
  }

  // Track filter application
  trackFilter(filterType, filterValue) {
    this.track('Filter Applied', {
      filter_type: filterType,
      filter_value: filterValue
    });
    
    // Track in Hotjar
    if (typeof hj !== 'undefined') {
      hj('event', 'filter_used');
    }
  }

  // Track location set
  trackLocationSet(lat, lng, area, method = 'manual') {
    this.track('Location Set', {
      latitude: lat,
      longitude: lng,
      area: area,
      method: method
    });
    
    // Track in Hotjar - important conversion event
    if (typeof hj !== 'undefined') {
      hj('event', 'location_set');
      // This helps identify where users are from in recordings
      hj('tagRecording', [area || 'unknown_area']);
    }
  }

  // Track AI chat interaction
  trackAIChat(schoolId, schoolName, action = 'started') {
    this.track('AI Chat ' + action.charAt(0).toUpperCase() + action.slice(1), {
      school_id: schoolId,
      school_name: schoolName
    });
  }

  // Track photo view
  trackPhotoView(schoolId, schoolName, photoType = 'google') {
    this.track('Photo Viewed', {
      school_id: schoolId,
      school_name: schoolName,
      photo_type: photoType
    });
  }

  // Track document view
  trackDocumentView(schoolId, schoolName, documentType) {
    this.track('Document Viewed', {
      school_id: schoolId,
      school_name: schoolName,
      document_type: documentType
    });
  }

  // Track video play
  trackVideoPlay(schoolId, schoolName, videoTitle) {
    this.track('Video Played', {
      school_id: schoolId,
      school_name: schoolName,
      video_title: videoTitle
    });
  }

  // Track claim action
  trackClaim(schoolId, schoolName, action = 'started') {
    this.track('School Claim ' + action.charAt(0).toUpperCase() + action.slice(1), {
      school_id: schoolId,
      school_name: schoolName
    });
  }

  // Track onboarding steps
  trackOnboardingStep(step, data = {}) {
    this.track('Onboarding Step Completed', {
      step: step,
      ...data
    });
  }

  // Track clicks on important CTAs
  trackCTA(ctaName, context = {}) {
    this.track('CTA Clicked', {
      cta_name: ctaName,
      ...context
    });
  }

  // Setup location tracking from cookie
  setupLocationTracking() {
    // Watch for location changes
    const originalSetCookie = document.cookie;
    Object.defineProperty(document, 'cookie', {
      get: function() { return originalSetCookie; },
      set: function(value) {
        originalSetCookie = value;
        
        // Check if user_location cookie was set
        if (value.includes('user_location=')) {
          const location = window.analytics.getUserLocation();
          if (location) {
            window.analytics.updateUserLocation(location);
          }
        }
        
        return value;
      }
    });
  }

  // Get user location from cookie
  getUserLocation() {
    const cookie = document.cookie.match(/user_location=([^;]+)/);
    if (cookie) {
      try {
        const decoded = decodeURIComponent(cookie[1]);
        return JSON.parse(decoded);
      } catch (e) {
        if (this.debugMode) {
          console.error('📊 [Analytics] Failed to parse location cookie:', e);
        }
      }
    }
    return null;
  }

  // Update user location in Mixpanel
  updateUserLocation(location) {
    if (!this.mixpanel) return;
    
    this.mixpanel.register({
      user_lat: location.lat,
      user_lng: location.lng,
      user_area: location.area
    });

    if (this.debugMode) {
      console.log('📊 [Analytics] User location updated:', location);
    }
  }

  // Get time spent on current page
  getTimeOnPage() {
    if (!window.pageLoadTime) {
      window.pageLoadTime = Date.now();
    }
    return Math.round((Date.now() - window.pageLoadTime) / 1000);
  }

  // Identify user (when they log in)
  identify(userId, properties = {}) {
    if (!this.mixpanel) return;
    
    const distinctId = `user_${userId}`;
    this.mixpanel.identify(distinctId);
    
    if (Object.keys(properties).length > 0) {
      this.mixpanel.people.set(properties);
    }

    if (this.debugMode) {
      console.log(`📊 [Analytics] User identified: ${distinctId}`, properties);
    }
  }

  // Alias anonymous user to authenticated user
  alias(userId) {
    if (!this.mixpanel) return;
    
    const newId = `user_${userId}`;
    this.mixpanel.alias(newId);

    if (this.debugMode) {
      console.log(`📊 [Analytics] User aliased to: ${newId}`);
    }
  }

  // Track form abandonment
  trackFormAbandonment(formName, fieldsCompleted, totalFields) {
    this.track('Form Abandoned', {
      form_name: formName,
      fields_completed: fieldsCompleted,
      total_fields: totalFields,
      completion_percentage: Math.round((fieldsCompleted / totalFields) * 100)
    });
  }

  // Track error
  trackError(errorMessage, context = {}) {
    this.track('Error Occurred', {
      error_message: errorMessage,
      ...context
    });
  }
}

// Initialize and export analytics service
const analytics = new AnalyticsService();

// Make it globally available
window.analytics = analytics;

export default analytics;