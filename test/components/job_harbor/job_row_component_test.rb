# frozen_string_literal: true

require "test_helper"

module JobHarbor
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

    test "discard and retry forms carry the page the operator is on as their return path" do
      job = mock_job_presenter(can_retry?: true)
      render_inline(JobRowComponent.new(job: job, return_to: "/job_harbor/jobs/status/failed?class_name=TestJob"))

      forms = Nokogiri::HTML.fragment(@rendered).css("form")
      assert_equal 2, forms.size
      forms.each do |form|
        assert_equal "/job_harbor/jobs/status/failed?class_name=TestJob", form.at_css("input[name=return_to]")["value"]
      end
    end

    MockJobPresenter = Struct.new(:id, :class_name, :queue_name, :status, :scheduled_at, :created_at,
                                  :can_retry?, :can_discard?, :execution_count, :retry_badge,
                                  :running_duration, :relative_created_at)

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
      MockJobPresenter.new(**defaults.merge(overrides))
    end
  end
end
