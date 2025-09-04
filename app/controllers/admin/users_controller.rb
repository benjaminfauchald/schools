module Admin
  class UsersController < Admin::ApplicationController

    def index
      search_term = params[:search]
      
      @users = User.all
      
      # Apply search filter
      if search_term.present?
        @users = @users.where(
          "email ILIKE ? OR role ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply role filter
      if params[:role].present?
        @users = @users.where(role: params[:role])
      end
      
      @users = @users.order(:email).limit(50)
      @total_users = User.count
      @admin_users = User.where(role: 'admin').count
      @school_owner_users = User.where(role: 'school_owner').count
    end

    def show
      @user = User.find(params[:id])
      @school_claims = @user.school_claims.includes(:school).order(created_at: :desc)
      @recent_activity = @user.audit_logs.order(created_at: :desc).limit(10) if @user.respond_to?(:audit_logs)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      
      if @user.save
        redirect_to admin_user_path(@user), notice: 'User was successfully created.'
      else
        render :new
      end
    end

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      @user = User.find(params[:id])
      
      if @user.school_claims.any?
        redirect_to admin_users_path, alert: 'Cannot delete user with existing school claims.'
      else
        @user.destroy
        redirect_to admin_users_path, notice: 'User was successfully deleted.'
      end
    end

    private

    def user_params
      params.require(:user).permit(:email, :role, :confirmed_at)
    end
  end
end
