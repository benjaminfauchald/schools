# School taxonomy seed data - comprehensive vocabularies and terms
# Run with: rails db:seed or rails runner 'load Rails.root.join("db/seeds/taxonomy.rb")'

puts "Seeding school taxonomies..."

# Create Vocabularies
vocabularies_data = [
  {
    code: 'curriculum',
    label: 'Curriculum',
    description: 'Educational curricula and programs offered by schools'
  },
  {
    code: 'accreditation', 
    label: 'Accreditation',
    description: 'Official accreditations and certifications'
  },
  {
    code: 'facility',
    label: 'Facilities',
    description: 'Physical facilities and infrastructure'
  },
  {
    code: 'extracurricular',
    label: 'Extracurricular Activities',
    description: 'Sports, clubs, and additional activities'
  },
  {
    code: 'language',
    label: 'Languages',
    description: 'Languages of instruction and support'
  },
  {
    code: 'program',
    label: 'Special Programs',
    description: 'Special educational programs and services'
  }
]

vocabularies_data.each do |vocab_data|
  vocab = Vocabulary.find_or_create_by(code: vocab_data[:code]) do |v|
    v.label = vocab_data[:label]
    v.description = vocab_data[:description]
  end
  puts "✓ Created vocabulary: #{vocab.label}"
end

