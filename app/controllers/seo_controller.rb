class SeoController < ApplicationController
  def sitemap
    @schools = School.includes(:place).limit(1000)
    @pages = Page.published.includes(:school).limit(1000)
    
    respond_to do |format|
      format.xml { render layout: false }
    end
  end

  def robots
    respond_to do |format|
      format.text { render layout: false }
    end
  end
end