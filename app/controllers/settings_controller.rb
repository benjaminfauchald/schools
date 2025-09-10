class SettingsController < ApplicationController
  def index
    # Settings page where users can view and manage their home location
  end

  def update_location
    # Validate location parameters
    location = params[:location]

    # Check if location parameters exist
    if location.blank? || location[:lat].blank? || location[:lng].blank?
      respond_to do |format|
        format.json do
          render json: {
            status: "error",
            errors: [ "Location parameters are required" ]
          }, status: :unprocessable_entity
        end
        format.html do
          redirect_to settings_path, alert: "Location parameters are required"
        end
      end
      return
    end

    # Convert to floats and validate
    begin
      lat = Float(location[:lat])
      lng = Float(location[:lng])
    rescue ArgumentError, TypeError
      respond_to do |format|
        format.json do
          render json: {
            status: "error",
            errors: [ "Invalid coordinate format" ]
          }, status: :unprocessable_entity
        end
        format.html do
          redirect_to settings_path, alert: "Invalid coordinate format"
        end
      end
      return
    end

    # Validate coordinate ranges
    if lat < -90 || lat > 90
      respond_to do |format|
        format.json do
          render json: {
            status: "error",
            errors: [ "Latitude must be between -90 and 90 degrees" ]
          }, status: :unprocessable_entity
        end
        format.html do
          redirect_to settings_path, alert: "Invalid latitude value"
        end
      end
      return
    end

    if lng < -180 || lng > 180
      respond_to do |format|
        format.json do
          render json: {
            status: "error",
            errors: [ "Longitude must be between -180 and 180 degrees" ]
          }, status: :unprocessable_entity
        end
        format.html do
          redirect_to settings_path, alert: "Invalid longitude value"
        end
      end
      return
    end

    # Valid coordinates - proceed with update
    respond_to do |format|
      format.json do
        render json: {
          status: "success",
          message: "Location updated successfully",
          location: { lat: lat, lng: lng }
        }
      end
      format.html do
        redirect_to settings_path, notice: "Location updated successfully"
      end
    end
  end
end
