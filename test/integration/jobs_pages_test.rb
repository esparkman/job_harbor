require "test_helper"

class JobsPagesTest < ActionDispatch::IntegrationTest
  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")

    enqueue_job(ReportJob, "weekly")
    enqueue_job(ReportJob, "monthly")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    @running = enqueue_job(ReportJob, "quarterly", queue: "critical")
    claim_job(@running, worker: @worker)
    @failed = fail_job(enqueue_job(FlakyPaymentJob, 42, queue: "critical"), worker: @worker)
    2.times { |i| finish_job(enqueue_job(ReportJob, "daily-#{i}"), worker: @worker) }
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
    assert_select "button", text: "Retry All Failed"
    assert_select "button", text: "Discard All Failed"
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
    assert_info_line "Exception Class", "PaymentGatewayError"
    assert_select ".card", text: /Error Message\s*Card declined for order 42/
    assert_select "pre.code-block", text: /test_helper\.rb:\d+.*perform/
    assert_select "pre.code-block", text: /job_class.*FlakyPaymentJob/
    assert_select "button", text: "Retry Job"
    assert_select "button", text: "Discard Job"
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
    assert_select "p", text: /Found 1 results for "FlakyPayment"/
    assert_equal [ [ "FlakyPaymentJob", "critical", "Failed" ] ], job_rows
  end

  test "operator searches by a job argument and sees every job enqueued with it" do
    get "/job_harbor/search", params: { q: "acme" }

    assert_select "p", text: /Found 2 results for "acme"/
    assert_equal [ [ "ThrottledImportJob", "imports", "Blocked" ], [ "ThrottledImportJob", "imports", "Pending" ] ], job_rows.sort
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

    def assert_status_tab_count(status, count)
      label = status.humanize.titleize
      assert_select "a.badge[href=?]", "/job_harbor/jobs/status/#{status}", { text: /\A#{label}\s+#{count}\z/ },
        "#{label} tab should show #{count}"
    end

    def assert_info_line(label, value)
      line = css_select(".info-line").find { |l| l.at_css(".info-line-label").text.strip == label }
      assert line, "Operator expected a '#{label}' line on the job page"
      assert_equal value, line.at_css(".info-line-value").text.strip, "'#{label}' line shows the wrong value"
    end
end

class EmptyJobsPagesTest < ActionDispatch::IntegrationTest
  test "operator opens blocked jobs when nothing is blocked and sees an empty state" do
    get "/job_harbor/jobs/status/blocked"

    assert_response :success
    assert_select "h3", text: "No jobs found"
    assert_select "p", text: "There are no blocked jobs."
  end
end
