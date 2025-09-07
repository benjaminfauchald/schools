require 'rails_helper'

RSpec.describe School, type: :model do
  describe 'basic database connection' do
    it 'can connect to the database' do
      expect(School.connection).to be_present
    end

    it 'can count schools' do
      expect { School.count }.not_to raise_error
    end
  end
end
