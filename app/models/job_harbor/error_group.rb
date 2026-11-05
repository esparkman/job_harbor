# frozen_string_literal: true

module JobHarbor
  # Failed jobs that raised the same exception class. latest_failure is a JobPresenter, so its message is masked.
  ErrorGroup = Data.define(:exception_class, :count, :first_seen_at, :last_seen_at, :latest_failure) do
    class << self
      def of(jobs)
        table = SolidQueue::FailedExecution.quoted_table_name
        rows = SolidQueue::FailedExecution.where(job_id: jobs.select(:id)).group(Arel.sql(exception_class_sql))
          .pluck(Arel.sql(exception_class_sql), Arel.sql("COUNT(*)"), Arel.sql("MIN(#{table}.created_at)"), Arel.sql("MAX(#{table}.id)"))
        latest = SolidQueue::FailedExecution.includes(:job).where(id: rows.map(&:last)).index_by(&:id)
        time = SolidQueue::FailedExecution.type_for_attribute(:created_at)

        # A group retried or discarded since the first query has no latest failure left, so it is skipped.
        rows.filter_map do |key, count, first_seen, latest_id|
          execution = latest[latest_id]
          next unless execution&.job

          new(exception_class: key || ErrorGroup::UNKNOWN, count: count, first_seen_at: time.deserialize(first_seen),
            last_seen_at: execution.created_at, latest_failure: JobPresenter.new(execution.job, failed_execution: execution))
        end.sort_by { |group| [ -group.count, -group.last_seen_at.to_f ] }
      end

      def matching(exception_class)
        if exception_class == ErrorGroup::UNKNOWN
          SolidQueue::FailedExecution.where("#{exception_class_sql} IS NULL")
        else
          SolidQueue::FailedExecution.where("#{exception_class_sql} = ?", exception_class)
        end
      end

      private

      # Blank, JSON null and the Unknown label itself all fold into NULL, so every Unknown failure is one group.
      def exception_class_sql
        value = JsonColumn.value(SolidQueue::FailedExecution, :error, "exception_class") || "NULL"
        "NULLIF(NULLIF(NULLIF(TRIM(#{value}), ''), 'null'), '#{ErrorGroup::UNKNOWN}')"
      end
    end
  end

  ErrorGroup::UNKNOWN = "Unknown error"
end
