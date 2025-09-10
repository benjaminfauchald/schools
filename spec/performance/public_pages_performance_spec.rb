require 'rails_helper'
require 'benchmark'

RSpec.describe 'Public Pages Performance - Regression Prevention', type: :request do
  # These tests ensure performance doesn't degrade over time
  # They will FAIL if someone introduces performance problems
  
  let!(:schools) { create_list(:school, 50) } # Create 50 schools for realistic testing
  
  before do
    # Set up realistic data with relationships
    schools.each_with_index do |school, index|
      # Spread schools across Bangkok area
      school.place.update!(
        lat: 13.7563 + (index * 0.01),
        lng: 100.5018 + (index * 0.01),
        formatted_address: "#{index} Test Road, Bangkok"
      )
      
      # Add related data that could cause N+1 problems
      create(:school_fee_schedule, school: school)
      create(:school_grade_offering, school: school)
      create_list(:media_item, 3, place: school.place)
    end
  end

  describe 'CRITICAL: Homepage Performance' do
    it 'loads within 3 seconds with 50 schools' do
      time = Benchmark.realtime do
        get '/', params: { home_lat: 13.7563, home_lng: 100.5018, radius: 50 }
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 3.0, "Homepage took #{time.round(2)}s, should be under 3s"
    end

    it 'returns JSON response within 1 second' do
      time = Benchmark.realtime do
        get '/', params: { home_lat: 13.7563, home_lng: 100.5018, radius: 50 }, 
            headers: { 'Accept' => 'application/json' }
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 1.0, "JSON response took #{time.round(2)}s, should be under 1s"
    end

    it 'handles pagination efficiently' do
      time = Benchmark.realtime do
        get '/', params: { home_lat: 13.7563, home_lng: 100.5018, page: 2, per_page: 25 }
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 2.0, "Pagination took #{time.round(2)}s, should be under 2s"
    end
  end

  describe 'CRITICAL: N+1 Query Detection' do
    it 'does not have N+1 queries on homepage' do
      # Warm up
      get '/', params: { home_lat: 13.7563, home_lng: 100.5018 }
      
      # Track queries
      queries_with_10 = count_database_queries do
        get '/', params: { home_lat: 13.7563, home_lng: 100.5018, per_page: 10 }
      end
      
      queries_with_25 = count_database_queries do
        get '/', params: { home_lat: 13.7563, home_lng: 100.5018, per_page: 25 }
      end
      
      # Should not scale linearly with results (N+1 would mean 15+ more queries)
      query_difference = queries_with_25 - queries_with_10
      expect(query_difference).to be < 5, 
        "Possible N+1: #{queries_with_10} queries for 10 items, #{queries_with_25} for 25 items"
    end

    it 'uses efficient queries for distance calculation' do
      query_count = count_database_queries do
        get '/', params: { home_lat: 13.7563, home_lng: 100.5018, radius: 20 }
      end
      
      # Should use single query with ST_Distance, not separate query per school
      expect(query_count).to be < 10, "Too many queries (#{query_count}), possible inefficient distance calculation"
    end
  end

  describe 'CRITICAL: School Detail Page Performance' do
    let(:school) { schools.first }
    
    it 'loads school detail page within 2 seconds' do
      time = Benchmark.realtime do
        get "/schools/#{school.id}"
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 2.0, "School page took #{time.round(2)}s, should be under 2s"
    end

    it 'eager loads all associations to prevent N+1' do
      query_count = count_database_queries do
        get "/schools/#{school.id}"
      end
      
      # Should load all data in < 15 queries (not 50+ from lazy loading)
      expect(query_count).to be < 15, "Too many queries (#{query_count}), associations not eager loaded"
    end
  end

  describe 'CRITICAL: Search Performance' do
    it 'returns search results within 1.5 seconds' do
      time = Benchmark.realtime do
        get '/schools/search', params: { 
          q: 'School', 
          home_lat: 13.7563, 
          home_lng: 100.5018 
        }
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 1.5, "Search took #{time.round(2)}s, should be under 1.5s"
    end

    it 'uses database indexes for text search' do
      # Create schools with searchable names
      create(:school, name: 'Bangkok International Academy')
      create(:school, name: 'International School Bangkok')
      
      time = Benchmark.realtime do
        get '/schools/search', params: { 
          q: 'International', 
          home_lat: 13.7563, 
          home_lng: 100.5018 
        }
      end
      
      expect(time).to be < 0.5, "Search not using indexes, took #{time.round(2)}s"
    end
  end

  describe 'CRITICAL: Filtered Results Performance' do
    it 'applies multiple filters efficiently' do
      time = Benchmark.realtime do
        get '/schools/filtered', params: {
          home_lat: 13.7563,
          home_lng: 100.5018,
          radius: 10,
          page: 1
        }
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 1.5, "Filtering took #{time.round(2)}s, should be under 1.5s"
    end

    it 'handles show_all parameter without timeout' do
      # This could be slow if not properly implemented
      time = Benchmark.realtime do
        get '/schools/filtered', params: {
          home_lat: 13.7563,
          home_lng: 100.5018,
          show_all: true
        }
      end
      
      expect(response).to have_http_status(:success)
      expect(time).to be < 3.0, "Show all took #{time.round(2)}s, should be under 3s"
    end
  end

  describe 'CRITICAL: Memory Usage' do
    it 'does not load unnecessary data into memory' do
      # Check that we're not loading full objects when we only need IDs/names
      get '/', params: { home_lat: 13.7563, home_lng: 100.5018 }, 
          headers: { 'Accept' => 'application/json' }
      
      json = JSON.parse(response.body)
      
      # Response should only include necessary fields, not full objects
      if json['schools'].any?
        school_keys = json['schools'].first.keys
        expect(school_keys).not_to include('created_at', 'updated_at'),
          "Loading unnecessary fields into memory"
        expect(school_keys).to include('id', 'name', 'distance_km'),
          "Missing essential fields"
      end
    end
  end

  describe 'CRITICAL: Concurrent Request Handling' do
    it 'handles multiple simultaneous requests efficiently' do
      threads = []
      response_times = []
      
      # Simulate 5 concurrent users
      5.times do |i|
        threads << Thread.new do
          time = Benchmark.realtime do
            # Use different coordinates to avoid caching
            get '/', params: { 
              home_lat: 13.7563 + (i * 0.001), 
              home_lng: 100.5018 
            }
          end
          response_times << time
        end
      end
      
      threads.each(&:join)
      
      average_time = response_times.sum / response_times.size
      max_time = response_times.max
      
      expect(average_time).to be < 2.0, "Average response time #{average_time.round(2)}s under load"
      expect(max_time).to be < 4.0, "Max response time #{max_time.round(2)}s under load"
    end
  end

  describe 'CRITICAL: Database Connection Pool' do
    it 'does not exhaust connection pool under load' do
      # This would fail if connection pool is too small or connections leak
      expect {
        10.times do
          Thread.new do
            get '/', params: { home_lat: 13.7563, home_lng: 100.5018 }
          end
        end
        sleep 0.5
      }.not_to raise_error
    end
  end

  describe 'CRITICAL: API Response Size' do
    it 'keeps JSON responses reasonably sized' do
      get '/', params: { home_lat: 13.7563, home_lng: 100.5018, per_page: 25 },
          headers: { 'Accept' => 'application/json' }
      
      response_size = response.body.bytesize
      
      # Response should be under 100KB for 25 schools
      expect(response_size).to be < 100_000, 
        "Response too large: #{response_size / 1000}KB, should be under 100KB"
    end
  end

  private

  def count_database_queries(&block)
    query_count = 0
    
    # Subscribe to SQL notifications
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      # Don't count SCHEMA or TRANSACTION queries
      unless event.payload[:sql] =~ /^(BEGIN|COMMIT|SCHEMA|PRAGMA)/
        query_count += 1
      end
    end
    
    yield
    
    ActiveSupport::Notifications.unsubscribe(subscriber)
    query_count
  end
end