require "test_helper"

class RecurringTasksPagesTest < ActionDispatch::IntegrationTest
  setup do
    @nightly = SolidQueue::RecurringTask.create!(key: "nightly_report", schedule: "every day at 3am",
      class_name: "ReportJob", arguments: [ "nightly" ], queue_name: "reports")
    @cleanup = SolidQueue::RecurringTask.create!(key: "cleanup_sessions", schedule: "every hour", command: "Session.sweep")
  end

  test "operator opens Recurring Tasks and sees every task's class, schedule, and queue" do
    get "/job_harbor/recurring_tasks"

    assert_response :success
    assert_select "h1", text: "Recurring Tasks"
    rows = css_select("table.sqd-table tbody tr").map { |tr| tr.css("td")[0..3].map { |td| td.text.strip } }
    assert_equal [ [ "cleanup_sessions", "", "every hour", "default" ], [ "nightly_report", "ReportJob", "every day at 3am", "reports" ] ], rows
    assert_select "a[href=?]", "/job_harbor/recurring_tasks/#{@nightly.id}", text: "nightly_report"
    assert_select "form[action=?] button", "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now", text: "Run Now"
    assert_select "a[href=?] .sqd-nav-badge", "/job_harbor/recurring_tasks", text: "2"
  end

  test "operator opens a recurring task and sees its details and the jobs it has enqueued" do
    @nightly.enqueue(at: 2.days.ago)
    @nightly.enqueue(at: 1.day.ago)
    job_ids = SolidQueue::RecurringExecution.where(task_key: "nightly_report").pluck(:job_id)
    assert_equal 2, job_ids.size, "Both enqueues should be recorded as executions"

    get "/job_harbor/recurring_tasks/#{@nightly.id}"

    assert_response :success
    assert_select "h1", text: "Task: nightly_report"
    assert_select ".info-line", text: /Job Class\s*ReportJob/
    assert_select ".info-line", text: /Schedule\s*every day at 3am/
    assert_select ".info-line", text: /Queue\s*reports/
    assert_select "pre.code-block", text: /"nightly"/
    assert_select ".info-line", text: /Total Executions\s*2\b/
    assert_select ".info-line", text: /Last Run/
    job_ids.each do |id|
      assert_select "tbody a[href=?]", "/job_harbor/jobs/#{id}", text: id.to_s
    end
  end

  test "operator opens a task with 25 executions, sees the total of 25, and the list shows the 20 most recent" do
    25.times { |i| @nightly.enqueue(at: Time.utc(2026, 1, 1) + i.days) }

    get "/job_harbor/recurring_tasks/#{@nightly.id}"

    assert_select ".info-line", text: /Total Executions\s*25\b/
    assert_select "tbody tr", count: 20
    assert_select "tbody td", text: "2026-01-25 00:00:00"
    assert_select "tbody td", text: "2026-01-06 00:00:00"
    assert_select "tbody td", text: "2026-01-05 00:00:00", count: 0
  end

  test "operator opens a task and sees when each run was scheduled for, not when the record was written" do
    travel_to Time.utc(2026, 3, 10, 12, 0, 0) do
      @nightly.enqueue(at: Time.utc(2026, 3, 1, 3, 0, 0))
      @nightly.enqueue(at: Time.utc(2026, 3, 5, 3, 0, 0))
    end

    travel_to Time.utc(2026, 3, 20, 12, 0, 0) do
      get "/job_harbor/recurring_tasks/#{@nightly.id}"
    end

    assert_select ".info-line", text: /Last Run\s*2026-03-05 03:00:00 UTC/
    assert_select "tbody td", text: "2026-03-05 03:00:00"
    assert_select "tbody td", text: "2026-03-01 03:00:00"
    assert_select "tbody td", text: /2026-03-10/, count: 0
  end

  test "operator opens a recurring task that has never run and sees zero executions" do
    get "/job_harbor/recurring_tasks/#{@cleanup.id}"

    assert_response :success
    assert_select ".info-line", text: /Total Executions\s*0\b/
    assert_select ".card-title", text: "Recent Executions", count: 0
  end

  test "operator opens a recurring task that was removed and lands on Recurring Tasks with a notice" do
    get "/job_harbor/recurring_tasks/#{SolidQueue::RecurringTask.maximum(:id) + 1}"

    assert_redirected_to "/job_harbor/recurring_tasks"
    follow_redirect!
    assert_select ".alert-error", text: "Recurring task not found."
  end
end
