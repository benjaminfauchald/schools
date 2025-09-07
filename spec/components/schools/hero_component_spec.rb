require 'rails_helper'

RSpec.describe Schools::HeroComponent, type: :component do
  let(:school) { create(:school) }
  let(:hero_data) do
    {
      name: 'Test International School',
      hero_image: double('hero_image', url: 'https://example.com/hero.jpg'),
      logo: double('logo', url: 'https://example.com/logo.jpg'),
      rating: {
        stars_display: '★★★★★',
        rating: 4.5,
        total_ratings: 120,
        source: 'Google'
      },
      key_stats: [
        { label: 'Students', value: '500+', icon: 'users' },
        { label: 'Founded', value: '1995', icon: 'calendar' }
      ]
    }
  end
  let(:contact_info) { {} }

  describe 'initialization' do
    it 'initializes with required parameters' do
      component = described_class.new(hero_data: hero_data, contact_info: contact_info, school: school)
      expect(component).to be_present
    end

    it 'works without school parameter' do
      component = described_class.new(hero_data: hero_data, contact_info: contact_info)
      expect(component).to be_present
    end
  end

  describe 'rendering' do
    subject(:rendered) do
      render_inline(described_class.new(hero_data: hero_data, contact_info: contact_info, school: school))
    end

    it 'displays school name' do
      expect(rendered.css('h1').text).to include('Test International School')
    end

    it 'displays hero image when available' do
      expect(rendered.css('img[src*="hero.jpg"]')).to be_present
    end

    it 'displays rating information' do
      expect(rendered.text).to include('★★★★★')
      expect(rendered.text).to include('4.5')
      expect(rendered.text).to include('120')
    end

    it 'displays key stats' do
      expect(rendered.text).to include('Students')
      expect(rendered.text).to include('500+')
      expect(rendered.text).to include('Founded')
      expect(rendered.text).to include('1995')
    end

    context 'when hero image is not available' do
      let(:hero_data) do
        {
          name: 'Test School',
          hero_image: nil,
          logo: double('logo', url: 'https://example.com/logo.jpg')
        }
      end

      it 'falls back to logo' do
        expect(rendered.css('img[src*="logo.jpg"]')).to be_present
      end
    end

    context 'when rating is not available' do
      let(:hero_data) { { name: 'Test School', rating: nil } }

      it 'does not display rating section' do
        expect(rendered.css('.rating')).to be_empty
      end
    end

    context 'when key stats are empty' do
      let(:hero_data) { { name: 'Test School', key_stats: [] } }

      it 'does not display stats section' do
        expect(rendered.css('.key-stats')).to be_empty
      end
    end
  end

  describe 'claim button functionality' do
    let(:user) { create(:user, :school_owner) }

    before do
      allow_any_instance_of(ActionView::Base).to receive(:user_signed_in?).and_return(true)
      allow_any_instance_of(ActionView::Base).to receive(:current_user).and_return(user)
    end

    context 'when school is unclaimed' do
      it 'shows claim button for school owner' do
        allow(user).to receive(:can_edit_school?).with(school).and_return(false)
        allow(user.school_claims).to receive(:where).and_return(double(exists?: false))

        component = described_class.new(hero_data: hero_data, contact_info: contact_info, school: school)
        expect(component.send(:should_show_claim_button?)).to be true
      end
    end

    context 'when school is already claimed' do
      before do
        create(:school_claim, :approved, school: school)
      end

      it 'does not show claim button' do
        component = described_class.new(hero_data: hero_data, contact_info: contact_info, school: school)
        expect(component.send(:should_show_claim_button?)).to be false
      end
    end

    context 'when user is not a school owner' do
      let(:regular_user) { create(:user) }

      before do
        allow_any_instance_of(ActionView::Base).to receive(:current_user).and_return(regular_user)
      end

      it 'does not show claim button' do
        component = described_class.new(hero_data: hero_data, contact_info: contact_info, school: school)
        expect(component.send(:should_show_claim_button?)).to be false
      end
    end

    context 'when user is not signed in' do
      before do
        allow_any_instance_of(ActionView::Base).to receive(:user_signed_in?).and_return(false)
        allow_any_instance_of(ActionView::Base).to receive(:current_user).and_return(nil)
      end

      it 'shows claim button for anonymous users if school unclaimed' do
        component = described_class.new(hero_data: hero_data, contact_info: contact_info, school: school)
        expect(component.send(:should_show_claim_button?)).to be true
      end
    end
  end

  describe 'private methods' do
    let(:component) { described_class.new(hero_data: hero_data, contact_info: contact_info, school: school) }

    describe '#school_name' do
      it 'returns name from hero_data' do
        expect(component.send(:school_name)).to eq('Test International School')
      end
    end

    describe '#hero_image_url' do
      it 'returns hero image URL when available' do
        expect(component.send(:hero_image_url)).to eq('https://example.com/hero.jpg')
      end

      context 'when hero image is nil' do
        before { hero_data[:hero_image] = nil }

        it 'falls back to logo URL' do
          expect(component.send(:hero_image_url)).to eq('https://example.com/logo.jpg')
        end
      end
    end

    describe '#rating_display' do
      it 'returns formatted rating data' do
        rating = component.send(:rating_display)
        expect(rating[:stars]).to eq('★★★★★')
        expect(rating[:value]).to eq(4.5)
        expect(rating[:count]).to eq(120)
        expect(rating[:source]).to eq('Google')
      end

      context 'when rating is nil' do
        before { hero_data[:rating] = nil }

        it 'returns nil' do
          expect(component.send(:rating_display)).to be_nil
        end
      end
    end

    describe '#key_stats' do
      it 'returns key stats array' do
        stats = component.send(:key_stats)
        expect(stats).to be_an(Array)
        expect(stats.size).to eq(2)
        expect(stats.first[:label]).to eq('Students')
      end

      context 'when key_stats is nil' do
        before { hero_data[:key_stats] = nil }

        it 'returns empty array' do
          expect(component.send(:key_stats)).to eq([])
        end
      end
    end
  end

  describe 'CSS classes' do
    let(:component) { described_class.new(hero_data: hero_data, contact_info: contact_info, school: school) }

    describe '#action_button_classes' do
      it 'returns claim button classes for claim action' do
        action = { claim_button: true }
        classes = component.send(:action_button_classes, action)
        expect(classes).to include('bg-green-600')
      end

      it 'returns contact button classes for contact action' do
        action = { contact_button: true }
        classes = component.send(:action_button_classes, action)
        expect(classes).to include('bg-blue-600')
      end

      it 'returns primary button classes for primary action' do
        action = { primary: true }
        classes = component.send(:action_button_classes, action)
        expect(classes).to include('bg-blue-600')
      end

      it 'returns secondary button classes for other actions' do
        action = {}
        classes = component.send(:action_button_classes, action)
        expect(classes).to include('bg-white')
      end
    end
  end
end
