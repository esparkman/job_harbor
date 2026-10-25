# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class StatusTabsComponentTest < ViewComponentTestCase
    COUNTS = { "all" => 12, "pending" => 3, "scheduled" => 1, "in_progress" => 2, "failed" => 4, "blocked" => 0, "finished" => 5 }.freeze

    test "operator sees an All tab and one tab per job status, each with its count, in display order" do
      render_inline(StatusTabsComponent.new(status: nil, counts: COUNTS))

      tabs = fragment.css("a.badge").map { |tab| [ tab["href"], tab.text.squish ] }
      assert_equal [
        [ "/job_harbor/jobs", "All 12" ],
        [ "/job_harbor/jobs/status/pending", "Pending 3" ],
        [ "/job_harbor/jobs/status/scheduled", "Scheduled 1" ],
        [ "/job_harbor/jobs/status/in_progress", "In Progress 2" ],
        [ "/job_harbor/jobs/status/failed", "Failed 4" ],
        [ "/job_harbor/jobs/status/blocked", "Blocked 0" ],
        [ "/job_harbor/jobs/status/finished", "Finished 5" ]
      ], tabs
    end

    test "every status tab carries the colour dot its badge uses" do
      render_inline(StatusTabsComponent.new(status: nil, counts: COUNTS))

      dots = fragment.css("a.badge .circle").map { |dot| dot["class"] }
      assert_equal JobStatus.all.map { |status| "circle #{status.circle_class}" }, dots
    end

    test "the All tab is the highlighted one when no status is open" do
      render_inline(StatusTabsComponent.new(status: nil, counts: COUNTS))

      assert_highlighted "/job_harbor/jobs", true
      JobStatus.all.each { |status| assert_highlighted "/job_harbor/jobs/status/#{status.key}", false }
    end

    test "only the open status tab is highlighted" do
      render_inline(StatusTabsComponent.new(status: "in_progress", counts: COUNTS))

      assert_highlighted "/job_harbor/jobs", false
      assert_highlighted "/job_harbor/jobs/status/in_progress", true
      assert_highlighted "/job_harbor/jobs/status/failed", false
    end

    private

    def assert_highlighted(href, highlighted)
      tab = fragment.at_css("a[href='#{href}']")
      assert tab, "expected a tab linking to #{href}"
      classes = tab["class"].split
      assert_equal highlighted, classes.include?("badge-primary"), "#{href} highlighted state is wrong"
      assert_equal !highlighted, classes.include?("badge-secondary"), "#{href} muted state is wrong"
    end
  end
end
