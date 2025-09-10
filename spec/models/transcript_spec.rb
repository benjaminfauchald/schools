require 'rails_helper'

RSpec.describe Transcript, type: :model do
  let(:school) { create(:school) }
  let(:place) { create(:place, school: school) }
  let(:transcript) { create(:transcript, place: place) }

  describe 'associations' do
    it { should belong_to(:place) }
    it { should have_many(:transcript_segments).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:video_id) }
    it { should validate_presence_of(:place) }
    
    it 'validates uniqueness of video_id scoped to place_id' do
      existing_transcript = create(:transcript, place: place, video_id: "abc123")
      new_transcript = build(:transcript, place: place, video_id: "abc123")
      expect(new_transcript).not_to be_valid
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).backed_by_column_of_type(:string).with_values(
      pending: "pending",
      processing: "processing", 
      completed: "completed",
      failed: "failed",
      no_transcript: "no_transcript"
    ) }
  end

  describe 'scopes' do
    describe '.processed' do
      it 'returns completed transcripts' do
        completed_transcript = create(:transcript, place: place, status: "completed")
        failed_transcript = create(:transcript, place: create(:place, school: school), status: "failed")
        pending_transcript = create(:transcript, place: create(:place, school: school), status: "pending")
        
        expect(Transcript.processed).to include(completed_transcript)
        expect(Transcript.processed).not_to include(failed_transcript, pending_transcript)
      end
    end

    describe '.failed' do
      it 'returns failed transcripts' do
        completed_transcript = create(:transcript, place: place, status: "completed")
        failed_transcript = create(:transcript, place: create(:place, school: school), status: "failed")
        
        expect(Transcript.failed).to include(failed_transcript)
        expect(Transcript.failed).not_to include(completed_transcript)
      end
    end

    describe '.pending_processing' do
      it 'returns pending and processing transcripts' do
        pending_transcript = create(:transcript, place: place, status: "pending")
        processing_transcript = create(:transcript, place: create(:place, school: school), status: "processing")
        completed_transcript = create(:transcript, place: create(:place, school: school), status: "completed")
        
        expect(Transcript.pending_processing).to include(pending_transcript, processing_transcript)
        expect(Transcript.pending_processing).not_to include(completed_transcript)
      end
    end

    describe '.ai_enabled' do
      it 'returns AI enabled transcripts' do
        ai_enabled_transcript = create(:transcript, place: place, ai_enabled: true)
        ai_disabled_transcript = create(:transcript, place: create(:place, school: school), ai_enabled: false)
        
        expect(Transcript.ai_enabled).to include(ai_enabled_transcript)
        expect(Transcript.ai_enabled).not_to include(ai_disabled_transcript)
      end
    end

    describe '.with_embeddings' do
      it 'returns transcripts with embeddings' do
        transcript_with_embedding = create(:transcript, place: place)
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcripts SET vector_embedding = '#{vector}' WHERE id = #{transcript_with_embedding.id}")
        transcript_with_embedding.reload
        
        transcript_without = create(:transcript, place: create(:place, school: school))
        
        expect(Transcript.with_embeddings).to include(transcript_with_embedding)
        expect(Transcript.with_embeddings).not_to include(transcript_without)
      end
    end

    describe '.cleaned' do
      it 'returns transcripts with cleaned text' do
        cleaned_transcript = create(:transcript, place: place, cleaned_transcript: "Clean text", transcript_cleaned_at: Time.current)
        uncleaned_transcript = create(:transcript, place: create(:place, school: school), cleaned_transcript: nil)
        
        expect(Transcript.cleaned).to include(cleaned_transcript)
        expect(Transcript.cleaned).not_to include(uncleaned_transcript)
      end
    end

    describe '.needs_cleaning' do
      it 'returns transcripts needing cleaning' do
        needs_cleaning = create(:transcript, place: place, full_transcript: "Raw text", cleaned_transcript: nil)
        already_cleaned = create(:transcript, place: create(:place, school: school), full_transcript: "Raw", cleaned_transcript: "Clean")
        
        expect(Transcript.needs_cleaning).to include(needs_cleaning)
        expect(Transcript.needs_cleaning).not_to include(already_cleaned)
      end
    end
  end

  describe 'instance methods' do
    describe '#processed?' do
      it 'returns true when completed with transcript' do
        transcript.update(status: "completed", full_transcript: "Some text")
        expect(transcript.processed?).to be true
      end

      it 'returns false when not completed' do
        transcript.update(status: "pending")
        expect(transcript.processed?).to be false
      end

      it 'returns false when completed but no transcript' do
        transcript.update(status: "completed", full_transcript: nil)
        expect(transcript.processed?).to be false
      end
    end

    describe '#available_for_ai?' do
      it 'returns true when processed and AI enabled' do
        transcript.update(status: "completed", full_transcript: "Text", ai_enabled: true)
        expect(transcript.available_for_ai?).to be true
      end

      it 'returns false when not processed' do
        transcript.update(status: "pending", ai_enabled: true)
        expect(transcript.available_for_ai?).to be false
      end

      it 'returns false when AI disabled' do
        transcript.update(status: "completed", full_transcript: "Text", ai_enabled: false)
        expect(transcript.available_for_ai?).to be false
      end
    end

    describe '#has_segments?' do
      it 'returns true when segments exist' do
        create(:transcript_segment, transcript: transcript)
        expect(transcript.has_segments?).to be true
      end

      it 'returns false when no segments' do
        expect(transcript.has_segments?).to be false
      end
    end

    describe '#duration_display' do
      it 'formats duration in hours, minutes, seconds' do
        transcript.update(duration_seconds: 3665)
        expect(transcript.duration_display).to eq("1h 1m 5s")
      end

      it 'formats duration in minutes, seconds' do
        transcript.update(duration_seconds: 125)
        expect(transcript.duration_display).to eq("2m 5s")
      end

      it 'formats duration in seconds only' do
        transcript.update(duration_seconds: 45)
        expect(transcript.duration_display).to eq("45s")
      end

      it 'returns "Unknown duration" when nil' do
        transcript.update(duration_seconds: nil)
        expect(transcript.duration_display).to eq("Unknown duration")
      end
    end

    describe '#youtube_url' do
      it 'returns video_url when present' do
        transcript.update(video_url: "https://youtube.com/watch?v=custom")
        expect(transcript.youtube_url).to eq("https://youtube.com/watch?v=custom")
      end

      it 'generates URL from video_id when video_url blank' do
        transcript.update(video_id: "abc123", video_url: nil)
        expect(transcript.youtube_url).to eq("https://www.youtube.com/watch?v=abc123")
      end
    end

    describe '#search_content' do
      it 'finds matching segments' do
        segment1 = create(:transcript_segment, transcript: transcript, text: "Ruby on Rails", segment_index: 0)
        segment2 = create(:transcript_segment, transcript: transcript, text: "Python Django", segment_index: 1)
        
        result = transcript.search_content("Rails")
        expect(result[:segments]).to include(segment1)
        expect(result[:segments]).not_to include(segment2)
        expect(result[:matches]).to eq(1)
      end

      it 'returns empty array for blank query' do
        create(:transcript_segment, transcript: transcript, text: "Some text", segment_index: 0)
        expect(transcript.search_content("")).to eq([])
      end
    end

    describe '#cleaned?' do
      it 'returns true when cleaned_transcript and timestamp present' do
        transcript.update(cleaned_transcript: "Clean text", transcript_cleaned_at: Time.current)
        expect(transcript.cleaned?).to be true
      end

      it 'returns false when cleaned_transcript missing' do
        transcript.update(cleaned_transcript: nil, transcript_cleaned_at: Time.current)
        expect(transcript.cleaned?).to be false
      end
    end

    describe '#best_transcript_content' do
      it 'returns cleaned transcript when available' do
        transcript.update(cleaned_transcript: "Clean", full_transcript: "Raw")
        expect(transcript.best_transcript_content).to eq("Clean")
      end

      it 'returns full transcript when cleaned not available' do
        transcript.update(cleaned_transcript: nil, full_transcript: "Raw")
        expect(transcript.best_transcript_content).to eq("Raw")
      end
    end

    describe '#needs_cleaning?' do
      it 'returns true when processed, AI enabled, has full transcript but no cleaned' do
        transcript.update(
          status: "completed",
          ai_enabled: true,
          full_transcript: "Raw text",
          cleaned_transcript: nil
        )
        expect(transcript.needs_cleaning?).to be true
      end

      it 'returns false when already cleaned' do
        transcript.update(
          status: "completed",
          ai_enabled: true,
          full_transcript: "Raw",
          cleaned_transcript: "Clean"
        )
        expect(transcript.needs_cleaning?).to be false
      end
    end

    describe '#has_embedding?' do
      it 'returns true when vector_embedding present' do
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcripts SET vector_embedding = '#{vector}' WHERE id = #{transcript.id}")
        transcript.reload
        expect(transcript.has_embedding?).to be true
      end

      it 'returns false when vector_embedding nil' do
        transcript.update(vector_embedding: nil)
        expect(transcript.has_embedding?).to be false
      end
    end

    describe '#embedding_up_to_date?' do
      it 'returns true when embedding generated recently' do
        transcript.update(embedding_generated_at: 5.days.ago)
        expect(transcript.embedding_up_to_date?).to be true
      end

      it 'returns false when embedding old' do
        transcript.update(embedding_generated_at: 40.days.ago)
        expect(transcript.embedding_up_to_date?).to be false
      end

      it 'returns false when embedding_generated_at nil' do
        transcript.update(embedding_generated_at: nil)
        expect(transcript.embedding_up_to_date?).to be false
      end
    end

    describe '#ready_for_embedding?' do
      it 'returns true when cleaned but no embedding' do
        transcript.update(
          cleaned_transcript: "Clean",
          transcript_cleaned_at: Time.current,
          vector_embedding: nil
        )
        expect(transcript.ready_for_embedding?).to be true
      end

      it 'returns false when not cleaned' do
        transcript.update(cleaned_transcript: nil, vector_embedding: nil)
        expect(transcript.ready_for_embedding?).to be false
      end

      it 'returns false when already has embedding' do
        transcript.update(
          cleaned_transcript: "Clean",
          transcript_cleaned_at: Time.current
        )
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcripts SET vector_embedding = '#{vector}' WHERE id = #{transcript.id}")
        transcript.reload
        expect(transcript.ready_for_embedding?).to be false
      end
    end

    describe '#mark_processing!' do
      it 'updates status to processing' do
        transcript.mark_processing!
        expect(transcript.reload.status).to eq("processing")
        expect(transcript.processing_error).to be_nil
        expect(transcript.processed_at).to be_present
      end
    end

    describe '#mark_completed!' do
      it 'updates status to completed with transcript' do
        transcript.mark_completed!("Transcript text")
        expect(transcript.reload.status).to eq("completed")
        expect(transcript.full_transcript).to eq("Transcript text")
        expect(transcript.processing_error).to be_nil
      end

      it 'creates segments when provided' do
        segments_data = [
          { text: "First segment", start_time: 0, end_time: 10 },
          { text: "Second segment", start_time: 10, end_time: 20 }
        ]
        
        expect {
          transcript.mark_completed!("Full text", segments_data)
        }.to change { transcript.transcript_segments.count }.by(2)
      end
    end

    describe '#mark_failed!' do
      it 'updates status to failed with error' do
        transcript.mark_failed!("API error")
        expect(transcript.reload.status).to eq("failed")
        expect(transcript.processing_error).to eq("API error")
      end
    end

    describe '#mark_no_transcript!' do
      it 'updates status to no_transcript with reason' do
        transcript.mark_no_transcript!("No captions available")
        expect(transcript.reload.status).to eq("no_transcript")
        expect(transcript.processing_error).to eq("No captions available")
      end
    end

    describe '#ai_context_data' do
      it 'exports transcript data for AI context' do
        transcript.update(
          video_id: "abc123",
          video_title: "Test Video",
          video_description: "Description",
          full_transcript: "Content",
          duration_seconds: 120,
          language: "en"
        )
        
        data = transcript.ai_context_data
        expect(data[:video_id]).to eq("abc123")
        expect(data[:title]).to eq("Test Video")
        expect(data[:content]).to eq("Content")
        expect(data[:duration]).to eq("2m 0s")
      end
    end
  end

  describe 'class methods' do
    describe '.processing_stats' do
      before do
        create_list(:transcript, 2, place: place, status: "completed")
        create(:transcript, place: place, status: "failed")
        create(:transcript, place: place, status: "pending")
        t = create(:transcript, place: place)
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcripts SET vector_embedding = '#{vector}' WHERE id = #{t.id}")
        t.reload
      end

      it 'returns processing statistics' do
        stats = Transcript.processing_stats
        expect(stats[:total]).to eq(5)
        expect(stats[:completed]).to eq(2)
        expect(stats[:failed]).to eq(1)
        expect(stats[:pending]).to eq(1)
        expect(stats[:with_embeddings]).to eq(1)
      end
    end

    describe '.search_by_content' do
      let!(:matching_transcript) { create(:transcript, place: place, status: "completed", full_transcript: "Ruby on Rails", video_title: "Rails Tutorial") }
      let!(:non_matching) { create(:transcript, place: place, status: "completed", full_transcript: "Python Django") }

      it 'finds transcripts matching query' do
        results = Transcript.search_by_content("Rails")
        expect(results).to include(matching_transcript)
        expect(results).not_to include(non_matching)
      end

      it 'searches in video title too' do
        results = Transcript.search_by_content("Tutorial")
        expect(results).to include(matching_transcript)
      end

      it 'returns empty for blank query' do
        expect(Transcript.search_by_content("")).to be_empty
      end

      it 'limits results' do
        10.times { create(:transcript, place: place, status: "completed", full_transcript: "Rails") }
        results = Transcript.search_by_content("Rails", limit: 5)
        expect(results.count).to eq(5)
      end
    end
  end
end