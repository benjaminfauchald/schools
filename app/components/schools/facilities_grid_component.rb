# frozen_string_literal: true

class Schools::FacilitiesGridComponent < ViewComponent::Base
  def initialize(facilities:)
    @facilities = facilities
  end

  private

  attr_reader :facilities

  def render?
    facility_groups.any? { |_, items| items.any? }
  end

  def facility_groups
    @facility_groups ||= {
      "Academic Facilities" => {
        items: facilities.select { |f| academic_facilities.include?(f.slug) },
        icon: "academic-cap",
        color: "blue"
      },
      "Sports & Recreation" => {
        items: facilities.select { |f| sports_facilities.include?(f.slug) },
        icon: "trophy",
        color: "green"
      },
      "Dining & Nutrition" => {
        items: facilities.select { |f| dining_facilities.include?(f.slug) },
        icon: "cake",
        color: "orange"
      },
      "Health & Wellness" => {
        items: facilities.select { |f| health_facilities.include?(f.slug) },
        icon: "heart",
        color: "red"
      },
      "Technology & Innovation" => {
        items: facilities.select { |f| tech_facilities.include?(f.slug) },
        icon: "computer-desktop",
        color: "purple"
      },
      "Arts & Culture" => {
        items: facilities.select { |f| arts_facilities.include?(f.slug) },
        icon: "musical-note",
        color: "pink"
      },
      "Campus Services" => {
        items: facilities.select { |f| service_facilities.include?(f.slug) },
        icon: "building-office",
        color: "gray"
      },
      "Other Facilities" => {
        items: facilities.reject { |f| categorized_facilities.include?(f.slug) },
        icon: "squares-plus",
        color: "indigo"
      }
    }.select { |_, group| group[:items].any? }
  end

  def total_facilities_count
    facilities.count
  end

  def section_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-5 h-5 text-gray-500 dark:text-gray-400")
  end

  private

  def academic_facilities
    %w[
      library science_lab computer_lab art_room music_room drama_studio
      language_lab chemistry_lab physics_lab biology_lab maker_space
      media_center robotics_lab engineering_lab design_studio
      lecture_hall seminar_room study_hall tutoring_center
    ]
  end

  def sports_facilities
    %w[
      gymnasium swimming_pool tennis_court basketball_court football_field
      soccer_field track_field volleyball_court badminton_court
      fitness_center dance_studio martial_arts_room climbing_wall
      outdoor_playground sports_complex athletics_track
    ]
  end

  def dining_facilities
    %w[
      cafeteria dining_hall kitchen snack_bar coffee_shop
      outdoor_dining_area breakfast_program lunch_program
      healthy_meals organic_food vegetarian_options
    ]
  end

  def health_facilities
    %w[
      medical_clinic nurse_office counseling_center therapy_room
      wellness_center meditation_room quiet_space sensory_room
      first_aid_station health_screening psychology_services
    ]
  end

  def tech_facilities
    %w[
      computer_lab technology_center innovation_lab makerspace
      3d_printing video_production_studio recording_studio
      green_screen robotics_center coding_lab digital_media_lab
      virtual_reality_lab augmented_reality
    ]
  end

  def arts_facilities
    %w[
      art_studio music_room theater drama_studio dance_studio
      exhibition_space gallery performance_hall concert_hall
      pottery_studio sculpture_studio photography_lab
      creative_arts_center cultural_center
    ]
  end

  def service_facilities
    %w[
      parking_lot bus_service transportation security_office
      reception_desk administrative_office uniform_shop
      boarding_facilities dormitory residential_hall
      chapel prayer_room spiritual_center community_center
    ]
  end

  def categorized_facilities
    academic_facilities + sports_facilities + dining_facilities +
      health_facilities + tech_facilities + arts_facilities + service_facilities
  end
end
