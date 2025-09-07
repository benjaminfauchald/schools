class TDDIndicator
  def self.green
    `osascript -e 'display notification "Tests Passing ✅" with title "RSpec"'`
  end

  def self.red
    `osascript -e 'display notification "Tests Failing ❌" with title "RSpec"'`
  end
end
