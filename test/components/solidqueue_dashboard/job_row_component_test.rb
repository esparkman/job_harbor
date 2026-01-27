# frozen_string_literal: true

require "test_helper"
require "ostruct"

module SolidqueueDashboard
  class JobRowComponentTest < ViewComponentTestCase
    test "renders job row with basic info" do
      job = mock_job_presenter
      render_inline(JobRowComponent.new(job: job))

      assert_includes @rendered, "TestJob"
      assert_includes @rendered, "default"
    end

    test "renders retry badge when execution_count > 1" do
      job = mock_job_presenter(execution_count: 3, retry_badge: "(x3)")
      render_inline(JobRowComponent.new(job: job))

      assert_includes @rendered, "(x3)"
      assert_includes @rendered, "sqd-retry-badge"
    end

    test "does not render retry badge when execution_count is 1" do
      job = mock_job_presenter(execution_count: 1, retry_badge: nil)
      render_inline(JobRowComponent.new(job: job))

      refute_includes @rendered, "sqd-retry-badge"
    end

    test "renders relative timestamp" do
      job = mock_job_presenter(relative_created_at: "5 minutes ago")
      render_inline(JobRowComponent.new(job: job))

      assert_includes @rendered, "5 minutes ago"
    end

    private

    def mock_job_presenter(overrides = {})
      defaults = {
        id: 1,
        class_name: "TestJob",
        queue_name: "default",
        status: "pending",
        scheduled_at: nil,
        created_at: 5.minutes.ago,
        can_retry?: false,
        can_discard?: true,
        execution_count: 1,
        retry_badge: nil,
        running_duration: nil,
        relative_created_at: "5 minutes ago"
      }
      OpenStruct.new(defaults.merge(overrides))
    end
  end
end
