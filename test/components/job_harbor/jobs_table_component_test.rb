# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobsTableComponentTest < ViewComponentTestCase
    MockJob = Struct.new(:id, :class_name, :queue_name, :status, :scheduled_at, :created_at,
                         :can_retry?, :can_discard?, :execution_count, :retry_badge,
                         :running_duration, :relative_created_at)

    test "operator sees the six job columns in order" do
      render_inline(JobsTableComponent.new(jobs: [ mock_job(id: 1) ]))

      headers = Nokogiri::HTML.fragment(@rendered).css("thead th").map(&:text)
      assert_equal [ "ID", "Job Class", "Queue", "Status", "Scheduled At", "Actions" ], headers
    end

    test "operator sees one row per job" do
      render_inline(JobsTableComponent.new(jobs: [ mock_job(id: 1, class_name: "AlphaJob"), mock_job(id: 2, class_name: "BetaJob") ]))

      rows = Nokogiri::HTML.fragment(@rendered).css("tbody tr")
      assert_equal 2, rows.size
      assert_includes @rendered, "AlphaJob"
      assert_includes @rendered, "BetaJob"
    end

    test "table sits in a plain card with no heading by default" do
      render_inline(JobsTableComponent.new(jobs: [ mock_job ]))

      doc = Nokogiri::HTML.fragment(@rendered)
      assert doc.at_css("div.card > div.table-wrapper > table.sqd-table"), "expected the table inside a plain card"
      assert_nil doc.at_css(".card-header")
    end

    test "operator sees the card heading when a title is given" do
      render_inline(JobsTableComponent.new(jobs: [ mock_job ], title: "Jobs in Queue"))

      assert_includes @rendered, '<div class="card-header">'
      assert_includes @rendered, '<h2 class="card-title">Jobs in Queue</h2>'
    end

    private

    def mock_job(overrides = {})
      defaults = {
        id: 1, class_name: "TestJob", queue_name: "default", status: "pending", scheduled_at: nil,
        created_at: 5.minutes.ago, can_retry?: false, can_discard?: true, execution_count: 1,
        retry_badge: nil, running_duration: nil, relative_created_at: "5 minutes ago"
      }
      MockJob.new(**defaults.merge(overrides))
    end
  end
end
