require "test_helper"

class JobListQueriesTest < ActionDispatch::IntegrationTest
  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")
  end

  test "operator opens All Jobs and the page runs the same number of queries for 10 jobs as for 30" do
    enqueue_mixed_jobs(10)
    ten = count_queries { get "/job_harbor/jobs", params: { per_page: 100 } }.size
    assert_equal 10, job_rows.size

    enqueue_mixed_jobs(20)
    thirty = count_queries { get "/job_harbor/jobs", params: { per_page: 100 } }.size
    assert_equal 30, job_rows.size

    assert_equal ten, thirty, "All Jobs ran more SQL for 30 jobs than for 10: the status of each row is queried separately"
  end

  test "operator opens the Failed tab and the page runs the same number of queries however many jobs failed" do
    enqueue_mixed_jobs(10)
    few = count_queries { get "/job_harbor/jobs/status/failed", params: { per_page: 100 } }.size
    failed_few = job_rows.size

    enqueue_mixed_jobs(20)
    many = count_queries { get "/job_harbor/jobs/status/failed", params: { per_page: 100 } }.size

    assert_operator job_rows.size, :>, failed_few
    assert_equal few, many, "The Failed tab ran more SQL for more failed jobs"
  end

  test "operator searches and the results page runs the same number of queries however many jobs match" do
    enqueue_mixed_jobs(10)
    few = count_queries { get "/job_harbor/search", params: { q: "Job", per_page: 100 } }.size
    matches_few = job_rows.size

    enqueue_mixed_jobs(20)
    many = count_queries { get "/job_harbor/search", params: { q: "Job", per_page: 100 } }.size

    assert_operator job_rows.size, :>, matches_few
    assert_equal few, many, "Search ran more SQL for more matching jobs"
  end

  test "operator opens a queue page and it runs the same number of queries for 10 jobs as for 30" do
    enqueue_mixed_jobs(10)
    ten = count_queries { get "/job_harbor/queues/default" }.size

    enqueue_mixed_jobs(20)
    thirty = count_queries { get "/job_harbor/queues/default" }.size

    assert_equal ten, thirty, "The queue page ran more SQL for 30 jobs than for 10"
  end

  private
    # Cycles pending, scheduled, running, failed, blocked and finished jobs.
    def enqueue_mixed_jobs(count)
      count.times do |i|
        case i % 6
        when 0 then enqueue_job(ReportJob, "pending-#{i}")
        when 1 then enqueue_job(NewsletterJob, "later-#{i}", at: 2.hours.from_now)
        when 2 then claim_job(enqueue_job(ReportJob, "running-#{i}"), worker: @worker)
        when 3 then fail_job(enqueue_job(FlakyPaymentJob, i), worker: @worker)
        when 4 then enqueue_job(ThrottledImportJob, "acme")
        when 5 then finish_job(enqueue_job(ReportJob, "done-#{i}"), worker: @worker)
        end
      end
    end

    def job_rows
      css_select("table.sqd-table tbody tr")
    end
end
