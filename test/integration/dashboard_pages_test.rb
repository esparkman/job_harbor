require "test_helper"

class DashboardPagesTest < ActionDispatch::IntegrationTest
  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")
    register_worker(name: "worker-old", heartbeat_at: 10.minutes.ago)

    enqueue_job(ReportJob, "weekly")
    enqueue_job(ReportJob, "monthly")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    claim_job(enqueue_job(ReportJob, "quarterly", queue: "critical"), worker: @worker)
    @failed = fail_job(enqueue_job(FlakyPaymentJob, 42, queue: "critical"), worker: @worker)
    2.times { |i| finish_job(enqueue_job(ReportJob, "daily-#{i}"), worker: @worker) }
  end

  test "operator opens the dashboard and sees a stat card for every job state, counted from the queue" do
    get "/job_harbor"

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_stat_card "Pending", 3
    assert_stat_card "Scheduled", 1
    assert_stat_card "In Progress", 1
    assert_stat_card "Failed", 1
    assert_stat_card "Blocked", 1
    assert_stat_card "Finished (24h)", 2
    assert_stat_card "Active Workers", 1
    assert_stat_card "Queues", 4
    assert_stat_card "Throughput", "2/hr"
  end

  test "operator clicks each dashboard stat card and lands on the page for that state" do
    destinations = {
      "Pending" => "Pending Jobs",
      "Scheduled" => "Scheduled Jobs",
      "In Progress" => "In Progress Jobs",
      "Failed" => "Failed Jobs",
      "Blocked" => "Blocked Jobs",
      "Finished (24h)" => "Finished Jobs",
      "Active Workers" => "Workers",
      "Queues" => "Queues"
    }

    get "/job_harbor"
    links = css_select("a.stat-card").to_h { |a| [ a.at_css(".stat-card-label").text.strip, a["href"] ] }
    assert_equal destinations.keys.sort, links.keys.sort, "Every countable stat card should be a link"

    destinations.each do |label, heading|
      get links[label]
      assert_response :success
      assert_select "h1", { text: heading }, "Clicking '#{label}' should open #{heading}"
    end
  end

  test "operator sees the failing job class and its error message under Recent Failures" do
    get "/job_harbor"

    assert_select ".card-title", text: "Recent Failures"
    assert_select "table.sqd-table tbody tr", text: /FlakyPaymentJob/ do
      assert_select "a[href=?]", "/job_harbor/jobs/#{@failed.id}", text: @failed.id.to_s
      assert_select "td", text: "Card declined for order 42"
      assert_select "form[action=?] button", "/job_harbor/jobs/#{@failed.id}/retry", text: "Retry"
    end
    assert_select "a[href=?]", "/job_harbor/jobs/status/failed", text: /View All Failed Jobs/
  end

  test "operator sees the failure rate per job class, with the failing class ranked first" do
    get "/job_harbor"

    rows = css_select(".sqd-failure-rates tbody tr").map { |tr| tr.css("td").map { |td| td.text.strip } }
    assert_equal [ "FlakyPaymentJob", "1", "1", "100.0%" ], rows.first, "Failing job class should lead the failure-rate table"
    assert_includes rows, [ "ReportJob", "5", "0", "0.0%" ]
    assert_includes rows, [ "ThrottledImportJob", "2", "0", "0.0%" ]
    assert_includes rows, [ "NewsletterJob", "1", "0", "0.0%" ]
  end

  test "operator sees the live worker count beside Workers in the navbar" do
    get "/job_harbor"

    assert_select "a[href=?] .sqd-nav-badge", "/job_harbor/workers", text: "1"
  end
end
