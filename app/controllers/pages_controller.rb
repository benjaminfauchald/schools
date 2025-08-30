# Public controller for displaying school pages
class PagesController < ApplicationController
  before_action :set_school
  before_action :set_page, only: [:show]
  
  # GET /schools/:school_id/pages
  def index
    @pages = @school.pages.published.includes(:school)
    @grouped_pages = group_pages_by_type(@pages)
    
    # Check if current user can edit this school (for navigation)
    @can_edit_school = current_user&.can_edit_school?(@school)
    
    # SEO meta tags
    @page_title = "#{@school.name} - Pages & Information"
    @meta_description = "Browse all pages and information about #{@school.name}, including about us, blog posts, academics, sports, and activities."
  end
  
  
  # GET /schools/:school_id/pages/:id
  def show
    # SEO meta tags
    @page_title = "#{@page.title} - #{@school.name}"
    @meta_description = @page.generate_meta_description
    
    # Check if current user can edit this school (for navigation)
    @can_edit_school = current_user&.can_edit_school?(@school)
    
    # Track page views (could be enhanced with analytics)
    Rails.logger.info "Page view: School #{@school.id}, Page #{@page.id} (#{@page.title})"
  end
  
  private
  
  def set_school
    # Handle both slug and numeric ID formats
    if params[:school_id].match?(/\A\d+\z/)
      @school = School.published.find(params[:school_id])
    else
      @school = School.published.find_by!(slug: params[:school_id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'School not found'
  end
  
  def set_page
    @page = @school.pages.published.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to school_pages_path(@school), alert: 'Page not found'
  end
  
  def group_pages_by_type(pages)
    {
      'About Us' => pages.about_us.sorted,
      'Blog Posts' => pages.blog.recent.limit(10),
      'Academics' => pages.academics.sorted,
      'Sports' => pages.sports.sorted,
      'Activities' => pages.activities.sorted,
      'Other' => pages.by_type('custom').sorted
    }.select { |_, pages_list| pages_list.any? }
  end
end