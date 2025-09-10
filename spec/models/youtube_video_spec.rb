require 'rails_helper'

RSpec.describe YoutubeVideo, type: :model do
  let(:school) { create(:school) }
  let(:place) { create(:place, school: school) }
  let(:youtube_video) { create(:youtube_video, place: place) }

  describe 'associations' do
    it { should belong_to(:place) }
  end

  describe 'validations' do
    it { should validate_presence_of(:video_id) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:thumbnail_url) }
    
    it 'validates uniqueness of video_id scoped to place_id' do
      existing_video = create(:youtube_video, place: place, video_id: "abc123")
      new_video = build(:youtube_video, place: place, video_id: "abc123")
      expect(new_video).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:visible_video) { create(:youtube_video, place: place, visible: true, sort_order: 2) }
    let!(:hidden_video) { create(:youtube_video, place: place, visible: false, sort_order: 1) }
    let!(:first_video) { create(:youtube_video, place: place, visible: true, sort_order: 1) }

    describe '.visible' do
      it 'returns only visible videos' do
        expect(YoutubeVideo.visible).to include(visible_video, first_video)
        expect(YoutubeVideo.visible).not_to include(hidden_video)
      end
    end

    describe '.ordered' do
      it 'orders by sort_order then created_at' do
        expect(YoutubeVideo.ordered.first).to eq(hidden_video)
        expect(YoutubeVideo.ordered.second).to eq(first_video)
        expect(YoutubeVideo.ordered.third).to eq(visible_video)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        old_video = create(:youtube_video, place: place, created_at: 2.days.ago)
        new_video = create(:youtube_video, place: place, created_at: 1.hour.ago)
        expect(YoutubeVideo.recent.first).to eq(new_video)
        expect(YoutubeVideo.recent.last).to eq(old_video)
      end
    end
  end

  describe 'instance methods' do
    before { youtube_video.update(video_id: "abc123xyz") }

    describe '#youtube_url' do
      it 'returns the YouTube watch URL' do
        expect(youtube_video.youtube_url).to eq("https://www.youtube.com/watch?v=abc123xyz")
      end
    end

    describe '#youtube_embed_url' do
      it 'returns the YouTube embed URL' do
        expect(youtube_video.youtube_embed_url).to eq("https://www.youtube.com/embed/abc123xyz?autoplay=1&rel=0")
      end
    end

    describe '#hq_thumbnail_url' do
      it 'returns the high quality thumbnail URL' do
        expect(youtube_video.hq_thumbnail_url).to eq("https://img.youtube.com/vi/abc123xyz/hqdefault.jpg")
      end
    end

    describe '#video_key' do
      it 'returns the video_id as key' do
        expect(youtube_video.video_key).to eq("abc123xyz")
      end
    end

    describe '#duration_display' do
      it 'returns duration when present' do
        youtube_video.update(duration: "5:30")
        expect(youtube_video.duration_display).to eq("5:30")
      end

      it 'falls back to video_data duration' do
        youtube_video.update(duration: nil, video_data: { "duration" => "3:45" })
        expect(youtube_video.duration_display).to eq("3:45")
      end

      it 'returns nil when no duration available' do
        youtube_video.update(duration: nil, video_data: {})
        expect(youtube_video.duration_display).to be_nil
      end
    end

    describe '#view_count_display' do
      it 'formats millions of views' do
        youtube_video.update(view_count: 2_500_000)
        expect(youtube_video.view_count_display).to eq("2.5M views")
      end

      it 'formats thousands of views' do
        youtube_video.update(view_count: 15_500)
        expect(youtube_video.view_count_display).to eq("15.5K views")
      end

      it 'formats hundreds of views' do
        youtube_video.update(view_count: 850)
        expect(youtube_video.view_count_display).to eq("850 views")
      end

      it 'returns nil when view_count nil' do
        youtube_video.update(view_count: nil)
        expect(youtube_video.view_count_display).to be_nil
      end
    end

    describe 'transcript-related methods' do
      let(:transcript) { create(:transcript, place: place, video_id: youtube_video.video_id) }

      describe '#transcript_record' do
        it 'finds the associated transcript by video_id' do
          transcript
          expect(youtube_video.transcript_record).to eq(transcript)
        end

        it 'returns nil when no transcript exists' do
          expect(youtube_video.transcript_record).to be_nil
        end
      end

      describe '#has_transcript?' do
        it 'returns true when completed transcript exists' do
          transcript.update(status: "completed")
          expect(youtube_video.has_transcript?).to be true
        end

        it 'returns false when transcript not completed' do
          transcript.update(status: "pending")
          expect(youtube_video.has_transcript?).to be false
        end

        it 'returns false when no transcript exists' do
          expect(youtube_video.has_transcript?).to be false
        end
      end

      describe '#transcript_status' do
        it 'returns transcript status when exists' do
          transcript.update(status: "processing")
          expect(youtube_video.transcript_status).to eq("processing")
        end

        it 'returns "not_started" when no transcript' do
          expect(youtube_video.transcript_status).to eq("not_started")
        end
      end

      describe '#transcript_available?' do
        it 'returns true by default' do
          expect(youtube_video.transcript_available?).to be true
        end
      end

      describe '#queue_transcript_processing' do
        it 'enqueues processing job' do
          expect {
            youtube_video.queue_transcript_processing
          }.to have_enqueued_job(ProcessVideoTranscriptJob).with(youtube_video.id, place.id, {})
        end

        it 'returns true when queued' do
          expect(youtube_video.queue_transcript_processing).to be true
        end
      end

      describe '#transcript_processing_status' do
        context 'when transcript completed' do
          before { transcript.update(status: "completed", ai_enabled: true) }

          it 'returns completed status with AI enabled' do
            status = youtube_video.transcript_processing_status
            expect(status[:status]).to eq("completed")
            expect(status[:message]).to eq("Transcript used for AI")
            expect(status[:badge_class]).to eq("success")
            expect(status[:ai_enabled]).to be true
          end

          it 'returns completed_disabled when AI disabled' do
            transcript.update(ai_enabled: false)
            status = youtube_video.transcript_processing_status
            expect(status[:status]).to eq("completed_disabled")
            expect(status[:message]).to eq("Transcript not used for AI")
          end
        end

        context 'when transcript processing' do
          before { transcript.update(status: "processing", updated_at: 2.minutes.ago) }

          it 'returns processing status with time' do
            status = youtube_video.transcript_processing_status
            expect(status[:status]).to eq("processing")
            expect(status[:message]).to match(/Processing \(\d+m\)/)
          end

          it 'returns failed when processing timed out' do
            transcript.update(updated_at: 15.minutes.ago)
            status = youtube_video.transcript_processing_status
            expect(status[:status]).to eq("failed")
            expect(status[:message]).to eq("Processing timed out")
          end
        end

        context 'when transcript failed' do
          before { transcript.update(status: "failed") }

          it 'returns failed status' do
            status = youtube_video.transcript_processing_status
            expect(status[:status]).to eq("failed")
            expect(status[:message]).to eq("Transcript failed")
          end
        end

        context 'when no transcript' do
          it 'returns not_started status' do
            status = youtube_video.transcript_processing_status
            expect(status[:status]).to eq("not_started")
            expect(status[:message]).to eq("No transcript")
          end
        end
      end

      describe '#can_retry_transcript?' do
        it 'returns true for failed transcripts' do
          transcript.update(status: "failed")
          expect(youtube_video.can_retry_transcript?).to be true
        end

        it 'returns true for not_started status' do
          expect(youtube_video.can_retry_transcript?).to be true
        end

        it 'returns true for timed out processing' do
          transcript.update(status: "processing", updated_at: 15.minutes.ago)
          expect(youtube_video.can_retry_transcript?).to be true
        end

        it 'returns false for no_transcript status' do
          transcript.update(status: "no_transcript")
          expect(youtube_video.can_retry_transcript?).to be false
        end

        it 'returns false for active processing' do
          transcript.update(status: "processing", updated_at: 2.minutes.ago)
          expect(youtube_video.can_retry_transcript?).to be false
        end
      end

      describe '#transcript_segments_count' do
        it 'returns count of transcript segments' do
          create_list(:transcript_segment, 3, transcript: transcript)
          expect(youtube_video.transcript_segments_count).to eq(3)
        end

        it 'returns 0 when no transcript' do
          expect(youtube_video.transcript_segments_count).to eq(0)
        end
      end
    end
  end
end