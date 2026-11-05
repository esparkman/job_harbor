# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class ErrorGroupTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup { freeze_time }

    test "groups failed jobs by exception class with counts and first and last failure times" do
      fail_with "Net::OpenTimeout", at: 2.hours.ago
      fail_with "Net::OpenTimeout", at: 1.hour.ago
      fail_with "Redis::ConnectionError", at: 5.minutes.ago

      groups = ErrorGroup.of(SolidQueue::Job.all)

      assert_equal [ [ "Net::OpenTimeout", 2, 2.hours.ago, 1.hour.ago ], [ "Redis::ConnectionError", 1, 5.minutes.ago, 5.minutes.ago ] ],
        groups.map { |group| [ group.exception_class, group.count, group.first_seen_at, group.last_seen_at ] }
    end

    test "counts only failures of the given jobs" do
      kept = fail_with "Net::OpenTimeout"
      fail_with "Net::OpenTimeout"

      assert_equal [ 1 ], ErrorGroup.of(SolidQueue::Job.where(id: kept.id)).map(&:count)
    end

    test "an error that is not a JSON object, or has no exception class, groups as Unknown error" do
      fail_with nil
      job = enqueue_job(ReportJob, "plain")
      SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
      SolidQueue::FailedExecution.create!(job: job, error: "worker crashed")

      assert_equal [ [ "Unknown error", 2 ] ], ErrorGroup.of(SolidQueue::Job.all).map { |group| [ group.exception_class, group.count ] }
    end

    test "a blank, null, numeric or literal Unknown error class all fold into the one Unknown error group" do
      [ "", "  ", nil, "Unknown error" ].each { |value| fail_raw(exception_class: value) }
      numeric = fail_raw(exception_class: 123)

      assert_equal [ [ "Unknown error", 4 ], [ "123", 1 ] ],
        ErrorGroup.of(SolidQueue::Job.all).map { |group| [ group.exception_class, group.count ] }
      assert_equal 4, ErrorGroup.matching(ErrorGroup::UNKNOWN).count
      assert_equal [ numeric.id ], ErrorGroup.matching("123").pluck(:job_id), "A numeric class must still be actionable"
    end

    test "matching finds the failures of one group, including Unknown error" do
      timeout = fail_with "Net::OpenTimeout"
      unknown = fail_with nil

      assert_equal [ timeout.id ], ErrorGroup.matching("Net::OpenTimeout").pluck(:job_id)
      assert_equal [ unknown.id ], ErrorGroup.matching(ErrorGroup::UNKNOWN).pluck(:job_id)
    end

    test "grouping runs the same number of queries for one group as for many" do
      fail_with "Net::OpenTimeout"
      one = capture_sql { ErrorGroup.of(SolidQueue::Job.all) }.size

      %w[A B C D].each { |name| 3.times { fail_with "#{name}Error" } }
      many = capture_sql { ErrorGroup.of(SolidQueue::Job.all) }.size

      assert_equal one, many
    end

    private
      def fail_raw(error)
        job = enqueue_job(ReportJob, "raw")
        SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
        SolidQueue::FailedExecution.create!(job: job, error: error.merge(message: "boom"))
        job
      end

      def fail_with(exception_class, at: Time.current)
        job = enqueue_job(ReportJob, "failing")
        SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
        error = { exception_class: exception_class, message: "boom", backtrace: [] }.compact
        travel_to(at) { SolidQueue::FailedExecution.create!(job: job, error: error) }
        job
      end
  end
end
