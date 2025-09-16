require 'rails_helper'

RSpec.describe AnalyticsService do
  describe '.track' do
    context 'when Mixpanel is not configured' do
      before do
        allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(nil)
      end

      it 'does not raise an error' do
        expect {
          AnalyticsService.track('Test Event', { test: true })
        }.not_to raise_error
      end
    end

    context 'when Mixpanel is configured' do
      let(:mock_tracker) { instance_double(Mixpanel::Tracker) }

      before do
        allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(mock_tracker)
        allow(mock_tracker).to receive(:track)
      end

      it 'tracks events with enriched properties' do
        user = create(:user)
        request = double('request',
          remote_ip: '127.0.0.1',
          user_agent: 'Test Browser',
          cookies: {}
        )

        expect(mock_tracker).to receive(:track) do |distinct_id, event_name, properties|
          expect(distinct_id).to eq("user_#{user.id}")
          expect(event_name).to eq('Test Event')
          expect(properties[:test_prop]).to eq('value')
          expect(properties['user_id']).to eq(user.id)
          expect(properties['user_type']).to eq(user.role)
          expect(properties['authenticated']).to eq(true)
          expect(properties['environment']).to eq('test')
        end

        AnalyticsService.track('Test Event', { test_prop: 'value' }, user: user, request: request)
      end

      it 'handles anonymous users' do
        request = double('request',
          session: double('session', id: 'test_session_123'),
          remote_ip: '127.0.0.1',
          user_agent: 'Test Browser',
          cookies: {}
        )

        expect(mock_tracker).to receive(:track) do |distinct_id, event_name, properties|
          expect(distinct_id).to eq('anon_test_session_123')
          expect(event_name).to eq('Anonymous Event')
          expect(properties['authenticated']).to eq(false)
        end

        AnalyticsService.track('Anonymous Event', {}, user: nil, request: request)
      end
    end
  end

  describe '.track_signup' do
    let(:mock_tracker) { instance_double(Mixpanel::Tracker) }
    let(:mock_people) { instance_double(Mixpanel::People) }
    let(:user) { create(:user) }

    before do
      allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(mock_tracker)
      allow(mock_tracker).to receive(:track)
      allow(mock_tracker).to receive(:people).and_return(mock_people)
      allow(mock_people).to receive(:set)
    end

    it 'tracks signup event and identifies user' do
      expect(mock_tracker).to receive(:track).with(
        "user_#{user.id}",
        'User Signed Up',
        hash_including(
          method: 'email',
          source: 'test',
          user_id: user.id,
          email: user.email
        )
      )

      expect(mock_people).to receive(:set).with(
        "user_#{user.id}",
        hash_including(
          '$email' => user.email,
          '$name' => user.display_name,
          'user_type' => user.role
        )
      )

      AnalyticsService.track_signup(user, method: 'email', source: 'test')
    end
  end

  describe '.track_school_view' do
    let(:mock_tracker) { instance_double(Mixpanel::Tracker) }
    let(:school) { create(:school, name: 'Test School') }

    before do
      allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(mock_tracker)
      allow(mock_tracker).to receive(:track)
    end

    it 'tracks school view with school details' do
      expect(mock_tracker).to receive(:track).with(
        anything,
        'School Viewed',
        hash_including(
          school_id: school.id,
          school_name: school.name,
          view_source: 'search'
        )
      )

      AnalyticsService.track_school_view(school, source: 'search')
    end
  end

  describe '.track_inquiry' do
    let(:mock_tracker) { instance_double(Mixpanel::Tracker) }
    let(:school) { create(:school, name: 'Test School') }
    let(:inquiry) { create(:school_inquiry, school: school, children_count: 2) }

    before do
      allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(mock_tracker)
      allow(mock_tracker).to receive(:track)
    end

    it 'tracks inquiry submission' do
      expect(mock_tracker).to receive(:track).with(
        anything,
        'Inquiry Sent',
        hash_including(
          school_id: school.id,
          school_name: school.name,
          children_count: 2,
          inquiry_id: inquiry.id
        )
      )

      AnalyticsService.track_inquiry(inquiry)
    end
  end
end
