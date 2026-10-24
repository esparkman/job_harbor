require "test_helper"

class DashboardPerformanceTest < ActionDispatch::IntegrationTest
  QUERY_BUDGET = 30

  setup do
    freeze_time
    worker = register_worker(name: "worker-1")

    20.times { |i| enqueue_job(ReportJob, "pending-#{i}") }
    5.times { |i| enqueue_job(NewsletterJob, "later-#{i}", queue: "mailers", at: 2.hours.from_now) }
    2.times { enqueue_job(ThrottledImportJob, "acme", queue: "imports") }
    5.times { |i| claim_job(enqueue_job(ReportJob, "claimed-#{i}", queue: "critical"), worker: worker) }
    8.times { |i| fail_job(enqueue_job(FlakyPaymentJob, i, queue: "critical"), worker: worker) }
    10.times { |i| finish_job(enqueue_job(ReportJob, "done-#{i}"), worker: worker) }
  end

  test "operator loads the dashboard on the default range and it stays within the query budget" do
    queries = count_queries { get "/job_harbor" }

    assert_response :success
    assert_operator queries.size, :<, QUERY_BUDGET, "Dashboard ran #{queries.size} queries:\n#{queries.join("\n")}"
  end

  test "operator loads the dashboard on the 7 day range and it stays within the query budget" do
    queries = count_queries { get "/job_harbor", params: { chart_range: "7d" } }

    assert_response :success
    assert_operator queries.size, :<, QUERY_BUDGET, "7d dashboard ran #{queries.size} queries:\n#{queries.join("\n")}"
  end

  test "operator picks the 7 day range and the chart shows 7 days with that button highlighted" do
    get "/job_harbor", params: { chart_range: "7d" }

    assert_select ".sqd-chart-ranges a.btn-default", text: "7 days"
    assert_equal 28, chart_series["labels"].size
  end

  test "operator opens a dashboard link with a bogus chart range and sees the default range highlighted to match the data" do
    get "/job_harbor", params: { chart_range: "bogus" }

    assert_response :success
    assert_select ".sqd-chart-ranges a.btn-default", count: 1
    assert_select ".sqd-chart-ranges a.btn-default", text: "24 hours"
    assert_equal 24, chart_series["labels"].size
  end

  test "operator with a configured default range sees it highlighted when the URL names no valid range" do
    configuration = JobHarbor.configuration
    original = configuration.default_chart_range
    configuration.default_chart_range = "1h"

    get "/job_harbor", params: { chart_range: "nope" }

    assert_select ".sqd-chart-ranges a.btn-default", text: "1 hour"
    assert_equal 12, chart_series["labels"].size
  ensure
    configuration.default_chart_range = original
  end

  private

  def chart_series
    JSON.parse(css_select(".sqd-chart").first["data-chart-data"])
  end
end
