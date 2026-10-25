require "test_helper"

class QueuePrePauseTest < ActionDispatch::IntegrationTest
  test "operator types a new queue name, pauses it and sees a paused card with zero counts" do
    enqueue_job(ReportJob, "weekly")

    get "/job_harbor/queues"
    assert_select "form[action=?][method=post]", "/job_harbor/queues/pause" do
      assert_select "input[type=text][name=name]", 1
      assert_select "button", text: "Pause"
    end

    assert_difference -> { SolidQueue::Pause.where(queue_name: "reports").count } => 1 do
      post "/job_harbor/queues/pause", params: { name: "  reports " }
    end

    assert SolidQueue::Queue.find_by_name("reports").paused?
    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'reports' has been paused."
    card = css_select(".card").find { |c| c.at_css("a.card-title")&.text&.strip == "reports" }
    assert card, "Operator expected a card for the pre-paused 'reports' queue"
    assert_equal "Paused", card.at_css(".card-header .badge").text.strip
    assert_equal %w[0 0 0 0], card.css(".text-xl").map { |n| n.text.strip }

    get "/job_harbor"
    assert_stat_card "Queues", 2
  end

  test "operator sees the pause form on Queues even before any queue exists" do
    get "/job_harbor/queues"

    assert_select "h3", text: "No queues found"
    assert_select "form[action=?] input[name=name]", "/job_harbor/queues/pause"
  end

  test "operator resumes a pre-paused queue with no jobs and its card goes away" do
    post "/job_harbor/queues/pause", params: { name: "reports" }

    delete "/job_harbor/queues/reports/resume"

    assert_equal 0, SolidQueue::Pause.count
    follow_redirect!
    assert_select ".card a.card-title", text: "reports", count: 0
  end

  test "operator submits a blank name and is told so without a pause being created" do
    [ "", "   " ].each do |blank|
      assert_no_difference -> { SolidQueue::Pause.count } do
        post "/job_harbor/queues/pause", params: { name: blank }
      end

      assert_redirected_to "/job_harbor/queues"
      follow_redirect!
      assert_select ".alert-error", text: "Enter a queue name to pause."
    end
  end

  test "missing name param is rejected without a pause" do
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pause"
    end

    assert_redirected_to "/job_harbor/queues"
  end

  test "non-string name params are rejected without a pause" do
    [ { name: [ "x" ] }, { name: { a: "x" } } ].each do |params|
      assert_no_difference -> { SolidQueue::Pause.count } do
        post "/job_harbor/queues/pause", params: params
      end

      assert_redirected_to "/job_harbor/queues"
      follow_redirect!
      assert_select ".alert-error", text: "Enter a queue name to pause."
    end
  end

  test "over-long name is rejected but the longest allowed name is accepted" do
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pause", params: { name: "a" * 256 }
    end
    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-error", text: "Queue name must be 255 characters or fewer."

    assert_difference -> { SolidQueue::Pause.count } => 1 do
      post "/job_harbor/queues/pause", params: { name: "a" * 255 }
    end
  end

  test "pausing the same new queue twice leaves one pause and says it was already paused" do
    post "/job_harbor/queues/pause", params: { name: "reports" }

    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pause", params: { name: "reports" }
    end

    follow_redirect!
    assert_select ".alert-success", text: "Queue 'reports' is already paused."
  end

  test "the per-queue pause still refuses a queue that does not exist" do
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/nowhere/pause"
    end
    follow_redirect!
    assert_select ".alert-error", text: "Queue not found."
  end

  test "a queue literally named pause can be pre-paused and then resumed" do
    post "/job_harbor/queues/pause", params: { name: "pause" }
    assert SolidQueue::Pause.exists?(queue_name: "pause")

    delete "/job_harbor/queues/pause/resume"
    assert_not SolidQueue::Pause.exists?(queue_name: "pause")
  end
end
