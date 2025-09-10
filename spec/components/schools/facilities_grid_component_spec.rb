# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Schools::FacilitiesGridComponent, type: :component do
  let(:academic_facility) { double('Term', slug: 'library', name: 'Library', label: 'Library') }
  let(:sports_facility) { double('Term', slug: 'gymnasium', name: 'Gymnasium', label: 'Gymnasium') }
  let(:tech_facility) { double('Term', slug: 'computer_lab', name: 'Computer Lab', label: 'Computer Lab') }
  let(:uncategorized_facility) { double('Term', slug: 'custom_facility', name: 'Custom Facility', label: 'Custom Facility') }

  describe '#initialize' do
    it 'accepts facilities parameter' do
      component = described_class.new(facilities: [ academic_facility ])
      expect(component.instance_variable_get(:@facilities)).to eq([ academic_facility ])
    end
  end

  describe 'render behavior' do
    it 'does not render when no facilities are provided' do
      component = described_class.new(facilities: [])
      rendered = render_inline(component)
      expect(rendered.to_html.strip).to be_empty
    end

    it 'renders when facilities are provided' do
      component = described_class.new(facilities: [ academic_facility ])
      rendered = render_inline(component)
      expect(rendered.to_html.strip).not_to be_empty
    end

    it 'renders when facilities exist but none match any category' do
      empty_facility = double('Term', slug: 'unknown_facility', name: 'Unknown', label: 'Unknown')
      component = described_class.new(facilities: [ empty_facility ])
      rendered = render_inline(component)
      expect(rendered.to_html.strip).not_to be_empty # "Other Facilities" category should still show
    end
  end

  describe '#total_facilities_count' do
    it 'returns correct count for multiple facilities' do
      facilities = [ academic_facility, sports_facility, tech_facility ]
      component = described_class.new(facilities: facilities)
      expect(component.send(:total_facilities_count)).to eq(3)
    end

    it 'returns zero for empty facilities' do
      component = described_class.new(facilities: [])
      expect(component.send(:total_facilities_count)).to eq(0)
    end
  end

  describe '#facility_groups' do
    let(:facilities) { [ academic_facility, sports_facility, tech_facility, uncategorized_facility ] }
    let(:component) { described_class.new(facilities: facilities) }

    it 'categorizes facilities correctly' do
      groups = component.send(:facility_groups)

      expect(groups['Academic Facilities'][:items]).to include(academic_facility)
      expect(groups['Sports & Recreation'][:items]).to include(sports_facility)
      expect(groups['Technology & Innovation'][:items]).to include(tech_facility)
      expect(groups['Other Facilities'][:items]).to include(uncategorized_facility)
    end

    it 'includes correct metadata for each group' do
      groups = component.send(:facility_groups)

      academic_group = groups['Academic Facilities']
      expect(academic_group[:icon]).to eq('academic-cap')
      expect(academic_group[:color]).to eq('blue')

      sports_group = groups['Sports & Recreation']
      expect(sports_group[:icon]).to eq('trophy')
      expect(sports_group[:color]).to eq('green')
    end

    it 'only includes groups that have facilities' do
      single_facility = [ academic_facility ]
      component = described_class.new(facilities: single_facility)
      groups = component.send(:facility_groups)

      expect(groups.keys).to include('Academic Facilities')
      expect(groups.keys).not_to include('Sports & Recreation')
    end

    it 'includes all 8 possible categories' do
      # Test that all categories are defined (even if empty)
      all_facilities = [
        double('Term', slug: 'library', name: 'Library', label: 'Library'),                    # Academic
        double('Term', slug: 'gymnasium', name: 'Gymnasium', label: 'Gymnasium'),                # Sports
        double('Term', slug: 'cafeteria', name: 'Cafeteria', label: 'Cafeteria'),               # Dining
        double('Term', slug: 'medical_clinic', name: 'Medical Clinic', label: 'Medical Clinic'),      # Health
        double('Term', slug: 'computer_lab', name: 'Computer Lab', label: 'Computer Lab'),          # Tech
        double('Term', slug: 'art_studio', name: 'Art Studio', label: 'Art Studio'),             # Arts
        double('Term', slug: 'parking_lot', name: 'Parking Lot', label: 'Parking Lot'),           # Services
        double('Term', slug: 'custom_room', name: 'Custom Room', label: 'Custom Room')            # Other
      ]

      component = described_class.new(facilities: all_facilities)
      groups = component.send(:facility_groups)

      expected_categories = [
        'Academic Facilities',
        'Sports & Recreation',
        'Dining & Nutrition',
        'Health & Wellness',
        'Technology & Innovation',
        'Arts & Culture',
        'Campus Services',
        'Other Facilities'
      ]

      expect(groups.keys).to match_array(expected_categories)
    end
  end

  describe 'categorization methods' do
    let(:component) { described_class.new(facilities: []) }

    it 'defines academic facilities' do
      academic = component.send(:academic_facilities)
      expect(academic).to include('library', 'science_lab', 'computer_lab')
      expect(academic).to be_an(Array)
    end

    it 'defines sports facilities' do
      sports = component.send(:sports_facilities)
      expect(sports).to include('gymnasium', 'swimming_pool', 'tennis_court')
      expect(sports).to be_an(Array)
    end

    it 'defines dining facilities' do
      dining = component.send(:dining_facilities)
      expect(dining).to include('cafeteria', 'dining_hall', 'kitchen')
      expect(dining).to be_an(Array)
    end

    it 'defines health facilities' do
      health = component.send(:health_facilities)
      expect(health).to include('medical_clinic', 'nurse_office', 'counseling_center')
      expect(health).to be_an(Array)
    end

    it 'defines tech facilities' do
      tech = component.send(:tech_facilities)
      expect(tech).to include('computer_lab', 'technology_center', 'innovation_lab')
      expect(tech).to be_an(Array)
    end

    it 'defines arts facilities' do
      arts = component.send(:arts_facilities)
      expect(arts).to include('art_studio', 'music_room', 'theater')
      expect(arts).to be_an(Array)
    end

    it 'defines service facilities' do
      services = component.send(:service_facilities)
      expect(services).to include('parking_lot', 'bus_service', 'transportation')
      expect(services).to be_an(Array)
    end
  end

  describe 'rendering' do
    it 'renders the component with facilities' do
      facilities = [ academic_facility, sports_facility ]
      rendered = render_inline(described_class.new(facilities: facilities))

      expect(rendered).to have_css('.bg-white')
      expect(rendered).to have_content('Campus Facilities')
      expect(rendered).to have_content('Academic Facilities')
    end

    it 'renders facility counts correctly' do
      facilities = [ academic_facility, sports_facility, tech_facility ]
      rendered = render_inline(described_class.new(facilities: facilities))

      expect(rendered).to have_content('Total Facilities')
      expect(rendered).to have_content('3') # total count
    end

    it 'renders TagBadgeComponent for each facility' do
      rendered = render_inline(described_class.new(facilities: [ academic_facility ]))

      # Should render the TagBadgeComponent (we can't easily test the component itself in unit tests)
      expect(rendered).to have_css('.flex-wrap') # container for badges
    end

    it 'does not render when no facilities match categories' do
      component = described_class.new(facilities: [])
      rendered = render_inline(component)
      expect(rendered.to_html.strip).to be_empty
    end
  end

  describe '#section_icon_svg' do
    let(:component) { described_class.new(facilities: []) }

    it 'calls heroicon helper with correct parameters' do
      mock_helpers = double('helpers')
      allow(component).to receive(:helpers).and_return(mock_helpers)

      expect(mock_helpers).to receive(:heroicon)
        .with('academic-cap', css_class: "w-5 h-5 text-gray-500 dark:text-gray-400")

      component.send(:section_icon_svg, 'academic-cap')
    end
  end

  describe 'categorized_facilities method' do
    let(:component) { described_class.new(facilities: []) }

    it 'combines all category arrays' do
      categorized = component.send(:categorized_facilities)
      expect(categorized).to be_an(Array)
      expect(categorized).to include('library', 'gymnasium', 'cafeteria', 'computer_lab')
    end
  end
end
