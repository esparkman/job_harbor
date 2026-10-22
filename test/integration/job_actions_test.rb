require "test_helper"

class JobActionsTest < ActionDispatch::IntegrationTest
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
    assert_discard_form "/job_harbor/jobs/#{@failed.id}/discard"

    assert_discarded(SolidQueue::FailedExecution, @failed) { delete "/job_harbor/jobs/#{@failed.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "failed", 0
    assert_status_tab_count "finished", 1
  end

  test "operator discards a pending job from the Pending list and it will never run" do
    get "/job_harbor/jobs/status/pending"
    assert_discard_form "/job_harbor/jobs/#{@pending.id}/discard"

    assert_discarded(SolidQueue::ReadyExecution, @pending) { delete "/job_harbor/jobs/#{@pending.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "pending", 1
    assert_status_tab_count "finished", 1
  end

  test "operator discards a scheduled job from its page and it is taken off the schedule" do
    get "/job_harbor/jobs/#{@scheduled.id}"
    assert_discard_form "/job_harbor/jobs/#{@scheduled.id}/discard", text: "Discard Job"

    assert_discarded(SolidQueue::ScheduledExecution, @scheduled) { delete "/job_harbor/jobs/#{@scheduled.id}/discard" }

    assert_lands_on_all_jobs_with "Job has been discarded."
    assert_status_tab_count "scheduled", 0
    assert_status_tab_count "finished", 1
  end

  # Concurrency slot is not released (backlog #18).
  test "operator discards a blocked job from the Blocked list and it leaves the Blocked list" do
    get "/job_harbor/jobs/status/blocked"
    assert_discard_form "/job_harbor/jobs/#{@blocked.id}/discard"

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
    assert_select "form[action=?] button", "/job_harbor/jobs/retry_all?status=failed", text: "Retry All Failed"

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

  test "operator discards all failed jobs and they move to Finished" do
    second = fail_job(enqueue_job(FlakyPaymentJob, 43), worker: @worker)

    get "/job_harbor/jobs/status/failed"
    assert_discard_form "/job_harbor/jobs/discard_all?status=failed", text: "Discard All Failed"

    assert_discarded(SolidQueue::FailedExecution, @failed, second) { delete "/job_harbor/jobs/discard_all?status=failed" }

    assert_redirected_to "/job_harbor/jobs?status=failed"
    follow_redirect!
    assert_select ".alert-success", text: "2 jobs discarded."
    assert_select "p", text: "There are no failed jobs."
    assert_status_tab_count "finished", 2
  end

  # No page renders a Discard All button for blocked jobs, but the controller supports it.
  test "operator discards all blocked jobs through the endpoint and the Blocked list empties" do
    get "/job_harbor/jobs/status/blocked"
    assert_select "form[action^=?]", "/job_harbor/jobs/discard_all", count: 0

    assert_discarded(SolidQueue::BlockedExecution, @blocked) { delete "/job_harbor/jobs/discard_all?status=blocked" }

    assert_redirected_to "/job_harbor/jobs?status=blocked"
    follow_redirect!
    assert_select ".alert-success", text: "1 jobs discarded." # backlog #17
    assert_select "p", text: "There are no blocked jobs."
  end

  private
    # backlog #1: discard deletes the execution and marks the job finished instead of SQ's own discard, which destroys the job row.
    def assert_discarded(execution_class, *jobs, &block)
      ids = jobs.map(&:id)
      finished_at = -> { SolidQueue::Job.where(id: ids).order(:id).pluck(:finished_at) }

      assert_difference -> { execution_class.where(job_id: ids).count }, -jobs.size, "Discard should remove the #{execution_class.name.demodulize}" do
        assert_changes finished_at, "Discarded jobs should be marked finished", from: [ nil ] * jobs.size, to: [ Time.current ] * jobs.size, &block
      end
      assert_equal ids.size, SolidQueue::Job.where(id: ids).count, "Discard keeps the job rows"
    end

    def assert_discard_form(action, text: "Discard")
      assert_select "form[action=?]", action, { count: 1 }, "Operator expected a '#{text}' button posting to #{action}" do
        assert_select "input[name=_method][value=delete]", 1, "'#{text}' must submit as DELETE"
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
