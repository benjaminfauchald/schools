# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    layout "admin"
    before_action :authenticate_user!
    before_action :ensure_admin_access

    private

    def ensure_admin_access
      unless current_user&.admin?
        flash[:alert] = "You don't have permission to access the admin area."
        redirect_to new_user_session_path
      end
    end

    # Helper method for accessing current admin user in views and controllers
    # Alias current_admin_user to current_user for compatibility
    def current_admin_user
      current_user if current_user&.admin?
    end
    helper_method :current_admin_user

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end
  end
end
