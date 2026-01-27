# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class FailureRatesComponentTest < ViewComponentTestCase
    test "renders failure rates table" do
      stats = [
        { class_name: "TestJob", total: 100, failed: 5, rate: 5.0 },
        { class_name: "OtherJob", total: 50, failed: 0, rate: 0.0 }
      ]

      render_inline(FailureRatesComponent.new(stats: stats))

      assert_includes @rendered, "sqd-failure-rates"
      assert_includes @rendered, "TestJob"
      assert_includes @rendered, "OtherJob"
    end

    test "shows rate badges with correct colors" do
      stats = [
        { class_name: "LowFailJob", total: 100, failed: 2, rate: 2.0 },
        { class_name: "MedFailJob", total: 100, failed: 10, rate: 10.0 },
        { class_name: "HighFailJob", total: 100, failed: 30, rate: 30.0 }
      ]

      render_inline(FailureRatesComponent.new(stats: stats))

      assert_includes @rendered, "sqd-rate-low"
      assert_includes @rendered, "sqd-rate-medium"
      assert_includes @rendered, "sqd-rate-high"
    end

    test "renders empty state when no stats" do
      render_inline(FailureRatesComponent.new(stats: []))

      assert_includes @rendered, "No jobs"
    end
  end
end
