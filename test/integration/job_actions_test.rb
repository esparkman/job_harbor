require "test_helper"

class BrokenExportJob < ActiveJob::Base
  def perform(*)
    raise PaymentGatewayError, "Export crashed"
  end
end

class JobActionsTest < ActionDispatch::IntegrationTest
  RETRY_COUNTERS_NOTE = "Retry %s? Automatic retry counts are not reset."
  DISCARD_JOB_CONFIRM = "Are you sure you want to discard this job?"

  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")

    @pending = enqueue_job(ReportJob, "weekly")
    @scheduled = enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    @blocked = enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    @running = enqueue_job(ReportJob, "quarterly", queue: "critical")
    claim_job(@running, worker: @worker)
    @failed = fail_job(enqueue_job(FlakyPaymentJob, 42, queue: "critical"), worker: @worker)
  end

  test "operator retries a failed payment job and it goes back to the ready queue" do
    get "/job_harbor/jobs/#{@failed.id}"
    assert_select "form[action=?] button", "/job_harbor/jobs/#{@failed.id}/retry", text: "Retry Job"

    assert_difference -> { SolidQueue::FailedExecution.where(job_id: @failed.id).count } => -1,
      -> { SolidQueue::ReadyExecution.where(job_id: @failed.id, queue_name: "critical").count } => 1 do
      post "/job_harbor/jobs/#{@failed.id}/retry"
    end

    assert_redirected_to "/job_harbor/jobs/#{@failed.id}"
    follow_redirect!
    assert_select ".alert-success", text: "Job has been queued for retry."
    assert_info_line "Status", "Pending"
    assert_select ".card-title", text: "Error Details", count: 0
    assert_select "button", text: "Retry Job", count: 0
  end

  test "operator clicks Retry on a stale page after the job was already retried and is told it cannot be retried" do
    get "/job_harbor/jobs/#{@failed.id}"
    assert_select "form[action=?] button", "/job_harbor/jobs/#{@failed.id}/retry", text: "Retry Job"
    SolidQueue::FailedExecution.find_by!(job_id: @failed.id).retry

    assert_no_difference -> { SolidQueue::ReadyExecution.where(job_id: @failed.id).count } do
      post "/job_harbor/jobs/#{@failed.id}/retry"
    end

    assert_redirected_to "/job_harbor/jobs/#{@failed.id}"
    follow_redirect!
    assert_select ".alert-error", text: "This job cannot be retried."
  end

  test "operator discards a failed job from the Failed list and it moves to Finished" do
    get "/job_harbor/jobs/status/failed"
    assert_discard_form "/job_harbor/jobs/#{@failed.id}/discard", confirm: DISCARD_JOB_CONFIRM

    assert_discarded(SolidQueue::FailedExecution, @failed) { delete "/job_harbor/jobs/#{@failed.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "failed", 0
    assert_status_tab_count "finished", 1
  end

  test "operator discards a pending job from the Pending list and it will never run" do
    get "/job_harbor/jobs/status/pending"
    assert_discard_form "/job_harbor/jobs/#{@pending.id}/discard", confirm: DISCARD_JOB_CONFIRM

    assert_discarded(SolidQueue::ReadyExecution, @pending) { delete "/job_harbor/jobs/#{@pending.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "pending", 1
    assert_status_tab_count "finished", 1
  end

  test "operator discards a scheduled job from its page and it is taken off the schedule" do
    get "/job_harbor/jobs/#{@scheduled.id}"
    assert_discard_form "/job_harbor/jobs/#{@scheduled.id}/discard", text: "Discard Job", confirm: DISCARD_JOB_CONFIRM

    assert_discarded(SolidQueue::ScheduledExecution, @scheduled) { delete "/job_harbor/jobs/#{@scheduled.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "scheduled", 0
    assert_status_tab_count "finished", 1
  end

  # Concurrency slot is not released (backlog #18).
  test "operator discards a blocked job from the Blocked list and it leaves the Blocked list" do
    get "/job_harbor/jobs/status/blocked"
    assert_discard_form "/job_harbor/jobs/#{@blocked.id}/discard", confirm: DISCARD_JOB_CONFIRM

    assert_discarded(SolidQueue::BlockedExecution, @blocked) { delete "/job_harbor/jobs/#{@blocked.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "blocked", 0
    assert_status_tab_count "finished", 1
  end

  test "operator tries to discard a running job and is told it cannot be discarded" do
    assert_no_changes -> { @running.reload.finished_at } do
      delete "/job_harbor/jobs/#{@running.id}/discard"
    end

    assert_redirected_to "/job_harbor/jobs/#{@running.id}"
    follow_redirect!
    assert_select ".alert-error", text: "This job cannot be discarded."
    assert_info_line "Status", "In Progress"
  end

  test "operator retries all failed jobs and the Failed list empties" do
    second = fail_job(enqueue_job(FlakyPaymentJob, 43), worker: @worker)

    get "/job_harbor/jobs/status/failed"
    assert_bulk_form "/job_harbor/jobs/retry_all?status=failed", text: "Retry 2 failed jobs",
      confirm: RETRY_COUNTERS_NOTE % "2 failed jobs", method: "post"

    assert_difference -> { SolidQueue::FailedExecution.count } => -2,
      -> { SolidQueue::ReadyExecution.where(job_id: [ @failed.id, second.id ]).count } => 2 do
      post "/job_harbor/jobs/retry_all?status=failed"
    end

    assert_redirected_to "/job_harbor/jobs?status=failed"
    follow_redirect!
    assert_select ".alert-success", text: "2 jobs queued for retry."
    assert_select "p", text: "There are no failed jobs."
    assert_status_tab_count "pending", 4
  end

  test "operator retries the only failed job in bulk and the notice says 1 job" do
    post "/job_harbor/jobs/retry_all?status=failed"

    follow_redirect!
    assert_select ".alert-success", text: "1 job queued for retry."
  end

  test "operator discards all failed jobs and they move to Finished" do
    second = fail_job(enqueue_job(FlakyPaymentJob, 43), worker: @worker)

    get "/job_harbor/jobs/status/failed"
    assert_bulk_form "/job_harbor/jobs/discard_all?status=failed", text: "Discard 2 failed jobs",
      confirm: "Discard 2 failed jobs? This cannot be undone."

    assert_discarded(SolidQueue::FailedExecution, @failed, second) { delete "/job_harbor/jobs/discard_all?status=failed" }

    assert_redirected_to "/job_harbor/jobs?status=failed"
    follow_redirect!
    assert_select ".alert-success", text: "2 jobs discarded."
    assert_select "p", text: "There are no failed jobs."
    assert_status_tab_count "finished", 2
  end

  test "operator discards all blocked jobs from the Blocked tab and the Blocked list empties" do
    get "/job_harbor/jobs/status/blocked"
    assert_bulk_form "/job_harbor/jobs/discard_all?status=blocked", text: "Discard 1 blocked job",
      confirm: "Discard 1 blocked job? This cannot be undone."
    assert_select "form[action^=?]", "/job_harbor/jobs/retry_all", count: 0

    assert_discarded(SolidQueue::BlockedExecution, @blocked) { delete "/job_harbor/jobs/discard_all?status=blocked" }

    assert_redirected_to "/job_harbor/jobs?status=blocked"
    follow_redirect!
    assert_select ".alert-success", text: "1 job discarded."
    assert_select "p", text: "There are no blocked jobs."
  end

  test "operator filtered to one class discards all and the other class's failed jobs are untouched" do
    flaky_a = fail_job(enqueue_job(FlakyPaymentJob, 43), worker: @worker)
    flaky_b = fail_job(enqueue_job(FlakyPaymentJob, 44), worker: @worker)
    export = fail_job(enqueue_job(BrokenExportJob, 1), worker: @worker)

    get "/job_harbor/jobs/status/failed?class_name=FlakyPaymentJob&queue_name=default"
    assert_bulk_form "/job_harbor/jobs/discard_all?class_name=FlakyPaymentJob&queue_name=default&status=failed",
      text: "Discard 2 failed jobs", confirm: "Discard 2 failed jobs? This cannot be undone."

    assert_difference -> { SolidQueue::FailedExecution.where(job_id: [ flaky_a.id, flaky_b.id ]).count } => -2,
      -> { SolidQueue::FailedExecution.where(job_id: [ @failed.id, export.id ]).count } => 0,
      -> { SolidQueue::Job.where(id: [ @failed.id, export.id ]).where.not(finished_at: nil).count } => 0,
      -> { SolidQueue::Job.where(id: [ flaky_a.id, flaky_b.id ]).where.not(finished_at: nil).count } => 2 do
      delete "/job_harbor/jobs/discard_all?class_name=FlakyPaymentJob&queue_name=default&status=failed"
    end

    assert_redirected_to "/job_harbor/jobs?class_name=FlakyPaymentJob&queue_name=default&status=failed"
    follow_redirect!
    assert_select ".alert-success", text: "2 jobs discarded."
    assert_select "a.badge[href=?]", "/job_harbor/jobs/status/failed", text: /\AFailed\s+2\z/
  end

  test "operator filtered to one class retries all and the other class's failed jobs stay failed" do
    flaky_a = fail_job(enqueue_job(FlakyPaymentJob, 43), worker: @worker)
    flaky_b = fail_job(enqueue_job(FlakyPaymentJob, 44), worker: @worker)
    export = fail_job(enqueue_job(BrokenExportJob, 1), worker: @worker)

    get "/job_harbor/jobs/status/failed?class_name=FlakyPaymentJob&queue_name=default"
    assert_bulk_form "/job_harbor/jobs/retry_all?class_name=FlakyPaymentJob&queue_name=default&status=failed",
      text: "Retry 2 failed jobs", confirm: RETRY_COUNTERS_NOTE % "2 failed jobs", method: "post"

    assert_difference -> { SolidQueue::FailedExecution.where(job_id: [ flaky_a.id, flaky_b.id ]).count } => -2,
      -> { SolidQueue::ReadyExecution.where(job_id: [ flaky_a.id, flaky_b.id ]).count } => 2,
      -> { SolidQueue::FailedExecution.where(job_id: [ @failed.id, export.id ]).count } => 0,
      -> { SolidQueue::ReadyExecution.where(job_id: [ @failed.id, export.id ]).count } => 0 do
      post "/job_harbor/jobs/retry_all?class_name=FlakyPaymentJob&queue_name=default&status=failed"
    end

    follow_redirect!
    assert_select ".alert-success", text: "2 jobs queued for retry."
  end

  test "operator retries a large failed list in bulk without a query per job" do
    jobs = Array.new(20) { |i| fail_job(enqueue_job(FlakyPaymentJob, 100 + i), worker: @worker) }

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      post "/job_harbor/jobs/retry_all?status=failed"
    end

    assert_equal 0, SolidQueue::FailedExecution.where(job_id: jobs.map(&:id)).count
    assert_operator queries, :<, jobs.size, "Bulk retry ran #{queries} SQL statements for #{jobs.size + 1} jobs; it should not scale per job"
  end

  test "every page's discard button asks for confirmation through a form-level data-confirm the layout handles" do
    get "/job_harbor/jobs/#{@failed.id}"
    assert_select "form[action=?][data-confirm=?]", "/job_harbor/jobs/#{@failed.id}/discard", DISCARD_JOB_CONFIRM
    assert_select "button[data-confirm]", count: 0

    scripts = css_select("script").map(&:text).join("\n")
    assert_includes scripts, "dataset.confirm", "Layout needs a handler that reads form data-confirm (not exercised: no JS runner)"
    assert_includes scripts, "preventDefault"
  end


  test "the confirm script carries the host app's CSP nonce when a nonce generator is configured" do
    with_csp_nonce("abc123") { get "/job_harbor/jobs" }

    script = css_select("script").find { |tag| tag.text.include?("dataset.confirm") }
    assert script, "Layout is missing the confirm handler script"
    assert_equal "abc123", script["nonce"], "Confirm script must carry the host's nonce or a strict CSP blocks it"
  end

  test "operator opens the Failed list with a malformed filter and it falls back to the unfiltered list" do
    get "/job_harbor/jobs/status/failed?class_name[x]=1&queue_name[]=a"

    assert_response :success
    assert_select "button", text: "Retry 1 failed job"
  end

  test "a bulk action with a malformed filter is rejected and touches no jobs" do
    assert_no_difference -> { SolidQueue::FailedExecution.count }, "Malformed retry_all must not widen to every failed job" do
      post "/job_harbor/jobs/retry_all?status=failed&class_name[x]=1"
    end
    assert_response :bad_request

    assert_no_difference [ -> { SolidQueue::FailedExecution.count }, -> { SolidQueue::BlockedExecution.count } ], "Malformed discard_all must not widen to every job" do
      delete "/job_harbor/jobs/discard_all?status=failed&queue_name[]=a"
      assert_response :bad_request
      delete "/job_harbor/jobs/discard_all?status=blocked&class_name[x]=1"
      assert_response :bad_request
    end
    assert_nil @failed.reload.finished_at
  end

  private
    # The app's env_config is applied to every request, so the nonce settings have to be swapped there.
    def with_csp_nonce(nonce)
      env_config = Rails.application.env_config
      keys = { "action_dispatch.content_security_policy" => ActionDispatch::ContentSecurityPolicy.new { |policy| policy.script_src :self },
               "action_dispatch.content_security_policy_nonce_generator" => ->(_request) { nonce } }
      originals = keys.keys.to_h { |key| [ key, env_config[key] ] }
      env_config.merge!(keys)
      yield
    ensure
      env_config.merge!(originals)
    end

    # backlog #1: discard deletes the execution and marks the job finished instead of SQ's own discard, which destroys the job row.
    def assert_discarded(execution_class, *jobs, &block)
      ids = jobs.map(&:id)
      finished_at = -> { SolidQueue::Job.where(id: ids).order(:id).pluck(:finished_at) }

      assert_difference -> { execution_class.where(job_id: ids).count }, -jobs.size, "Discard should remove the #{execution_class.name.demodulize}" do
        assert_changes finished_at, "Discarded jobs should be marked finished", from: [ nil ] * jobs.size, to: [ Time.current ] * jobs.size, &block
      end
      assert_equal ids.size, SolidQueue::Job.where(id: ids).count, "Discard keeps the job rows"
    end

    def assert_discard_form(action, confirm:, text: "Discard")
      assert_bulk_form action, text: text, confirm: confirm
    end

    def assert_bulk_form(action, text:, confirm:, method: "delete")
      assert_select "form[action=?][data-confirm=?]", action, confirm, { count: 1 }, "Operator expected a '#{text}' button posting to #{action} that asks '#{confirm}'" do
        if method == "delete"
          assert_select "input[name=_method][value=delete]", 1, "'#{text}' must submit as DELETE"
        else
          assert_select "input[name=_method]", 0, "'#{text}' must submit as POST"
        end
        assert_select "button", text: text
      end
    end

    def assert_lands_on_all_jobs_with(notice)
      assert_redirected_to "/job_harbor/jobs"
      follow_redirect!
      assert_select ".alert-success", text: notice
    end

    def assert_status_tab_count(status, count)
      label = status.humanize.titleize
      assert_select "a.badge[href=?]", "/job_harbor/jobs/status/#{status}", { text: /\A#{label}\s+#{count}\z/ },
        "#{label} tab should show #{count} after the action"
    end

    def assert_info_line(label, value)
      line = css_select(".info-line").find { |l| l.at_css(".info-line-label").text.strip == label }
      assert line, "Operator expected a '#{label}' line on the job page"
      assert_equal value, line.at_css(".info-line-value").text.strip, "'#{label}' line shows the wrong value"
    end
end
