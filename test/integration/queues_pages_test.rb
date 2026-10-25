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

  test "operator sees the same queue total on the dashboard as the Queues page lists when a queue is paused and empty" do
    enqueue_job(ReportJob, "weekly")
    SolidQueue::Pause.create!(queue_name: "low_priority")

    get "/job_harbor/queues"
    listed = css_select(".card a.card-title").size
    assert_equal 2, listed

    get "/job_harbor"

    assert_stat_card "Queues", listed
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
