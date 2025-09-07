require 'rails_helper'

RSpec.describe School, type: :model do
  describe 'basic validations' do
    it 'is valid with valid attributes' do
      school = build(:school)
      expect(school).to be_valid
    end

    it 'requires a name' do
      school = build(:school, name: nil)
      expect(school).not_to be_valid
      expect(school.errors[:name]).to include("can't be blank")
    end

    it 'can create a school without associations' do
      school = School.new(
        name: 'Test School',
        slug: 'test-school',
        status: 'published'
      )
      expect(school).to be_valid
      expect(school.save).to be true
    end
  end
end
