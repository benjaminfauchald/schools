# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    layout "admin"
    before_action :authenticate_admin
    before_action :ensure_admin_access

    private

    def authenticate_admin
      redirect_to new_admin_user_session_path unless admin_user_signed_in?
    end

    def ensure_admin_access
      unless admin_user_signed_in?
        flash[:alert] = "You don't have permission to access the admin area."
        redirect_to new_admin_user_session_path
      end
    end

    # Helper method for accessing current admin user in views and controllers
    # This is provided by Devise automatically as current_admin_user
    # No need to override it

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end
  end
end
