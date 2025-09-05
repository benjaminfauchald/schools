require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_inclusion_of(:role).in_array(%w[school_owner admin]) }
  end

  describe 'associations' do
    it { should have_many(:school_claims).dependent(:destroy) }
    it { should have_many(:claimed_schools).through(:school_claims) }
    it { should have_many(:audit_logs).dependent(:destroy) }
    it { should have_many(:school_inquiries).dependent(:destroy) }
  end
  
  describe 'enums' do
    it 'defines role enum correctly' do
      expect(User.roles).to eq({
        'school_owner' => 'school_owner',
        'admin' => 'admin'
      })
    end
  end

  describe '#admin?' do
    it 'returns true for admin users' do
      admin = create(:user, :admin)
      expect(admin.admin?).to be true
    end
    
    it 'returns false for school owner users' do
      user = create(:user)
      expect(user.admin?).to be false
    end
  end
  
  describe '.from_omniauth' do
    let(:auth_hash) do
      OpenStruct.new(
        provider: 'facebook',
        uid: '123456789',
        info: OpenStruct.new(
          name: 'John Doe',
          email: 'john@example.com'
        )
      )
    end
    
    context 'when user exists with same provider and uid' do
      let!(:existing_user) { create(:user, :facebook_user, uid: '123456789') }
      
      it 'returns the existing user' do
        user = User.from_omniauth(auth_hash)
        expect(user).to eq(existing_user)
      end
    end
    
    context 'when user does not exist' do
      it 'creates a new user' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)
      end
      
      it 'sets the correct attributes' do
        user = User.from_omniauth(auth_hash)
        expect(user.provider).to eq('facebook')
        expect(user.uid).to eq('123456789')
        expect(user.email).to eq('john@example.com')
      end
    end
  end

  describe 'factory' do
    it 'creates valid user' do
      user = build(:user)
      expect(user).to be_valid
    end
    
    it 'creates admin user with trait' do
      admin = create(:user, :admin)
      expect(admin.admin?).to be true
    end
    
    it 'creates facebook user with trait' do
      fb_user = create(:user, :facebook_user)
      expect(fb_user.provider).to eq('facebook')
      expect(fb_user.uid).to be_present
    end
  end
end