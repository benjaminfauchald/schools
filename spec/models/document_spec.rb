require 'rails_helper'

RSpec.describe Document, type: :model do
  let(:school) { create(:school) }
  let(:place) { create(:place, school: school) }
  let(:document) { create(:document, place: place) }

  describe 'associations' do
    it { should belong_to(:place) }
    it { should have_one_attached(:file) }
  end

  describe 'validations' do
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:file_checksum) }

    it 'validates uniqueness of file_checksum scoped to place_id' do
      existing_document = create(:document, place: place, file_checksum: "abc123")
      new_document = build(:document, place: place, file_checksum: "abc123")
      expect(new_document).not_to be_valid
      expect(new_document.errors[:file_checksum]).to include("This file is already uploaded: Delete the existing file and try again if you want to replace it.")
    end

    it 'validates presence of file on create' do
      document = build(:document, place: place)
      document.file = nil
      expect(document).not_to be_valid
      expect(document.errors[:file]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    describe '.processing_completed' do
      it 'returns documents with processing completed' do
        completed_doc = create(:document, place: place, processing_completed: true)
        failed_doc = create(:document, place: create(:place, school: school), processing_failed: true)
        pending_doc = create(:document, place: create(:place, school: school), processing_completed: false, processing_failed: false)

        expect(Document.processing_completed).to include(completed_doc)
        expect(Document.processing_completed).not_to include(failed_doc, pending_doc)
      end
    end

    describe '.processing_failed' do
      it 'returns documents with processing failed' do
        completed_doc = create(:document, place: place, processing_completed: true)
        failed_doc = create(:document, place: create(:place, school: school), processing_failed: true)
        pending_doc = create(:document, place: create(:place, school: school), processing_completed: false, processing_failed: false)

        expect(Document.processing_failed).to include(failed_doc)
        expect(Document.processing_failed).not_to include(completed_doc, pending_doc)
      end
    end

    describe '.pending_processing' do
      it 'returns documents pending processing' do
        completed_doc = create(:document, place: place, processing_completed: true)
        failed_doc = create(:document, place: create(:place, school: school), processing_failed: true)
        pending_doc = create(:document, place: create(:place, school: school), processing_completed: false, processing_failed: false)

        expect(Document.pending_processing).to include(pending_doc)
        expect(Document.pending_processing).not_to include(completed_doc, failed_doc)
      end
    end

    describe '.ai_enabled' do
      it 'returns documents with AI enabled' do
        ai_enabled_doc = create(:document, place: place, ai_enabled: true)
        ai_disabled_doc = create(:document, place: create(:place, school: school), ai_enabled: false)

        expect(Document.ai_enabled).to include(ai_enabled_doc)
        expect(Document.ai_enabled).not_to include(ai_disabled_doc)
      end
    end

    describe '.with_embeddings' do
      it 'returns documents with embeddings' do
        doc_with_embedding = create(:document, place: place)
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE documents SET embedding = '#{vector}' WHERE id = #{doc_with_embedding.id}")
        doc_with_embedding.reload

        doc_without = create(:document, place: create(:place, school: school))

        expect(Document.with_embeddings).to include(doc_with_embedding)
        expect(Document.with_embeddings).not_to include(doc_without)
      end
    end

    describe '.recent' do
      it 'orders documents by created_at desc' do
        old_doc = create(:document, place: place, created_at: 2.days.ago)
        new_doc = create(:document, place: create(:place, school: school), created_at: 1.hour.ago)

        recent_docs = Document.recent
        expect(recent_docs.first).to eq(new_doc)
        expect(recent_docs.to_a.last).to eq(old_doc)
      end
    end
  end

  describe 'instance methods' do
    describe '#processing_status' do
      it 'returns :completed when processing_completed is true' do
        document.update(processing_completed: true)
        expect(document.processing_status).to eq(:completed)
      end

      it 'returns :failed when processing_failed is true' do
        document.update(processing_failed: true)
        expect(document.processing_status).to eq(:failed)
      end

      it 'returns :processing when created more than 5 minutes ago and not completed or failed' do
        document.update(created_at: 10.minutes.ago, processing_completed: false, processing_failed: false)
        expect(document.processing_status).to eq(:processing)
      end

      it 'returns :pending when recently created' do
        document.update(created_at: 1.minute.ago, processing_completed: false, processing_failed: false)
        expect(document.processing_status).to eq(:pending)
      end
    end

    describe '#processing_status_display' do
      it 'returns appropriate display strings' do
        document.update(processing_completed: true)
        expect(document.processing_status_display).to eq("✅ Processed")

        document.update(processing_completed: false, processing_failed: true)
        expect(document.processing_status_display).to eq("❌ Failed")
      end
    end

    describe '#can_reprocess?' do
      it 'returns true when processing failed or completed' do
        document.update(processing_failed: true)
        expect(document.can_reprocess?).to be true

        document.update(processing_failed: false, processing_completed: true)
        expect(document.can_reprocess?).to be true
      end

      it 'returns false when neither failed nor completed' do
        document.update(processing_failed: false, processing_completed: false)
        expect(document.can_reprocess?).to be false
      end
    end

    describe '#file_extension' do
      it 'returns the file extension' do
        document.update(original_filename: "test.pdf")
        expect(document.file_extension).to eq(".pdf")

        document.update(original_filename: "report.DOCX")
        expect(document.file_extension).to eq(".docx")
      end

      it 'returns nil when original_filename is blank' do
        document.update(original_filename: nil)
        expect(document.file_extension).to be_nil
      end
    end

    describe '#file_type_display' do
      it 'returns appropriate display names for file types' do
        document.update(original_filename: "test.pdf")
        expect(document.file_type_display).to eq("PDF Document")

        document.update(original_filename: "test.docx")
        expect(document.file_type_display).to eq("Word Document")

        document.update(original_filename: "test.xlsx")
        expect(document.file_type_display).to eq("Excel Spreadsheet")

        document.update(original_filename: "test.pptx")
        expect(document.file_type_display).to eq("PowerPoint Presentation")
      end
    end

    describe '#file_size_display' do
      it 'formats file size appropriately' do
        document.update(file_size: 500)
        expect(document.file_size_display).to eq("500 bytes")

        document.update(file_size: 5_000)
        expect(document.file_size_display).to eq("4.9 KB")

        document.update(file_size: 5_000_000)
        expect(document.file_size_display).to eq("4.8 MB")
      end

      it 'returns "Unknown size" when file_size is nil' do
        document.update(file_size: nil)
        expect(document.file_size_display).to eq("Unknown size")
      end
    end

    describe '#has_extracted_text?' do
      it 'returns true when extracted_text present' do
        document.update(extracted_text: "Some text")
        expect(document.has_extracted_text?).to be true
      end

      it 'returns false when extracted_text blank' do
        document.update(extracted_text: "")
        expect(document.has_extracted_text?).to be false
      end
    end

    describe '#has_embedding?' do
      it 'returns true when embedding present' do
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE documents SET embedding = '#{vector}' WHERE id = #{document.id}")
        document.reload
        expect(document.has_embedding?).to be true
      end

      it 'returns false when embedding blank' do
        document.update(embedding: nil)
        expect(document.has_embedding?).to be false
      end
    end

    describe '#text_preview' do
      it 'returns preview of extracted text' do
        document.update(extracted_text: "This is a long text that should be truncated")
        expect(document.text_preview(limit: 10)).to eq("This is a ...")
      end

      it 'returns full text when shorter than limit' do
        document.update(extracted_text: "Short text")
        expect(document.text_preview(limit: 100)).to eq("Short text")
      end

      it 'returns "No text extracted" when no extracted text' do
        document.update(extracted_text: nil)
        expect(document.text_preview).to eq("No text extracted")
      end
    end

    describe '#increment_download_count!' do
      it 'increments the download count' do
        expect { document.increment_download_count! }.to change { document.reload.download_count }.by(1)
      end
    end
  end

  describe 'class methods' do
    describe '.duplicate_exists?' do
      it 'returns true when duplicate checksum exists for place' do
        # Create a document first (it will get its own checksum from the file)
        doc = create(:document, place: place)
        expect(doc).to be_persisted

        # Now check if duplicate_exists works with the actual checksum
        actual_checksum = doc.file_checksum
        expect(Document.duplicate_exists?(actual_checksum, place.id)).to be true
      end

      it 'returns false when no duplicate exists' do
        expect(Document.duplicate_exists?("xyz789", place.id)).to be false
      end
    end

    describe '.search_by_text' do
      let!(:doc1) { create(:document, place: place, extracted_text: "Ruby on Rails programming", processing_completed: true) }
      let!(:doc2) { create(:document, place: create(:place, school: school), extracted_text: "Python Django development", processing_completed: true) }
      let!(:doc3) { create(:document, place: create(:place, school: school), extracted_text: "Rails migration guide", processing_completed: true) }

      it 'finds documents matching the query' do
        results = Document.search_by_text("Rails")
        expect(results).to include(doc1, doc3)
        expect(results).not_to include(doc2)
      end

      it 'returns empty for blank query' do
        expect(Document.search_by_text("")).to be_empty
        expect(Document.search_by_text(nil)).to be_empty
      end

      it 'limits results' do
        10.times do |i|
          create(:document,
                 place: create(:place, school: school),
                 extracted_text: "Rails content #{i}",
                 processing_completed: true)
        end
        results = Document.search_by_text("Rails", limit: 5)
        expect(results.count).to eq(5)
      end
    end

    describe '.normalize_search_query' do
      it 'removes punctuation and collapses spaces' do
        expect(Document.normalize_search_query("Hello, world! How are you?")).to eq("Hello world How are you")
        expect(Document.normalize_search_query("test...  multiple   spaces")).to eq("test multiple spaces")
      end
    end

    describe '.extract_keywords' do
      it 'extracts meaningful keywords from query' do
        keywords = Document.extract_keywords("How to implement user authentication in Rails?")
        expect(keywords).to include("implement", "user", "authentication", "rails")
        expect(keywords).not_to include("how", "to", "in")
      end

      it 'removes stop words and short words' do
        keywords = Document.extract_keywords("The a an and or is at be")
        expect(keywords).to be_empty
      end
    end

    describe '.processing_stats' do
      before do
        2.times { create(:document, place: create(:place, school: school), processing_completed: true) }
        create(:document, place: create(:place, school: school), processing_failed: true)
        create(:document, place: create(:place, school: school), processing_completed: false, processing_failed: false)
        d = create(:document, place: create(:place, school: school), ai_enabled: true)
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE documents SET embedding = '#{vector}' WHERE id = #{d.id}")
        d.reload
      end

      it 'returns processing statistics' do
        stats = Document.processing_stats
        expect(stats[:total]).to eq(5)
        expect(stats[:completed]).to eq(2)
        expect(stats[:failed]).to eq(1)
        expect(stats[:pending]).to eq(2)
        expect(stats[:with_embeddings]).to eq(1)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'enqueues processing job' do
        expect {
          create(:document, place: place)
        }.to have_enqueued_job(ProcessDocumentJob)
      end
    end
  end

  describe 'constants' do
    it 'defines supported MIME types' do
      expect(Document::SUPPORTED_MIME_TYPES).to include("application/pdf", "application/msword")
    end

    it 'defines supported extensions' do
      expect(Document::SUPPORTED_EXTENSIONS).to include(".pdf", ".docx", ".xlsx")
    end
  end
end
