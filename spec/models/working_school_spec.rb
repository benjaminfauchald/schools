require 'rails_helper'

RSpec.describe School, type: :model do
  describe 'basic functionality without associations' do
    it 'can create a school without place association' do
      school = School.new(
        name: 'Test School',
        slug: 'test-school',
        status: 'published'
      )
      expect(school.valid?).to be true
    end

    it 'validates required name' do
      school = School.new(slug: 'test-school', status: 'published')
      expect(school.valid?).to be false
      expect(school.errors[:name]).to include("can't be blank")
    end

    it 'validates required slug' do
      school = School.new(name: 'Test School', status: 'published')
      expect(school.valid?).to be true
      expect(school.slug).to be_present # Should auto-generate
    end

    it 'validates status inclusion' do
      expect {
        School.new(name: 'Test School', slug: 'test', status: 'invalid_status')
      }.to raise_error(ArgumentError, "'invalid_status' is not a valid status")
    end
  end
end
