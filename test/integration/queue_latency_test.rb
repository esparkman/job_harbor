require "test_helper"

class QueueLatencyTest < ActionDispatch::IntegrationTest
  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")
  end

  test "operator opens Queues and sees how long the oldest ready job in each queue has waited" do
    travel_to(2.hours.ago) { enqueue_job(ReportJob, "old") }
    travel_to(10.minutes.ago) { enqueue_job(ReportJob, "new") }
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)

    get "/job_harbor/queues"

    assert_queue_latency "default", "about 2 hours"
    assert_queue_latency "mailers", "—"
  end

  test "operator opens a queue with nothing ready to run and sees no latency" do
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    claim_job(enqueue_job(NewsletterJob, "reset", queue: "mailers"), worker: @worker)

    get "/job_harbor/queues/mailers"

    assert_stat_card "Latency", "—"
  end

  test "operator opens a queue and sees how long its oldest ready job has waited" do
    travel_to(2.hours.ago) { enqueue_job(ReportJob, "old") }

    get "/job_harbor/queues/default"

    assert_stat_card "Latency", "about 2 hours"
  end

  test "operator sees the slowest queue on the dashboard and clicks through to it" do
    travel_to(5.minutes.ago) { enqueue_job(ReportJob, "urgent", queue: "critical") }
    travel_to(2.hours.ago) { enqueue_job(ReportJob, "old") }

    get "/job_harbor"

    assert_stat_card "Queue Latency", "about 2 hours"
    assert_select "a.stat-card[href=?] .stat-card-detail", "/job_harbor/queues/default", text: "default"

    get "/job_harbor/queues/default"
    assert_select "h1", text: "Queue: default"
  end

  test "operator sees a paused queue's own latency but the dashboard names the slowest running queue" do
    travel_to(3.days.ago) { enqueue_job(ReportJob, "stuck", queue: "low_priority") }
    travel_to(5.minutes.ago) { enqueue_job(ReportJob, "fresh") }
    SolidQueue::Pause.create!(queue_name: "low_priority")

    get "/job_harbor"

    assert_stat_card "Queue Latency", "5 minutes"
    assert_select "a.stat-card[href=?] .stat-card-detail", "/job_harbor/queues/default", text: "default"

    get "/job_harbor/queues"

    assert_queue_latency "low_priority", "3 days"
  end

  test "operator sees no dashboard latency when every queue with waiting jobs is paused" do
    travel_to(1.hour.ago) { enqueue_job(ReportJob, "stuck", queue: "low_priority") }
    SolidQueue::Pause.create!(queue_name: "low_priority")

    get "/job_harbor"

    assert_stat_card "Queue Latency", "—"
    assert_select ".stat-card-detail", count: 0
  end

  private
    def assert_queue_latency(name, latency)
      card = css_select(".card").find { |c| c.at_css("a.card-title")&.text&.strip == name }
      assert card, "Operator expected a card for the '#{name}' queue"
      line = card.css(".info-line").find { |l| l.at_css(".info-line-label").text.strip == "Latency" }
      assert line, "'#{name}' queue card shows no latency"
      assert_equal latency, line.at_css(".info-line-value").text.strip, "'#{name}' queue card shows the wrong latency"
    end
end
