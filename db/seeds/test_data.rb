# Comprehensive Test Data Seeder for Schools Application
# Run with: rails runner 'load Rails.root.join("db/seeds/test_data.rb")'
# All data is tagged with test_data: true for easy cleanup

puts "🏫 Creating comprehensive test data for schools application..."
puts "📍 All test data will be tagged for easy cleanup"

# Bangkok districts for realistic distribution
BANGKOK_DISTRICTS = [
  { name: 'Sathorn', lat: 13.7167, lng: 100.5289 },
  { name: 'Silom', lat: 13.7248, lng: 100.5340 },
  { name: 'Sukhumvit', lat: 13.7357, lng: 100.5640 },
  { name: 'Phloenchit', lat: 13.7427, lng: 100.5470 },
  { name: 'Asok', lat: 13.7372, lng: 100.5610 },
  { name: 'Thonglor', lat: 13.7308, lng: 100.5827 },
  { name: 'Ekkamai', lat: 13.7206, lng: 100.5901 },
  { name: 'Phrom Phong', lat: 13.7302, lng: 100.5704 },
  { name: 'Ari', lat: 13.7789, lng: 100.5436 },
  { name: 'Saphan Phong', lat: 13.7611, lng: 100.5456 },
  { name: 'Ratchada', lat: 13.7584, lng: 100.5648 },
  { name: 'Huai Khwang', lat: 13.7776, lng: 100.5740 },
  { name: 'Wang Thonglang', lat: 13.7702, lng: 100.5967 },
  { name: 'Lat Phrao', lat: 13.8039, lng: 100.5615 },
  { name: 'Bang Sue', lat: 13.8197, lng: 100.5268 }
]

# School types with different characteristics
SCHOOL_PROFILES = [
  {
    type: 'premium_international',
    curricula: %w[ib_pyp ib_myp ib_dp],
    accreditations: %w[cis wasc ibo_authorization],
    languages: %w[english mandarin french],
    tuition_range: [ 800000, 1200000 ],
    facilities: %w[swimming_pool gymnasium library science_labs art_studio music_room theatre cafeteria medical_center]
  },
  {
    type: 'british_international',
    curricula: %w[uk_eyfs uk_national uk_igcse uk_alevel],
    accreditations: %w[cobis cambridge_international],
    languages: %w[english thai mandarin],
    tuition_range: [ 600000, 900000 ],
    facilities: %w[football_field tennis_court basketball_court library computer_lab cafeteria]
  },
  {
    type: 'american_international',
    curricula: %w[us_common_core us_ap],
    accreditations: %w[wasc neasc],
    languages: %w[english spanish french],
    tuition_range: [ 500000, 800000 ],
    facilities: %w[track_field gymnasium library science_labs computer_lab theatre]
  },
  {
    type: 'bilingual_thai',
    curricula: %w[thai_national],
    accreditations: %w[thai_moe],
    languages: %w[thai english mandarin],
    tuition_range: [ 200000, 400000 ],
    facilities: %w[playground library computer_lab cafeteria medical_center]
  },
  {
    type: 'local_premium',
    curricula: %w[thai_national uk_igcse],
    accreditations: %w[thai_moe],
    languages: %w[thai english],
    tuition_range: [ 100000, 300000 ],
    facilities: %w[basketball_court library computer_lab playground cafeteria]
  }
]

# Create test schools with varied profiles
schools_data = []
timestamp = Time.current.to_i
global_counter = 0

SCHOOL_PROFILES.each_with_index do |profile, profile_idx|
  # Create 10 schools per profile type
  10.times do |school_idx|
    global_counter += 1
    district = BANGKOK_DISTRICTS.sample

    # Generate realistic coordinates within district
    lat = district[:lat] + (rand(-0.01..0.01))
    lng = district[:lng] + (rand(-0.01..0.01))

    school_name = case profile[:type]
    when 'premium_international'
      [ "Bangkok International School", "International School of Bangkok", "Regents International School Bangkok" ][school_idx % 3]
    when 'british_international'
      [ "St Andrews International School", "Harrow International School", "Brighton College Bangkok" ][school_idx % 3]
    when 'american_international'
      [ "American School of Bangkok", "International School Bangkok", "Wells International School" ][school_idx % 3]
    when 'bilingual_thai'
      [ "Triam Udom Suksa School", "Srinakharinwirot University Prasarnmit Demonstration School", "Chulalongkorn University Demonstration School" ][school_idx % 3]
    when 'local_premium'
      [ "Bangkok Prep", "Thai-Chinese International School", "Assumption College" ][school_idx % 3]
    end

    # Add unique identifier with timestamp and counter to avoid duplicates
    unique_name = "#{school_name} #{district[:name]} Campus #{timestamp}_#{global_counter}"

    schools_data << {
      name: unique_name,
      profile: profile,
      district: district[:name],
      lat: lat,
      lng: lng,
      profile_type: profile[:type],
      unique_id: "#{profile_idx}_#{school_idx}"
    }
  end
