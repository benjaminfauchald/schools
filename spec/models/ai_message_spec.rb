require 'rails_helper'

RSpec.describe AiMessage, type: :model do
  let(:school) { create(:school) }
  let(:user) { create(:user) }
  let(:ai_conversation) { create(:ai_conversation, school: school, user: user) }
  let(:ai_message) { create(:ai_message, ai_conversation: ai_conversation) }

  describe 'associations' do
    it { should belong_to(:ai_conversation) }
  end

  describe 'validations' do
    it { should validate_presence_of(:ai_conversation) }
    it { should validate_presence_of(:role) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:message_type) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).backed_by_column_of_type(:string).with_values(user: "user", assistant: "assistant") }
    it { should define_enum_for(:message_type).backed_by_column_of_type(:string).with_values(text: "text", suggested_question: "suggested_question", data_analysis: "data_analysis") }
  end

  describe 'scopes' do
    let!(:user_message) { create(:ai_message, ai_conversation: ai_conversation, role: "user") }
    let!(:assistant_message) { create(:ai_message, ai_conversation: ai_conversation, role: "assistant") }
    let!(:message_with_sources) { create(:ai_message, ai_conversation: ai_conversation, source_references: [{ "type" => "document" }]) }

    describe '.recent' do
      it 'orders by created_at' do
        old_message = create(:ai_message, ai_conversation: ai_conversation, created_at: 2.hours.ago)
        new_message = create(:ai_message, ai_conversation: ai_conversation, created_at: 1.hour.ago)
        # Just check that the old message comes before the new message
        recent_messages = AiMessage.recent.to_a
        expect(recent_messages.index(old_message)).to be < recent_messages.index(new_message)
      end
    end

    describe '.by_role' do
      it 'filters by role' do
        expect(AiMessage.by_role("user")).to include(user_message)
        expect(AiMessage.by_role("user")).not_to include(assistant_message)
      end
    end

    describe '.with_sources' do
      it 'returns messages with source references' do
        expect(AiMessage.with_sources).to include(message_with_sources)
        expect(AiMessage.with_sources).not_to include(user_message, assistant_message)
      end
    end

    describe '.by_conversation' do
      it 'filters by conversation id' do
        other_conversation = create(:ai_conversation, school: school, user: user)
        other_message = create(:ai_message, ai_conversation: other_conversation)
        
        expect(AiMessage.by_conversation(ai_conversation.id)).to include(user_message, assistant_message)
        expect(AiMessage.by_conversation(ai_conversation.id)).not_to include(other_message)
      end
    end
  end

  describe 'instance methods' do
    describe '#school' do
      it 'returns the school through conversation' do
        expect(ai_message.school).to eq(school)
      end
    end

    describe '#user' do
      it 'returns the user through conversation' do
        expect(ai_message.user).to eq(user)
      end
    end

    describe '#has_sources?' do
      it 'returns true when source_references present' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [{ "type" => "document" }])
        expect(message.has_sources?).to be true
      end

      it 'returns false when source_references empty' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [])
        expect(message.has_sources?).to be false
      end
    end

    describe '#formatted_sources' do
      it 'formats document sources' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [
          { "type" => "document", "title" => "Test Doc", "description" => "A test document" }
        ])
        sources = message.formatted_sources
        expect(sources.first["type"]).to eq("Document")
        expect(sources.first["title"]).to eq("Test Doc")
        expect(sources.first["icon"]).to eq("📄")
      end

      it 'formats transcript sources' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [
          { "type" => "transcript", "video_title" => "Test Video", "text" => "Video content" }
        ])
        sources = message.formatted_sources
        expect(sources.first["type"]).to eq("Video Transcript")
        expect(sources.first["title"]).to eq("Test Video")
        expect(sources.first["icon"]).to eq("🎥")
      end

      it 'formats school data sources' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [
          { "type" => "school_data", "field_name" => "Academic Programs" }
        ])
        sources = message.formatted_sources
        expect(sources.first["type"]).to eq("School Information")
        expect(sources.first["title"]).to eq("Academic Programs")
        expect(sources.first["icon"]).to eq("🏫")
      end
    end

    describe '#user_message?' do
      it 'returns true for user role' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "user")
        expect(message.user_message?).to be true
      end

      it 'returns false for assistant role' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "assistant")
        expect(message.user_message?).to be false
      end
    end

    describe '#assistant_message?' do
      it 'returns true for assistant role' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "assistant")
        expect(message.assistant_message?).to be true
      end

      it 'returns false for user role' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "user")
        expect(message.assistant_message?).to be false
      end
    end

    describe '#age_display' do
      it 'returns "Just now" for recent messages' do
        message = create(:ai_message, ai_conversation: ai_conversation, created_at: 30.seconds.ago)
        expect(message.age_display).to eq("Just now")
      end

      it 'returns minutes ago for messages within an hour' do
        message = create(:ai_message, ai_conversation: ai_conversation, created_at: 15.minutes.ago)
        expect(message.age_display).to eq("15m ago")
      end

      it 'returns hours ago for messages within a day' do
        message = create(:ai_message, ai_conversation: ai_conversation, created_at: 3.hours.ago)
        expect(message.age_display).to eq("3h ago")
      end

      it 'returns days ago for messages within a week' do
        message = create(:ai_message, ai_conversation: ai_conversation, created_at: 2.days.ago)
        expect(message.age_display).to eq("2d ago")
      end

      it 'returns formatted date for older messages' do
        message = create(:ai_message, ai_conversation: ai_conversation, created_at: 2.months.ago)
        expect(message.age_display).to match(/\w{3} \d{2}, \d{4}/)
      end
    end

    describe '#content_preview' do
      it 'returns full content when short' do
        message = create(:ai_message, ai_conversation: ai_conversation, content: "Short content")
        expect(message.content_preview).to eq("Short content")
      end

      it 'truncates long content' do
        long_content = "a" * 150
        message = create(:ai_message, ai_conversation: ai_conversation, content: long_content)
        expect(message.content_preview.length).to eq(100)
        expect(message.content_preview).to end_with("...")
      end
    end

    describe '#mentions?' do
      let(:message) { create(:ai_message, ai_conversation: ai_conversation, content: "This is about schools and education") }

      it 'returns true when keyword is mentioned' do
        expect(message.mentions?("school")).to be true
      end

      it 'returns false when keyword is not mentioned' do
        expect(message.mentions?("university")).to be false
      end

      it 'handles array of keywords' do
        expect(message.mentions?(["university", "school"])).to be true
      end

      it 'is case insensitive' do
        expect(message.mentions?("SCHOOLS")).to be true
      end
    end

    describe '#next_message and #previous_message' do
      let!(:first_message) { create(:ai_message, ai_conversation: ai_conversation, created_at: 3.hours.ago) }
      let!(:middle_message) { create(:ai_message, ai_conversation: ai_conversation, created_at: 2.hours.ago) }
      let!(:last_message) { create(:ai_message, ai_conversation: ai_conversation, created_at: 1.hour.ago) }

      it '#next_message returns the next message' do
        expect(first_message.next_message).to eq(middle_message)
        expect(middle_message.next_message).to eq(last_message)
        expect(last_message.next_message).to be_nil
      end

      it '#previous_message returns the previous message' do
        expect(last_message.previous_message).to eq(middle_message)
        expect(middle_message.previous_message).to eq(first_message)
        expect(first_message.previous_message).to be_nil
      end
    end

    describe '#editable?' do
      it 'returns true for recent user messages' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "user", created_at: 2.minutes.ago)
        expect(message.editable?).to be true
      end

      it 'returns false for old user messages' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "user", created_at: 10.minutes.ago)
        expect(message.editable?).to be false
      end

      it 'returns false for assistant messages' do
        message = create(:ai_message, ai_conversation: ai_conversation, role: "assistant", created_at: 2.minutes.ago)
        expect(message.editable?).to be false
      end
    end

    describe '#source_statistics' do
      it 'returns empty hash when no sources' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [])
        expect(message.source_statistics).to eq({})
      end

      it 'returns statistics for sources' do
        message = create(:ai_message, ai_conversation: ai_conversation, source_references: [
          { "type" => "document" },
          { "type" => "document" },
          { "type" => "transcript" },
          { "type" => "school_data" }
        ])
        
        stats = message.source_statistics
        expect(stats[:total_sources]).to eq(4)
        expect(stats[:by_type]["document"]).to eq(2)
        expect(stats[:by_type]["transcript"]).to eq(1)
        expect(stats[:has_documents]).to be true
        expect(stats[:has_transcripts]).to be true
        expect(stats[:has_school_data]).to be true
        expect(stats[:has_place_data]).to be false
      end
    end

    describe '#ai_context_data' do
      it 'exports message data for AI context' do
        message = create(:ai_message, 
          ai_conversation: ai_conversation, 
          role: "user", 
          content: "Test content",
          message_type: "text",
          metadata: { "key" => "value" }
        )
        
        data = message.ai_context_data
        expect(data[:id]).to eq(message.id)
        expect(data[:role]).to eq("user")
        expect(data[:content]).to eq("Test content")
        expect(data[:message_type]).to eq("text")
        expect(data[:metadata]).to eq({ "key" => "value" })
        expect(data[:has_sources]).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.conversation_flow' do
      it 'returns conversation messages in order' do
        create(:ai_message, ai_conversation: ai_conversation, role: "user", content: "Question", created_at: 2.hours.ago)
        create(:ai_message, ai_conversation: ai_conversation, role: "assistant", content: "Answer", created_at: 1.hour.ago)
        
        flow = AiMessage.conversation_flow(ai_conversation.id)
        expect(flow.first[0]).to eq("user")
        expect(flow.first[1]).to eq("Question")
        expect(flow.last[0]).to eq("assistant")
        expect(flow.last[1]).to eq("Answer")
      end
    end

    describe '.by_message_type_stats' do
      before do
        create_list(:ai_message, 2, ai_conversation: ai_conversation, message_type: "text")
        create(:ai_message, ai_conversation: ai_conversation, message_type: "suggested_question")
      end

      it 'returns count by message type' do
        stats = AiMessage.by_message_type_stats
        expect(stats["text"]).to eq(2)
        expect(stats["suggested_question"]).to eq(1)
      end
    end
  end
end