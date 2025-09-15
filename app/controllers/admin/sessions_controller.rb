class Admin::SessionsController < Devise::SessionsController
  layout "admin"
  skip_before_action :verify_authenticity_token, only: [:destroy]
  
  # Override to check admin role
  def create
    self.resource = warden.authenticate!(auth_options)
    if resource.admin?
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      sign_out(resource)
      flash[:alert] = "You don't have permission to access the admin area."
      redirect_to new_admin_session_path
    end
  end
  
  # Handle sign out
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    redirect_to after_sign_out_path_for(resource_name)
  end
  
  # Override the after_sign_in_path to redirect to admin dashboard
  def after_sign_in_path_for(resource)
    admin_root_path
  end

  # Override the after_sign_out_path to redirect to admin login
  def after_sign_out_path_for(resource_or_scope)
    admin_new_session_path
  end

  protected

  # Permit additional parameters if needed
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:email])
  end
end