require "test_helper"

class JobsPagesTest < ActionDispatch::IntegrationTest
  teardown { JobHarbor.configuration.filter_parameters = nil }

  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")
    @running, @failed = enqueue_job_in_every_state(worker: @worker).values_at(:running, :failed)
  end

  test "operator follows a stale page link past the end and sees the last real page" do
    24.times { |i| enqueue_job(ReportJob, "bulk-#{i}") }
    oldest = SolidQueue::Job.minimum(:id)
    newest = SolidQueue::Job.maximum(:id)

    get "/job_harbor/jobs", params: { page: 99 }

    assert_response :success
    assert_select "a[href=?]", "/job_harbor/jobs/#{oldest}"
    assert_select "a[href=?]", "/job_harbor/jobs/#{newest}", count: 0
    get "/job_harbor/jobs", params: { page: 0 }
    assert_select "a[href=?]", "/job_harbor/jobs/#{newest}"
  end

  test "operator opens All Jobs and sees every job with a count on each status tab" do
    get "/job_harbor/jobs"

    assert_response :success
    assert_select "h1", text: "All Jobs"
    assert_select "a.badge[href=?]", "/job_harbor/jobs", text: /\AAll\s+9\z/
    assert_status_tab_count "pending", 3
    assert_status_tab_count "scheduled", 1
    assert_status_tab_count "in_progress", 1
    assert_status_tab_count "failed", 1
    assert_status_tab_count "blocked", 1
    assert_status_tab_count "finished", 2
    assert_equal 9, job_rows.size, "All Jobs should list every job"
  end

  test "operator opens pending jobs and sees only jobs waiting to run" do
    get "/job_harbor/jobs/status/pending"

    assert_select "h1", text: "Pending Jobs"
    assert_equal [ [ "ReportJob", "default", "Pending" ], [ "ReportJob", "default", "Pending" ], [ "ThrottledImportJob", "imports", "Pending" ] ],
      job_rows.sort
    assert_select "tbody button", text: "Discard", count: 3
  end

  test "operator opens scheduled jobs and sees the job waiting for its run time" do
    get "/job_harbor/jobs/status/scheduled"

    assert_select "h1", text: "Scheduled Jobs"
    assert_equal [ [ "NewsletterJob", "mailers", "Scheduled" ] ], job_rows
  end

  test "operator opens in-progress jobs and sees the running job with how long it has run" do
    get "/job_harbor/jobs/status/in_progress"

    assert_select "h1", text: "In Progress Jobs"
    assert_equal [ [ "ReportJob", "critical", "In Progress" ] ], job_rows
    assert_select "tbody td", text: /\(less than a minute\)/
    assert_select "tbody button", count: 0
  end

  test "operator opens failed jobs and sees the failing job class with retry and discard controls" do
    get "/job_harbor/jobs/status/failed"

    assert_select "h1", text: "Failed Jobs"
    assert_equal [ [ "FlakyPaymentJob", "critical", "Failed" ] ], job_rows
    assert_select "tbody form[action=?] button", "/job_harbor/jobs/#{@failed.id}/retry", text: "Retry"
    assert_select "tbody form[action=?] button", "/job_harbor/jobs/#{@failed.id}/discard", text: "Discard"
    assert_select "button", text: "Retry 1 failed job"
    assert_select "button", text: "Discard 1 failed job"
  end

  test "operator opens blocked jobs and sees the job held back by its concurrency limit" do
    get "/job_harbor/jobs/status/blocked"

    assert_select "h1", text: "Blocked Jobs"
    assert_equal [ [ "ThrottledImportJob", "imports", "Blocked" ] ], job_rows
  end

  test "operator opens finished jobs and sees completed jobs with no actions left to take" do
    get "/job_harbor/jobs/status/finished"

    assert_select "h1", text: "Finished Jobs"
    assert_equal [ [ "ReportJob", "default", "Finished" ], [ "ReportJob", "default", "Finished" ] ], job_rows
    assert_select "tbody button", count: 0
  end

  test "operator filters All Jobs to one queue and sees only that queue's jobs" do
    get "/job_harbor/jobs", params: { queue_name: "critical" }

    assert_equal [ [ "FlakyPaymentJob", "critical", "Failed" ], [ "ReportJob", "critical", "In Progress" ] ], job_rows.sort
  end

  test "operator filters All Jobs to one job class and sees only that class" do
    get "/job_harbor/jobs", params: { class_name: "ThrottledImportJob" }

    assert_equal [ [ "ThrottledImportJob", "imports", "Blocked" ], [ "ThrottledImportJob", "imports", "Pending" ] ], job_rows.sort
  end

  test "operator opens a failed job and sees the exception class, message, and backtrace" do
    get "/job_harbor/jobs/#{@failed.id}"

    assert_response :success
    assert_select "h1", text: "Job ##{@failed.id}"
    assert_info_line "Status", "Failed"
    assert_info_line "Job Class", "FlakyPaymentJob"
    assert_select ".info-line a[href=?]", "/job_harbor/queues/critical", text: "critical"
    assert_select ".card-title", text: "Error Details"
    assert_info_line "Exception Class", "JobFailure"
    assert_select ".card", text: /Error Message\s*Card declined for order 42/
    assert_select "pre.code-block", text: /flaky_payment_job\.rb:\d+.*perform/
    assert_select "button", text: "Retry Job"
    assert_select "button", text: "Discard Job"
  end

  test "operator opens a job and sees its real arguments first, with the full payload tucked in a details block" do
    get "/job_harbor/jobs/#{@failed.id}"

    assert_select ".card-title", text: "Arguments"
    shown_arguments = css_select("pre.code-block").first.text
    assert_equal [ 42 ], JSON.parse(shown_arguments), "The Arguments card should show the order id the job was enqueued with"
    assert_not_includes shown_arguments, "job_class"
    assert_select "details > summary", text: "Full payload"
    assert_select "details pre.code-block", text: /"job_class": "FlakyPaymentJob"/
  end

  test "operator opens a job with no arguments and the page says so instead of showing an empty list" do
    job = enqueue_job(NewsletterJob)

    get "/job_harbor/jobs/#{job.id}"

    assert_select ".card", text: /Arguments\s*No arguments/
    assert_select "details pre.code-block", text: /"job_class": "NewsletterJob"/
  end

  test "operator opens a running job and sees which worker claimed it" do
    get "/job_harbor/jobs/#{@running.id}"

    assert_response :success
    assert_info_line "Status", "In Progress"
    assert_info_line "Worker", "worker-1"
    assert_select ".card-title", text: "Error Details", count: 0
    assert_select "button", text: "Retry Job", count: 0
    assert_select "button", text: "Discard Job", count: 0
  end

  test "operator follows a link to a job that no longer exists and lands on All Jobs with a notice" do
    get "/job_harbor/jobs/#{SolidQueue::Job.maximum(:id) + 1}"

    assert_redirected_to "/job_harbor/jobs"
    follow_redirect!
    assert_select ".alert-error", text: "Job not found."
  end

  test "operator searches by job class name and sees the matching job" do
    get "/job_harbor/search", params: { q: "FlakyPayment" }

    assert_response :success
    assert_select "h1", text: "Search Results"
    assert_select "p", text: /Found 1 result for "FlakyPayment"/
    assert_equal [ [ "FlakyPaymentJob", "critical", "Failed" ] ], job_rows
  end

  test "operator searches in lowercase and still finds the job class" do
    get "/job_harbor/search", params: { q: "flakypayment" }

    assert_equal [ [ "FlakyPaymentJob", "critical", "Failed" ] ], job_rows
  end

  test "with filtering off, operator searches by a job argument and sees every job enqueued with it" do
    JobHarbor.configuration.filter_parameters = false

    get "/job_harbor/search", params: { q: "acme" }

    assert_select "p", text: /Found 2 results for "acme"/
    assert_equal [ [ "ThrottledImportJob", "imports", "Blocked" ], [ "ThrottledImportJob", "imports", "Pending" ] ], job_rows.sort
  end

  test "with filtering on, searching for argument text finds nothing" do
    get "/job_harbor/search", params: { q: "acme" }

    assert_select "p", text: /Found 0 results for "acme"/
  end

  test "operator searches for a percent sign and no job matches it as a wildcard" do
    get "/job_harbor/search", params: { q: "%" }

    assert_select "p", text: /Found 0 results for "%"/
    assert_empty job_rows
  end

  test "operator searches with an underscore and it matches that character, not any character" do
    get "/job_harbor/search", params: { q: "Flaky_Payment" }
    assert_select "p", text: /Found 0 results/

    get "/job_harbor/search", params: { q: "Flak_Payment" }
    assert_select "p", text: /Found 0 results/

    JobHarbor.configuration.filter_parameters = false
    enqueue_job(ReportJob, "a_b")
    enqueue_job(ReportJob, "axb")
    get "/job_harbor/search", params: { q: "a_b" }
    assert_select "p", text: /Found 1 result\b/
  end

  test "operator searches by job id and sees that job" do
    get "/job_harbor/search", params: { q: @failed.id.to_s }

    assert_includes job_rows, [ "FlakyPaymentJob", "critical", "Failed" ]
  end

  test "operator searches by an Active Job ID and sees exactly that job" do
    get "/job_harbor/search", params: { q: @failed.active_job_id }

    assert_select "p", text: /Found 1 result for/
    assert_equal [ [ "FlakyPaymentJob", "critical", "Failed" ] ], job_rows
  end

  test "operator searches for something no job matches and sees a no-results message" do
    get "/job_harbor/search", params: { q: "NoSuchThing" }

    assert_select "p", text: /Found 0 results for "NoSuchThing"/
    assert_select "h3", text: "No results found"
  end

  test "operator submits an empty search and is sent back to All Jobs" do
    get "/job_harbor/search", params: { q: "  " }

    assert_redirected_to "/job_harbor/jobs"
  end

  private
    def job_rows
      css_select("table.sqd-table tbody tr").map do |row|
        cells = row.css("td")
        [ cells[1].at_css("code").text.strip, cells[2].at_css("a").text.strip, cells[3].at_css(".badge").text.strip ]
      end
    end
end
