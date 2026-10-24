# frozen_string_literal: true

module JobHarbor
  class RecurringTaskArguments
    def initialize(task)
      @task = task
    end

    def present?
      stored.present?
    end

    def formatted
      SensitiveValueFilter.pretty_generate(stored)
    end

    private

    # The stored JSON, not task.arguments: that deserializes GlobalIDs and raises for a deleted record.
    def stored
      @stored ||= begin
        raw = @task.read_attribute_before_type_cast(:arguments)
        raw.is_a?(String) ? JSON.parse(raw) : raw
      rescue JSON::ParserError
        raw
      end
    end
  end
end
