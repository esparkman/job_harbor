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
        assert_equal 1, capture_sql { QueueStats.new("mailers").count(status) }.size, "#{status.key} count ran more than one query"
      end
    end

    test "names lists every queue once, sorted, including a paused queue that has no jobs" do
      SolidQueue::Pause.create!(queue_name: "archive")
      SolidQueue::Pause.create!(queue_name: "mailers")

      assert_equal %w[archive mailers reports], QueueStats.names
    end

    test "a queue whose jobs have all finished still appears on the Queues page" do
      finish_job(enqueue_job(ReportJob, queue: "archive"), worker: @worker)

      assert_includes QueueStats.all.map(&:name), "archive"
    end

    test "find returns a queue that has jobs" do
      assert_equal "mailers", QueueStats.find("mailers").name
    end

    test "find returns a paused queue that has no jobs" do
      SolidQueue::Pause.create!(queue_name: "archive")

      assert_equal "archive", QueueStats.find("archive").name
    end

    test "find returns nil for an unknown queue" do
      assert_nil QueueStats.find("nope")
    end

    test "oldest ready at is when the longest-waiting ready job became ready, ignoring scheduled and running jobs" do
      freeze_time
      travel_to(2.hours.ago) { enqueue_job(ReportJob, "old", queue: "slow") }
      travel_to(10.minutes.ago) { enqueue_job(ReportJob, "new", queue: "slow") }
      travel_to(3.days.ago) do
        enqueue_job(NewsletterJob, "overdue", queue: "slow", at: 1.hour.from_now)
        claim_job(enqueue_job(ReportJob, "running", queue: "slow"), worker: @worker)
      end

      assert_equal 2.hours.ago, QueueStats.new("slow").oldest_ready_at
    end

    test "a scheduled job starts waiting when it is dispatched, not when it was enqueued" do
      freeze_time
      travel_to(3.days.ago) { enqueue_job(NewsletterJob, "digest", queue: "slow", at: 1.hour.from_now) }
      # Dispatch stamps ready executions with the database clock, which time travel can't move, so dispatch now and wait.
      SolidQueue::ScheduledExecution.dispatch_next_batch(10)
      travel 5.minutes

      assert_in_delta 5.minutes.ago, QueueStats.new("slow").oldest_ready_at, 1.second
    end

    test "a queue with no ready jobs has no oldest ready time" do
      claim_job(enqueue_job(ReportJob, "running", queue: "busy"), worker: @worker)

      assert_nil QueueStats.new("busy").oldest_ready_at
    end

    test "oldest ready at takes a single query" do
      assert_equal 1, capture_sql { QueueStats.new("mailers").oldest_ready_at }.size
    end

    test "longest waiting is the unpaused queue whose oldest ready job has waited longest" do
      freeze_time
      travel_to(2.hours.ago) { enqueue_job(ReportJob, "old", queue: "slow") }
      travel_to(3.days.ago) { enqueue_job(ReportJob, "older", queue: "stopped") }
      SolidQueue::Pause.create!(queue_name: "stopped")

      waiting = QueueStats.longest_waiting

      assert_equal "slow", waiting.name
      assert_no_queries { assert_equal 2.hours.ago, waiting.oldest_ready_at }
    end

    test "longest waiting is nil when every queue with ready jobs is paused" do
      SolidQueue::ReadyExecution.distinct.pluck(:queue_name).each { |name| SolidQueue::Pause.create!(queue_name: name) }

      assert_nil QueueStats.longest_waiting
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
