# frozen_string_literal: true

class Schools::InteractiveMapComponent < ViewComponent::Base
  def initialize(school_data:, contact_info:, location_data:)
    @school_data = school_data
    @contact_info = contact_info
    @location_data = location_data
  end

  private

  attr_reader :school_data, :contact_info, :location_data

  def render?
    school_coordinates.present?
  end

  def school_coordinates
    @school_coordinates ||= contact_info[:coordinates]
  end

  def school_name
    school_data[:name]
  end

  def school_address
    contact_info[:address]
  end

  def map_id
    "school-map-#{object_id}"
  end

  def directions_panel_id
    "directions-panel-#{object_id}"
  end

  def travel_info_id
    "travel-info-#{object_id}"
  end

  def default_center
    # Bangkok city center as fallback
    [ 13.7563, 100.5018 ]
  end

  def school_lat
    school_coordinates&.first || default_center[0]
  end

  def school_lng
    school_coordinates&.last || default_center[1]
  end
end
