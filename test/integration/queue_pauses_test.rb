require "test_helper"

class QueuePausesTest < ActionDispatch::IntegrationTest
  test "operator types a new queue name, pauses it and sees a paused card with zero counts" do
    enqueue_job(ReportJob, "weekly")

    get "/job_harbor/queues"
    assert_select "form[action=?][method=post]", "/job_harbor/queues/pauses" do
      assert_select "input[type=text][name=name]", 1
      assert_select "button", text: "Pause"
    end

    assert_difference -> { SolidQueue::Pause.where(queue_name: "reports").count } => 1 do
      post "/job_harbor/queues/pauses", params: { name: "  reports " }
    end

    assert SolidQueue::Queue.find_by_name("reports").paused?
    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'reports' has been paused."
    card = card_for("reports")
    assert card, "Operator expected a card for the pre-paused 'reports' queue"
    assert_includes card.text, "Paused"
    assert_select "form[action=?] button", "/job_harbor/queues/reports/resume", text: "Resume"
    %w[Pending Scheduled].each { |label| assert_equal "0", stat_value(card, label) }

    get "/job_harbor"
    assert_stat_card "Queues", 2
  end

  test "operator sees the pause form on Queues even before any queue exists" do
    get "/job_harbor/queues"

    assert_select "h3", text: "No queues found"
    assert_select "form[action=?] input[name=name][maxlength=?]", "/job_harbor/queues/pauses", JobHarbor::QueueStats::MAX_NAME_LENGTH.to_s
  end

  test "operator resumes a pre-paused queue with no jobs and its card goes away" do
    post "/job_harbor/queues/pauses", params: { name: "reports" }

    delete "/job_harbor/queues/reports/resume"

    assert_equal 0, SolidQueue::Pause.count
    follow_redirect!
    assert_select ".card a.card-title", text: "reports", count: 0
  end

  test "operator submits a blank name and is told so without a pause being created" do
    [ "", "   " ].each do |blank|
      assert_no_difference -> { SolidQueue::Pause.count } do
        post "/job_harbor/queues/pauses", params: { name: blank }
      end

      assert_redirected_to "/job_harbor/queues"
      follow_redirect!
      assert_select ".alert-error", text: "Enter a queue name."
    end
  end

  test "missing name param is rejected without a pause" do
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pauses"
    end

    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-error", text: "Enter a queue name."
  end

  test "non-string name params are rejected without a pause" do
    [ { name: [ "x" ] }, { name: { a: "x" } } ].each do |params|
      assert_no_difference -> { SolidQueue::Pause.count } do
        post "/job_harbor/queues/pauses", params: params
      end

      assert_redirected_to "/job_harbor/queues"
      follow_redirect!
      assert_select ".alert-error", text: "Enter a queue name."
    end
  end

  test "a name with a control character is rejected without a pause" do
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pauses", params: { name: "a\u0000b" }
    end

    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-error", text: "Queue name can't contain control characters."
  end

  test "over-long name is rejected but the longest allowed name is accepted" do
    max = JobHarbor::QueueStats::MAX_NAME_LENGTH
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pauses", params: { name: "a" * (max + 1) }
    end
    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-error", text: "Queue name must be #{max} characters or fewer."

    assert_difference -> { SolidQueue::Pause.count } => 1 do
      post "/job_harbor/queues/pauses", params: { name: "a" * max }
    end
  end

  test "pausing the same new queue twice leaves one pause and says it was already paused" do
    post "/job_harbor/queues/pauses", params: { name: "reports" }

    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/pauses", params: { name: "reports" }
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

  test "a queue literally named pauses can be opened, paused and resumed from its own routes" do
    enqueue_job(ReportJob, "weekly", queue: "pauses")

    get "/job_harbor/queues/pauses"
    assert_response :success
    assert_select "form[action=?] button", "/job_harbor/queues/pauses/pause", text: "Pause Queue"

    post "/job_harbor/queues/pauses/pause"
    assert SolidQueue::Pause.exists?(queue_name: "pauses")

    delete "/job_harbor/queues/pauses/resume"
    assert_not SolidQueue::Pause.exists?(queue_name: "pauses")
  end

  test "a name with a trailing non-breaking space pauses the plain name" do
    assert_difference -> { SolidQueue::Pause.where(queue_name: "reports").count } => 1 do
      post "/job_harbor/queues/pauses", params: { name: "reports\u00A0" }
    end
  end

  private

    def card_for(name)
      css_select(".card").find { |c| c.at_css("a.card-title")&.text&.strip == name }
    end

    def stat_value(card, label)
      label_node = card.css("div").find { |d| d.element_children.empty? && d.text.strip == label }
      label_node.previous_element.text.strip
    end
end
