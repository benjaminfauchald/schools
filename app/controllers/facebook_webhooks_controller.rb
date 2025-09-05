class FacebookWebhooksController < ApplicationController
  protect_from_forgery with: :null_session # Disable CSRF for webhook endpoints
  before_action :validate_webhook_signature, except: [:verify]
  
  # GET /facebook_webhooks/verify - Facebook webhook verification
  def verify
    Rails.logger.info "FacebookWebhooksController: Webhook verification request received"
    
    # Facebook sends challenge parameter for webhook verification
    challenge = params['hub.challenge']
    verify_token = params['hub.verify_token']
    mode = params['hub.mode']
    
    expected_verify_token = ENV['FACEBOOK_WEBHOOK_VERIFY_TOKEN'] || 'default_verify_token'
    
    if mode == 'subscribe' && verify_token == expected_verify_token
      Rails.logger.info "FacebookWebhooksController: Webhook verification successful"
      render plain: challenge, status: :ok
    else
      Rails.logger.warn "FacebookWebhooksController: Webhook verification failed - mode: #{mode}, token match: #{verify_token == expected_verify_token}"
      render plain: 'Verification failed', status: :forbidden
    end
  end

  # POST /facebook_webhooks/delete_data - Handle data deletion requests
  def delete_data
    Rails.logger.info "FacebookWebhooksController: Data deletion request received"
    
    begin
      result = FacebookWebhookService.new(request.raw_post).process_deletion_request
      
      if result[:success]
        Rails.logger.info "FacebookWebhooksController: Data deletion completed successfully for Facebook ID: #{result[:facebook_user_id]}"
        render json: { 
          url: "#{request.base_url}/facebook_webhooks/deletion_status/#{result[:facebook_user_id]}",
          confirmation_code: generate_confirmation_code(result[:facebook_user_id])
        }, status: :ok
      else
        Rails.logger.error "FacebookWebhooksController: Data deletion failed: #{result[:error]}"
        render json: { error: result[:error] }, status: :bad_request
      end
      
    rescue StandardError => e
      error_message = "Failed to process data deletion webhook: #{e.message}"
      Rails.logger.error "FacebookWebhooksController: #{error_message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end

  # POST /facebook_webhooks/deauthorize - Handle app deauthorization
  def deauthorize
    Rails.logger.info "FacebookWebhooksController: Deauthorization request received"
    
    begin
      result = FacebookWebhookService.new(request.raw_post).process_deauthorization
      
      if result[:success]
        Rails.logger.info "FacebookWebhooksController: Deauthorization completed successfully for Facebook ID: #{result[:facebook_user_id]}"
        render json: { success: true }, status: :ok
      else
        Rails.logger.error "FacebookWebhooksController: Deauthorization failed: #{result[:error]}"
        render json: { error: result[:error] }, status: :bad_request
      end
      
    rescue StandardError => e
      error_message = "Failed to process deauthorization webhook: #{e.message}"
      Rails.logger.error "FacebookWebhooksController: #{error_message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end

  # GET /facebook_webhooks/deletion_status/:facebook_user_id - Status endpoint for Facebook
  def deletion_status
    facebook_user_id = params[:facebook_user_id]
    confirmation_code = params[:confirmation_code]
    
    # Verify confirmation code
    expected_code = generate_confirmation_code(facebook_user_id)
    
    unless confirmation_code == expected_code
      render json: { error: "Invalid confirmation code" }, status: :forbidden
      return
    end

    # Find the most recent deletion audit log for this Facebook user
    deletion_log = WebhookAuditLog.deletions
                                  .where(facebook_user_id: facebook_user_id)
                                  .successful
                                  .recent
                                  .first

    if deletion_log
      render json: {
        status: "deleted",
        deleted_at: deletion_log.processed_at.iso8601,
        confirmation_code: confirmation_code
      }, status: :ok
    else
      render json: {
        status: "not_found",
        message: "No successful deletion record found for this user"
      }, status: :not_found
    end
  end

  private

  def validate_webhook_signature
    validator = FacebookSignatureValidator.new(request)
    
    unless validator.valid_signature?
      Rails.logger.warn "FacebookWebhooksController: Invalid webhook signature - #{validator.error_message}"
      
      # Log invalid webhook attempt
      WebhookAuditLog.create!(
        webhook_type: action_name == 'delete_data' ? 'deletion' : 'deauthorization',
        facebook_user_id: 'unknown',
        user: nil,
        payload: request.raw_post.present? ? (JSON.parse(request.raw_post) rescue {}) : {},
        status: 'invalid',
        error_message: "Invalid signature: #{validator.error_message}",
        processed_at: Time.current
      )
      
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  rescue StandardError => e
    Rails.logger.error "FacebookWebhooksController: Signature validation error: #{e.message}"
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  def generate_confirmation_code(facebook_user_id)
    # Generate a simple confirmation code based on Facebook user ID and app secret
    # This is not cryptographically secure but sufficient for Facebook's requirements
    secret_key = ENV['FACEBOOK_APP_SECRET'] || 'default_secret'
    Digest::SHA256.hexdigest("#{facebook_user_id}#{secret_key}")[0..15]
  end
end