# frozen_string_literal: true

class Schools::FacilitiesGridComponentPreview < ViewComponent::Preview
  # Default state with mixed facilities from different categories
  def default
    facilities = [
      create_facility('library', 'Library'),
      create_facility('science_lab', 'Science Lab'),
      create_facility('gymnasium', 'Gymnasium'),
      create_facility('swimming_pool', 'Swimming Pool'),
      create_facility('cafeteria', 'Cafeteria'),
      create_facility('computer_lab', 'Computer Lab'),
      create_facility('art_studio', 'Art Studio'),
      create_facility('parking_lot', 'Parking Lot'),
      create_facility('custom_facility', 'Custom Learning Space')
    ]

    render Schools::FacilitiesGridComponent.new(facilities: facilities)
  end

  # Empty state - no facilities
  def empty_state
    render Schools::FacilitiesGridComponent.new(facilities: [])
  end

  # Academic-heavy school
  def academic_focused
    facilities = [
      create_facility('library', 'Main Library'),
      create_facility('science_lab', 'Science Laboratory'),
      create_facility('chemistry_lab', 'Chemistry Lab'),
      create_facility('physics_lab', 'Physics Lab'),
      create_facility('biology_lab', 'Biology Lab'),
      create_facility('computer_lab', 'Computer Lab'),
      create_facility('language_lab', 'Language Lab'),
      create_facility('media_center', 'Media Center'),
      create_facility('study_hall', 'Study Hall')
    ]

    render Schools::FacilitiesGridComponent.new(facilities: facilities)
  end

  # Sports-focused school
  def sports_focused
    facilities = [
      create_facility('gymnasium', 'Main Gymnasium'),
      create_facility('swimming_pool', '50m Swimming Pool'),
      create_facility('tennis_court', 'Tennis Courts'),
      create_facility('football_field', 'Football Field'),
      create_facility('basketball_court', 'Basketball Court'),
      create_facility('track_field', 'Athletics Track'),
      create_facility('fitness_center', 'Fitness Center'),
      create_facility('dance_studio', 'Dance Studio'),
      create_facility('climbing_wall', 'Climbing Wall'),
      create_facility('sports_complex', 'Sports Complex')
    ]

    render Schools::FacilitiesGridComponent.new(facilities: facilities)
  end

  # All categories populated
  def comprehensive
    facilities = [
      # Academic
      create_facility('library', 'Main Library'),
      create_facility('science_lab', 'Science Lab'),
      create_facility('computer_lab', 'Computer Lab'),

      # Sports
      create_facility('gymnasium', 'Gymnasium'),
      create_facility('swimming_pool', 'Swimming Pool'),
      create_facility('tennis_court', 'Tennis Court'),

      # Dining
      create_facility('cafeteria', 'Main Cafeteria'),
      create_facility('coffee_shop', 'Coffee Shop'),

      # Health
      create_facility('medical_clinic', 'Medical Clinic'),
      create_facility('counseling_center', 'Counseling Center'),

      # Technology
      create_facility('innovation_lab', 'Innovation Lab'),
      create_facility('robotics_lab', 'Robotics Lab'),

      # Arts
      create_facility('art_studio', 'Art Studio'),
      create_facility('music_room', 'Music Room'),
      create_facility('theater', 'Theater'),

      # Services
      create_facility('parking_lot', 'Parking Lot'),
      create_facility('bus_service', 'Bus Service'),

      # Other/Custom
      create_facility('maker_space_custom', 'Custom Maker Space'),
      create_facility('meditation_garden', 'Meditation Garden')
    ]

    render Schools::FacilitiesGridComponent.new(facilities: facilities)
  end

  # Large dataset - stress test
  def large_dataset
    facilities = []

    # Academic facilities
    %w[library science_lab computer_lab art_room music_room chemistry_lab physics_lab biology_lab].each do |slug|
      facilities << create_facility(slug, slug.humanize)
    end

    # Sports facilities
    %w[gymnasium swimming_pool tennis_court basketball_court football_field soccer_field track_field volleyball_court].each do |slug|
      facilities << create_facility(slug, slug.humanize)
    end

    # Dining facilities
    %w[cafeteria dining_hall kitchen snack_bar coffee_shop].each do |slug|
      facilities << create_facility(slug, slug.humanize)
    end

    # Health facilities
    %w[medical_clinic nurse_office counseling_center wellness_center].each do |slug|
      facilities << create_facility(slug, slug.humanize)
    end

    # Tech facilities
    %w[computer_lab technology_center innovation_lab robotics_lab].each do |slug|
      facilities << create_facility(slug, "#{slug.humanize} Advanced")
    end

    # Arts facilities
    %w[art_studio music_room theater dance_studio].each do |slug|
      facilities << create_facility(slug, slug.humanize)
    end

    # Service facilities
    %w[parking_lot bus_service security_office reception_desk].each do |slug|
      facilities << create_facility(slug, slug.humanize)
    end

    # Add some uncategorized facilities
    10.times do |i|
      facilities << create_facility("custom_facility_#{i}", "Custom Space #{i + 1}")
    end

    render Schools::FacilitiesGridComponent.new(facilities: facilities)
  end

  # Tech-heavy modern school
  def tech_innovation
    facilities = [
      create_facility('computer_lab', 'Computer Lab'),
      create_facility('technology_center', 'Technology Center'),
      create_facility('innovation_lab', 'Innovation Lab'),
      create_facility('makerspace', 'Makerspace'),
      create_facility('3d_printing', '3D Printing Lab'),
      create_facility('robotics_center', 'Robotics Center'),
      create_facility('coding_lab', 'Coding Lab'),
      create_facility('digital_media_lab', 'Digital Media Lab'),
      create_facility('virtual_reality_lab', 'VR Lab'),
      create_facility('recording_studio', 'Recording Studio'),
      create_facility('video_production_studio', 'Video Production')
    ]

    render Schools::FacilitiesGridComponent.new(facilities: facilities)
  end

  private

  # Helper method to create facility mock objects
  def create_facility(slug, name)
    # Create a simple struct to mimic the Term model
    Struct.new(:slug, :name).new(slug, name)
  end
end
