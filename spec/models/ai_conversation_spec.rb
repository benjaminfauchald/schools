require 'rails_helper'

RSpec.describe AiConversation, type: :model do
  let(:school) { create(:school) }
  let(:user) { create(:user) }
  let(:ai_conversation) { create(:ai_conversation, school: school, user: user) }

  describe 'associations' do
    it { should belong_to(:school) }
    it { should belong_to(:user) }
    it { should have_many(:ai_messages).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:school) }
    it { should validate_presence_of(:user) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).backed_by_column_of_type(:string).with_values(active: "active", archived: "archived", suspended: "suspended") }
  end

  describe 'scopes' do
    let!(:recent_conversation) { create(:ai_conversation, school: school, user: user, last_message_at: 1.hour.ago) }
    let!(:old_conversation) { create(:ai_conversation, school: school, user: user, last_message_at: 2.months.ago) }

    describe '.recent' do
      it 'orders by last_message_at desc' do
        expect(AiConversation.recent.first).to eq(recent_conversation)
      end
    end

    describe '.for_school' do
      it 'returns conversations for specific school' do
        other_school = create(:school)
        other_conversation = create(:ai_conversation, school: other_school, user: user)
        expect(AiConversation.for_school(school.id)).to include(recent_conversation, old_conversation)
        expect(AiConversation.for_school(school.id)).not_to include(other_conversation)
      end
    end

    describe '.for_user' do
      it 'returns conversations for specific user' do
        other_user = create(:user)
        other_conversation = create(:ai_conversation, school: school, user: other_user)
        expect(AiConversation.for_user(user.id)).to include(recent_conversation, old_conversation)
        expect(AiConversation.for_user(user.id)).not_to include(other_conversation)
      end
    end

    describe '.with_recent_activity' do
      it 'returns conversations with activity in last 30 days' do
        expect(AiConversation.with_recent_activity).to include(recent_conversation)
        expect(AiConversation.with_recent_activity).not_to include(old_conversation)
      end
    end
  end

  describe 'callbacks' do
    describe '#set_default_title' do
      it 'sets default title on creation' do
        conversation = AiConversation.create!(school: school, user: user)
        expect(conversation.title).to match(/Chat \w{3} \d{2}, \d{4}/)
      end

      it 'does not override existing title' do
        conversation = AiConversation.create!(school: school, user: user, title: "Custom Title")
        expect(conversation.title).to eq("Custom Title")
      end
    end
  end

  describe 'instance methods' do
    describe '#last_message' do
      it 'returns the most recent message' do
        old_message = create(:ai_message, ai_conversation: ai_conversation, created_at: 2.hours.ago)
        new_message = create(:ai_message, ai_conversation: ai_conversation, created_at: 1.hour.ago)
        expect(ai_conversation.last_message).to eq(new_message)
      end
    end

    describe '#first_user_message' do
      it 'returns the first user message' do
        assistant_message = create(:ai_message, ai_conversation: ai_conversation, role: "assistant")
        user_message = create(:ai_message, ai_conversation: ai_conversation, role: "user")
        expect(ai_conversation.first_user_message).to eq(user_message)
      end
    end

    describe '#has_messages?' do
      it 'returns true when messages exist' do
        create(:ai_message, ai_conversation: ai_conversation)
        expect(ai_conversation.has_messages?).to be true
      end

      it 'returns false when no messages exist' do
        expect(ai_conversation.has_messages?).to be false
      end
    end

    describe '#message_count' do
      it 'returns the count of messages' do
        create_list(:ai_message, 3, ai_conversation: ai_conversation)
        expect(ai_conversation.message_count).to eq(3)
      end
    end

    describe '#add_user_message' do
      it 'creates a user message' do
        expect {
          ai_conversation.add_user_message("Test message", { key: "value" })
        }.to change { ai_conversation.ai_messages.count }.by(1)
        
        message = ai_conversation.ai_messages.last
        expect(message.role).to eq("user")
        expect(message.content).to eq("Test message")
        expect(message.metadata).to eq({ "key" => "value" })
      end

      it 'updates last_message_at' do
        expect {
          ai_conversation.add_user_message("Test message")
        }.to change { ai_conversation.reload.last_message_at }
      end
    end

    describe '#add_assistant_message' do
      it 'creates an assistant message' do
        source_refs = ["ref1", "ref2"]
        expect {
          ai_conversation.add_assistant_message("Response", source_refs, { key: "value" })
        }.to change { ai_conversation.ai_messages.count }.by(1)
        
        message = ai_conversation.ai_messages.last
        expect(message.role).to eq("assistant")
        expect(message.content).to eq("Response")
        expect(message.source_references).to eq(source_refs)
      end
    end

    describe '#archive!' do
      it 'sets status to archived' do
        ai_conversation.archive!
        expect(ai_conversation.reload.status).to eq("archived")
      end
    end

    describe '#reactivate!' do
      it 'sets status to active' do
        ai_conversation.update!(status: "archived")
        ai_conversation.reactivate!
        expect(ai_conversation.reload.status).to eq("active")
      end
    end

    describe '#age_in_days' do
      it 'returns age in days' do
        ai_conversation.update!(created_at: 5.days.ago)
        expect(ai_conversation.age_in_days).to be_within(0.1).of(5)
      end
    end

    describe '#recent?' do
      it 'returns true for conversations less than 24 hours old' do
        ai_conversation.update!(created_at: 12.hours.ago)
        expect(ai_conversation.recent?).to be true
      end

      it 'returns false for conversations more than 24 hours old' do
        ai_conversation.update!(created_at: 2.days.ago)
        expect(ai_conversation.recent?).to be false
      end
    end

    describe '#accessible_by?' do
      it 'returns true for the conversation owner' do
        expect(ai_conversation.accessible_by?(user)).to be true
      end

      it 'returns false for other users without claims' do
        other_user = create(:user)
        expect(ai_conversation.accessible_by?(other_user)).to be false
      end

      it 'returns true for users with active claims on the school' do
        other_user = create(:user)
        create(:school_claim, school: school, user: other_user, status: "approved")
        expect(ai_conversation.accessible_by?(other_user)).to be true
      end
    end

    describe '#statistics' do
      before do
        create_list(:ai_message, 2, ai_conversation: ai_conversation, role: "user")
        create_list(:ai_message, 3, ai_conversation: ai_conversation, role: "assistant")
      end

      it 'returns conversation statistics' do
        stats = ai_conversation.statistics
        expect(stats[:total_messages]).to eq(5)
        expect(stats[:user_messages]).to eq(2)
        expect(stats[:assistant_messages]).to eq(3)
      end
    end

    describe '#export_data' do
      it 'exports conversation data' do
        create(:ai_message, ai_conversation: ai_conversation)
        export = ai_conversation.export_data
        
        expect(export[:id]).to eq(ai_conversation.id)
        expect(export[:school_id]).to eq(school.id)
        expect(export[:user_id]).to eq(user.id)
        expect(export[:message_count]).to eq(1)
      end
    end
  end

  describe 'class methods' do
    describe '.for_school_and_user' do
      it 'returns conversations for specific school and user' do
        conversation = create(:ai_conversation, school: school, user: user)
        other = create(:ai_conversation, school: create(:school), user: user)
        
        result = AiConversation.for_school_and_user(school.id, user.id)
        expect(result).to include(conversation)
        expect(result).not_to include(other)
      end
    end

    describe '.conversation_stats' do
      before do
        create_list(:ai_conversation, 2, status: "active")
        create(:ai_conversation, status: "archived")
      end

      it 'returns overall statistics' do
        stats = AiConversation.conversation_stats
        expect(stats[:total_conversations]).to eq(3)
        expect(stats[:active_conversations]).to eq(2)
        expect(stats[:archived_conversations]).to eq(1)
      end
    end
  end
end