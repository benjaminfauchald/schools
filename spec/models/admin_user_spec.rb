require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  describe 'validations' do
    subject { build(:admin_user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(AdminUser.devise_modules).to include(:database_authenticatable)
    end

    it 'includes recoverable' do
      expect(AdminUser.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(AdminUser.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(AdminUser.devise_modules).to include(:validatable)
    end
  end

  describe 'email validation' do
    it 'accepts valid email addresses' do
      admin = build(:admin_user, email: 'admin@example.com')
      expect(admin).to be_valid
    end

    it 'rejects invalid email addresses' do
      admin = build(:admin_user, email: 'invalid-email')
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include('is invalid')
    end

    it 'requires email to be unique' do
      create(:admin_user, email: 'admin@example.com')
      duplicate = build(:admin_user, email: 'admin@example.com')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include('has already been taken')
    end

    it 'is case insensitive for uniqueness' do
      create(:admin_user, email: 'admin@example.com')
      duplicate = build(:admin_user, email: 'ADMIN@EXAMPLE.COM')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'password validation' do
    it 'requires password on creation' do
      admin = build(:admin_user, password: nil)
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to include("can't be blank")
    end

    it 'requires minimum password length' do
      admin = build(:admin_user, password: '12345')
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to include('is too short (minimum is 6 characters)')
    end

    it 'accepts valid password' do
      admin = build(:admin_user, password: 'password123')
      expect(admin).to be_valid
    end
  end

  describe 'factory' do
    it 'creates valid admin user' do
      admin = build(:admin_user)
      expect(admin).to be_valid
    end

    it 'creates unique emails' do
      admin1 = create(:admin_user)
      admin2 = create(:admin_user)
      expect(admin1.email).not_to eq(admin2.email)
    end
  end
end