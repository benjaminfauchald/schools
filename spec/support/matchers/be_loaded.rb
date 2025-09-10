RSpec::Matchers.define :be_loaded do
  match do |association|
    association.loaded?
  end

  failure_message do |association|
    "expected #{association} to be loaded but it was not"
  end

  failure_message_when_negated do |association|
    "expected #{association} not to be loaded but it was"
  end
end
