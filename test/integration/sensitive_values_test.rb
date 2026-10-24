require "test_helper"

class SensitiveValuesTest < ActionDispatch::IntegrationTest
  SCRUBBER = ->(_key, value) { value.gsub!(/tok_live_\w+/, "[SCRUBBED]") if value.is_a?(String) }

  setup do
    @worker = register_worker(name: "worker-1")
    @job = enqueue_job(ReportJob, { password: "hunter2", email: "a@b.c", plan: "pro" })
  end

  teardown { JobHarbor.configuration.filter_parameters = nil }

  test "operator opens a job and sees secrets masked in Arguments and Full payload but other values intact" do
    get "/job_harbor/jobs/#{@job.id}"

    assert_response :success
    assert_not_includes response.body, "hunter2", "The job page leaked a password"
    assert_not_includes response.body, "a@b.c", "The job page leaked an email"
    shown_arguments = JSON.parse(css_select("pre.code-block").first.text)
    assert_equal({ "password" => "[FILTERED]", "email" => "[FILTERED]", "plan" => "pro", "_aj_symbol_keys" => %w[password email plan] },
      shown_arguments.first)
    assert_select "details pre.code-block", text: /"password": "\[FILTERED\]"/
    assert_select "details pre.code-block", text: /"_aj_symbol_keys"/
  end

  test "with filter_parameters set to false the operator sees the raw values" do
    JobHarbor.configuration.filter_parameters = false

    get "/job_harbor/jobs/#{@job.id}"

    assert_includes response.body, "hunter2"
  end

  test "a filter key the host app adds after boot masks the value on the next page view" do
    Rails.application.config.filter_parameters << :plan

    get "/job_harbor/jobs/#{@job.id}"

    assert_select "pre.code-block", text: /"plan": "\[FILTERED\]"/
  ensure
    Rails.application.config.filter_parameters.delete(:plan)
  end

  test "searching for a hidden value finds nothing, and finds the job only when filtering is off" do
    get "/job_harbor/search", params: { q: "hunter2" }
    assert_select "p", text: /Found 0 results/

    JobHarbor.configuration.filter_parameters = false
    get "/job_harbor/search", params: { q: "hunter2" }
    assert_select "p", text: /Found 1 result for/
  end

  test "with an empty filter list nothing is masked, so argument search is back" do
    JobHarbor.configuration.filter_parameters = []

    get "/job_harbor/search", params: { q: "hunter2" }

    assert_select "p", text: /Found 1 result for/
  end

  test "searching still finds a job by class, job ID and Active Job ID while filtering" do
    get "/job_harbor/search", params: { q: "ReportJob" }
    assert_select "p", text: /Found 1 result/

    get "/job_harbor/search", params: { q: @job.id.to_s }
    assert_select "p", text: /Found 1 result/

    get "/job_harbor/search", params: { q: @job.active_job_id }
    assert_select "p", text: /Found 1 result/
  end

  test "a host Proc filter scrubs the error message on the job page" do
    failed = fail_job(enqueue_job(FlakyPaymentJob, "tok_live_abc123"), worker: @worker)
    Rails.application.config.filter_parameters << SCRUBBER

    get "/job_harbor/jobs/#{failed.id}"

    assert_not_includes response.body, "tok_live_abc123", "The job page leaked a token that the host filter scrubs"
    assert_select ".card", text: /Error Message\s*Card declined for order \[SCRUBBED\]/
  ensure
    Rails.application.config.filter_parameters.delete(SCRUBBER)
  end

  test "a host Proc filter scrubs the error message in the dashboard's recent failures" do
    fail_job(enqueue_job(FlakyPaymentJob, "tok_live_abc123"), worker: @worker)
    Rails.application.config.filter_parameters << SCRUBBER

    get "/job_harbor"

    assert_not_includes response.body, "tok_live_abc123", "The dashboard's recent failures leaked a token"
    assert_select "td", text: /Card declined for order \[SCRUBBED\]/
  ensure
    Rails.application.config.filter_parameters.delete(SCRUBBER)
  end

  test "a host Proc filter scrubs the backtrace on the job page" do
    failed = fail_job(enqueue_job(FlakyPaymentJob, 42), worker: @worker)
    scrubber = ->(_key, value) { value.gsub!("test_helper", "[SCRUBBED]") if value.is_a?(String) }
    Rails.application.config.filter_parameters << scrubber

    get "/job_harbor/jobs/#{failed.id}"

    assert_select "pre.code-block", text: /\[SCRUBBED\]\.rb/
    assert_not_includes css_select("pre.code-block").map(&:text).join, "test_helper"
  ensure
    Rails.application.config.filter_parameters.delete(scrubber)
  end

  test "operator opens a recurring task and sees its secret arguments masked" do
    task = SolidQueue::RecurringTask.create!(key: "sync", schedule: "every hour", class_name: "ReportJob",
      arguments: [ { "api_token" => "x-secret-value", "region" => "eu" } ])

    get "/job_harbor/recurring_tasks/#{task.id}"

    assert_response :success
    assert_not_includes response.body, "x-secret-value"
    assert_select "pre.code-block", text: /"api_token": "\[FILTERED\]"/
    assert_select "pre.code-block", text: /"region": "eu"/
  end

  test "a recurring task whose argument points at a deleted record still opens" do
    task = SolidQueue::RecurringTask.create!(key: "gid", schedule: "every hour", class_name: "ReportJob", arguments: [ "x" ])
    SolidQueue::RecurringTask.where(id: task.id).update_all(arguments: [ { "_aj_globalid" => "gid://dummy/Ghost/1" } ].to_json)

    get "/job_harbor/recurring_tasks/#{task.id}"

    assert_response :success
    assert_select "pre.code-block", text: /gid:\/\/dummy\/Ghost\/1/
  end
end
