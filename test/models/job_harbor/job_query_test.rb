# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobQueryTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup do
      @worker = register_worker(name: "worker-1")
    end

    teardown { JobHarbor.configuration.filter_parameters = nil }

    test "the job list shows the newest job first" do
      older = enqueue_job(ReportJob)
      newer = enqueue_job(ReportJob)
      newer.update_columns(created_at: 1.day.ago)

      _, jobs = JobQuery.new.page(1, per_page: 25)

      assert_equal [ newer.id, older.id ], jobs.map(&:id), "Order follows the primary key, which rises with insert order"
    end

    test "page info reports page, pages, count, prev and next across first, middle and last page" do
      5.times { |i| SolidQueue::Job.create!(queue_name: "default", class_name: "PageJob#{i}", arguments: "{}") }
      query = JobQuery.new

      first, first_jobs = query.page(1, per_page: 2)
      assert_equal [ 1, 3, 5, nil, 2 ], [ first.page, first.pages, first.count, first.prev, first.next ]
      assert_equal 2, first_jobs.size

      middle, = query.page(2, per_page: 2)
      assert_equal [ 2, 3, 5, 1, 3 ], [ middle.page, middle.pages, middle.count, middle.prev, middle.next ]

      last, last_jobs = query.page(3, per_page: 2)
      assert_equal [ 3, 3, 5, 2, nil ], [ last.page, last.pages, last.count, last.prev, last.next ]
      assert_equal 1, last_jobs.size
    end

    test "a page number past the end or below one lands on a real page" do
      3.times { enqueue_job(ReportJob) }

      assert_equal 2, JobQuery.new.page(99, per_page: 2).first.page
      assert_equal 1, JobQuery.new.page("junk", per_page: 2).first.page
      assert_equal 1, JobQuery.new.page(-4, per_page: 2).first.page
    end

    test "an empty list is one empty page" do
      info, jobs = JobQuery.new.page(1, per_page: 25)

      assert_equal [ 1, 0, 0 ], [ info.page, info.pages, info.count ]
      assert_empty jobs
    end

    test "each status tab lists only jobs in that status" do
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
        _, found = JobQuery.new(status: status).page(1, per_page: 25)
        assert_includes found.map(&:id), jobs.first.id, "#{status} tab is missing its job"
        assert_equal [ status ], found.map(&:status).uniq, "#{status} tab lists jobs in another status"
      end
    end

    test "an unknown or blank status lists every job" do
      enqueue_job(ReportJob)
      enqueue_job(NewsletterJob, at: 1.hour.from_now)

      [ nil, "", "nonsense" ].each do |status|
        assert_equal 2, JobQuery.new(status: status).page(1, per_page: 25).first.count
      end
    end

    test "class and queue filters narrow the list, and blank filters are ignored" do
      wanted = enqueue_job(ReportJob, queue: "critical")
      enqueue_job(ReportJob, queue: "default")
      enqueue_job(NewsletterJob, queue: "critical")

      assert_equal [ wanted.id ], JobQuery.new(class_name: "ReportJob", queue_name: "critical").page(1, per_page: 25).last.map(&:id)
      assert_equal 3, JobQuery.new(class_name: "", queue_name: "").page(1, per_page: 25).first.count
    end

    test "filters apply within a status tab" do
      failed = fail_job(enqueue_job(FlakyPaymentJob, 1, queue: "critical"), worker: @worker)
      fail_job(enqueue_job(FlakyPaymentJob, 2, queue: "default"), worker: @worker)

      _, jobs = JobQuery.new(status: "failed", queue_name: "critical").page(1, per_page: 25)

      assert_equal [ failed.id ], jobs.map(&:id)
    end

    test "the job list runs the same number of queries however many jobs are on the page" do
      enqueue_job(ReportJob)
      few = count_queries { JobQuery.new.page(1, per_page: 25) }.size
      claim_job(enqueue_job(ReportJob), worker: @worker)
      fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      enqueue_job(NewsletterJob, at: 1.hour.from_now)
      many = count_queries { JobQuery.new.page(1, per_page: 25) }.size

      assert_equal few, many, "The job list should preload executions instead of querying per row"
    end

    test "filter options list each job class and queue once, sorted" do
      enqueue_job(ReportJob, queue: "reports")
      enqueue_job(ReportJob, queue: "default")
      enqueue_job(NewsletterJob, queue: "default")

      assert_equal({ class_names: %w[NewsletterJob ReportJob], queue_names: %w[default reports] }, JobQuery.filter_options)
    end

    test "filter options are empty before any job exists" do
      assert_equal({ class_names: [], queue_names: [] }, JobQuery.filter_options)
    end

    test "counts show the total and each status tab in display order" do
      enqueue_job(ReportJob)
      enqueue_job(NewsletterJob, at: 1.hour.from_now)
      claim_job(enqueue_job(ReportJob), worker: @worker)
      fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      finish_job(enqueue_job(ReportJob), worker: @worker)

      counts = JobQuery.counts

      assert_equal [ "all", *JobStatus.keys ], counts.keys
      assert_equal({ "all" => 5, "pending" => 1, "scheduled" => 1, "in_progress" => 1, "failed" => 1, "blocked" => 0, "finished" => 1 }, counts)
    end

    test "bulk jobs are offered only on tabs with bulk actions" do
      %w[pending scheduled in_progress finished].each do |status|
        assert_nil JobQuery.new(status: status).bulk_jobs, "#{status} tab should not offer bulk actions"
      end
      assert_nil JobQuery.new.bulk_jobs
      assert_nil JobQuery.new(status: "nonsense").bulk_jobs
      assert_not_nil JobQuery.new(status: "failed").bulk_jobs
      assert_not_nil JobQuery.new(status: "blocked").bulk_jobs
    end

    test "bulk jobs are the failed jobs the class and queue filters leave" do
      keep = fail_job(enqueue_job(FlakyPaymentJob, 1, queue: "critical"), worker: @worker)
      fail_job(enqueue_job(FlakyPaymentJob, 2, queue: "default"), worker: @worker)
      enqueue_job(ReportJob, queue: "critical")

      assert_equal 2, JobQuery.new(status: "failed").bulk_jobs.count
      assert_equal [ keep.id ], JobQuery.new(status: "failed", class_name: "FlakyPaymentJob", queue_name: "critical").bulk_jobs.ids
      assert_equal 0, JobQuery.new(status: "failed", class_name: "ReportJob").bulk_jobs.count
    end

    test "bulk jobs act on exactly the jobs the list shows when status, filters and search are all given" do
      keep = fail_job(enqueue_job(FlakyPaymentJob, 1, queue: "critical"), worker: @worker)
      fail_job(enqueue_job(FlakyPaymentJob, 2, queue: "critical"), worker: @worker)
      enqueue_job(FlakyPaymentJob, 3, queue: "critical")
      query = JobQuery.new(status: "failed", class_name: "FlakyPaymentJob", queue_name: "critical", search: keep.id.to_s)

      assert_equal [ keep.id ], query.jobs.ids
      assert_equal query.jobs.ids, query.bulk_jobs.ids, "A bulk action would touch jobs the list does not show"
    end

    test "searching within a status tab narrows to that status" do
      failed = fail_job(enqueue_job(FlakyPaymentJob, 1), worker: @worker)
      enqueue_job(FlakyPaymentJob, 2)

      assert_equal [ failed.id ], JobQuery.new(status: "failed", search: "Flaky").jobs.ids
    end

    test "bulk jobs on the blocked tab are the blocked jobs" do
      enqueue_job(ThrottledImportJob, "acme")
      blocked = enqueue_job(ThrottledImportJob, "acme")

      assert_equal [ blocked.id ], JobQuery.new(status: "blocked").bulk_jobs.ids
    end

    test "searching by class name finds the job whatever the case" do
      enqueue_job(NewsletterJob)
      report = enqueue_job(ReportJob)

      %w[ReportJob reportjob port].each do |text|
        assert_equal [ report.id ], JobQuery.search(text).page(1, per_page: 25).last.map(&:id), "Searching #{text.inspect} missed the job"
      end
    end

    test "searching with filtering on does not find a job by its argument text" do
      enqueue_job(ReportJob, "hunter2")

      assert_equal 0, JobQuery.search("hunter2").page(1, per_page: 25).first.count
    end

    test "searching with filtering off finds jobs by argument text" do
      JobHarbor.configuration.filter_parameters = false
      job = enqueue_job(ReportJob, "hunter2")
      enqueue_job(ReportJob, "other")

      assert_equal [ job.id ], JobQuery.search("hunter2").page(1, per_page: 25).last.map(&:id)
    end

    test "searching by a numeric job id finds that job while filtering is on" do
      job = enqueue_job(ReportJob)

      assert_equal [ job.id ], JobQuery.search(job.id.to_s).page(1, per_page: 25).last.map(&:id)
    end

    test "searching by an Active Job ID finds exactly that job while filtering is on" do
      job = enqueue_job(ReportJob)
      enqueue_job(ReportJob)

      assert_equal [ job.id ], JobQuery.search(job.active_job_id).page(1, per_page: 25).last.map(&:id)
    end

    test "searching for a percent sign or underscore matches that character, not a wildcard" do
      enqueue_job(ReportJob)
      enqueue_job(NewsletterJob)

      assert_equal 0, JobQuery.search("%").page(1, per_page: 25).first.count
      assert_equal 0, JobQuery.search("Repor_Job").page(1, per_page: 25).first.count
      assert_equal 0, JobQuery.search("Report_ob").page(1, per_page: 25).first.count
    end

    test "search results are paginated with the same page info as the job list" do
      3.times { enqueue_job(ReportJob) }

      info, jobs = JobQuery.search("Report").page(2, per_page: 2)

      assert_equal [ 2, 2, 3 ], [ info.page, info.pages, info.count ]
      assert_equal 1, jobs.size
    end
  end
end
