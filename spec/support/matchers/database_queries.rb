RSpec::Matchers.define :make_database_queries do |options|
  supports_block_expectations

  match do |block|
    @queries = []
    ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      @queries << payload[:sql] unless payload[:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|PRAGMA|SELECT.*FROM.*schema_migrations)/)
    end

    block.call

    ActiveSupport::Notifications.unsubscribe('sql.active_record')

    if options[:count]
      case options[:count]
      when Range
        options[:count].include?(@queries.size)
      when Integer
        @queries.size == options[:count]
      else
        false
      end
    else
      true
    end
  end

  failure_message do |_block|
    if options[:count]
      "expected #{options[:count]} database queries but got #{@queries.size}:\n#{@queries.join("\n")}"
    else
      "expected to make database queries"
    end
  end

  failure_message_when_negated do |_block|
    "expected not to make database queries but made #{@queries.size}"
  end
end
