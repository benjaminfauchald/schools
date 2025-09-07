class SchoolOwner::ApplicationController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_school_owner!

  layout "school_owner"

  private

  def ensure_school_owner!
    unless current_user&.school_owner?
      redirect_to root_path, alert: "Access denied. School owners only."
    end
  end

  def current_school
    @current_school ||= current_user.owned_schools.find(params[:school_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to school_owner_dashboard_index_path, alert: "School not found or access denied."
  end
end
