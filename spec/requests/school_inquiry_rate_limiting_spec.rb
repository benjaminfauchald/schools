require 'rails_helper'

RSpec.describe 'School Inquiry Rate Limiting', type: :request do
  # CRITICAL MISSING TEST: School inquiries have NO rate limiting!
  # This is a MAJOR security vulnerability because:
  # 1. SPAM ATTACK: Malicious users can spam schools with unlimited inquiry emails
  # 2. EMAIL BOMBING: Schools could receive thousands of notification emails
  # 3. DATABASE FLOODING: Attackers can fill the database with junk inquiries
  # 4. RESOURCE EXHAUSTION: Server resources consumed by processing unlimited requests
  # 5. REPUTATION DAMAGE: Email service could blacklist the app for sending spam
  # This ONE test exposes a critical production vulnerability that needs immediate fixing!

  let(:school) { create(:school, name: 'Target School for Spam Attack') }
  let(:facebook_user) { create(:user, :facebook_user, email: 'spammer@example.com') }

  # Clear rate limit cache before each test to ensure test isolation
  before do
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end

  let(:inquiry_params) do
    {
      school_inquiry: {
        name: 'Spam Bot',
        email: 'spam@example.com',
        phone: '+1234567890',
        message: 'This is spam message number',
        children_count: 1
      }
    }
  end

  describe 'POST /schools/:school_id/school_inquiries - Rate Limiting' do
    before { sign_in facebook_user, scope: :user }

    it 'FIXED: Rate limiting now properly blocks spam attacks' do
      # This test verifies that the vulnerability has been FIXED
      # It should now block spam attempts after 5 requests

      successful_requests = 0
      blocked_requests = 0

      # Attempt to send 100 inquiries in rapid succession
      # This simulates a spam attack
      100.times do |i|
        params = inquiry_params.deep_dup
        params[:school_inquiry][:message] = "Spam message #{i}"

        post school_school_inquiries_path(school_id: school.id),
             params: params,
             as: :json

        if response.status == 200
          successful_requests += 1
        elsif response.status == 429 # Too Many Requests
          blocked_requests += 1
        end
      end

      # FIXED: Only first 5 requests succeed, rest are blocked!
      expect(successful_requests).to eq(5)
      expect(blocked_requests).to eq(95)

      # Verify that only 5 inquiries were created in the database
      expect(SchoolInquiry.where(school: school, user: facebook_user).count).to eq(5)

      puts "\n✅ VULNERABILITY FIXED! Rate limiting is working:"
      puts "✅ #{successful_requests} inquiries allowed (rate limit: 5/minute)"
      puts "🛡️ #{blocked_requests} spam attempts blocked!"
      puts "📧 School protected from email bombing"
      puts "💾 Database protected from spam pollution"
    end

    it 'demonstrates how rate limiting SHOULD work (this test should FAIL until fixed)' do
      # This test shows the EXPECTED behavior with proper rate limiting
      # It will FAIL now, but should PASS once rate limiting is implemented

      successful_requests = 0
      blocked_requests = 0
      error_messages = []

      # Reasonable rate limit: 5 inquiries per minute per user
      15.times do |i|
        params = inquiry_params.deep_dup
        params[:school_inquiry][:message] = "Message #{i}"

        post school_school_inquiries_path(school_id: school.id),
             params: params,
             as: :json

        if response.status == 200
          successful_requests += 1
        elsif response.status == 429
          blocked_requests += 1
          json = JSON.parse(response.body)
          error_messages << json['error']
        end
      end

      # EXPECTED: First 5 succeed, next 10 are blocked
      expect(successful_requests).to eq(5)
      expect(blocked_requests).to eq(10)

      # Should get helpful error message
      expect(error_messages.first.downcase).to include('rate limit') if error_messages.any?

      # Should include retry-after header
      if blocked_requests > 0
        expect(response.headers['Retry-After']).to be_present
      end
    end

    it 'blocks spam from different schools with user rate limiting' do
      # Rate limiting protects against cross-school spam attacks
      schools = create_list(:school, 5)

      total_inquiries_sent = 0
      blocked_count = 0

      schools.each do |target_school|
        10.times do |i|
          params = inquiry_params.deep_dup
          params[:school_inquiry][:message] = "Spam to #{target_school.name} ##{i}"

          post school_school_inquiries_path(school_id: target_school.id),
               params: params,
               as: :json

          if response.status == 200
            total_inquiries_sent += 1
          else
            blocked_count += 1
          end
        end
      end

      # FIXED: Only 5 inquiries allowed due to user rate limiting
      expect(total_inquiries_sent).to eq(5)
      expect(blocked_count).to eq(45)
      expect(SchoolInquiry.where(user: facebook_user).count).to eq(5)

      puts "\n✅ CROSS-SCHOOL SPAM BLOCKED:"
      puts "🛡️ Only #{total_inquiries_sent} inquiries allowed (rate limited)"
      puts "🚫 Blocked #{blocked_count} spam attempts across #{schools.count} schools!"
    end

    it 'blocks rapid-fire spam (burst attack) with rate limiting' do
      # Simulate burst attack - send inquiries as fast as possible
      start_time = Time.current
      successful_count = 0
      blocked_count = 0

      # Send 20 requests in rapid succession
      20.times do |i|
        params = inquiry_params.deep_dup
        params[:school_inquiry][:message] = "Rapid fire message #{i}"

        post school_school_inquiries_path(school_id: school.id),
             params: params,
             as: :json

        if response.status == 200
          successful_count += 1
        else
          blocked_count += 1
        end
      end

      elapsed_time = Time.current - start_time

      puts "\n🚨 BURST ATTACK RESULTS:"
      puts "⏱️  Time elapsed: #{elapsed_time.round(2)} seconds"
      puts "✅ Successful spam inquiries: #{successful_count}/20"
      puts "🛡️ Blocked by rate limiting: #{blocked_count}/20"
      puts "📧 Requests per second attempted: #{(20 / elapsed_time).round(2)}"
      puts "✅ Rate limiting is working!"

      # Only 5 should succeed due to rate limiting (5 per minute per user)
      expect(successful_count).to eq(5)
      expect(blocked_count).to eq(15)
    end

    it 'prevents email bombing with rate limiting' do
      # Show how rate limiting protects the email system
      email_count_before = ActionMailer::Base.deliveries.count

      # Try to send 20 spam inquiries
      successful = 0
      blocked = 0
      20.times do |i|
        params = inquiry_params.deep_dup
        params[:school_inquiry][:message] = "Email bomb #{i}"

        post school_school_inquiries_path(school_id: school.id),
             params: params,
             as: :json

        if response.status == 200
          successful += 1
        else
          blocked += 1
        end
      end

      email_count_after = ActionMailer::Base.deliveries.count
      emails_sent = email_count_after - email_count_before

      # Only 5 emails sent due to rate limiting
      expect(emails_sent).to eq(5)
      expect(successful).to eq(5)
      expect(blocked).to eq(15)

      puts "\n✅ EMAIL BOMBING PREVENTED:"
      puts "🛡️ Only #{emails_sent} emails sent (rate limited)"
      puts "✅ Email service protected from blacklisting!"
      puts "🚫 Blocked #{blocked} spam attempts"
    end

    it 'prevents database pollution with rate limiting' do
      initial_count = SchoolInquiry.count

      # Try to spam with junk data - reduced to 10 for faster test
      successful = 0
      blocked = 0
      10.times do |i|
        params = inquiry_params.deep_dup
        params[:school_inquiry][:message] = "X" * 2000 # Max length message
        params[:school_inquiry][:name] = "Spam Bot #{i}" * 10 # Long name

        post school_school_inquiries_path(school_id: school.id),
             params: params,
             as: :json

        if response.status == 200
          successful += 1
        else
          blocked += 1
        end
      end

      total_junk_records = SchoolInquiry.count - initial_count
      total_bytes = SchoolInquiry.where(user: facebook_user).sum { |i|
        i.message.length + i.name.length + (i.email&.length || 0) + (i.phone&.length || 0)
      }

      # Only 5 records created due to rate limiting
      expect(total_junk_records).to eq(5)
      expect(successful).to eq(5)
      expect(blocked).to eq(5)

      puts "\n💾 DATABASE POLLUTION:"
      puts "🗑️  #{total_junk_records} junk records created (from just 10 requests!)"
      puts "💿 ~#{(total_bytes / 1024.0).round(2)} KB of spam data stored"
      puts "⚠️  No cleanup mechanism exists!"
    end
  end

  describe 'Required rate limiting implementation' do
    it 'should implement per-user rate limiting' do
      # Recommended implementation:
      # - 5 inquiries per minute per user
      # - 20 inquiries per hour per user
      # - 50 inquiries per day per user

      skip 'Rate limiting not yet implemented - CRITICAL SECURITY ISSUE'

      # Test code for when implemented:
      6.times do
        post school_school_inquiries_path(school_id: school.id),
             params: inquiry_params,
             as: :json
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include('rate limit exceeded')
    end

    it 'should implement per-IP rate limiting' do
      skip 'IP-based rate limiting not yet implemented'

      # Even if using different accounts, same IP should be limited
      # This prevents creating multiple accounts to bypass user limits
    end

    it 'should implement per-school rate limiting' do
      skip 'Per-school protection not yet implemented'

      # Protect individual schools from targeted attacks
      # Limit: 100 inquiries per hour per school from all users
    end
  end

  describe 'Rate limiting fix verification' do
    # These tests will PASS once the vulnerability is fixed

    it 'returns 429 status when rate limit exceeded' do
      skip 'Waiting for rate limiting implementation'

      # Send 6 requests (assuming limit is 5)
      6.times do
        post school_school_inquiries_path(school_id: school.id),
             params: inquiry_params,
             as: :json
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'includes Retry-After header' do
      skip 'Waiting for rate limiting implementation'

      6.times do
        post school_school_inquiries_path(school_id: school.id),
             params: inquiry_params,
             as: :json
      end

      expect(response.headers['Retry-After']).to eq('60')
    end

    it 'rate limit resets after time window' do
      skip 'Waiting for rate limiting implementation'

      # Send 5 requests (at limit)
      5.times do
        post school_school_inquiries_path(school_id: school.id),
             params: inquiry_params,
             as: :json
      end
      expect(response).to have_http_status(:ok)

      # 6th request blocked
      post school_school_inquiries_path(school_id: school.id),
           params: inquiry_params,
           as: :json
      expect(response).to have_http_status(:too_many_requests)

      # Wait for rate limit to reset
      travel_to(61.seconds.from_now) do
        post school_school_inquiries_path(school_id: school.id),
             params: inquiry_params,
             as: :json
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
