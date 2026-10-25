module PageTestHelper
  def assert_stat_card(label, value)
    card = css_select(".stat-card").find { |c| c.at_css(".stat-card-label").text.strip == label }
    assert card, "Operator expected a '#{label}' stat card but the page has none"
    assert_equal value.to_s, card.at_css(".stat-card-value").text.strip, "'#{label}' stat card shows the wrong number"
  end

  # The tab's whole badge text, so "Failed 1" passes and "Failed 10" does not.
  def assert_status_tab_count(status, count)
    label = status.humanize.titleize
    assert_select "a.badge[href=?]", "/job_harbor/jobs/status/#{status}", { text: /\A#{label}\s+#{count}\z/ },
      "#{label} tab should show #{count}"
  end

  def assert_info_line(label, value)
    line = css_select(".info-line").find { |l| l.at_css(".info-line-label").text.strip == label }
    assert line, "Operator expected a '#{label}' line on the job page"
    assert_equal value, line.at_css(".info-line-value").text.strip, "'#{label}' line shows the wrong value"
  end

  # The app's env_config is applied to every request, so the nonce settings have to be swapped there.
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
