# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class ChartDataTest < ActiveSupport::TestCase
    test "available_ranges returns valid time ranges" do
      ranges = ChartData.available_ranges
      assert_includes ranges.map { |r| r[:value] }, "15m"
      assert_includes ranges.map { |r| r[:value] }, "1h"
      assert_includes ranges.map { |r| r[:value] }, "6h"
      assert_includes ranges.map { |r| r[:value] }, "24h"
      assert_includes ranges.map { |r| r[:value] }, "7d"
    end

    test "responds to series method" do
      chart = ChartData.new(range: "1h")
      assert_respond_to chart, :series
    end

    test "parses range correctly" do
      chart = ChartData.new(range: "24h")
      assert_respond_to chart, :series
    end
  end
end
