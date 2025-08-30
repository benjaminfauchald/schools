class Users::ConfirmationsController < Devise::ConfirmationsController
  # Override show action to handle confirmation with auto sign in
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    yield resource if block_given?

    if resource.errors.empty?
      # Automatically sign in the user after confirmation (magic link functionality)
      sign_in(resource)
      set_flash_message!(:notice, :confirmed)
      respond_with_navigational(resource) do
        redirect_to after_confirmation_path_for(resource_name, resource)
      end
    else
      respond_with_navigational(resource.errors, status: :unprocessable_entity) do
        render :new
      end
    end
  end

  protected

  # Override the after confirmation path to redirect to dashboard
  def after_confirmation_path_for(resource_name, resource)
    if resource.school_owner?
      school_owner_dashboard_index_path
    else
      root_path
    end
  end

  private

  def set_flash_message!(key, kind, options = {})
    if kind == :confirmed && resource.school_owner?
      flash[:notice] = "Your email has been confirmed! Welcome to your school management dashboard."
    else
      super
    end
  end
end