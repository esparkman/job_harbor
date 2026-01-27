# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class FailureStatsTest < ActiveSupport::TestCase
    test "stats returns empty array when no jobs" do
      stats = FailureStats.new
      assert_respond_to stats, :stats
    end

    test "rate_badge_class returns green for low rates" do
      assert_equal "sqd-rate-low", FailureStats.rate_badge_class(3.5)
    end

    test "rate_badge_class returns yellow for medium rates" do
      assert_equal "sqd-rate-medium", FailureStats.rate_badge_class(12.0)
    end

    test "rate_badge_class returns red for high rates" do
      assert_equal "sqd-rate-high", FailureStats.rate_badge_class(25.0)
    end
  end
end
