require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    freeze_time
    @worker = register_worker(name: "worker-1")
    @failed = fail_job(enqueue_job(FlakyPaymentJob, 42, queue: "critical"), worker: @worker)
    JobHarbor.reset_configuration!
  end

  teardown do
    JobHarbor.reset_configuration!
    Rails.application.reload_routes!
  end

  test "anonymous visitor to an unconfigured production install is refused the dashboard" do
    in_production do
      get "/job_harbor"
    end

    assert_response :forbidden
    assert_select ".stat-card", count: 0
  end

  test "anonymous visitor to an unconfigured production install cannot retry all failed jobs" do
    assert_no_difference -> { SolidQueue::FailedExecution.count } do
      assert_no_difference -> { SolidQueue::ReadyExecution.count } do
        in_production do
          post "/job_harbor/jobs/retry_all", params: { status: "failed" }
        end
      end
    end

    assert_response :forbidden
    assert SolidQueue::FailedExecution.exists?(job_id: @failed.id), "Failed job was retried by an anonymous request"
  end

  test "visitor to an unconfigured production install with a host root page is sent there with an alert" do
    draw_host_routes_with_root

    assert_no_difference -> { SolidQueue::FailedExecution.count } do
      in_production do
        post "/job_harbor/jobs/retry_all", params: { status: "failed" }
      end
    end

    assert_redirected_to "/"
    assert_equal "Admin access required.", flash[:alert]
  end

  test "API client refused by a production install with a host root page gets 403 instead of a redirect" do
    draw_host_routes_with_root

    in_production do
      get "/job_harbor", headers: { "Accept" => "application/json" }
    end

    assert_response :forbidden
    assert_nil flash[:alert]
  end

  test "anonymous visitor to an unconfigured staging install is refused the dashboard" do
    in_environment("staging") { get "/job_harbor" }

    assert_response :forbidden
    assert_select ".stat-card", count: 0
  end

  test "developer opens the dashboard of an unconfigured install in development" do
    in_environment("development") { get "/job_harbor" }

    assert_response :success
    assert_select ".stat-card"
  end

  test "developer opens the dashboard of an unconfigured install in test" do
    get "/job_harbor"

    assert_response :success
    assert_select ".stat-card"
  end

  test "explicitly configured deny rule refuses the operator in the test environment" do
    JobHarbor.configure { |config| config.authorize_with = -> { false } }

    assert_no_difference -> { SolidQueue::ReadyExecution.count } do
      post "/job_harbor/jobs/retry_all", params: { status: "failed" }
    end

    assert_response :forbidden
    assert SolidQueue::FailedExecution.exists?(job_id: @failed.id)
  end

  test "explicitly configured allow rule lets the operator in on a production install" do
    JobHarbor.configure { |config| config.authorize_with = -> { true } }

    in_production do
      get "/job_harbor"
    end

    assert_response :success
    assert_select ".stat-card"
  end

  test "admin allowed by a configured rule retries all failed jobs in production" do
    JobHarbor.configure { |config| config.authorize_with = -> { request.headers["X-Admin"] == "yes" } }

    in_production do
      assert_difference -> { SolidQueue::FailedExecution.count } => -1 do
        post "/job_harbor/jobs/retry_all", params: { status: "failed" }, headers: { "X-Admin" => "yes" }
      end
    end

    assert_not SolidQueue::FailedExecution.exists?(job_id: @failed.id)
  end

  test "clearing authorize_with falls back to the unconfigured default" do
    JobHarbor.configure { |config| config.authorize_with = -> { true } }
    JobHarbor.configure { |config| config.authorize_with = nil }

    in_production { get "/job_harbor" }

    assert_response :forbidden
  end

  test "rule that redirects the visitor itself and returns false gets its own redirect, not a 500" do
    JobHarbor.configure do |config|
      config.authorize_with = -> {
        redirect_to "/elsewhere"
        false
      }
    end

    assert_no_difference -> { SolidQueue::ReadyExecution.count } do
      post "/job_harbor/jobs/retry_all", params: { status: "failed" }
    end

    assert_redirected_to "/elsewhere"
    assert SolidQueue::FailedExecution.exists?(job_id: @failed.id)
  end

  test "rule sending an unauthenticated visitor to the host login page works through main_app" do
    Rails.application.routes.draw do
      resource :session, only: :new
      mount JobHarbor::Engine => "/job_harbor"
    end
    JobHarbor.configure do |config|
      config.authorize_with = -> { redirect_to(main_app.new_session_path) && false }
    end

    get "/job_harbor"

    assert_redirected_to "/session/new"
  end

  test "rule using a bare host route helper inside the engine fails, which is why the README says main_app" do
    Rails.application.routes.draw do
      resource :session, only: :new
      mount JobHarbor::Engine => "/job_harbor"
    end
    JobHarbor.configure do |config|
      config.authorize_with = -> { redirect_to(new_session_path) && false }
    end

    assert_raises(NoMethodError, ActionController::UrlGenerationError) { get "/job_harbor" }
  end

  test "host without a root route gets 403 rather than a 500 when access is denied" do
    JobHarbor.configure { |config| config.authorize_with = -> { false } }

    get "/job_harbor"

    assert_response :forbidden
  end

  private

  def in_production(&block) = in_environment("production", &block)

  def in_environment(name)
    original = Rails.env.to_s
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end

  def draw_host_routes_with_root
    Rails.application.routes.draw do
      root to: proc { [ 200, {}, [ "home" ] ] }
      mount JobHarbor::Engine => "/job_harbor"
    end
  end
end
