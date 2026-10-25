require "test_helper"

class RecurringTaskActionsTest < ActionDispatch::IntegrationTest
  setup do
    @nightly = SolidQueue::RecurringTask.create!(key: "nightly_report", schedule: "every day at 3am",
      class_name: "ReportJob", arguments: [ "nightly" ], queue_name: "reports")
  end

  test "operator clicks Run Now on Recurring Tasks and the task's job is enqueued and recorded as an execution" do
    freeze_time
    get "/job_harbor/recurring_tasks"
    assert_select "form[action=?] button", "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now", text: "Run Now"

    assert_difference -> { SolidQueue::Job.where(class_name: "ReportJob", queue_name: "reports").count } => 1,
      -> { SolidQueue::RecurringExecution.where(task_key: "nightly_report", run_at: Time.current.change(usec: 0)).count } => 1 do
      post "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now"
    end

    job = SolidQueue::RecurringExecution.find_by!(task_key: "nightly_report").job
    assert_equal [ "nightly" ], job.arguments["arguments"], "Run Now should enqueue the task with its configured arguments"
    assert SolidQueue::ReadyExecution.exists?(job_id: job.id), "Run Now should make the job ready to run immediately"

    assert_redirected_to "/job_harbor/recurring_tasks/#{@nightly.id}"
    follow_redirect!
    assert_select ".alert-success", text: "Task 'nightly_report' has been enqueued."
    assert_select ".info-line", text: /Total Executions\s*1\b/
    assert_select "tbody a[href=?]", "/job_harbor/jobs/#{job.id}", text: job.id.to_s
  end

  test "operator clicks Run Now on a task's page and lands back on it with the new execution listed" do
    get "/job_harbor/recurring_tasks/#{@nightly.id}"
    assert_select "form[action=?] button", "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now", text: "Run Now"

    assert_difference -> { SolidQueue::RecurringExecution.where(task_key: "nightly_report").count } => 1 do
      post "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now"
    end

    job = SolidQueue::RecurringExecution.find_by!(task_key: "nightly_report").job
    assert_redirected_to "/job_harbor/recurring_tasks/#{@nightly.id}"
    follow_redirect!
    assert_select ".alert-success", text: "Task 'nightly_report' has been enqueued."
    assert_select ".card-title", text: "Recent Executions"
    assert_select "tbody a[href=?]", "/job_harbor/jobs/#{job.id}", text: job.id.to_s
  end

  test "operator double-clicks Run Now within one second, is told the second click enqueued nothing, and only one job exists" do
    # Same wall-clock second, different microseconds: the clock must not be frozen to one instant.
    second = Time.current.change(usec: 0)
    travel_to second + 0.2.seconds, with_usec: true
    post "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now"
    assert_redirected_to "/job_harbor/recurring_tasks/#{@nightly.id}"
    follow_redirect!
    assert_select ".alert-success", text: "Task 'nightly_report' has been enqueued."

    travel_to second + 0.5.seconds, with_usec: true
    assert_no_difference [ -> { SolidQueue::Job.count }, -> { SolidQueue::RecurringExecution.count } ] do
      post "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now"
    end

    assert_redirected_to "/job_harbor/recurring_tasks/#{@nightly.id}"
    follow_redirect!
    assert_select ".alert-success", count: 0
    assert_select ".alert-error", text: "Task 'nightly_report' was not enqueued. It may have just run, or the job refused to enqueue; check the logs."
    assert_select ".info-line", text: /Total Executions\s*1\b/
  end

  test "operator clicks Run Now in two different seconds and two jobs are enqueued" do
    second = Time.current.change(usec: 0)
    travel_to second + 0.2.seconds, with_usec: true
    post "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now"

    travel_to second + 1.2.seconds, with_usec: true
    assert_difference [ -> { SolidQueue::Job.count }, -> { SolidQueue::RecurringExecution.count } ], 1 do
      post "/job_harbor/recurring_tasks/#{@nightly.id}/enqueue_now"
    end

    follow_redirect!
    assert_select ".alert-success", text: "Task 'nightly_report' has been enqueued."
    assert_select ".info-line", text: /Total Executions\s*2\b/
  end

  test "operator clicks Run Now on a task whose job class is not defined and is told why, with nothing enqueued" do
    task = missing_class_task("missing_job_task", "MissingJob")

    get "/job_harbor/recurring_tasks/#{task.id}"
    assert_response :success
    assert_select "code", text: "MissingJob"

    assert_no_difference [ -> { SolidQueue::Job.count }, -> { SolidQueue::RecurringExecution.count } ] do
      post "/job_harbor/recurring_tasks/#{task.id}/enqueue_now"
    end

    assert_redirected_to "/job_harbor/recurring_tasks/#{task.id}"
    follow_redirect!
    assert_select ".alert-success", count: 0
    assert_select ".alert-error", text: "Task 'missing_job_task' can't run: MissingJob isn't a job class defined in this app."
  end

  test "operator clicks Run Now on a task whose class is not a job and is told why, with nothing enqueued" do
    task = missing_class_task("string_task", "String")

    assert_no_difference [ -> { SolidQueue::Job.count }, -> { SolidQueue::RecurringExecution.count } ] do
      post "/job_harbor/recurring_tasks/#{task.id}/enqueue_now"
    end

    assert_redirected_to "/job_harbor/recurring_tasks/#{task.id}"
    follow_redirect!
    assert_select ".alert-error", text: "Task 'string_task' can't run: String isn't a job class defined in this app."
  end

  test "operator clicks Run Now on a command task and is told it was enqueued" do
    task = SolidQueue::RecurringTask.create!(key: "cleanup_command", schedule: "every day at 3am", command: "1 + 1")

    assert_enqueued_jobs 1 do
      post "/job_harbor/recurring_tasks/#{task.id}/enqueue_now"
    end

    follow_redirect!
    assert_select ".alert-success", text: "Task 'cleanup_command' has been enqueued."
  end

  test "operator clicks Run Now on a task whose job refuses to enqueue and is told nothing was enqueued" do
    task = SolidQueue::RecurringTask.create!(key: "refused_report", schedule: "every day at 3am", class_name: "RefusedReportJob")

    post_refused = -> do
      assert_no_difference [ -> { SolidQueue::Job.count }, -> { SolidQueue::RecurringExecution.count } ] do
        post "/job_harbor/recurring_tasks/#{task.id}/enqueue_now"
      end
    end
    # Solid Queue 1.0.x raises on a halted job and the dashboard reports it; 1.7 returns the job unraised.
    if Gem::Version.new(SolidQueue::VERSION) < Gem::Version.new("1.1")
      assert_error_reported(ActiveRecord::NotNullViolation, &post_refused)
    else
      post_refused.call
    end

    assert_redirected_to "/job_harbor/recurring_tasks/#{task.id}"
    follow_redirect!
    assert_select ".alert-success", count: 0
    assert_select ".alert-error", text: "Task 'refused_report' was not enqueued. It may have just run, or the job refused to enqueue; check the logs."
  end

  test "operator clicks Run Now on a task whose job is not on Solid Queue and refuses to enqueue and is told nothing was enqueued" do
    task = SolidQueue::RecurringTask.create!(key: "refused_newsletter", schedule: "every day at 3am", class_name: "RefusedNewsletterJob")

    post "/job_harbor/recurring_tasks/#{task.id}/enqueue_now"

    assert_redirected_to "/job_harbor/recurring_tasks/#{task.id}"
    follow_redirect!
    assert_select ".alert-success", count: 0
    assert_select ".alert-error", text: /was not enqueued/
  end

  test "operator clicks Run Now for a task that was removed and lands on Recurring Tasks with a notice" do
    missing_id = @nightly.id
    @nightly.destroy!

    assert_no_difference -> { SolidQueue::Job.count } do
      post "/job_harbor/recurring_tasks/#{missing_id}/enqueue_now"
    end

    assert_redirected_to "/job_harbor/recurring_tasks"
    follow_redirect!
    assert_select ".alert-error", text: "Recurring task not found."
  end

  private

  # Solid Queue validates that the class exists, so a task for a removed job can only come from old data.
  def missing_class_task(key, class_name)
    SolidQueue::RecurringTask.new(key: key, schedule: "every day at 3am", class_name: class_name).tap do |task|
      task.save!(validate: false)
    end
  end
end