end

puts "📊 Generating #{schools_data.length} schools across #{SCHOOL_PROFILES.length} profile types"

# Track created records for cleanup
created_records = {
  places: [],
  schools: [],
  school_fee_schedules: [],
  school_grade_offerings: [],
  media_items: [],
  events: [],
  taggings: []
}

schools_data.each_with_index do |school_data, idx|
  puts "🏗️  Creating school #{idx + 1}/#{schools_data.length}: #{school_data[:name]}"

  # Create Place first (Google Maps style data)
  place = Place.create!(
    place_id: "test_place_#{idx + 1}_#{SecureRandom.hex(8)}",
    google_place_id: "ChIJ#{SecureRandom.alphanumeric(20)}",
    name: school_data[:name],
    formatted_address: "#{rand(1..999)} #{[ 'Sukhumvit Road', 'Silom Road', 'Sathorn Road', 'Ploenchit Road' ].sample}, #{school_data[:district]}, Bangkok 10#{rand(110..120)}, Thailand",
    vicinity: "#{school_data[:district]}, Bangkok",
    business_status: 'OPERATIONAL',
    rating: rand(3.8..5.0).round(1),
    user_ratings_total: rand(50..500),
    lat: school_data[:lat],
    lng: school_data[:lng],
    formatted_phone_number: "+66 #{rand(10..99)}-#{rand(100..999)}-#{rand(1000..9999)}",
    website: "https://#{school_data[:name].parameterize}.edu",
    types: [ 'school', 'point_of_interest', 'establishment' ],
    opening_hours: {
      'open_now' => true,
      'periods' => [
        {
          'close' => { 'day' => 1, 'time' => '1600' },
          'open' => { 'day' => 1, 'time' => '0730' }
        },
        {
          'close' => { 'day' => 2, 'time' => '1600' },
          'open' => { 'day' => 2, 'time' => '0730' }
        },
        {
          'close' => { 'day' => 3, 'time' => '1600' },
          'open' => { 'day' => 3, 'time' => '0730' }
        },
        {
          'close' => { 'day' => 4, 'time' => '1600' },
          'open' => { 'day' => 4, 'time' => '0730' }
        },
        {
          'close' => { 'day' => 5, 'time' => '1600' },
          'open' => { 'day' => 5, 'time' => '0730' }
        }
      ],
      'weekday_text' => [
        'Monday: 7:30 AM – 4:00 PM',
        'Tuesday: 7:30 AM – 4:00 PM',
        'Wednesday: 7:30 AM – 4:00 PM',
        'Thursday: 7:30 AM – 4:00 PM',
        'Friday: 7:30 AM – 4:00 PM',
        'Saturday: Closed',
        'Sunday: Closed'
      ]
    },
    last_fetched_at: Time.current,
    api_status: 'OK',
    # Mark as test data
    raw_api_response: { 'test_data' => true }
  )
  created_records[:places] << place.id

  # Create School
  school = School.create!(
    place: place,
    name: school_data[:name],
    slug: "#{school_data[:name].parameterize}-#{school_data[:unique_id]}",
    about: "#{school_data[:name]} is a #{school_data[:profile_type].humanize.downcase} located in #{school_data[:district]}, Bangkok. We provide excellent education with a focus on developing global citizens prepared for the challenges of tomorrow.",
    founded_year: rand(1995..2020),
    ownership: [ 'nonprofit', 'private', 'foundation' ].sample,
    phone: place.formatted_phone_number,
    email: "test#{idx + 1}@testschool.edu",
    website_url: place.website,
    address_line_1: place.formatted_address.split(',').first,
    district: school_data[:district],
    province: 'Bangkok',
    postcode: "10#{rand(110..120)}",
    country_code: 'TH',
    lat: school_data[:lat],
    lng: school_data[:lng],
    student_teacher_ratio: rand(8.0..15.0).round(1),
    avg_class_size: rand(15..25),
    boarding: school_data[:profile][:facilities].include?('boarding_house'),
    school_bus: school_data[:profile][:facilities].include?('bus_service'),
    language_support_notes: "Full ESL support available. Native speakers for #{school_data[:profile][:languages].map(&:humanize).join(', ')} programs.",
    status: 'published',
    last_verification_at: rand(1.month.ago..Time.current),
    # Mark as test data in the tsv field metadata
    tsv: "'test_data':1"
  )
  created_records[:schools] << school.id

  # Add curriculum taggings
  school_data[:profile][:curricula].each do |curriculum_slug|
    term = Term.joins(:vocabulary).find_by(slug: curriculum_slug, vocabularies: { code: 'curriculum' })
    if term
      tagging = school.taggings.create!(
        term: term,
        context: 'curriculum',
        notes: "Test data curriculum assignment"
      )
      created_records[:taggings] << tagging.id
    end
  end

  # Add accreditation taggings
  school_data[:profile][:accreditations].each do |accred_slug|
    term = Term.joins(:vocabulary).find_by(slug: accred_slug, vocabularies: { code: 'accreditation' })
    if term
      tagging = school.taggings.create!(
        term: term,
        context: 'accreditation',
        notes: "Test data accreditation",
        valid_from: rand(2.years.ago..6.months.ago).to_date,
        valid_to: rand(2.years.from_now..5.years.from_now).to_date
      )
      created_records[:taggings] << tagging.id
    end
  end

  # Add language taggings
  school_data[:profile][:languages].each do |lang_slug|
    term = Term.joins(:vocabulary).find_by(slug: lang_slug, vocabularies: { code: 'language' })
    if term
      tagging = school.taggings.create!(
        term: term,
        context: 'language',
        notes: "Test data language support"
      )
      created_records[:taggings] << tagging.id
    end
  end

  # Add facility taggings
  school_data[:profile][:facilities].each do |facility_slug|
    term = Term.joins(:vocabulary).find_by(slug: facility_slug, vocabularies: { code: 'facility' })
    if term
      tagging = school.taggings.create!(
        term: term,
        context: 'facility',
        notes: "Test data facility"
      )
      created_records[:taggings] << tagging.id
    end
  end

  # Add some extracurricular activities (random selection)
  extracurricular_terms = Term.joins(:vocabulary).where(vocabularies: { code: 'extracurricular' })
  extracurricular_terms.sample(rand(5..10)).each do |term|
    tagging = school.taggings.create!(
      term: term,
      context: 'extracurricular',
      notes: "Test data extracurricular activity"
    )
    created_records[:taggings] << tagging.id
  end

  # Add special programs (random selection)
  program_terms = Term.joins(:vocabulary).where(vocabularies: { code: 'program' })
  program_terms.sample(rand(2..4)).each do |term|
    tagging = school.taggings.create!(
      term: term,
      context: 'program',
      notes: "Test data special program"
    )
    created_records[:taggings] << tagging.id
  end

  # Create Grade Offering
  case school_data[:profile_type]
  when 'premium_international', 'british_international', 'american_international'
    min_age, max_age = [ 3.0, 18.0 ]
    grades = "Pre-K to Grade 12"
  when 'bilingual_thai'
    min_age, max_age = [ 6.0, 18.0 ]
    grades = "Grade 1 to Grade 12"
  when 'local_premium'
    min_age, max_age = [ 6.0, 15.0 ]
    grades = "Grade 1 to Grade 9"
  end

  grade_offering = school.create_school_grade_offering!(
    min_age: min_age,
    max_age: max_age,
    grades: grades,
    notes: "Test data grade offering for #{school_data[:profile_type].humanize.downcase}"
  )
  created_records[:school_grade_offerings] << grade_offering.id

  # Create Fee Schedule
  current_year = Date.current.year
  academic_year = "#{current_year}/#{current_year + 1}"

  tuition_min, tuition_max = school_data[:profile][:tuition_range]

  fee_schedule = school.school_fee_schedules.create!(
    academic_year: academic_year,
    currency: 'THB',
    application_fee: rand(5000..20000),
    enrollment_fee: rand(10000..50000),
    capital_levy: school_data[:profile_type].include?('premium') ? rand(50000..100000) : nil,
    min_tuition: tuition_min,
    max_tuition: tuition_max,
    boarding_fee_annual: school.boarding? ? rand(300000..500000) : nil,
    transport_fee_annual: school.school_bus? ? rand(30000..80000) : nil,
    notes: "Test data fee schedule for academic year #{academic_year}",
    is_published: true
  )
  created_records[:school_fee_schedules] << fee_schedule.id

  # Add fee bands for different grade levels
  if tuition_min != tuition_max
    case school_data[:profile_type]
    when 'premium_international', 'british_international', 'american_international'
      # Early Years (Pre-K to K)
      fee_schedule.school_fee_bands.create!(
        grade_from: 0,
        grade_to: 0,
        annual_tuition: tuition_min
      )
      # Elementary (1-5)
      fee_schedule.school_fee_bands.create!(
        grade_from: 1,
        grade_to: 5,
        annual_tuition: tuition_min + ((tuition_max - tuition_min) * 0.3)
      )
      # Middle School (6-8)
      fee_schedule.school_fee_bands.create!(
        grade_from: 6,
        grade_to: 8,
        annual_tuition: tuition_min + ((tuition_max - tuition_min) * 0.6)
      )
      # High School (9-12)
      fee_schedule.school_fee_bands.create!(
        grade_from: 9,
        grade_to: 12,
        annual_tuition: tuition_max
      )
    else
      # Simple two-tier structure
      fee_schedule.school_fee_bands.create!(
        grade_from: 1,
        grade_to: 6,
        annual_tuition: tuition_min
      )
      fee_schedule.school_fee_bands.create!(
        grade_from: 7,
        grade_to: 12,
        annual_tuition: tuition_max
      )
    end
  end

  # Add Media Items
  media_types = [ 'logo', 'campus_photo', 'brochure' ]
  media_types.each_with_index do |media_type, media_idx|
    media_item = place.media_items.create!(
      kind: media_type,
      url: "https://example.com/test-images/#{school.slug}/#{media_type}_#{media_idx + 1}.jpg",
      alt_text: "#{school.name} #{media_type.humanize}",
      sort_order: media_idx
    )
    created_records[:media_items] << media_item.id
  end

  # Add Events (Open Days)
  2.times do |event_idx|
    event_date = rand(1.week.from_now..3.months.from_now)
    event = place.events.create!(
      title: event_idx == 0 ? "Open Day" : "Information Session",
      starts_at: event_date.change(hour: 9, min: 0),
      ends_at: event_date.change(hour: 12, min: 0),
      location: school.name,
      url: "#{school.website_url}/events/#{event_idx == 0 ? 'open-day' : 'info-session'}",
      description: "Join us for a comprehensive #{event_idx == 0 ? 'open day' : 'information session'} to learn about our programs, facilities, and admission process. Test data event."
    )
    created_records[:events] << event.id
  end
