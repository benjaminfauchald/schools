require 'rails_helper'

RSpec.describe 'Basic RSpec Setup', type: :model do
  it 'can run basic tests' do
    expect(1 + 1).to eq(2)
  end

  it 'has Rails environment loaded' do
    expect(Rails.env).to eq('test')
  end

  it 'has database connection' do
    expect(ActiveRecord::Base.connection).to be_present
  end
end
