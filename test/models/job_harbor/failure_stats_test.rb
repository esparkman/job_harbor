# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class FailureStatsTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup do
      freeze_time
      @worker = register_worker(name: "w")
    end

    test "stats is empty when there are no jobs" do
      assert_equal [], FailureStats.new.stats
    end

    test "each job class gets its total, failed count and rate, worst rate first" do
      3.times { |i| enqueue_job(FlakyPaymentJob, i) }
      fail_job(enqueue_job(FlakyPaymentJob, 99), worker: @worker)
      2.times { |i| enqueue_job(ReportJob, i) }
      enqueue_job(NewsletterJob, "digest")

      assert_equal [
        { class_name: "FlakyPaymentJob", total: 4, failed: 1, rate: 25.0 },
        { class_name: "NewsletterJob", total: 1, failed: 0, rate: 0.0 },
        { class_name: "ReportJob", total: 2, failed: 0, rate: 0.0 }
      ], FailureStats.new.stats.sort_by { |s| [ -s[:rate], s[:class_name] ] }
    end

    test "rates are rounded to one decimal" do
      2.times { |i| enqueue_job(FlakyPaymentJob, i) }
      fail_job(enqueue_job(FlakyPaymentJob, 99), worker: @worker)

      assert_equal 33.3, FailureStats.new.stats.first[:rate]
    end

    test "jobs enqueued before the 24 hour window are left out" do
      enqueue_job(ReportJob, "old").update_columns(created_at: 25.hours.ago)
      old_failure = fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      old_failure.update_columns(created_at: 2.days.ago)
      enqueue_job(ReportJob, "new")

      assert_equal [ { class_name: "ReportJob", total: 1, failed: 0, rate: 0.0 } ], FailureStats.new.stats
    end

    test "the query count stays the same however many jobs there are" do
      baseline = count_queries { FailureStats.new.stats }.size

      30.times { |i| enqueue_job(ReportJob, i) }
      5.times { |i| fail_job(enqueue_job(FlakyPaymentJob, i), worker: @worker) }
      queries = count_queries { FailureStats.new.stats }

      assert_equal 2, baseline
      assert_equal baseline, queries.size, "Failure stats should not query per job or per class, got:\n#{queries.join("\n")}"
    end
  end
end