end

puts "\n🎉 Test data creation complete!"
puts "📊 Created:"
puts "   • #{created_records[:places].length} Places"
puts "   • #{created_records[:schools].length} Schools"
puts "   • #{created_records[:school_grade_offerings].length} Grade Offerings"
puts "   • #{created_records[:school_fee_schedules].length} Fee Schedules"
puts "   • #{created_records[:taggings].length} Taxonomy Taggings"
puts "   • #{created_records[:media_items].length} Media Items"
puts "   • #{created_records[:events].length} Events"

# Create cleanup data file for later use
cleanup_data = {
  created_at: Time.current,
  record_ids: created_records
}

cleanup_file_path = Rails.root.join('tmp', 'test_data_cleanup.json')
FileUtils.mkdir_p(File.dirname(cleanup_file_path))
File.write(cleanup_file_path, JSON.pretty_generate(cleanup_data))

puts "\n🧹 Cleanup data saved to: #{cleanup_file_path}"
puts "📝 Run cleanup with: rails runner 'load Rails.root.join(\"db/seeds/cleanup_test_data.rb\")'"

puts "\n✅ All test data has been successfully created!"
puts "🔍 You can now explore the application with realistic school data"
puts "🏫 School types created:"
puts "   • Premium International (10 schools)"
puts "   • British International (10 schools)"
puts "   • American International (10 schools)"
puts "   • Bilingual Thai (10 schools)"
puts "   • Local Premium (10 schools)"
puts "📍 Distributed across #{BANGKOK_DISTRICTS.length} Bangkok districts"
