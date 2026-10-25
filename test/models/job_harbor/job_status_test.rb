# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobStatusTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    test "statuses come in the order the tabs and cards show them" do
      assert_equal %w[pending scheduled in_progress failed blocked finished], JobStatus.keys
    end

    test "each status keeps the label and colour the badges have always used" do
      shown = JobStatus.all.map { |status| [ status.key, status.label, status.badge_class, status.circle_class ] }

      assert_equal [
        [ "pending", "Pending", "badge-sky", "circle-sky" ],
        [ "scheduled", "Scheduled", "badge-yellow", "circle-yellow" ],
        [ "in_progress", "In Progress", "badge-amber", "circle-amber" ],
        [ "failed", "Failed", "badge-red", "circle-red" ],
        [ "blocked", "Blocked", "badge-zinc", "circle-zinc" ],
        [ "finished", "Finished", "badge-green", "circle-green" ]
      ], shown
    end

    test "every status but finished maps to a real Solid Queue execution association" do
      JobStatus.all.reject(&:finished?).each do |status|
        reflection = SolidQueue::Job.reflect_on_association(status.execution_association)
        assert reflection, "#{status.key} points at a missing association"
        assert_equal reflection.klass, status.execution_class
      end
      assert_nil JobStatus.find("finished").execution_association
      assert_nil JobStatus.find("finished").execution_class
    end

    test "precedence lists every job status that has an execution, once" do
      assert_equal JobStatus.all.reject(&:finished?).map(&:key).sort, JobStatus.by_precedence.map(&:key).sort
      assert_equal %w[failed in_progress blocked scheduled pending], JobStatus.by_precedence.map(&:key)
    end

    test "find takes a string or symbol and answers nil for an unknown status" do
      assert_equal "in_progress", JobStatus.find(:in_progress).key
      assert_equal "failed", JobStatus.find("failed").key
      assert_nil JobStatus.find("unknown")
      assert_nil JobStatus.find(nil)
    end

    test "each status names the route helper its tab links to" do
      assert_equal :in_progress_jobs_path, JobStatus.find("in_progress").path_helper
      JobStatus.all.each do |status|
        assert_equal "/job_harbor/jobs/status/#{status.key}", JobHarbor::Engine.routes.url_helpers.public_send(status.path_helper)
      end
    end

    test "only failed jobs can be retried and only failed and blocked ones are bulk-actionable" do
      assert_equal %w[failed], JobStatus.all.select(&:retryable).map(&:key)
      assert_equal %w[failed], JobStatus.all.select(&:bulk_retry?).map(&:key)
      assert_equal %w[failed blocked], JobStatus.all.select(&:bulk_actions).map(&:key)
      assert_equal %w[pending scheduled failed blocked], JobStatus.all.select(&:discardable).map(&:key)
    end

    test "count and jobs agree for every status on live data" do
      worker = register_worker(name: "worker-1")
      enqueue_job(ReportJob, "ready")
      enqueue_job(NewsletterJob, "later", at: 2.hours.from_now)
      claim_job(enqueue_job(ReportJob, "running"), worker: worker)
      fail_job(enqueue_job(FlakyPaymentJob, 1), worker: worker)
      finish_job(enqueue_job(ReportJob, "done"), worker: worker)

      expected = { "pending" => 1, "scheduled" => 1, "in_progress" => 1, "failed" => 1, "blocked" => 0, "finished" => 1 }
      assert_equal expected, JobStatus.all.to_h { |status| [ status.key, status.count ] }
      assert_equal expected, JobStatus.all.to_h { |status| [ status.key, status.jobs.count ] }
    end

    test "counting for a queue counts only that queue's jobs, whichever table carries the queue name" do
      worker = register_worker(name: "worker-1")
      enqueue_job(ReportJob, "ready")
      enqueue_job(ReportJob, "elsewhere", queue: "mailers")
      enqueue_job(NewsletterJob, "later", at: 2.hours.from_now)
      enqueue_job(NewsletterJob, "later elsewhere", queue: "mailers", at: 2.hours.from_now)
      claim_job(enqueue_job(ReportJob, "running"), worker: worker)
      fail_job(enqueue_job(FlakyPaymentJob, 1), worker: worker)
      claim_job(enqueue_job(ReportJob, "running elsewhere", queue: "mailers"), worker: worker)
      fail_job(enqueue_job(FlakyPaymentJob, 2, queue: "mailers"), worker: worker)
      2.times { enqueue_job(ThrottledImportJob, "acme") }
      2.times { enqueue_job(ThrottledImportJob, "acme-mailers", queue: "mailers") }
      finish_job(enqueue_job(ReportJob, "done"), worker: worker)
      finish_job(enqueue_job(ReportJob, "done elsewhere", queue: "mailers"), worker: worker)

      expected = { "pending" => 2, "scheduled" => 1, "in_progress" => 1, "failed" => 1, "blocked" => 1, "finished" => 1 }
      assert_equal expected, JobStatus.all.to_h { |status| [ status.key, status.count(queue_name: "default") ] }
      assert_equal 0, JobStatus.find("failed").count(queue_name: "nowhere")
    end
  end
end
