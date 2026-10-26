require "application_system_test_case"

class AutoRefreshTest < ApplicationSystemTestCase
  WORKERS_BADGE = "nav a[href$='/workers'] .navbar-badge"

  setup do
    enqueue_job(ReportJob, "weekly")
    register_worker(name: "worker-1")
    visit "/job_harbor/queues"
    poll_every_second
  end

  test "operator half-types a queue name to pause, looks away, and the name is still there after a refresh" do
    type_queue_name_and_look_away "repo"

    wait_for_poll

    assert_field "Queue name", with: "repo", wait: 0
  end

  test "operator holding a half-typed queue name still sees the Workers badge count a new worker" do
    assert_selector WORKERS_BADGE, exact_text: "1"
    type_queue_name_and_look_away "repo"

    register_worker(name: "worker-2")

    assert_selector WORKERS_BADGE, exact_text: "2"
    assert_field "Queue name", with: "repo", wait: 0
  end

  test "operator clears a half-typed queue name and then sees the queue that was paused while they were typing" do
    type_queue_name_and_look_away "repo"
    SolidQueue::Pause.create!(queue_name: "reports")
    wait_for_poll
    assert_no_selector ".card a.card-title", exact_text: "reports", wait: 0
    assert_field "Queue name", with: "repo", wait: 0

    type_queue_name_and_look_away ""

    assert_selector ".card a.card-title", exact_text: "reports"
  end

  private
    def poll_every_second
      execute_script("localStorage.setItem('jh-refresh-interval', '1')")
      refresh
      # Counts poll responses the refresh script has parsed, whether or not it swapped the content
      execute_script(<<~JS)
        window.jhPolls = 0;
        var parse = DOMParser.prototype.parseFromString;
        DOMParser.prototype.parseFromString = function() { window.jhPolls++; return parse.apply(this, arguments); };
      JS
    end

    # A request already in flight may predate the caller's change; requests never overlap, so the second response is fresh
    def wait_for_poll
      execute_script("window.jhPolls = 0")
      page.document.synchronize do
        raise Capybara::ExpectationNotMet, "Auto-refresh never polled" unless evaluate_script("window.jhPolls") >= 2
      end
    end

    def type_queue_name_and_look_away(text)
      fill_in "Queue name", with: text
      find("h1").click
    end
end
