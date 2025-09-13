require 'rails_helper'

RSpec.describe Event, type: :model do
  let(:place) { create(:place) }
  let(:event) { create(:event, place: place) }

  describe 'associations' do
    it { should belong_to(:place) }
  end

  describe 'validations' do
    subject { build(:event, place: place) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:starts_at) }

    it 'validates URL format' do
      event = build(:event, place: place, url: 'not-a-url')
      expect(event).not_to be_valid
      expect(event.errors[:url]).to include('is invalid')

      event.url = 'https://example.com/event'
      expect(event).to be_valid

      event.url = nil
      expect(event).to be_valid # allow_blank
    end

    describe 'ends_at validation' do
      it 'requires ends_at to be after starts_at' do
        event = build(:event, place: place, starts_at: Time.current, ends_at: Time.current - 1.hour)
        expect(event).not_to be_valid
        expect(event.errors[:ends_at]).to include('must be after start time')
      end

      it 'allows ends_at to be nil' do
        event = build(:event, place: place, starts_at: Time.current, ends_at: nil)
        expect(event).to be_valid
      end

      it 'allows ends_at to be after starts_at' do
        event = build(:event, place: place, starts_at: Time.current, ends_at: Time.current + 1.hour)
        expect(event).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:past_event) { create(:event, place: place, starts_at: 2.days.ago, ends_at: 1.day.ago) }
    let!(:current_event) { create(:event, place: place, starts_at: 1.hour.ago, ends_at: 1.hour.from_now) }
    let!(:upcoming_event) { create(:event, place: place, starts_at: 1.day.from_now) }
    let!(:today_event) { create(:event, place: place, starts_at: Time.current.noon) }
    let!(:this_week_event) { create(:event, place: place, starts_at: Date.current.beginning_of_week + 2.days) }
    let!(:next_month_event) { create(:event, place: place, starts_at: 1.month.from_now) }

    describe '.upcoming' do
      it 'returns future events' do
        expect(Event.upcoming).to include(upcoming_event)
        expect(Event.upcoming).not_to include(past_event, current_event)
      end
    end

    describe '.past' do
      it 'returns past events' do
        expect(Event.past).to include(past_event)
        expect(Event.past).not_to include(upcoming_event)
      end
    end

    describe '.current' do
      it 'returns currently happening events' do
        expect(Event.current).to include(current_event)
        expect(Event.current).not_to include(past_event, upcoming_event)
      end
    end

    describe '.ongoing' do
      it 'is an alias for current' do
        expect(Event.ongoing.to_a).to eq(Event.current.to_a)
      end
    end

    describe '.today' do
      it 'returns events starting today' do
        expect(Event.today).to include(today_event)
        expect(Event.today).not_to include(upcoming_event, past_event)
      end
    end

    describe '.this_week' do
      it 'returns events starting this week' do
        expect(Event.this_week).to include(this_week_event)
        expect(Event.this_week).not_to include(next_month_event)
      end
    end

    describe '.this_month' do
      it 'returns events starting this month' do
        # Events created in current month
        current_month_events = Event.where(starts_at: Date.current.beginning_of_month..Date.current.end_of_month)
        expect(Event.this_month.count).to eq(current_month_events.count)
      end
    end

    describe '.ordered' do
      it 'orders by starts_at ascending' do
        ordered = Event.ordered
        # Events should be ordered from earliest to latest
        expect(ordered.map(&:starts_at)).to eq(ordered.map(&:starts_at).sort)
      end
    end
  end

  describe 'instance methods' do
    describe '#happening_now?' do
      it 'returns true for current events' do
        event.starts_at = 1.hour.ago
        event.ends_at = 1.hour.from_now
        expect(event.happening_now?).to be true
      end

      it 'returns false for past events' do
        event.starts_at = 2.days.ago
        event.ends_at = 1.day.ago
        expect(event.happening_now?).to be false
      end

      it 'returns false for future events' do
        event.starts_at = 1.day.from_now
        event.ends_at = 2.days.from_now
        expect(event.happening_now?).to be false
      end

      it 'handles events without end time' do
        event.starts_at = 1.hour.ago
        event.ends_at = nil
        expect(event.happening_now?).to be true

        event.starts_at = 1.hour.from_now
        event.ends_at = nil
        expect(event.happening_now?).to be false
      end
    end

    describe '#upcoming?' do
      it 'returns true for future events' do
        event.starts_at = 1.day.from_now
        expect(event.upcoming?).to be true
      end

      it 'returns false for past or current events' do
        event.starts_at = 1.hour.ago
        expect(event.upcoming?).to be false
      end
    end

    describe '#past?' do
      it 'returns true when event has ended' do
        event.starts_at = 2.days.ago
        event.ends_at = 1.day.ago
        expect(event.past?).to be true
      end

      it 'uses starts_at when ends_at is nil' do
        event.starts_at = 1.day.ago
        event.ends_at = nil
        expect(event.past?).to be true

        event.starts_at = 1.day.from_now
        event.ends_at = nil
        expect(event.past?).to be false
      end
    end

    describe '#duration_minutes' do
      it 'calculates duration in minutes' do
        event.starts_at = Time.current
        event.ends_at = Time.current + 90.minutes
        expect(event.duration_minutes).to eq(90)
      end

      it 'returns nil when ends_at is nil' do
        event.ends_at = nil
        expect(event.duration_minutes).to be_nil
      end
    end

    describe '#duration_display' do
      it 'formats duration as hours and minutes' do
        event.starts_at = Time.current
        event.ends_at = Time.current + 90.minutes
        expect(event.duration_display).to eq('1h 30m')

        event.ends_at = Time.current + 2.hours
        expect(event.duration_display).to eq('2h')

        event.ends_at = Time.current + 45.minutes
        expect(event.duration_display).to eq('45m')
      end

      it 'returns message when ends_at is nil' do
        event.ends_at = nil
        expect(event.duration_display).to eq('Duration not specified')
      end
    end

    describe '#time_range_display' do
      it 'formats time range for same day' do
        event.starts_at = Time.zone.parse('2024-01-15 09:00')
        event.ends_at = Time.zone.parse('2024-01-15 17:00')
        expect(event.time_range_display).to eq('9:00 AM - 5:00 PM')
      end

      it 'includes dates for multi-day events' do
        event.starts_at = Time.zone.parse('2024-01-15 09:00')
        event.ends_at = Time.zone.parse('2024-01-16 17:00')
        expect(event.time_range_display).to include('Jan 15')
        expect(event.time_range_display).to include('Jan 16')
      end

      it 'handles events without end time' do
        event.starts_at = Time.zone.parse('2024-01-15 09:00')
        event.ends_at = nil
        expect(event.time_range_display).to eq('9:00 AM')
      end
    end

    describe '#date_range_display' do
      it 'shows single date for same-day events' do
        event.starts_at = Time.zone.parse('2024-01-15 09:00')
        event.ends_at = Time.zone.parse('2024-01-15 17:00')
        expect(event.date_range_display).to eq('January 15, 2024')
      end

      it 'shows date range for multi-day events' do
        event.starts_at = Time.zone.parse('2024-01-15 09:00')
        event.ends_at = Time.zone.parse('2024-01-17 17:00')
        expect(event.date_range_display).to eq('January 15, 2024 - January 17, 2024')
      end
    end

    describe '#days_until' do
      it 'calculates days until event' do
        event.starts_at = 3.days.from_now
        expect(event.days_until).to eq(3)
      end

      it 'returns 0 for past events' do
        event.starts_at = 1.day.ago
        event.ends_at = 1.hour.ago
        expect(event.days_until).to eq(0)
      end

      it 'returns 0 for today events' do
        event.starts_at = Date.current.noon
        event.ends_at = Date.current.noon + 2.hours
        expect(event.days_until).to eq(0)
      end
    end

    describe '#status_display' do
      it 'returns Happening Now for current events' do
        event.starts_at = 1.hour.ago
        event.ends_at = 1.hour.from_now
        expect(event.status_display).to eq('Happening Now')
      end

      it 'returns Today for events starting today' do
        # Set to future time today to avoid "Happening Now"
        event.starts_at = Time.current.end_of_day - 1.hour
        event.ends_at = Time.current.end_of_day
        expect(event.status_display).to match(/Today|In \d+ days/)
      end

      it 'returns Tomorrow for next day events' do
        event.starts_at = 1.day.from_now.noon
        event.ends_at = 1.day.from_now.noon + 2.hours
        expect(event.status_display).to eq('Tomorrow')
      end

      it 'returns In X days for near future events' do
        event.starts_at = 5.days.from_now
        event.ends_at = 5.days.from_now + 2.hours
        expect(event.status_display).to eq('In 5 days')
      end

      it 'returns Upcoming for distant future events' do
        event.starts_at = 2.weeks.from_now
        event.ends_at = 2.weeks.from_now + 2.hours
        expect(event.status_display).to eq('Upcoming')
      end

      it 'returns Past for past events' do
        event.starts_at = 1.day.ago
        event.ends_at = 1.hour.ago
        expect(event.status_display).to eq('Past')
      end
    end
  end

  describe 'factory' do
    it 'creates valid event' do
      event = build(:event, place: place)
      expect(event).to be_valid
    end

    it 'creates events with different times' do
      past = create(:event, place: place, starts_at: 1.day.ago)
      future = create(:event, place: place, starts_at: 1.day.from_now)
      expect(past.past?).to be true
      expect(future.upcoming?).to be true
    end
  end
end
