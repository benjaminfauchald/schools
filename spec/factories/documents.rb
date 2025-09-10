FactoryBot.define do
  factory :document do
    association :place
    filename { "test_document.pdf" }
    original_filename { "test_document.pdf" }
    content_type { "application/pdf" }
    file_size { 1024 }
    file_checksum { "checksum_#{SecureRandom.hex(32)}" }
    ai_enabled { true }
    processing_completed { false }
    processing_failed { false }
    
    transient do
      skip_file_attachment { false }
    end
    
    after(:build) do |document, evaluator|
      unless evaluator.skip_file_attachment
        if document.file.blank? && !document.persisted?
          document.file.attach(
            io: StringIO.new("Test PDF content"),
            filename: document.original_filename || "test.pdf",
            content_type: document.content_type || "application/pdf"
          )
        end
      end
    end
    
    trait :without_file do
      transient do
        skip_file_attachment { true }
      end
      
      after(:build) do |document|
        document.define_singleton_method(:file_attached?) { false }
      end
    end
    
    trait :processed do
      processing_completed { true }
      extracted_text { "This is extracted text from the document" }
      last_processed_at { Time.current }
    end
    
    trait :failed do
      processing_failed { true }
      processing_error { "Failed to extract text" }
    end
    
    trait :with_embedding do
      processing_completed { true }
      extracted_text { "Document content" }
      # embedding must be set via raw SQL after creation
      after(:create) do |document|
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE documents SET embedding = '#{vector}' WHERE id = #{document.id}")
      end
    end
    
    trait :word_document do
      filename { "test_document.docx" }
      original_filename { "test_document.docx" }
      content_type { "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
    end
    
    trait :excel_document do
      filename { "test_spreadsheet.xlsx" }
      original_filename { "test_spreadsheet.xlsx" }
      content_type { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
    end
  end
end