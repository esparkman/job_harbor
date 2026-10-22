require "test_helper"

class QueueActionsTest < ActionDispatch::IntegrationTest
  setup do
    enqueue_job(ReportJob, "weekly")
    enqueue_job(NewsletterJob, "digest", queue: "mailers")
  end

  test "operator pauses a queue from Queues and Solid Queue stops treating it as active" do
    get "/job_harbor/queues"
    assert_select "form[action=?] button", "/job_harbor/queues/default/pause", text: "Pause"

    assert_difference -> { SolidQueue::Pause.where(queue_name: "default").count } => 1 do
      post "/job_harbor/queues/default/pause"
    end

    assert SolidQueue::Queue.find_by_name("default").paused?, "Solid Queue should see the default queue as paused"
    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'default' has been paused."
    assert_queue_card_state "default", "Paused"
    assert_queue_card_state "mailers", "Active"
    assert_select "form[action=?] button", "/job_harbor/queues/default/resume", text: "Resume"
  end

  test "operator pauses an already paused queue from a stale page and it stays paused once" do
    get "/job_harbor/queues"
    assert_select "form[action=?] button", "/job_harbor/queues/default/pause", text: "Pause"
    SolidQueue::Pause.create!(queue_name: "default")

    assert_no_difference -> { SolidQueue::Pause.where(queue_name: "default").count } do
      post "/job_harbor/queues/default/pause"
    end

    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'default' has been paused."
    assert_queue_card_state "default", "Paused"
  end

  test "two pause submits racing past the paused check leave one Pause row and no error" do
    SolidQueue::Pause.create!(queue_name: "default")

    with_racing_pause_check do
      assert_no_difference -> { SolidQueue::Pause.where(queue_name: "default").count } do
        post "/job_harbor/queues/default/pause"
      end
    end

    assert_redirected_to "/job_harbor/queues"
    assert_equal 1, SolidQueue::Pause.where(queue_name: "default").count
  end

  test "operator resumes a paused queue from its page and it goes back to active" do
    SolidQueue::Pause.create!(queue_name: "default")

    get "/job_harbor/queues/default"
    assert_select "form[action=?]", "/job_harbor/queues/default/resume" do
      assert_select "input[name=_method][value=delete]", 1, "Resume Queue must submit as DELETE"
      assert_select "button", text: "Resume Queue"
    end

    assert_difference -> { SolidQueue::Pause.where(queue_name: "default").count } => -1 do
      delete "/job_harbor/queues/default/resume"
    end

    assert_not SolidQueue::Queue.find_by_name("default").paused?, "Solid Queue should see the default queue as active again"
    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'default' has been resumed."
    assert_queue_card_state "default", "Active"
    assert_select "form[action=?] button", "/job_harbor/queues/default/pause", text: "Pause"
  end

  test "operator tries to pause a queue that has no jobs and lands on Queues with a notice" do
    assert_no_difference -> { SolidQueue::Pause.count } do
      post "/job_harbor/queues/nowhere/pause"
    end

    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-error", text: "Queue not found."
  end

  private
    # Simulates a racing check-then-create: the existence check misses a pause that's already there.
    def with_racing_pause_check
      SolidQueue::Pause.define_singleton_method(:exists?) { |*| false }
      yield
    ensure
      SolidQueue::Pause.singleton_class.remove_method(:exists?)
    end

    def assert_queue_card_state(name, state)
      card = css_select(".card").find { |c| c.at_css("a.card-title")&.text&.strip == name }
      assert card, "Operator expected a card for the '#{name}' queue"
      assert_equal state, card.at_css(".card-header .badge").text.strip, "'#{name}' queue shows the wrong state after the action"
    end
end
