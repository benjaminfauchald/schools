require 'rails_helper'

RSpec.describe SchoolInquiry, type: :model do
  # First test: validations for name
  describe 'validations' do
    describe 'name' do
      let(:school) { create(:school) }

      it 'requires a name' do
        inquiry = build(:school_inquiry, school: school, name: nil)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:name]).to include("can't be blank")
      end

      it 'limits name to 100 characters' do
        inquiry = build(:school_inquiry, school: school, name: 'a' * 101)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:name]).to include('is too long (maximum is 100 characters)')
      end
    end

    describe 'email' do
      let(:school) { create(:school) }

      it 'requires an email' do
        inquiry = build(:school_inquiry, school: school, email: nil)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:email]).to include("can't be blank")
      end

      it 'validates email format' do
        inquiry = build(:school_inquiry, school: school, email: 'invalid.email')
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:email]).to include('is invalid')
      end

      it 'accepts valid email addresses' do
        valid_emails = [ 'user@example.com', 'test.user+tag@domain.co.uk', 'admin@subdomain.example.org' ]
        valid_emails.each do |email|
          inquiry = build(:school_inquiry, school: school, email: email)
          expect(inquiry).to be_valid
        end
      end
    end

    describe 'message' do
      let(:school) { create(:school) }

      it 'requires a message' do
        inquiry = build(:school_inquiry, school: school, message: nil)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:message]).to include("can't be blank")
      end

      it 'limits message to 2000 characters' do
        inquiry = build(:school_inquiry, school: school, message: 'a' * 2001)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:message]).to include('is too long (maximum is 2000 characters)')
      end
    end

    describe 'children_count' do
      let(:school) { create(:school) }

      it 'requires children_count' do
        inquiry = build(:school_inquiry, school: school, children_count: nil)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:children_count]).to include("can't be blank")
      end

      it 'must be greater than 0' do
        inquiry = build(:school_inquiry, school: school, children_count: 0)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:children_count]).to include('must be greater than 0')
      end

      it 'must not exceed 20' do
        inquiry = build(:school_inquiry, school: school, children_count: 21)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:children_count]).to include('must be less than or equal to 20')
      end
    end

    describe 'phone' do
      let(:school) { create(:school) }

      it 'is optional' do
        inquiry = build(:school_inquiry, school: school, phone: nil)
        expect(inquiry).to be_valid
      end

      it 'limits phone to 20 characters' do
        inquiry = build(:school_inquiry, school: school, phone: '1' * 21)
        expect(inquiry).not_to be_valid
        expect(inquiry.errors[:phone]).to include('is too long (maximum is 20 characters)')
      end
    end

    describe 'status' do
      let(:school) { create(:school) }

      it 'validates inclusion in allowed statuses' do
        # Rails enums raise ArgumentError for invalid values
        expect {
          build(:school_inquiry, school: school, status: 'invalid')
        }.to raise_error(ArgumentError, "'invalid' is not a valid status")
      end

      it 'accepts valid statuses' do
        %w[new read responded closed].each do |status|
          inquiry = build(:school_inquiry, school: school, status: status)
          expect(inquiry).to be_valid
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'sets default status to new on create' do
        school = create(:school)
        inquiry = SchoolInquiry.new(
          school: school,
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Interested in your school',
          children_count: 2
        )
        inquiry.valid?
        expect(inquiry.status).to eq('new')
      end
    end
  end

  describe 'instance methods' do
    let(:school) { create(:school) }
    let(:inquiry) { create(:school_inquiry, school: school) }

    describe '#mark_as_read!' do
      it 'marks new inquiry as read' do
        new_inquiry = create(:school_inquiry, school: school, status: 'new')
        expect {
          new_inquiry.mark_as_read!
        }.to change { new_inquiry.status }.from('new').to('read')
      end

      it 'sets read_at timestamp' do
        new_inquiry = create(:school_inquiry, school: school, status: 'new', read_at: nil)
        new_inquiry.mark_as_read!
        expect(new_inquiry.read_at).not_to be_nil
      end

      it 'does not update already read inquiries' do
        read_inquiry = create(:school_inquiry, school: school, status: 'read')
        original_read_at = 1.day.ago
        read_inquiry.update!(read_at: original_read_at)
        read_inquiry.mark_as_read!
        expect(read_inquiry.reload.read_at.to_i).to eq(original_read_at.to_i)
      end
    end

    describe '#display_phone' do
      it 'returns phone when present' do
        inquiry = build(:school_inquiry, phone: '+1234567890')
        expect(inquiry.display_phone).to eq('+1234567890')
      end

      it 'returns "Not provided" when phone is nil' do
        inquiry = build(:school_inquiry, phone: nil)
        expect(inquiry.display_phone).to eq('Not provided')
      end

      it 'returns "Not provided" when phone is empty string' do
        inquiry = build(:school_inquiry, phone: '')
        expect(inquiry.display_phone).to eq('Not provided')
      end
    end

    describe '#days_ago' do
      it 'returns 0 for new inquiries' do
        inquiry = create(:school_inquiry, school: school)
        expect(inquiry.days_ago).to eq(0)
      end

      it 'calculates days for older inquiries' do
        inquiry = create(:school_inquiry, school: school)
        inquiry.update!(created_at: 5.days.ago)
        expect(inquiry.days_ago).to eq(5)
      end
    end

    describe '#lead_source' do
      it 'identifies Facebook users' do
        user = create(:user, :facebook_user)
        inquiry = create(:school_inquiry, school: school, user: user)
        expect(inquiry.lead_source).to eq("Facebook: #{user.facebook_name}")
      end

      it 'identifies registered users' do
        user = create(:user, email: 'user@example.com')
        inquiry = create(:school_inquiry, school: school, user: user)
        expect(inquiry.lead_source).to eq('Registered User: user@example.com')
      end

      it 'identifies direct inquiries without user' do
        inquiry = create(:school_inquiry, school: school, user: nil)
        expect(inquiry.lead_source).to eq('Direct (Legacy)')
      end
    end
  end

  describe 'scopes' do
    let(:school) { create(:school) }

    describe '.recent' do
      it 'orders by created_at descending' do
        old_inquiry = create(:school_inquiry, school: school, created_at: 2.days.ago)
        new_inquiry = create(:school_inquiry, school: school, created_at: 1.hour.ago)
        expect(SchoolInquiry.recent).to eq([ new_inquiry, old_inquiry ])
      end
    end

    describe '.unread' do
      it 'returns inquiries with nil read_at' do
        unread = create(:school_inquiry, school: school, read_at: nil)
        read = create(:school_inquiry, school: school, read_at: 1.hour.ago)
        expect(SchoolInquiry.unread).to include(unread)
        expect(SchoolInquiry.unread).not_to include(read)
      end
    end
  end
end
