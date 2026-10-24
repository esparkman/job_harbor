require "test_helper"

class QueuesPagesTest < ActionDispatch::IntegrationTest
  test "operator opens Queues and sees each queue's live counts and whether it is paused" do
    worker = register_worker(name: "worker-1")
    enqueue_job(ReportJob, "weekly")
    enqueue_job(ReportJob, "monthly")
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    claim_job(enqueue_job(ReportJob, "quarterly", queue: "critical"), worker: worker)
    SolidQueue::Pause.create!(queue_name: "low_priority")

    get "/job_harbor/queues"

    assert_response :success
    assert_select "h1", text: "Queues"
    assert_equal %w[critical default low_priority mailers], css_select(".card a.card-title").map { |a| a.text.strip }
    assert_queue_card "default", status: "Active", counts: { "Pending" => "2", "Scheduled" => "0", "In Progress" => "0", "Blocked" => "0" }
    assert_queue_card "mailers", status: "Active", counts: { "Pending" => "0", "Scheduled" => "1", "In Progress" => "0", "Blocked" => "0" }
    assert_queue_card "critical", status: "Active", counts: { "Pending" => "0", "Scheduled" => "0", "In Progress" => "1", "Blocked" => "0" }
    assert_queue_card "low_priority", status: "Paused", counts: { "Pending" => "0", "Scheduled" => "0", "In Progress" => "0", "Blocked" => "0" }
    assert_select "form[action=?] button", "/job_harbor/queues/low_priority/resume", text: "Resume"
    assert_select "form[action=?] button", "/job_harbor/queues/default/pause", text: "Pause"
  end

  test "operator opens Queues before any job exists and sees an empty state" do
    get "/job_harbor/queues"

    assert_response :success
    assert_select "h3", text: "No queues found"
  end

  test "operator opens a queue and sees its counts and the jobs waiting in it" do
    worker = register_worker(name: "worker-1")
    enqueue_job(NewsletterJob, "welcome", queue: "mailers")
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    claim_job(enqueue_job(NewsletterJob, "reset", queue: "mailers"), worker: worker)
    fail_job(enqueue_job(FlakyPaymentJob, 7, queue: "mailers"), worker: worker)

    get "/job_harbor/queues/mailers"

    assert_response :success
    assert_select "h1", text: "Queue: mailers"
    assert_stat_card "Pending", 1
    assert_stat_card "Scheduled", 1
    assert_stat_card "In Progress", 1
    assert_stat_card "Failed", 1
    assert_stat_card "Blocked", 0
    assert_select "button", text: "Pause Queue"
    assert_select ".alert-warning", count: 0

    rows = css_select("table.sqd-table tbody tr").map { |tr| [ tr.at_css("code").text, tr.at_css(".badge").text.strip ] }
    assert_equal [ [ "FlakyPaymentJob", "Failed" ], [ "NewsletterJob", "In Progress" ], [ "NewsletterJob", "Pending" ], [ "NewsletterJob", "Scheduled" ] ],
      rows.sort
    assert_select "tbody button", text: "Retry", count: 1
  end

  test "operator opens a queue with a blocked job and sees it counted on the queue page and its card" do
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(ThrottledImportJob, "globex", queue: "other")

    get "/job_harbor/queues/imports"

    assert_stat_card "Pending", 1
    assert_stat_card "Blocked", 1
    assert_select "tbody .badge", text: "Blocked", count: 1

    get "/job_harbor/queues"

    assert_queue_card "imports", status: "Active", counts: { "Pending" => "1", "Scheduled" => "0", "In Progress" => "0", "Blocked" => "1" }
    assert_queue_card "other", status: "Active", counts: { "Pending" => "1", "Scheduled" => "0", "In Progress" => "0", "Blocked" => "0" }
  end

  test "operator pages through a busy queue and sees only that queue's jobs on every page" do
    27.times { |i| enqueue_job(ReportJob, "report-#{i}") }
    3.times { |i| enqueue_job(NewsletterJob, "digest-#{i}", queue: "mailers") }

    get "/job_harbor/queues/default"

    assert_response :success
    assert_equal 25, css_select("table.sqd-table tbody tr").size, "Page 1 of a 27-job queue should be full"
    assert_equal [ "default" ], css_select("table.sqd-table tbody tr td:nth-child(3)").map { |td| td.text.strip }.uniq,
      "Page 1 shows jobs from another queue"
    assert_equal %w[1 2], css_select(".pagination-link").map { |a| a.text.strip }.grep(/\A\d+\z/)

    get "/job_harbor/queues/default", params: { page: 2 }

    assert_equal 2, css_select("table.sqd-table tbody tr").size, "Page 2 should hold the 2 remaining default jobs"
    assert_equal [ "default" ], css_select("table.sqd-table tbody tr td:nth-child(3)").map { |td| td.text.strip }.uniq
  end

  test "operator opens a queue page and can discard a pending job after a confirmation" do
    job = enqueue_job(ReportJob, "weekly")

    get "/job_harbor/queues/default"

    assert_select "form[action=?][data-confirm]", "/job_harbor/jobs/#{job.id}/discard" do
      assert_select "button", text: "Discard"
    end

    assert_difference -> { SolidQueue::Job.count } => -1 do
      delete "/job_harbor/jobs/#{job.id}/discard"
    end
  end

  test "operator opens a paused queue and is warned that its jobs will not run" do
    SolidQueue::Pause.create!(queue_name: "low_priority")

    get "/job_harbor/queues/low_priority"

    assert_response :success
    assert_select ".alert-warning", text: /This queue is currently paused/
    assert_select "button", text: "Resume Queue"
    assert_select "h3", text: "No jobs in this queue"
  end

  test "operator opens a queue that does not exist and lands on Queues with a notice" do
    get "/job_harbor/queues/nowhere"

    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-error", text: "Queue not found."
  end

  private
    def assert_queue_card(name, status:, counts:)
      card = css_select(".card").find { |c| c.at_css("a.card-title")&.text&.strip == name }
      assert card, "Operator expected a card for the '#{name}' queue"
      assert_equal status, card.at_css(".card-header .badge").text.strip, "'#{name}' queue shows the wrong state"
      shown = card.at_css(".card-content > div").element_children.to_h do |stat|
        value, label = stat.element_children.map { |el| el.text.strip }
        [ label, value ]
      end
      assert_equal counts, shown, "'#{name}' queue card shows the wrong counts"
    end
