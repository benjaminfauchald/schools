class SchoolInquiriesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_facebook_authentication!
  before_action :check_rate_limit!, only: [ :create ]
  before_action :set_school

  def create
    @inquiry = @school.school_inquiries.build(inquiry_params)
    @inquiry.ip_address = request.remote_ip
    @inquiry.user = current_user
    
    # Auto-fill missing fields from current user if authenticated
    if current_user
      @inquiry.name ||= current_user.facebook_name || current_user.email.split('@').first.humanize
      @inquiry.email ||= current_user.email
      @inquiry.phone ||= current_user.phone if current_user.respond_to?(:phone)
      
      # Update user's email if it was changed in the form
      if @inquiry.email.present? && @inquiry.email != current_user.email
        Rails.logger.info "Updating user email from #{current_user.email} to #{@inquiry.email}"
        current_user.update(email: @inquiry.email)
      end
      
      # Update user's phone if provided and user has phone field
      if @inquiry.phone.present? && current_user.respond_to?(:phone=)
        current_user.update(phone: @inquiry.phone)
      end
    end

    if @inquiry.save
      # Send email notifications
      begin
        SchoolInquiryMailer.new_inquiry_notification(@inquiry).deliver_now
      rescue => e
        Rails.logger.error "Failed to send inquiry email: #{e.message}"
      end

      render json: {
        success: true,
        message: "Your inquiry has been sent successfully. The school will contact you soon!"
      }
    else
      Rails.logger.error "School inquiry validation failed: #{@inquiry.errors.full_messages}"
      render json: {
        success: false,
        errors: @inquiry.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "School inquiry creation error: #{e.message}"
    render json: {
      success: false,
      errors: [ "An unexpected error occurred. Please try again." ]
    }, status: :internal_server_error
  end

  private

  def set_school
    @school = School.find(params[:school_id])
  end

  def inquiry_params
    params.require(:school_inquiry).permit(:name, :email, :phone, :message, :children_count)
  end

  def require_facebook_authentication!
    unless current_user&.provider == "facebook"
      render json: {
        success: false,
        errors: [ "You must sign in with Facebook to contact schools." ],
        requires_facebook_auth: true
      }, status: :forbidden
    end
  end

  def check_rate_limit!
    # Implement multi-tier rate limiting for security
    # Per-user limits: 5/minute, 20/hour, 50/day
    # Per-IP limits: 10/minute, 50/hour
    # Per-school limits: 100/hour from all users

    user_id = current_user.id
    client_ip = request.remote_ip
    school_id = params[:school_id]
    current_time = Time.current

    # Check rate limits BEFORE incrementing
    if user_rate_limit_exceeded?(user_id, current_time)
      render json: {
        success: false,
        error: "Rate limit exceeded. You can send up to 5 inquiries per minute. Please wait before trying again.",
        retry_after: 60
      }, status: :too_many_requests
      response.headers["Retry-After"] = "60"
      return
    end

    # Check per-IP rate limits (prevents multiple account abuse)
    if ip_rate_limit_exceeded?(client_ip, current_time)
      render json: {
        success: false,
        error: "Too many requests from your network. Please wait before trying again.",
        retry_after: 60
      }, status: :too_many_requests
      response.headers["Retry-After"] = "60"
      return
    end

    # Check per-school rate limits (protects individual schools)
    if school_rate_limit_exceeded?(school_id, current_time)
      render json: {
        success: false,
        error: "This school is receiving too many inquiries. Please try again later.",
        retry_after: 300
      }, status: :too_many_requests
      response.headers["Retry-After"] = "300"
      return
    end

    # Increment counters AFTER all checks pass (request will proceed)
    increment_rate_limit_counters(user_id, client_ip, school_id, current_time)
  end

  def user_rate_limit_exceeded?(user_id, current_time)
    # Check minute limit (5 per minute)
    minute_key = "inquiry_rate_limit:user:#{user_id}:minute:#{current_time.to_i / 60}"
    minute_count = Rails.cache.read(minute_key).to_i
    return true if minute_count >= 5

    # Check hour limit (20 per hour)
    hour_key = "inquiry_rate_limit:user:#{user_id}:hour:#{current_time.to_i / 3600}"
    hour_count = Rails.cache.read(hour_key).to_i
    return true if hour_count >= 20

    # Check day limit (50 per day)
    day_key = "inquiry_rate_limit:user:#{user_id}:day:#{current_time.to_date}"
    day_count = Rails.cache.read(day_key).to_i
    return true if day_count >= 50

    false
  end

  def ip_rate_limit_exceeded?(client_ip, current_time)
    # Check minute limit (10 per minute)
    minute_key = "inquiry_rate_limit:ip:#{client_ip}:minute:#{current_time.to_i / 60}"
    minute_count = Rails.cache.read(minute_key).to_i
    return true if minute_count >= 10

    # Check hour limit (50 per hour)
    hour_key = "inquiry_rate_limit:ip:#{client_ip}:hour:#{current_time.to_i / 3600}"
    hour_count = Rails.cache.read(hour_key).to_i
    return true if hour_count >= 50

    false
  end

  def school_rate_limit_exceeded?(school_id, current_time)
    # Check hour limit (100 per hour for a single school from all users)
    hour_key = "inquiry_rate_limit:school:#{school_id}:hour:#{current_time.to_i / 3600}"
    hour_count = Rails.cache.read(hour_key).to_i
    return true if hour_count >= 100

    false
  end

  def increment_rate_limit_counters(user_id, client_ip, school_id, current_time)
    # Increment user counters
    minute_key = "inquiry_rate_limit:user:#{user_id}:minute:#{current_time.to_i / 60}"
    hour_key = "inquiry_rate_limit:user:#{user_id}:hour:#{current_time.to_i / 3600}"
    day_key = "inquiry_rate_limit:user:#{user_id}:day:#{current_time.to_date}"

    # Use fetch to initialize to 0 if not exists, then increment
    Rails.cache.write(minute_key, (Rails.cache.read(minute_key).to_i + 1), expires_in: 1.minute)
    Rails.cache.write(hour_key, (Rails.cache.read(hour_key).to_i + 1), expires_in: 1.hour)
    Rails.cache.write(day_key, (Rails.cache.read(day_key).to_i + 1), expires_in: 1.day)

    # Increment IP counters
    ip_minute_key = "inquiry_rate_limit:ip:#{client_ip}:minute:#{current_time.to_i / 60}"
    ip_hour_key = "inquiry_rate_limit:ip:#{client_ip}:hour:#{current_time.to_i / 3600}"

    Rails.cache.write(ip_minute_key, (Rails.cache.read(ip_minute_key).to_i + 1), expires_in: 1.minute)
    Rails.cache.write(ip_hour_key, (Rails.cache.read(ip_hour_key).to_i + 1), expires_in: 1.hour)

    # Increment school counter
    school_hour_key = "inquiry_rate_limit:school:#{school_id}:hour:#{current_time.to_i / 3600}"
    Rails.cache.write(school_hour_key, (Rails.cache.read(school_hour_key).to_i + 1), expires_in: 1.hour)
  end
end
