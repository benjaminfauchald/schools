require 'rails_helper'

RSpec.describe TranscriptSegment, type: :model do
  let(:school) { create(:school) }
  let(:place) { create(:place, school: school) }
  let(:transcript) { create(:transcript, place: place, video_id: "abc123") }
  let(:segment) { create(:transcript_segment, transcript: transcript) }

  describe 'associations' do
    it { should belong_to(:transcript) }
  end

  describe 'validations' do
    it { should validate_presence_of(:transcript) }
    it { should validate_presence_of(:segment_index) }
    it { should validate_presence_of(:text) }
    
    it 'validates uniqueness of segment_index scoped to transcript_id' do
      existing_segment = create(:transcript_segment, transcript: transcript, segment_index: 0)
      new_segment = build(:transcript_segment, transcript: transcript, segment_index: 0)
      expect(new_segment).not_to be_valid
    end
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'orders by segment_index' do
        segment3 = create(:transcript_segment, transcript: transcript, segment_index: 2)
        segment1 = create(:transcript_segment, transcript: transcript, segment_index: 0)
        segment2 = create(:transcript_segment, transcript: transcript, segment_index: 1)
        
        expect(TranscriptSegment.ordered).to eq([segment1, segment2, segment3])
      end
    end

    describe '.by_speaker' do
      it 'filters by speaker' do
        speaker_segment = create(:transcript_segment, transcript: transcript, speaker: "John", segment_index: 0)
        no_speaker_segment = create(:transcript_segment, transcript: transcript, speaker: nil, segment_index: 1)
        
        expect(TranscriptSegment.by_speaker("John")).to include(speaker_segment)
        expect(TranscriptSegment.by_speaker("John")).not_to include(no_speaker_segment)
      end

      it 'returns all when speaker is blank' do
        segment1 = create(:transcript_segment, transcript: transcript, segment_index: 0)
        segment2 = create(:transcript_segment, transcript: transcript, segment_index: 1)
        
        expect(TranscriptSegment.by_speaker(nil)).to include(segment1, segment2)
      end
    end

    describe '.by_time_range' do
      it 'filters by time range' do
        early_segment = create(:transcript_segment, transcript: transcript, start_time: 0, end_time: 10, segment_index: 0)
        late_segment = create(:transcript_segment, transcript: transcript, start_time: 20, end_time: 30, segment_index: 1)
        
        results = TranscriptSegment.by_time_range(0, 15)
        expect(results).to include(early_segment)
        expect(results).not_to include(late_segment)
      end
    end

    describe '.with_confidence_above' do
      it 'filters by confidence threshold' do
        high_confidence = create(:transcript_segment, transcript: transcript, confidence: 0.9, segment_index: 0)
        low_confidence = create(:transcript_segment, transcript: transcript, confidence: 0.5, segment_index: 1)
        
        results = TranscriptSegment.with_confidence_above(0.8)
        expect(results).to include(high_confidence)
        expect(results).not_to include(low_confidence)
      end
    end

    describe '.with_embeddings' do
      it 'returns segments with embeddings' do
        segment_with_embedding = create(:transcript_segment, transcript: transcript, segment_index: 0)
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcript_segments SET vector_embedding = '#{vector}' WHERE id = #{segment_with_embedding.id}")
        segment_with_embedding.reload
        
        segment_without = create(:transcript_segment, transcript: transcript, vector_embedding: nil, segment_index: 1)
        
        expect(TranscriptSegment.with_embeddings).to include(segment_with_embedding)
        expect(TranscriptSegment.with_embeddings).not_to include(segment_without)
      end
    end
  end

  describe 'instance methods' do
    describe '#duration' do
      it 'calculates duration from start and end time' do
        segment.update(start_time: 10.5, end_time: 25.5)
        expect(segment.duration).to eq(15.0)
      end

      it 'returns nil when times missing' do
        segment.update(start_time: nil, end_time: 25)
        expect(segment.duration).to be_nil
      end
    end

    describe '#duration_display' do
      it 'formats short duration in seconds' do
        segment.update(start_time: 0, end_time: 45.5)
        expect(segment.duration_display).to eq("45.5s")
      end

      it 'formats long duration in minutes and seconds' do
        segment.update(start_time: 0, end_time: 125.5)
        expect(segment.duration_display).to eq("2m 5.5s")
      end

      it 'returns "Unknown" when duration nil' do
        segment.update(start_time: nil, end_time: nil)
        expect(segment.duration_display).to eq("Unknown")
      end
    end

    describe '#time_range_display' do
      it 'formats time range' do
        segment.update(start_time: 65, end_time: 125)
        expect(segment.time_range_display).to eq("1:05 - 2:05")
      end

      it 'handles hours' do
        segment.update(start_time: 3665, end_time: 3725)
        expect(segment.time_range_display).to eq("1:01:05 - 1:02:05")
      end

      it 'returns "Unknown time" when times missing' do
        segment.update(start_time: nil, end_time: nil)
        expect(segment.time_range_display).to eq("Unknown time")
      end
    end

    describe '#youtube_url_with_timestamp' do
      it 'adds timestamp to YouTube URL' do
        segment.update(start_time: 120)
        expect(segment.youtube_url_with_timestamp).to eq("https://www.youtube.com/watch?v=abc123&t=120s")
      end

      it 'returns base URL when no start_time' do
        segment.update(start_time: nil)
        expect(segment.youtube_url_with_timestamp).to eq("https://www.youtube.com/watch?v=abc123")
      end
    end

    describe '#matches_query?' do
      before { segment.update(text: "Ruby on Rails development") }

      it 'returns true for matching query' do
        expect(segment.matches_query?("Rails")).to be true
      end

      it 'returns false for non-matching query' do
        expect(segment.matches_query?("Python")).to be false
      end

      it 'is case insensitive' do
        expect(segment.matches_query?("RUBY")).to be true
      end

      it 'returns false for blank query' do
        expect(segment.matches_query?("")).to be false
      end
    end

    describe '#has_embedding?' do
      it 'returns true when vector_embedding present' do
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcript_segments SET vector_embedding = '#{vector}' WHERE id = #{segment.id}")
        segment.reload
        expect(segment.has_embedding?).to be true
      end

      it 'returns false when vector_embedding nil' do
        segment.update(vector_embedding: nil)
        expect(segment.has_embedding?).to be false
      end
    end

    describe '#embedding_up_to_date?' do
      it 'returns true when embedding generated recently' do
        segment.update(embedding_generated_at: 5.days.ago)
        expect(segment.embedding_up_to_date?).to be true
      end

      it 'returns false when embedding old' do
        segment.update(embedding_generated_at: 40.days.ago)
        expect(segment.embedding_up_to_date?).to be false
      end

      it 'returns false when embedding_generated_at nil' do
        segment.update(embedding_generated_at: nil)
        expect(segment.embedding_up_to_date?).to be false
      end
    end

    describe '#ai_context_data' do
      it 'exports segment data for AI context' do
        segment.update(
          segment_index: 5,
          text: "Test content",
          start_time: 10,
          end_time: 20,
          speaker: "John",
          confidence: 0.95
        )
        
        data = segment.ai_context_data
        expect(data[:segment_index]).to eq(5)
        expect(data[:text]).to eq("Test content")
        expect(data[:duration]).to eq(10)
        expect(data[:speaker]).to eq("John")
        expect(data[:confidence]).to eq(0.95)
      end
    end

    describe '#surrounding_context' do
      let!(:seg1) { create(:transcript_segment, transcript: transcript, segment_index: 0, text: "First") }
      let!(:seg2) { create(:transcript_segment, transcript: transcript, segment_index: 1, text: "Second") }
      let!(:seg3) { create(:transcript_segment, transcript: transcript, segment_index: 2, text: "Third") }
      let!(:seg4) { create(:transcript_segment, transcript: transcript, segment_index: 3, text: "Fourth") }

      it 'returns surrounding segments' do
        context = seg2.surrounding_context(before: 1, after: 1)
        expect(context).to eq([seg1, seg2, seg3])
      end

      it 'handles edge cases at start' do
        context = seg1.surrounding_context(before: 2, after: 1)
        expect(context).to eq([seg1, seg2])
      end

      it 'handles edge cases at end' do
        context = seg4.surrounding_context(before: 1, after: 2)
        expect(context).to eq([seg3, seg4])
      end
    end

    describe '#next_segment and #previous_segment' do
      let!(:seg1) { create(:transcript_segment, transcript: transcript, segment_index: 0) }
      let!(:seg2) { create(:transcript_segment, transcript: transcript, segment_index: 1) }
      let!(:seg3) { create(:transcript_segment, transcript: transcript, segment_index: 2) }

      it '#next_segment returns the next segment' do
        expect(seg1.next_segment).to eq(seg2)
        expect(seg2.next_segment).to eq(seg3)
        expect(seg3.next_segment).to be_nil
      end

      it '#previous_segment returns the previous segment' do
        expect(seg3.previous_segment).to eq(seg2)
        expect(seg2.previous_segment).to eq(seg1)
        expect(seg1.previous_segment).to be_nil
      end
    end

    describe '#likely_important?' do
      it 'identifies important content patterns' do
        segment.update(text: "The most important finding is...")
        expect(segment.likely_important?).to be true

        segment.update(text: "In conclusion, we found that...")
        expect(segment.likely_important?).to be true

        segment.update(text: "What is the main purpose?")
        expect(segment.likely_important?).to be true

        segment.update(text: "First, we need to consider...")
        expect(segment.likely_important?).to be true

        segment.update(text: "However, this contradicts...")
        expect(segment.likely_important?).to be true
      end

      it 'returns false for non-important content' do
        segment.update(text: "Just some regular text")
        expect(segment.likely_important?).to be false
      end

      it 'returns false for blank text' do
        segment.update(text: "")
        expect(segment.likely_important?).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.search_by_content' do
      let!(:completed_transcript) { create(:transcript, place: place, status: "completed") }
      let!(:matching_segment) { create(:transcript_segment, transcript: completed_transcript, text: "Ruby on Rails") }
      let!(:non_matching) { create(:transcript_segment, transcript: completed_transcript, text: "Python Django") }

      it 'finds segments matching query' do
        results = TranscriptSegment.search_by_content("Rails")
        expect(results).to include(matching_segment)
        expect(results).not_to include(non_matching)
      end

      it 'only includes segments from completed transcripts' do
        pending_transcript = create(:transcript, place: place, status: "pending")
        pending_segment = create(:transcript_segment, transcript: pending_transcript, text: "Rails")
        
        results = TranscriptSegment.search_by_content("Rails")
        expect(results).not_to include(pending_segment)
      end

      it 'returns empty for blank query' do
        expect(TranscriptSegment.search_by_content("")).to be_empty
      end

      it 'limits results' do
        10.times do |i|
          create(:transcript_segment, transcript: completed_transcript, text: "Rails", segment_index: 10 + i)
        end
        results = TranscriptSegment.search_by_content("Rails", limit: 5)
        expect(results.count).to eq(5)
      end
    end

    describe '.by_transcript_ids' do
      let(:other_transcript) { create(:transcript, place: place) }
      let!(:segment1) { create(:transcript_segment, transcript: transcript) }
      let!(:segment2) { create(:transcript_segment, transcript: other_transcript) }

      it 'filters by transcript IDs' do
        results = TranscriptSegment.by_transcript_ids([transcript.id])
        expect(results).to include(segment1)
        expect(results).not_to include(segment2)
      end
    end
  end
end