require "test_helper"

class DashboardPerformanceTest < ActionDispatch::IntegrationTest
  QUERY_BUDGET = 30

  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")
  end

  test "operator loads the dashboard on the default range and it stays within the query budget" do
    seed_jobs(40)
    queries = count_queries { get "/job_harbor" }

    assert_response :success
    assert_operator queries.size, :<, QUERY_BUDGET, "Dashboard ran #{queries.size} queries:\n#{queries.join("\n")}"
  end

  test "operator loads the dashboard on the 7 day range and it stays within the query budget" do
    seed_jobs(40)
    queries = count_queries { get "/job_harbor", params: { chart_range: "7d" } }

    assert_response :success
    assert_operator queries.size, :<, QUERY_BUDGET, "7d dashboard ran #{queries.size} queries:\n#{queries.join("\n")}"
  end

  test "the dashboard runs the same queries for 5 jobs as for 45 on every range" do
    %w[24h 7d].each do |range|
      SolidQueue::Job.destroy_all
      seed_failures
      small = count_queries { get "/job_harbor", params: { chart_range: range } }

      seed_jobs(40)
      large = count_queries { get "/job_harbor", params: { chart_range: range } }

      assert_equal small.size, large.size, "#{range} dashboard should not query per job, got:\n#{large.join("\n")}"
    end
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

  # Failures of two classes, so recent failures and failure rates have rows to render.
  def seed_failures
    enqueue_job(ReportJob, "pending")
    2.times { |i| fail_job(enqueue_job(FlakyPaymentJob, i, queue: "critical"), worker: @worker) }
    fail_job(enqueue_job(OtherFlakyJob, 1, queue: "mailers"), worker: @worker)
    finish_job(enqueue_job(ReportJob, "done"), worker: @worker)
  end

  def seed_jobs(count)
    seed_failures if SolidQueue::Job.none?
    (count / 4).times { |i| enqueue_job(ReportJob, "pending-#{i}") }
    (count / 8).times { |i| enqueue_job(NewsletterJob, "later-#{i}", queue: "mailers", at: 2.hours.from_now) }
    (count / 8).times { |i| claim_job(enqueue_job(ReportJob, "claimed-#{i}", queue: "imports"), worker: @worker) }
    (count / 8).times { |i| fail_job(enqueue_job(i.even? ? FlakyPaymentJob : OtherFlakyJob, i, queue: "critical"), worker: @worker) }
    (count / 4).times { |i| finish_job(enqueue_job(ReportJob, "done-#{i}"), worker: @worker) }
    2.times { enqueue_job(ThrottledImportJob, "acme", queue: "imports") }
  end

  def chart_series
    JSON.parse(css_select(".sqd-chart").first["data-chart-data"])
  end
end
