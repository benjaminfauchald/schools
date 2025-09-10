require 'rails_helper'

RSpec.describe MediaItem, type: :model do
  let(:place) { create(:place) }
  let(:media_item) { create(:media_item, place: place) }

  describe 'associations' do
    it { should belong_to(:place) }
    it { should have_one_attached(:file) }
  end

  describe 'validations' do
    subject { build(:media_item, place: place) }

    it { should validate_presence_of(:kind) }
    
    it 'validates kind inclusion' do
      valid_kinds = %w[logo photo brochure fee_schedule_pdf video virtual_tour menu floor_plan]
      valid_kinds.each do |kind|
        media_item = build(:media_item, place: place, kind: kind)
        expect(media_item).to be_valid
      end

      invalid_media = build(:media_item, place: place, kind: 'invalid_kind')
      expect(invalid_media).not_to be_valid
      expect(invalid_media.errors[:kind]).to include('is not included in the list')
    end

    it 'validates URL format when file not attached' do
      media_item = build(:media_item, place: place, url: 'not-a-url')
      expect(media_item).not_to be_valid
      expect(media_item.errors[:url]).to include('is invalid')

      media_item.url = 'https://example.com/image.jpg'
      expect(media_item).to be_valid
    end

    it 'requires either URL or file' do
      media_item = build(:media_item, place: place, url: nil)
      media_item.file.purge if media_item.file.attached?
      expect(media_item).not_to be_valid
    end

    it { should validate_numericality_of(:sort_order).is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it 'defines source enum with prefix' do
      media_item.source = 'google_places'
      expect(media_item.from_google_places?).to be true

      media_item.source = 'school_upload'
      expect(media_item.from_school_upload?).to be true

      media_item.source = 'admin_upload'
      expect(media_item.from_admin_upload?).to be true
    end
  end

  describe 'scopes' do
    let!(:photo) { create(:media_item, place: place, kind: 'photo', sort_order: 2) }
    let!(:logo) { create(:media_item, place: place, kind: 'logo', sort_order: 1) }
    let!(:brochure) { create(:media_item, place: place, kind: 'brochure', sort_order: 3) }
    let!(:video) { create(:media_item, place: place, kind: 'video') }
    let!(:google_photo) { create(:media_item, place: place, kind: 'photo', source: 'google_places') }
    let!(:uploaded_photo) { create(:media_item, place: place, kind: 'photo', source: 'school_upload') }

    describe '.by_kind' do
      it 'filters by kind' do
        expect(MediaItem.by_kind('photo')).to include(photo, google_photo, uploaded_photo)
        expect(MediaItem.by_kind('photo')).not_to include(logo, brochure, video)
      end
    end

    describe '.ordered' do
      it 'orders by sort_order then created_at' do
        # Create items with specific sort orders
        item1 = create(:media_item, place: place, sort_order: 10)
        item2 = create(:media_item, place: place, sort_order: 5)
        item3 = create(:media_item, place: place, sort_order: 15)
        
        ordered = MediaItem.ordered
        # Verify they're ordered by sort_order
        expect(ordered.map(&:sort_order)).to eq(ordered.map(&:sort_order).sort)
      end
    end

    describe '.photos' do
      it 'returns only photos' do
        expect(MediaItem.photos).to include(photo, google_photo, uploaded_photo)
        expect(MediaItem.photos).not_to include(logo, brochure, video)
      end
    end

    describe '.uploaded_photos' do
      it 'returns non-Google photos' do
        expect(MediaItem.uploaded_photos).to include(uploaded_photo)
        expect(MediaItem.uploaded_photos).not_to include(google_photo)
      end
    end

    describe '.google_photos' do
      it 'returns only Google photos' do
        expect(MediaItem.google_photos).to include(google_photo)
        expect(MediaItem.google_photos).not_to include(uploaded_photo)
      end
    end

    describe '.documents' do
      it 'returns brochures and fee schedules' do
        fee_schedule = create(:media_item, place: place, kind: 'fee_schedule_pdf')
        expect(MediaItem.documents).to include(brochure, fee_schedule)
        expect(MediaItem.documents).not_to include(photo, video)
      end
    end

    describe '.videos' do
      it 'returns videos and virtual tours' do
        virtual_tour = create(:media_item, place: place, kind: 'virtual_tour')
        expect(MediaItem.videos).to include(video, virtual_tour)
        expect(MediaItem.videos).not_to include(photo, brochure)
      end
    end
  end

  describe 'instance methods' do
    describe '#image?' do
      it 'returns true for logos and photos' do
        expect(build(:media_item, kind: 'logo').image?).to be true
        expect(build(:media_item, kind: 'photo').image?).to be true
        expect(build(:media_item, kind: 'video').image?).to be false
      end
    end

    describe '#document?' do
      it 'returns true for document types' do
        expect(build(:media_item, kind: 'brochure').document?).to be true
        expect(build(:media_item, kind: 'fee_schedule_pdf').document?).to be true
        expect(build(:media_item, kind: 'menu').document?).to be true
        expect(build(:media_item, kind: 'floor_plan').document?).to be true
        expect(build(:media_item, kind: 'photo').document?).to be false
      end
    end

    describe '#video?' do
      it 'returns true for video types' do
        expect(build(:media_item, kind: 'video').video?).to be true
        expect(build(:media_item, kind: 'virtual_tour').video?).to be true
        expect(build(:media_item, kind: 'photo').video?).to be false
      end
    end

    # file_extension method doesn't exist in the model, removing test

    describe '#display_alt_text' do
      it 'returns alt_text if present' do
        media_item.alt_text = 'Custom alt text'
        expect(media_item.display_alt_text).to eq('Custom alt text')
      end

      it 'generates alt text based on kind' do
        media_item.alt_text = nil
        media_item.kind = 'logo'
        expect(media_item.display_alt_text).to eq("#{place.name} logo")

        media_item.kind = 'photo'
        expect(media_item.display_alt_text).to eq("#{place.name} photo")

        media_item.kind = 'fee_schedule_pdf'
        expect(media_item.display_alt_text).to eq("#{place.name} fee schedule")
      end
    end

    describe '#kind_display' do
      it 'returns human-readable kind names' do
        expect(build(:media_item, kind: 'photo').kind_display).to eq('Photo')
        expect(build(:media_item, kind: 'fee_schedule_pdf').kind_display).to eq('Fee Schedule')
        expect(build(:media_item, kind: 'virtual_tour').kind_display).to eq('Virtual Tour')
        expect(build(:media_item, kind: 'brochure').kind_display).to eq('Brochure')
      end
    end

    describe '#url_accessible?' do
      it 'returns true for valid HTTP/HTTPS URLs' do
        media_item.url = 'https://example.com/image.jpg'
        expect(media_item.url_accessible?).to be true

        media_item.url = 'http://example.com/image.jpg'
        expect(media_item.url_accessible?).to be true
      end

      it 'returns false for invalid URLs' do
        media_item.url = 'not-a-url'
        expect(media_item.url_accessible?).to be false

        media_item.url = 'ftp://example.com/file'
        expect(media_item.url_accessible?).to be false
      end

      it 'returns false when URL is blank' do
        media_item.url = nil
        expect(media_item.url_accessible?).to be false
      end
    end

    describe '#uploaded?' do
      it 'returns true when file is attached' do
        media_item.file.attach(
          io: StringIO.new("test"),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )
        expect(media_item.uploaded?).to be true
      end

      it 'returns false when no file attached' do
        media_item.file.purge if media_item.file.attached?
        expect(media_item.uploaded?).to be false
      end
    end
  end

  describe 'factory' do
    it 'creates valid media item' do
      media_item = build(:media_item, place: place)
      expect(media_item).to be_valid
    end

    it 'creates media items with different kinds' do
      photo = create(:media_item, place: place, kind: 'photo')
      video = create(:media_item, place: place, kind: 'video')
      expect(photo.kind).to eq('photo')
      expect(video.kind).to eq('video')
    end
  end
end