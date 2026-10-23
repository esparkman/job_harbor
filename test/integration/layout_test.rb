require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  setup { JobHarbor.reset_configuration! }
  teardown { JobHarbor.reset_configuration! }

  test "every script in the layout carries the host's CSP nonce so a strict script-src runs them" do
    with_csp_nonce("abc123") { get "/job_harbor" }

    scripts = css_select("script")
    assert_operator scripts.size, :>=, 5, "Layout should render its inline scripts"
    unnonced = scripts.reject { |tag| tag["nonce"] == "abc123" }
    assert_empty unnonced.map { |tag| tag.text.strip.lines.first }, "Inline scripts without the nonce are blocked by a strict CSP"
  end

  test "no inline style attributes anywhere in the dashboard so a strict style-src does not break the layout" do
    failed = enqueue_job(FlakyPaymentJob, 42)
    fail_job(failed, worker: register_worker(name: "worker-1"))

    [ "/job_harbor", "/job_harbor/jobs", "/job_harbor/search?q=a", "/job_harbor/jobs/#{failed.id}" ].each do |path|
      get path
      assert_response :success
      assert_select "[style]", count: 0
    end
  end

  test "the page content sits in one refresh target so auto-refresh swaps it" do
    get "/job_harbor"

    assert_select "[data-refresh-target=content]", count: 1
    assert_select "[data-refresh-target=content] .stat-card", minimum: 1
    assert_select "[data-refresh-target=content] nav.navbar", count: 0
    assert_select "[data-refresh-target=content] .sqd-refresh-select", count: 0
  end

  test "the refresh selector shows the default interval as selected" do
    get "/job_harbor"

    assert_select ".sqd-refresh-select option[selected]", count: 1
    assert_select ".sqd-refresh-select option[selected][value=?]", "30", text: "30s"
  end

  test "a configured interval that is not a standard option is still shown as selected" do
    JobHarbor.configure { |config| config.poll_interval = 10 }

    get "/job_harbor"

    assert_select ".sqd-refresh-select option[selected][value=?]", "10", text: "10s"
  end

  test "with real-time updates disabled the page has no refresh selector and no refresh script, only nonced scripts" do
    JobHarbor.configure { |config| config.enable_real_time_updates = false }

    with_csp_nonce("abc123") { get "/job_harbor" }

    assert_select ".sqd-refresh-select", count: 0
    scripts = css_select("script")
    assert_operator scripts.size, :>=, 4, "The other inline scripts should still render"
    assert scripts.none? { |tag| tag.text.include?("jh-refresh-interval") }, "The refresh script must not render when the flag is off, whatever localStorage says"
    assert scripts.all? { |tag| tag["nonce"] == "abc123" }
  end

  test "the job detail page does not auto-refresh so the operator can read and scroll the backtrace" do
    failed = enqueue_job(FlakyPaymentJob, 42)
    fail_job(failed, worker: register_worker(name: "worker-1"))

    get "/job_harbor/jobs/#{failed.id}"

    assert_select ".sqd-refresh-select", count: 0
    assert css_select("script").none? { |tag| tag.text.include?("jh-refresh-interval") }, "Job detail must not poll"
  end

  test "list pages keep the refresh selector and script" do
    get "/job_harbor/jobs"

    assert_select ".sqd-refresh-select", count: 1
    assert css_select("script").any? { |tag| tag.text.include?("jh-refresh-interval") }
  end

  test "the refresh script skips a poll while one is in flight or the operator is focused or selecting text" do
    get "/job_harbor"

    script = css_select("script").find { |tag| tag.text.include?("jh-refresh-interval") }.text
    assert_includes script, "inFlight", "Overlapping polls must be skipped"
    assert_includes script, "document.activeElement", "A focused button or link inside the content must block the swap"
    assert_includes script, "getSelection", "Selected text must block the swap"
  end

  private
    def with_csp_nonce(nonce)
      env_config = Rails.application.env_config
      keys = { "action_dispatch.content_security_policy" => ActionDispatch::ContentSecurityPolicy.new { |policy| policy.script_src :self },
               "action_dispatch.content_security_policy_nonce_generator" => ->(_request) { nonce } }
      originals = keys.keys.to_h { |key| [ key, env_config[key] ] }
      env_config.merge!(keys)
      yield
    ensure
      env_config.merge!(originals)
    end
end
