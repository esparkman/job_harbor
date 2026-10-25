# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class QueueStatsTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup do
      @worker = register_worker(name: "worker-1")
      seed_queue("mailers", ready: 1, later: 1, running: 1, failed: 1, throttled: 2, done: 1)
      seed_queue("reports", ready: 2, later: 2, running: 2, failed: 3, throttled: 3, done: 0)
    end

    test "counts each status for the queue alone, ignoring jobs in other queues" do
      expected = {
        "mailers" => { "pending" => 2, "scheduled" => 1, "in_progress" => 1, "failed" => 1, "blocked" => 1, "finished" => 1 },
        "reports" => { "pending" => 3, "scheduled" => 2, "in_progress" => 2, "failed" => 3, "blocked" => 2, "finished" => 0 }
      }

      expected.each do |name, counts|
        stats = QueueStats.new(name)
        assert_equal counts, JobStatus.all.to_h { |status| [ status.key, stats.count(status) ] },
          "#{name} counted jobs from another queue or missed its own"
      end
    end

    test "a queue with no jobs counts zero for every status" do
      stats = QueueStats.new("empty")

      assert_equal JobStatus.keys.to_h { |key| [ key, 0 ] }, JobStatus.all.to_h { |status| [ status.key, stats.count(status) ] }
    end

    test "counting a status takes a single query" do
      JobStatus.all.each do |status|
        assert_equal 1, count_queries { QueueStats.new("mailers").count(status) }.size, "#{status.key} count ran more than one query"
      end
    end

    private
      def seed_queue(queue, ready:, later:, running:, failed:, throttled:, done:)
        ready.times { |n| enqueue_job(ReportJob, "ready-#{n}", queue: queue) }
        later.times { |n| enqueue_job(NewsletterJob, "later-#{n}", queue: queue, at: 2.hours.from_now) }
        running.times { |n| claim_job(enqueue_job(ReportJob, "running-#{n}", queue: queue), worker: @worker) }
        failed.times { |n| fail_job(enqueue_job(FlakyPaymentJob, n, queue: queue), worker: @worker) }
        throttled.times { enqueue_job(ThrottledImportJob, "acme-#{queue}", queue: queue) }
        done.times { |n| finish_job(enqueue_job(ReportJob, "done-#{n}", queue: queue), worker: @worker) }
      end
  end
end
