class FacebookWebhookService
  def initialize(payload)
    @payload = payload.is_a?(String) ? JSON.parse(payload) : payload
  rescue JSON::ParserError => e
    Rails.logger.error "FacebookWebhookService: Invalid JSON payload: #{e.message}"
    @payload = {}
  end

  def process_deletion_request
    facebook_user_id = extract_facebook_user_id
    
    if facebook_user_id.blank?
      error_msg = "No Facebook user ID found in deletion request payload"
      Rails.logger.error "FacebookWebhookService: #{error_msg}"
      
      WebhookAuditLog.log_deletion(
        facebook_user_id: 'unknown',
        payload: @payload,
        status: 'failed',
        error_message: error_msg
      )
      
      return { success: false, error: error_msg }
    end

    # Find user by Facebook UID
    user = User.find_by(provider: 'facebook', uid: facebook_user_id)
    
    begin
      if user
        Rails.logger.info "FacebookWebhookService: Processing deletion request for user #{user.id} (FB: #{facebook_user_id})"
        
        # Delete Facebook-specific data while preserving business records
        user.delete_facebook_data!
        
        Rails.logger.info "FacebookWebhookService: Successfully deleted Facebook data for user #{user.id}"
      else
        Rails.logger.info "FacebookWebhookService: No user found for Facebook ID #{facebook_user_id}, logging deletion request"
      end

      # Log successful processing regardless of whether user was found
      WebhookAuditLog.log_deletion(
        facebook_user_id: facebook_user_id,
        user: user,
        payload: @payload,
        status: 'processed'
      )

      { success: true, facebook_user_id: facebook_user_id, user_found: !user.nil? }

    rescue StandardError => e
      error_msg = "Failed to process deletion request: #{e.message}"
      Rails.logger.error "FacebookWebhookService: #{error_msg}"
      Rails.logger.error e.backtrace.join("\n")
      
      WebhookAuditLog.log_deletion(
        facebook_user_id: facebook_user_id,
        user: user,
        payload: @payload,
        status: 'failed',
        error_message: error_msg
      )
      
      { success: false, error: error_msg }
    end
  end

  def process_deauthorization
    facebook_user_id = extract_facebook_user_id
    
    if facebook_user_id.blank?
      error_msg = "No Facebook user ID found in deauthorization payload"
      Rails.logger.error "FacebookWebhookService: #{error_msg}"
      
      WebhookAuditLog.log_deauthorization(
        facebook_user_id: 'unknown',
        payload: @payload,
        status: 'failed',
        error_message: error_msg
      )
      
      return { success: false, error: error_msg }
    end

    # Find user by Facebook UID
    user = User.find_by(provider: 'facebook', uid: facebook_user_id)
    
    begin
      if user
        Rails.logger.info "FacebookWebhookService: Processing deauthorization for user #{user.id} (FB: #{facebook_user_id})"
        
        # Revoke Facebook authorization while keeping user account
        user.deauthorize_facebook!
        
        Rails.logger.info "FacebookWebhookService: Successfully deauthorized Facebook for user #{user.id}"
      else
        Rails.logger.info "FacebookWebhookService: No user found for Facebook ID #{facebook_user_id}, logging deauthorization"
      end

      # Log successful processing regardless of whether user was found
      WebhookAuditLog.log_deauthorization(
        facebook_user_id: facebook_user_id,
        user: user,
        payload: @payload,
        status: 'processed'
      )

      { success: true, facebook_user_id: facebook_user_id, user_found: !user.nil? }

    rescue StandardError => e
      error_msg = "Failed to process deauthorization: #{e.message}"
      Rails.logger.error "FacebookWebhookService: #{error_msg}"
      Rails.logger.error e.backtrace.join("\n")
      
      WebhookAuditLog.log_deauthorization(
        facebook_user_id: facebook_user_id,
        user: user,
        payload: @payload,
        status: 'failed',
        error_message: error_msg
      )
      
      { success: false, error: error_msg }
    end
  end

  private

  def extract_facebook_user_id
    # Facebook sends different payload structures for different webhook types
    # For data deletion: { "user_id" => "facebook_user_id" }
    # For deauthorization: { "user_id" => "facebook_user_id" } or similar
    
    @payload['user_id'] || @payload['id'] || @payload.dig('user', 'id')
  end
end