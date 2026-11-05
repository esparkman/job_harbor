require "test_helper"

class ErrorGroupsTest < ActionDispatch::IntegrationTest
  GROUPS_PATH = "/job_harbor/jobs/status/failed/groups"

  setup do
    freeze_time
    register_worker(name: "worker-1")
  end

  teardown { JobHarbor.configuration.filter_parameters = nil }

  test "operator switches the Failed tab to Grouped and sees failures grouped by exception class, biggest first" do
    fail_with "Net::OpenTimeout", "execution expired", at: 3.hours.ago
    fail_with "Net::OpenTimeout", "execution expired", at: 2.hours.ago
    fail_with "Net::OpenTimeout", "execution expired after 30 seconds", at: 1.hour.ago
    fail_with "ActiveRecord::RecordNotFound", "Couldn't find User with 'id'=12345", at: 10.minutes.ago

    get "/job_harbor/jobs/status/failed"
    assert_select "a[href=?]", GROUPS_PATH, text: "Grouped"

    get GROUPS_PATH

    assert_response :success
    assert_equal [ "Net::OpenTimeout", "ActiveRecord::RecordNotFound" ], group_rows.map { |row| row[:exception] }
    timeout = group_rows.first
    assert_equal "3", timeout[:count]
    assert_equal 3.hours.ago.to_fs(:job_harbor_short), timeout[:first_seen]
    assert_equal 1.hour.ago.to_fs(:job_harbor_short), timeout[:last_seen]
    assert_equal "execution expired after 30 seconds", timeout[:message], "The sample should be the most recent failure's message"
    assert_equal "1", group_rows.second[:count]
  end

  test "operator sees groups with the same count ordered by most recent failure" do
    fail_with "Redis::ConnectionError", "refused", at: 2.hours.ago
    fail_with "Net::OpenTimeout", "expired", at: 5.minutes.ago

    get GROUPS_PATH

    assert_equal [ "Net::OpenTimeout", "Redis::ConnectionError" ], group_rows.map { |row| row[:exception] }
  end

  test "operator sees a failure with no exception class under Unknown error" do
    job = enqueue_job(ReportJob, "odd")
    SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
    SolidQueue::FailedExecution.create!(job: job, error: "worker crashed")

    get GROUPS_PATH

    assert_equal [ "Unknown error" ], group_rows.map { |row| row[:exception] }
  end

  test "operator sees a masked sample message when the host filters a value in it" do
    fail_with "Stripe::InvalidRequestError", "No such charge for tok_live_abc123"

    with_host_filter_parameters(->(_key, value) { value.gsub!(/tok_live_\w+/, "[SCRUBBED]") if value.is_a?(String) }) do
      get GROUPS_PATH

      assert_not_includes response.body, "tok_live_abc123", "The grouped view leaked a value the host filter scrubs"
      assert_equal "No such charge for [SCRUBBED]", group_rows.first[:message]
    end
  end

  test "operator filters the Grouped view to one queue and only that queue's failures are counted" do
    2.times { fail_with "Net::OpenTimeout", "expired", queue: "default" }
    fail_with "Net::OpenTimeout", "expired", queue: "mailers"

    get GROUPS_PATH, params: { queue_name: "mailers" }

    assert_equal [ [ "Net::OpenTimeout", "1" ] ], group_rows.map { |row| row.values_at(:exception, :count) }
  end

  test "operator clicks View on a group and sees only that group's failures in the filtered list" do
    fail_with "Net::OpenTimeout", "expired in mailers", queue: "mailers"
    fail_with "Net::OpenTimeout", "expired in default", queue: "default"
    fail_with "Redis::ConnectionError", "refused", queue: "mailers"

    get GROUPS_PATH, params: { queue_name: "mailers" }
    view_link = css_select("tbody tr").find { |tr| tr.text.include?("Net::OpenTimeout") }.at_css("a", text: "View")["href"]
    get view_link

    assert_response :success
    assert_select "table.sqd-table tbody tr", 1
    assert_select "table.sqd-table tbody tr td", text: "mailers"
    assert_select "button", text: "Retry 1 failed job"
    assert_select "span", text: /Only\s+Net::OpenTimeout\s+failures/
    assert_select "a[href=?]", "/job_harbor/jobs/status/failed?queue_name=mailers", text: "Show all"
  end

  test "operator retries one group after confirming and only that group's jobs leave the failed list" do
    timeouts = 3.times.map { fail_with "Net::OpenTimeout", "expired" }
    missing = fail_with "ActiveRecord::RecordNotFound", "gone"

    get GROUPS_PATH
    form = group_form("Net::OpenTimeout", "Retry all")
    assert_equal "Retry 3 failed jobs? Automatic retry counts are not reset.", form["data-confirm"]

    assert_difference -> { SolidQueue::FailedExecution.count } => -3 do
      post form["action"]
    end

    assert_redirected_to GROUPS_PATH
    follow_redirect!
    assert_select ".alert-success", text: "3 jobs queued for retry."
    assert_equal [ "ActiveRecord::RecordNotFound" ], group_rows.map { |row| row[:exception] }
    assert_equal 3, SolidQueue::ReadyExecution.where(job_id: timeouts.map(&:id)).count
    assert SolidQueue::FailedExecution.exists?(job_id: missing.id), "Retrying one group must leave the other group failed"
  end

  test "operator discards one group after confirming and the group disappears" do
    2.times { fail_with "Redis::ConnectionError", "refused" }
    fail_with "Net::OpenTimeout", "expired"

    get GROUPS_PATH
    form = group_form("Redis::ConnectionError", "Discard all")
    assert_equal "Discard 2 failed jobs? This cannot be undone.", form["data-confirm"]

    assert_difference -> { SolidQueue::Job.count } => -2 do
      delete form["action"]
    end

    follow_redirect!
    assert_select ".alert-success", text: "2 jobs discarded."
    assert_equal [ "Net::OpenTimeout" ], group_rows.map { |row| row[:exception] }
  end

  test "operator retries the Unknown error group and only those jobs are retried" do
    job = enqueue_job(ReportJob, "odd")
    SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
    SolidQueue::FailedExecution.create!(job: job, error: "worker crashed")
    other = fail_with "Net::OpenTimeout", "expired"

    get GROUPS_PATH
    post group_form("Unknown error", "Retry all")["action"]

    follow_redirect!
    assert_select ".alert-success", text: "1 job queued for retry."
    assert SolidQueue::FailedExecution.exists?(job_id: other.id)
  end

  test "a group action with a malformed filter is rejected and changes no jobs" do
    fail_with "Net::OpenTimeout", "expired"

    assert_no_difference -> { SolidQueue::FailedExecution.count } do
      post "/job_harbor/jobs/retry_all", params: { status: "failed", error_class: "Net::OpenTimeout", queue_name: { x: "1" } }
      assert_response :bad_request
      delete "/job_harbor/jobs/discard_all", params: { status: "failed", error_class: [ "Net::OpenTimeout" ] }
      assert_response :bad_request
    end
  end

  test "a group action with a blank exception filter is rejected instead of acting on every failed job" do
    2.times { fail_with "Net::OpenTimeout", "expired" }

    assert_no_difference -> { SolidQueue::FailedExecution.count }, "A blank error_class must not widen to every failed job" do
      delete "/job_harbor/jobs/discard_all", params: { status: "failed", error_class: "" }
      assert_response :bad_request
      post "/job_harbor/jobs/retry_all", params: { status: "failed", error_class: "  " }
      assert_response :bad_request
    end
  end

  test "operator filters the Grouped view to a queue with no failures and is told the filters hide them" do
    fail_with "Net::OpenTimeout", "expired", queue: "default"

    get GROUPS_PATH, params: { queue_name: "mailers" }

    assert_select "p", text: "No failed jobs match these filters."
  end

  test "operator opens the Grouped view with no failed jobs and sees the empty state" do
    get GROUPS_PATH

    assert_response :success
    assert_select "h3", text: "No jobs found"
    assert_select "table", 0
  end

  private
    def fail_with(exception_class, message, queue: "default", at: Time.current)
      job = enqueue_job(ReportJob, message, queue: queue)
      SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
      travel_to(at) { SolidQueue::FailedExecution.create!(job: job, error: { exception_class: exception_class, message: message, backtrace: [] }) }
      job
    end

    def group_rows
      css_select("table.sqd-error-groups tbody tr").map do |tr|
        cells = tr.css("td").map { |td| td.text.strip }
        { exception: cells[0], count: cells[1], first_seen: cells[2], last_seen: cells[3], message: cells[4] }
      end
    end

    def group_form(exception_class, button)
      row = css_select("table.sqd-error-groups tbody tr").find { |tr| tr.at_css("td").text.strip == exception_class }
      assert row, "Operator expected a '#{exception_class}' group"
      form = row.css("form").find { |f| f.at_css("button")&.text&.strip == button }
      assert form, "'#{exception_class}' group has no '#{button}' button"
      form
    end
end