# Create Terms
terms_data = [
  # Curriculum Terms
  { vocab: 'curriculum', slug: 'ib_pyp', label: 'IB Primary Years Programme', metadata: { stage: 'PYP', issuer: 'IBO', age_range: '3-12' } },
  { vocab: 'curriculum', slug: 'ib_myp', label: 'IB Middle Years Programme', metadata: { stage: 'MYP', issuer: 'IBO', age_range: '11-16' } },
  { vocab: 'curriculum', slug: 'ib_dp', label: 'IB Diploma Programme', metadata: { stage: 'DP', issuer: 'IBO', age_range: '16-19' } },
  { vocab: 'curriculum', slug: 'uk_eyfs', label: 'UK Early Years Foundation Stage', metadata: { stage: 'Early Years', issuer: 'UK', age_range: '0-5' } },
  { vocab: 'curriculum', slug: 'uk_national', label: 'UK National Curriculum', metadata: { stage: 'Primary/Secondary', issuer: 'UK', age_range: '5-16' } },
  { vocab: 'curriculum', slug: 'uk_igcse', label: 'UK IGCSE', metadata: { stage: 'Secondary', issuer: 'Cambridge/Edexcel', age_range: '14-16' } },
  { vocab: 'curriculum', slug: 'uk_alevel', label: 'UK A-Level', metadata: { stage: 'Pre-University', issuer: 'Cambridge/Edexcel', age_range: '16-18' } },
  { vocab: 'curriculum', slug: 'us_common_core', label: 'US Common Core', metadata: { stage: 'K-12', issuer: 'USA', age_range: '5-18' } },
  { vocab: 'curriculum', slug: 'us_ap', label: 'US Advanced Placement', metadata: { stage: 'High School', issuer: 'College Board', age_range: '15-18' } },
  { vocab: 'curriculum', slug: 'thai_national', label: 'Thai National Curriculum', metadata: { stage: 'All', issuer: 'Thailand', age_range: '3-18' } },
  { vocab: 'curriculum', slug: 'singapore_primary', label: 'Singapore Primary', metadata: { stage: 'Primary', issuer: 'Singapore', age_range: '6-12' } },
  { vocab: 'curriculum', slug: 'montessori', label: 'Montessori Method', metadata: { stage: 'Early Years/Primary', issuer: 'AMI/AMS', age_range: '3-12' } },
  { vocab: 'curriculum', slug: 'waldorf_steiner', label: 'Waldorf/Steiner Education', metadata: { stage: 'All', issuer: 'Waldorf', age_range: '3-18' } },
  
  # Accreditation Terms
  { vocab: 'accreditation', slug: 'cis', label: 'Council of International Schools (CIS)', metadata: { region: 'International', type: 'institutional' } },
  { vocab: 'accreditation', slug: 'wasc', label: 'Western Association of Schools and Colleges', metadata: { region: 'USA/International', type: 'institutional' } },
  { vocab: 'accreditation', slug: 'neasc', label: 'New England Association of Schools and Colleges', metadata: { region: 'USA/International', type: 'institutional' } },
  { vocab: 'accreditation', slug: 'acamis', label: 'Association of China and Mongolia International Schools', metadata: { region: 'Asia', type: 'membership' } },
  { vocab: 'accreditation', slug: 'earcos', label: 'East Asia Regional Council of Schools', metadata: { region: 'East Asia', type: 'membership' } },
  { vocab: 'accreditation', slug: 'cobis', label: 'Council of British International Schools', metadata: { region: 'International', type: 'membership' } },
  { vocab: 'accreditation', slug: 'thai_moe', label: 'Thai Ministry of Education', metadata: { region: 'Thailand', type: 'license' } },
  { vocab: 'accreditation', slug: 'ibo_authorization', label: 'IB Organization Authorization', metadata: { region: 'International', type: 'program' } },
  { vocab: 'accreditation', slug: 'cambridge_international', label: 'Cambridge International School', metadata: { region: 'International', type: 'program' } },
  
  # Facility Terms - Sports
  { vocab: 'facility', slug: 'swimming_pool', label: 'Swimming Pool', metadata: { category: 'Sports', type: 'aquatic' } },
  { vocab: 'facility', slug: 'olympic_pool', label: 'Olympic-sized Pool', metadata: { category: 'Sports', type: 'aquatic', size: 'olympic' } },
  { vocab: 'facility', slug: 'gymnasium', label: 'Gymnasium', metadata: { category: 'Sports', type: 'indoor' } },
  { vocab: 'facility', slug: 'football_field', label: 'Football Field', metadata: { category: 'Sports', type: 'outdoor' } },
  { vocab: 'facility', slug: 'tennis_court', label: 'Tennis Court', metadata: { category: 'Sports', type: 'court' } },
  { vocab: 'facility', slug: 'basketball_court', label: 'Basketball Court', metadata: { category: 'Sports', type: 'court' } },
  { vocab: 'facility', slug: 'track_field', label: 'Track and Field', metadata: { category: 'Sports', type: 'athletics' } },
  { vocab: 'facility', slug: 'sports_hall', label: 'Sports Hall', metadata: { category: 'Sports', type: 'multi_use' } },
  
  # Facility Terms - Academic
  { vocab: 'facility', slug: 'library', label: 'Library', metadata: { category: 'Academic', type: 'learning' } },
  { vocab: 'facility', slug: 'science_labs', label: 'Science Laboratories', metadata: { category: 'Academic', type: 'laboratory' } },
  { vocab: 'facility', slug: 'computer_lab', label: 'Computer Laboratory', metadata: { category: 'Academic', type: 'technology' } },
  { vocab: 'facility', slug: 'maker_space', label: 'Maker Space', metadata: { category: 'Academic', type: 'technology' } },
  { vocab: 'facility', slug: 'robotics_lab', label: 'Robotics Laboratory', metadata: { category: 'Academic', type: 'stem' } },
  
  # Facility Terms - Arts
  { vocab: 'facility', slug: 'art_studio', label: 'Art Studio', metadata: { category: 'Arts', type: 'visual' } },
  { vocab: 'facility', slug: 'music_room', label: 'Music Room', metadata: { category: 'Arts', type: 'performing' } },
  { vocab: 'facility', slug: 'theatre', label: 'Theatre/Auditorium', metadata: { category: 'Arts', type: 'performing' } },
  { vocab: 'facility', slug: 'dance_studio', label: 'Dance Studio', metadata: { category: 'Arts', type: 'performing' } },
  { vocab: 'facility', slug: 'recording_studio', label: 'Recording Studio', metadata: { category: 'Arts', type: 'music' } },
  
  # Facility Terms - Amenities
  { vocab: 'facility', slug: 'cafeteria', label: 'Cafeteria', metadata: { category: 'Amenities', type: 'dining' } },
  { vocab: 'facility', slug: 'medical_center', label: 'Medical Center', metadata: { category: 'Services', type: 'health' } },
  { vocab: 'facility', slug: 'boarding_house', label: 'Boarding House', metadata: { category: 'Accommodation', type: 'residential' } },
  { vocab: 'facility', slug: 'playground', label: 'Playground', metadata: { category: 'Recreation', type: 'outdoor' } },
  { vocab: 'facility', slug: 'bus_service', label: 'School Bus Service', metadata: { category: 'Transport', type: 'service' } },
  
  # Extracurricular Terms - Sports
  { vocab: 'extracurricular', slug: 'football', label: 'Football/Soccer', metadata: { category: 'Sports', type: 'team' } },
  { vocab: 'extracurricular', slug: 'basketball', label: 'Basketball', metadata: { category: 'Sports', type: 'team' } },
  { vocab: 'extracurricular', slug: 'swimming', label: 'Swimming', metadata: { category: 'Sports', type: 'individual' } },
  { vocab: 'extracurricular', slug: 'tennis', label: 'Tennis', metadata: { category: 'Sports', type: 'individual' } },
  { vocab: 'extracurricular', slug: 'volleyball', label: 'Volleyball', metadata: { category: 'Sports', type: 'team' } },
  { vocab: 'extracurricular', slug: 'martial_arts', label: 'Martial Arts', metadata: { category: 'Sports', type: 'combat' } },
  { vocab: 'extracurricular', slug: 'badminton', label: 'Badminton', metadata: { category: 'Sports', type: 'racquet' } },
  { vocab: 'extracurricular', slug: 'track_field_club', label: 'Track and Field', metadata: { category: 'Sports', type: 'athletics' } },
  
  # Extracurricular Terms - STEM
  { vocab: 'extracurricular', slug: 'robotics', label: 'Robotics Club', metadata: { category: 'STEM', type: 'technology' } },
  { vocab: 'extracurricular', slug: 'coding', label: 'Coding/Programming', metadata: { category: 'STEM', type: 'technology' } },
  { vocab: 'extracurricular', slug: 'math_olympiad', label: 'Math Olympiad', metadata: { category: 'STEM', type: 'competition' } },
  { vocab: 'extracurricular', slug: 'science_fair', label: 'Science Fair', metadata: { category: 'STEM', type: 'competition' } },
  { vocab: 'extracurricular', slug: 'engineering_club', label: 'Engineering Club', metadata: { category: 'STEM', type: 'technology' } },
  
  # Extracurricular Terms - Arts
  { vocab: 'extracurricular', slug: 'drama', label: 'Drama/Theatre', metadata: { category: 'Arts', type: 'performing' } },
  { vocab: 'extracurricular', slug: 'music_band', label: 'Music/Band', metadata: { category: 'Arts', type: 'music' } },
  { vocab: 'extracurricular', slug: 'choir', label: 'Choir', metadata: { category: 'Arts', type: 'music' } },
  { vocab: 'extracurricular', slug: 'art_club', label: 'Art Club', metadata: { category: 'Arts', type: 'visual' } },
  { vocab: 'extracurricular', slug: 'photography', label: 'Photography Club', metadata: { category: 'Arts', type: 'visual' } },
  { vocab: 'extracurricular', slug: 'creative_writing', label: 'Creative Writing', metadata: { category: 'Arts', type: 'literary' } },
  
  # Extracurricular Terms - Leadership & Academic
  { vocab: 'extracurricular', slug: 'model_un', label: 'Model United Nations', metadata: { category: 'Leadership', type: 'simulation' } },
  { vocab: 'extracurricular', slug: 'student_council', label: 'Student Council', metadata: { category: 'Leadership', type: 'governance' } },
  { vocab: 'extracurricular', slug: 'debate', label: 'Debate Team', metadata: { category: 'Academic', type: 'competition' } },
  { vocab: 'extracurricular', slug: 'chess', label: 'Chess Club', metadata: { category: 'Academic', type: 'strategy' } },
  { vocab: 'extracurricular', slug: 'yearbook', label: 'Yearbook Committee', metadata: { category: 'Media', type: 'publication' } },
  { vocab: 'extracurricular', slug: 'newspaper', label: 'School Newspaper', metadata: { category: 'Media', type: 'journalism' } },
  
  # Language Terms
  { vocab: 'language', slug: 'english', label: 'English', metadata: { type: 'instruction', family: 'germanic' } },
  { vocab: 'language', slug: 'thai', label: 'Thai', metadata: { type: 'instruction', family: 'tai_kadai' } },
  { vocab: 'language', slug: 'mandarin', label: 'Mandarin Chinese', metadata: { type: 'instruction', family: 'sino_tibetan' } },
  { vocab: 'language', slug: 'japanese', label: 'Japanese', metadata: { type: 'instruction', family: 'japonic' } },
  { vocab: 'language', slug: 'korean', label: 'Korean', metadata: { type: 'instruction', family: 'koreanic' } },
  { vocab: 'language', slug: 'french', label: 'French', metadata: { type: 'instruction', family: 'romance' } },
  { vocab: 'language', slug: 'german', label: 'German', metadata: { type: 'instruction', family: 'germanic' } },
  { vocab: 'language', slug: 'spanish', label: 'Spanish', metadata: { type: 'instruction', family: 'romance' } },
  { vocab: 'language', slug: 'esl', label: 'English as Second Language (ESL)', metadata: { type: 'support', purpose: 'language_learning' } },
  { vocab: 'language', slug: 'mother_tongue', label: 'Mother Tongue Support', metadata: { type: 'support', purpose: 'heritage' } },
  
  # Program Terms
  { vocab: 'program', slug: 'gifted_talented', label: 'Gifted and Talented Program', metadata: { category: 'Academic Support', target: 'high_ability' } },
  { vocab: 'program', slug: 'learning_support', label: 'Learning Support', metadata: { category: 'Special Needs', target: 'learning_differences' } },
  { vocab: 'program', slug: 'sen', label: 'Special Educational Needs (SEN)', metadata: { category: 'Special Needs', target: 'disabilities' } },
  { vocab: 'program', slug: 'counseling', label: 'Counseling Services', metadata: { category: 'Student Support', type: 'mental_health' } },
  { vocab: 'program', slug: 'university_guidance', label: 'University Guidance', metadata: { category: 'Student Support', type: 'career' } },
  { vocab: 'program', slug: 'leadership', label: 'Leadership Development', metadata: { category: 'Character Building', type: 'leadership' } },
  { vocab: 'program', slug: 'community_service', label: 'Community Service', metadata: { category: 'Character Building', type: 'service' } },
  { vocab: 'program', slug: 'outdoor_education', label: 'Outdoor Education', metadata: { category: 'Experiential Learning', type: 'outdoor' } },
  { vocab: 'program', slug: 'exchange_program', label: 'Student Exchange Program', metadata: { category: 'International', type: 'cultural' } },
  { vocab: 'program', slug: 'summer_school', label: 'Summer School', metadata: { category: 'Extended Learning', season: 'summer' } },
  { vocab: 'program', slug: 'after_school', label: 'After School Program', metadata: { category: 'Extended Learning', time: 'after_hours' } }
]

