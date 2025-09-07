class SettingsController < ApplicationController
  def index
    # Settings page where users can view and manage their home location
  end

  def update_location
    # This endpoint could be used for server-side location validation if needed
    # For now, all location management is handled client-side

    respond_to do |format|
      format.json do
        render json: {
          status: "success",
          message: "Location updated successfully"
        }
      end
      format.html do
        redirect_to settings_path, notice: "Location updated successfully"
      end
    end
  end
end
