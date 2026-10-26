require "test_helper"

class QueueDottedNamesTest < ActionDispatch::IntegrationTest
  test "operator pauses reports.daily from the form, then resumes it from its card" do
    post "/job_harbor/queues/pauses", params: { name: "reports.daily" }
    assert SolidQueue::Pause.exists?(queue_name: "reports.daily")

    get "/job_harbor/queues"
    assert_select "a.card-title[href=?]", "/job_harbor/queues/reports.daily", text: "reports.daily"
    assert_select "form[action=?] button", "/job_harbor/queues/reports.daily/resume", text: "Resume"

    delete "/job_harbor/queues/reports.daily/resume"

    assert_redirected_to "/job_harbor/queues"
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'reports.daily' has been resumed."
    assert_not SolidQueue::Pause.exists?(queue_name: "reports.daily")
  end

  test "operator opens the page of a pre-paused dotted queue" do
    post "/job_harbor/queues/pauses", params: { name: "reports.daily" }

    get "/job_harbor/queues/reports.daily"

    assert_response :success
    assert_select "h3", text: "No jobs in this queue"
    assert_select "form[action=?] button", "/job_harbor/queues/reports.daily/resume", text: "Resume Queue"
  end

  test "operator opens, pauses and resumes a queue whose jobs use a dotted name" do
    enqueue_job(ReportJob, "weekly", queue: "billing.charges")

    get "/job_harbor/queues"
    assert_select "a.card-title[href=?]", "/job_harbor/queues/billing.charges", text: "billing.charges"

    get "/job_harbor/queues/billing.charges"
    assert_response :success
    assert_select "form[action=?] button", "/job_harbor/queues/billing.charges/pause", text: "Pause Queue"
    assert_select "table", 1

    post "/job_harbor/queues/billing.charges/pause"
    assert SolidQueue::Queue.find_by_name("billing.charges").paused?
    follow_redirect!
    assert_select ".alert-success", text: "Queue 'billing.charges' has been paused."

    delete "/job_harbor/queues/billing.charges/resume"
    assert_not SolidQueue::Queue.find_by_name("billing.charges").paused?
  end

  test "a name with a slash still round-trips through its card link" do
    post "/job_harbor/queues/pauses", params: { name: "a/b" }

    get "/job_harbor/queues"
    assert_select "a.card-title[href=?]", "/job_harbor/queues/a%2Fb", text: "a/b"

    get "/job_harbor/queues/a%2Fb"
    assert_response :success

    delete "/job_harbor/queues/a%2Fb/resume"
    assert_not SolidQueue::Pause.exists?(queue_name: "a/b")
  end

  { "a?b" => "a%3Fb", "a#b" => "a%23b" }.each do |name, escaped|
    test "operator pauses #{name} from the form, sees its card link and resumes it" do
      post "/job_harbor/queues/pauses", params: { name: name }
      assert SolidQueue::Pause.exists?(queue_name: name)

      get "/job_harbor/queues"
      assert_response :success
      assert_select "a.card-title[href=?]", "/job_harbor/queues/#{escaped}", text: name
      assert_select "form[action=?] button", "/job_harbor/queues/#{escaped}/resume", text: "Resume"

      delete "/job_harbor/queues/#{escaped}/resume"
      assert_not SolidQueue::Pause.exists?(queue_name: name)
    end

    test "operator opens a queue named #{name} that already has jobs" do
      enqueue_job(ReportJob, "weekly", queue: name)

      get "/job_harbor/queues"
      assert_response :success
      assert_select "a.card-title[href=?]", "/job_harbor/queues/#{escaped}", text: name

      get "/job_harbor/queues/#{escaped}"
      assert_response :success
      assert_select "table", 1
    end
  end
end
