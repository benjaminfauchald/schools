# Test manual transcript creation to isolate the issue
school = School.find(271) 
video = school.place.youtube_videos.first

puts '🧪 Testing manual transcript processing...'
puts "Video: #{video.title} (#{video.video_id})"

# Create a test transcript
transcript = video.place.transcripts.find_or_create_by(video_id: video.video_id) do |t|
  t.video_title = video.title
  t.video_description = video.description  
  t.video_url = video.youtube_url
  t.status = 'pending'
end

puts "Transcript status: #{transcript.status}"

# Test marking as processing
begin
  transcript.mark_processing!
  puts "✅ mark_processing! succeeded - Status: #{transcript.reload.status}"
rescue => e
  puts "❌ mark_processing! failed: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end

# Test marking as failed
begin
  transcript.mark_failed!('Test error message')
  puts "✅ mark_failed! succeeded - Status: #{transcript.reload.status}"
rescue => e
  puts "❌ mark_failed! failed: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end

# Test marking as completed with minimal data
begin
  transcript.mark_completed!('Test transcript text', [])
  puts "✅ mark_completed! succeeded - Status: #{transcript.reload.status}"
rescue => e
  puts "❌ mark_completed! failed: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end