terms_data.each do |term_data|
  vocabulary = Vocabulary.find_by!(code: term_data[:vocab])
  
  term = Term.find_or_create_by(
    vocabulary: vocabulary,
    slug: term_data[:slug]
  ) do |t|
    t.label = term_data[:label]
    t.metadata = term_data[:metadata] || {}
  end
  
  puts "✓ Created term: #{vocabulary.label} > #{term.label}"
end

# Create some hierarchical terms (parent-child relationships)
hierarchy_data = [
  # STEM parent category with children
  { parent_vocab: 'extracurricular', parent_slug: 'stem_club', parent_label: 'STEM Club',
    children: %w[robotics coding math_olympiad science_fair engineering_club] },
    
  # Arts parent category
  { parent_vocab: 'extracurricular', parent_slug: 'arts_program', parent_label: 'Arts Program',
    children: %w[drama music_band choir art_club photography creative_writing] },
    
  # Sports categories
  { parent_vocab: 'extracurricular', parent_slug: 'team_sports', parent_label: 'Team Sports',
    children: %w[football basketball volleyball] },
    
  { parent_vocab: 'extracurricular', parent_slug: 'individual_sports', parent_label: 'Individual Sports', 
    children: %w[swimming tennis badminton track_field_club martial_arts] }
]

hierarchy_data.each do |hierarchy|
  vocabulary = Vocabulary.find_by!(code: hierarchy[:parent_vocab])
  
  # Create parent term
  parent_term = Term.find_or_create_by(
    vocabulary: vocabulary,
    slug: hierarchy[:parent_slug]
  ) do |t|
    t.label = hierarchy[:parent_label]
    t.metadata = { category: 'Parent Category' }
  end
  
  # Update children to have this parent
  hierarchy[:children].each do |child_slug|
    child_term = Term.find_by(vocabulary: vocabulary, slug: child_slug)
    if child_term
      child_term.update(parent: parent_term)
      puts "✓ Linked #{child_term.label} to parent #{parent_term.label}"
    end
  end
end

puts "\n✅ Taxonomy seeding complete!"
puts "Created #{Vocabulary.count} vocabularies and #{Term.count} terms"
puts "Vocabularies: #{Vocabulary.pluck(:label).join(', ')}"
puts "\nTerm counts by vocabulary:"
Vocabulary.includes(:terms).each do |vocab|
  puts "  #{vocab.label}: #{vocab.terms.count} terms"
end