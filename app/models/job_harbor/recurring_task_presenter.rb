# frozen_string_literal: true

module JobHarbor
  class RecurringTaskPresenter
    def initialize(task)
      @task = task
    end

    def arguments?
      stored_arguments.present?
    end

    def formatted_arguments
      ArgumentFilter.pretty_generate(stored_arguments)
    end

    private

    # The stored JSON, not task.arguments: that deserializes GlobalIDs and raises for a deleted record.
    def stored_arguments
      @stored_arguments ||= begin
        raw = @task.read_attribute_before_type_cast(:arguments)
        raw.is_a?(String) ? JSON.parse(raw) : raw
      rescue JSON::ParserError
        raw
      end
    end
  end
end
