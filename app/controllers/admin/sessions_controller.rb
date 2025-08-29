class Admin::SessionsController < Devise::SessionsController
  # Override the after_sign_in_path to redirect to admin dashboard
  def after_sign_in_path_for(resource)
    admin_root_path
  end

  # Override the after_sign_out_path to redirect to admin login
  def after_sign_out_path_for(resource_or_scope)
    new_admin_user_session_path
  end

  protected

  # Permit additional parameters if needed
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:email])
  end
end