end

class WorkersPagesTest < ActionDispatch::IntegrationTest
  setup { freeze_time }

  test "operator opens Workers and sees how many are alive versus stale" do
    register_worker(name: "worker-1", hostname: "harbor-1", pid: 101)
    register_worker(name: "worker-2", hostname: "harbor-2", pid: 202)
    register_worker(name: "worker-old", hostname: "harbor-3", pid: 303, heartbeat_at: 10.minutes.ago)

    get "/job_harbor/workers"

    assert_response :success
    assert_select "h1", text: "Workers"
    assert_stat_card "Processes", 3
    assert_stat_card "Live", 2
    assert_stat_card "Stale", 1
  end

  test "operator sees each worker's host, pid, and last heartbeat on its card" do
    register_worker(name: "worker-1", hostname: "harbor-1", pid: 101)
    register_worker(name: "worker-old", hostname: "harbor-3", pid: 303, heartbeat_at: 10.minutes.ago)

    get "/job_harbor/workers"

    assert_worker_card "worker-1", badge: "Active", "Hostname" => "harbor-1", "PID" => "101", "Last Heartbeat" => "less than a minute ago"
    assert_worker_card "worker-old", badge: "Stale", "Hostname" => "harbor-3", "PID" => "303", "Last Heartbeat" => "10 minutes ago"
  end

  test "operator sees every process on Workers, labeled by kind, while only live workers count as workers elsewhere" do
    register_worker(name: "worker-1", pid: 101)
    register_worker(name: "worker-old", pid: 303, heartbeat_at: 10.minutes.ago)
    register_worker(name: "supervisor-1", pid: 1, kind: "Supervisor(fork)")

    get "/job_harbor/workers"

    assert_stat_card "Processes", 3
    assert_stat_card "Live", 2
    assert_stat_card "Stale", 1
    assert_select "[data-live-workers]", text: "Live workers: 1"
    assert_equal 3, css_select(".card .card-title").size, "Workers should list a card for every process"
    assert_worker_kind "worker-1", "Worker"
    assert_worker_kind "worker-old", "Worker"
    assert_worker_kind "supervisor-1", "Supervisor"
    assert_equal "Supervisor(fork)", worker_card("supervisor-1").at_css("[data-kind]")["data-kind"]
    assert_worker_card "supervisor-1", badge: "Active", "Hostname" => "harbor-1", "PID" => "1", "Last Heartbeat" => "less than a minute ago"
    assert_worker_card "worker-old", badge: "Stale", "Hostname" => "harbor-1", "PID" => "303", "Last Heartbeat" => "10 minutes ago"

    assert_select "a[href=?] .sqd-nav-badge", "/job_harbor/workers", text: "1"
    get "/job_harbor"
    assert_stat_card "Active Workers", 1
    assert_select "a[href=?] .sqd-nav-badge", "/job_harbor/workers", text: "1"
  end

  test "operator sees the queues each worker polls on its card" do
    register_worker(name: "worker-1", queues: "default,mailers")
    register_worker(name: "worker-2", queues: "*")
    register_worker(name: "worker-3")

    get "/job_harbor/workers"

    assert_equal %w[default mailers], worker_queues("worker-1")
    assert_equal %w[*], worker_queues("worker-2")
    assert_empty worker_queues("worker-3"), "A worker with no recorded queues should show no queue list"
  end

  test "a worker is stale once its heartbeat is older than Solid Queue's process_alive_threshold" do
    register_worker(name: "worker-1", heartbeat_at: 2.minutes.ago)
    original = SolidQueue.process_alive_threshold

    SolidQueue.process_alive_threshold = 1.minute
    get "/job_harbor/workers"
    assert_worker_card "worker-1", badge: "Stale", "Hostname" => "harbor-1", "PID" => "4242", "Last Heartbeat" => "2 minutes ago"
    assert_stat_card "Stale", 1
    get "/job_harbor"
    assert_stat_card "Active Workers", 0

    SolidQueue.process_alive_threshold = 10.minutes
    get "/job_harbor/workers"
    assert_worker_card "worker-1", badge: "Active", "Hostname" => "harbor-1", "PID" => "4242", "Last Heartbeat" => "2 minutes ago"
    get "/job_harbor"
    assert_stat_card "Active Workers", 1
  ensure
    SolidQueue.process_alive_threshold = original
  end

  test "operator opens Workers with no processes running and sees an empty state" do
    get "/job_harbor/workers"

    assert_response :success
    assert_stat_card "Processes", 0
    assert_select "[data-live-workers]", text: "Live workers: 0"
    assert_select "h3", text: "No workers found"
  end

  private
    def worker_card(name)
      css_select(".card").find { |c| c.at_css(".card-title")&.text&.strip == name }
    end

    def worker_queues(name)
      worker_card(name).css("code").map { |c| c.text.strip }
    end

    def assert_worker_kind(name, kind)
      assert_equal kind, worker_card(name).at_css("[data-kind]")&.text&.strip, "Worker '#{name}' is labeled with the wrong process kind"
    end

    def assert_worker_card(name, badge:, **lines)
      card = worker_card(name)
      assert card, "Operator expected a card for worker '#{name}'"
      assert_equal badge, card.at_css("[data-heartbeat] .badge").text.strip, "Worker '#{name}' shows the wrong heartbeat state"
      shown = card.css(".info-line").to_h { |l| [ l.at_css(".info-line-label").text.strip, l.at_css(".info-line-value").text.strip ] }
      assert_equal lines.transform_keys(&:to_s), shown, "Worker '#{name}' card shows the wrong details"
    end
end

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

class EmptyRecurringTasksPagesTest < ActionDispatch::IntegrationTest
  test "operator opens Recurring Tasks with none configured and sees how to add them" do
    get "/job_harbor/recurring_tasks"

    assert_response :success
    assert_select "h3", text: "No recurring tasks found"
    assert_select "p", text: /config\/recurring.yml/
  end
end
