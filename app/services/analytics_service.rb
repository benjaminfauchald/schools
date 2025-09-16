# AnalyticsService provides centralized tracking for all user events and metrics
# Handles both authenticated and anonymous users with consistent event structure
class AnalyticsService
  class << self
    # Track a generic event with properties
    def track(event_name, properties = {}, user: nil, request: nil)
      return unless enabled?

      distinct_id = get_distinct_id(user, request)
      enriched_properties = enrich_properties(properties, user, request)

      tracker.track(distinct_id, event_name, enriched_properties)
    rescue => e
      Rails.logger.error "Analytics tracking error: #{e.message}"
    end

    # Update user profile properties
    def identify(user, properties = {})
      return unless enabled?

      distinct_id = user_id(user)

      # Set user properties
      people_properties = {
        "$email" => user.email,
        "$name" => user.display_name,
        "registration_date" => user.created_at,
        "registration_method" => user.provider || "email",
        "user_type" => user.role,
        "facebook_user" => user.facebook_user?,
        "schools_claimed" => user.school_claims.approved.count,
        "total_inquiries" => user.school_inquiries.count
      }.merge(properties)

      tracker.people.set(distinct_id, people_properties)
    rescue => e
      Rails.logger.error "Analytics identify error: #{e.message}"
    end

    # Track page view event
    def track_page_view(path, title, user: nil, request: nil)
      track("Page Viewed", {
        path: path,
        title: title,
        url: request&.url,
        referrer: request&.referrer
      }, user: user, request: request)
    end

    # Track user registration
    def track_signup(user, method:, source: nil)
      track("User Signed Up", {
        method: method,
        source: source,
        user_id: user.id,
        email: user.email
      }, user: user)

      # Also identify the user
      identify(user)
    end

    # Track user login
    def track_login(user, method:)
      track("User Signed In", {
        method: method,
        user_id: user.id
      }, user: user)
    end

    # Track school view
    def track_school_view(school, user: nil, request: nil, source: "direct")
      track("School Viewed", {
        school_id: school.id,
        school_name: school.name,
        school_area: school.district,
        school_rating: school.rating,
        view_source: source,
        has_photos: school.photos.any?,
        has_contact_info: school.formatted_phone_number.present?
      }, user: user, request: request)
    end

    # Track inquiry submission
    def track_inquiry(inquiry, user: nil, request: nil)
      track("Inquiry Sent", {
        school_id: inquiry.school_id,
        school_name: inquiry.school.name,
        children_count: inquiry.children_count,
        user_type: user ? "registered" : "anonymous",
        inquiry_id: inquiry.id
      }, user: user, request: request)
    end

    # Track location set
    def track_location_set(lat:, lng:, area: nil, user: nil, request: nil)
      track("Location Set", {
        latitude: lat,
        longitude: lng,
        area: area,
        method: "manual"
      }, user: user, request: request)
    end

    # Track search
    def track_search(query:, filters: {}, results_count: 0, user: nil, request: nil)
      track("School Search", {
        query: query,
        filters: filters.to_json,
        results_count: results_count,
        has_filters: filters.any?
      }, user: user, request: request)
    end

    # Track filter usage
    def track_filter(filter_type:, filter_value:, user: nil, request: nil)
      track("Filter Applied", {
        filter_type: filter_type,
        filter_value: filter_value
      }, user: user, request: request)
    end

    # Track school claim
    def track_claim(claim, action:)
      track("School Claim " + action.capitalize, {
        school_id: claim.school_id,
        school_name: claim.school.name,
        claim_id: claim.id,
        evidence_type: claim.evidence_url.present? ? "url" : "none"
      }, user: claim.user)
    end

    # Track AI chat interaction
    def track_ai_chat(school:, message_count: 1, user: nil, request: nil)
      track("AI Chat Used", {
        school_id: school.id,
        school_name: school.name,
        message_count: message_count
      }, user: user, request: request)
    end

    # Track document view
    def track_document_view(document, school:, user: nil, request: nil)
      track("Document Viewed", {
        document_id: document.id,
        document_type: document.document_type,
        school_id: school.id,
        school_name: school.name
      }, user: user, request: request)
    end

    # Track photo view
    def track_photo_view(school:, photo_type: "google", user: nil, request: nil)
      track("Photo Viewed", {
        school_id: school.id,
        school_name: school.name,
        photo_type: photo_type
      }, user: user, request: request)
    end

    # Track onboarding completion
    def track_onboarding_complete(duration_seconds:, user: nil, request: nil)
      track("Onboarding Completed", {
        duration_seconds: duration_seconds,
        duration_formatted: format_duration(duration_seconds)
      }, user: user, request: request)
    end

    # Alias user IDs when they sign up (link anonymous to authenticated)
    def alias_user(anonymous_id, user)
      return unless enabled?

      tracker.alias(user_id(user), anonymous_id)
    rescue => e
      Rails.logger.error "Analytics alias error: #{e.message}"
    end

    private

    def tracker
      Rails.application.config.mixpanel_tracker
    end

    def enabled?
      tracker.present?
    end

    def get_distinct_id(user, request)
      if user&.id
        user_id(user)
      elsif request&.session&.id
        "anon_#{request.session.id}"
      else
        "anon_#{SecureRandom.uuid}"
      end
    end

    def user_id(user)
      "user_#{user.id}"
    end

    def enrich_properties(properties, user, request)
      enriched = properties.dup

      # Add timestamp
      enriched["time"] = Time.current.to_i

      # Add user context if available
      if user
        enriched["user_id"] = user.id
        enriched["user_type"] = user.role
        enriched["authenticated"] = true
      else
        enriched["authenticated"] = false
      end

      # Add request context if available
      if request
        enriched["ip"] = request.remote_ip
        enriched["user_agent"] = request.user_agent
        enriched["locale"] = I18n.locale

        # Add location from cookies if available
        if request.cookies["user_location"].present?
          begin
            location = JSON.parse(request.cookies["user_location"])
            enriched["user_lat"] = location["lat"]
            enriched["user_lng"] = location["lng"]
            enriched["user_area"] = location["area"]
          rescue JSON::ParserError
            # Ignore invalid JSON
          end
        end
      end

      # Add Rails environment
      enriched["environment"] = Rails.env

      enriched
    end

    def format_duration(seconds)
      return "#{seconds} seconds" if seconds < 60

      minutes = seconds / 60
      remaining_seconds = seconds % 60

      if minutes < 60
        "#{minutes}m #{remaining_seconds}s"
      else
        hours = minutes / 60
        remaining_minutes = minutes % 60
        "#{hours}h #{remaining_minutes}m"
      end
    end
  end
end
