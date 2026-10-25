require "test_helper"

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
