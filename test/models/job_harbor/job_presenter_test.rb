# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobPresenterTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup do
      @worker = register_worker(name: "worker-1")
    end

    test "serialized_payload is the whole Active Job payload an enqueued job was stored with" do
      presenter = JobPresenter.new(enqueue_job(ReportJob, "weekly", 42))

      payload = presenter.serialized_payload
      assert_equal "ReportJob", payload["job_class"]
      assert_equal [ "weekly", 42 ], payload["arguments"]
      assert_equal 0, payload["executions"]
      assert_includes payload.keys, "locale"
    end

    test "job_arguments are the arguments the job was enqueued with, not the payload around them" do
      presenter = JobPresenter.new(enqueue_job(ReportJob, "weekly", { "region" => "eu" }))

      assert_equal "weekly", presenter.job_arguments.first
      assert_equal "eu", presenter.job_arguments.last["region"]
      assert_equal 2, presenter.job_arguments.size
    end

    test "job_arguments is empty when the job was enqueued without any" do
      assert_empty JobPresenter.new(enqueue_job(NewsletterJob)).job_arguments
    end

    test "job_arguments and serialized_payload tolerate a row whose arguments are not a payload hash" do
      job = SolidQueue::Job.create!(queue_name: "default", class_name: "OddJob", arguments: "{}")
      presenter = JobPresenter.new(job)

      assert_empty presenter.job_arguments
      assert_equal "{}", presenter.serialized_payload
    end

    test "formatted_arguments and formatted_payload are pretty-printed JSON" do
      presenter = JobPresenter.new(enqueue_job(ReportJob, "weekly"))

      assert_equal "[\n  \"weekly\"\n]", presenter.formatted_arguments
      assert_equal "ReportJob", JSON.parse(presenter.formatted_payload)["job_class"]
    end

    test "a fresh job is attempt 1 and shows no retry badge" do
      presenter = JobPresenter.new(enqueue_job(ReportJob))

      assert_equal 0, presenter.serialized_payload["executions"]
      assert_equal 1, presenter.execution_count
      assert_nil presenter.retry_badge
    end

    test "a job whose payload records one earlier run is attempt 2 and shows (x2)" do
      job = enqueue_job(ReportJob)
      job.update!(arguments: job.arguments.merge("executions" => 1))

      presenter = JobPresenter.new(job)
      assert_equal 2, presenter.execution_count
      assert_equal "(x2)", presenter.retry_badge
    end

    test "a job whose payload records two earlier runs is attempt 3 and shows (x3)" do
      job = enqueue_job(ReportJob)
      job.update!(arguments: job.arguments.merge("executions" => 2))

      presenter = JobPresenter.new(job)
      assert_equal 3, presenter.execution_count
      assert_equal "(x3)", presenter.retry_badge
    end

    test "status names where each job is in its lifecycle" do
      pending = enqueue_job(ReportJob)
      scheduled = enqueue_job(NewsletterJob, at: 1.hour.from_now)
      running = claim_job(enqueue_job(ReportJob), worker: @worker).job
      failed = fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      finished = finish_job(enqueue_job(ReportJob), worker: @worker)
      enqueue_job(ThrottledImportJob, "acme")
      blocked = enqueue_job(ThrottledImportJob, "acme")
      orphan = enqueue_job(ReportJob)
      orphan.ready_execution.destroy

      statuses = [ pending, scheduled, running, failed, blocked, finished, orphan ].map { |job| JobPresenter.new(SolidQueue::Job.find(job.id)).status }

      assert_equal %w[pending scheduled in_progress failed blocked finished unknown], statuses
    end

    test "status reports failed ahead of any other execution the job still holds" do
      job = fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      SolidQueue::ReadyExecution.create!(job_id: job.id, queue_name: job.queue_name, priority: job.priority)

      assert_equal "failed", JobPresenter.new(SolidQueue::Job.find(job.id)).status
    end

    test "running_duration is how long the claimed job has run, and nil for a job that is not running" do
      running = claim_job(enqueue_job(ReportJob), worker: @worker).job
      travel 5.minutes

      assert_equal "5 minutes", JobPresenter.new(SolidQueue::Job.find(running.id)).running_duration
      assert_nil JobPresenter.new(enqueue_job(ReportJob)).running_duration
    end

    test "status and running_duration run no queries once the page's jobs are loaded" do
      claim_job(enqueue_job(ReportJob), worker: @worker)
      fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      enqueue_job(ReportJob)
      enqueue_job(NewsletterJob, at: 1.hour.from_now)

      _, presenters = JobPresenter.all_with_status(nil, per_page: 10)
      queries = []
      counter = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        presenters.each { |presenter| [ presenter.status, presenter.running_duration, presenter.execution_count, presenter.can_retry? ] }
      end

      assert_empty queries, "Reading a loaded row's status should not hit the database"
    end

    test "relative_created_at returns human-readable time" do
      assert_includes JobPresenter.new(enqueue_job(ReportJob)).relative_created_at, "ago"
    end

    test "all_with_status lists the newest job first" do
      older = enqueue_job(ReportJob)
      newer = enqueue_job(ReportJob)
      newer.update_columns(created_at: 1.day.ago)

      _, jobs = JobPresenter.all_with_status(nil)

      assert_equal [ newer.id, older.id ], jobs.map(&:id), "Order follows the primary key, which rises with insert order"
    end

    test "all_with_status page info reports page, pages, count, prev and next across first, middle and last page" do
      5.times { |i| SolidQueue::Job.create!(queue_name: "default", class_name: "PageJob#{i}", arguments: "{}") }

      first, first_jobs = JobPresenter.all_with_status(nil, page: 1, per_page: 2)
      assert_equal [ 1, 3, 5, nil, 2 ], [ first.page, first.pages, first.count, first.prev, first.next ]
      assert_equal 2, first_jobs.size

      middle, = JobPresenter.all_with_status(nil, page: 2, per_page: 2)
      assert_equal [ 2, 3, 5, 1, 3 ], [ middle.page, middle.pages, middle.count, middle.prev, middle.next ]

      last, last_jobs = JobPresenter.all_with_status(nil, page: 3, per_page: 2)
      assert_equal [ 3, 3, 5, 2, nil ], [ last.page, last.pages, last.count, last.prev, last.next ]
      assert_equal 1, last_jobs.size
    end

    test "all_with_status narrows to each status through the job's execution record" do
      pending = enqueue_job(ReportJob)
      scheduled = enqueue_job(NewsletterJob, at: 1.hour.from_now)
      running = claim_job(enqueue_job(ReportJob), worker: @worker).job
      failed = fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      finished = finish_job(enqueue_job(ReportJob), worker: @worker)
      enqueue_job(ThrottledImportJob, "acme")
      blocked = enqueue_job(ThrottledImportJob, "acme")

      expected = { "pending" => [ pending ], "scheduled" => [ scheduled ], "in_progress" => [ running ],
                   "failed" => [ failed ], "blocked" => [ blocked ], "finished" => [ finished ] }
      expected.each do |status, jobs|
        _, found = JobPresenter.all_with_status(status)
        assert_includes found.map(&:id), jobs.first.id, "#{status} tab is missing its job"
        assert_equal [ status ], found.map(&:status).uniq, "#{status} tab lists jobs in another status"
      end
    end
  end
end
