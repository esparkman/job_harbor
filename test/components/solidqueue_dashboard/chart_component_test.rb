# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class ChartComponentTest < ViewComponentTestCase
    test "renders chart container" do
      series = {
        labels: [ "10:00", "11:00", "12:00" ],
        completed: [ 10, 20, 15 ],
        failed: [ 1, 0, 2 ],
        enqueued: [ 15, 25, 20 ]
      }

      render_inline(ChartComponent.new(series: series, current_range: "24h"))

      assert_includes @rendered, "sqd-chart"
      assert_includes @rendered, "canvas"
    end

    test "renders time range selector" do
      series = {
        labels: [ "10:00" ],
        completed: [ 10 ],
        failed: [ 1 ],
        enqueued: [ 15 ]
      }

      render_inline(ChartComponent.new(series: series, current_range: "24h"))

      assert_includes @rendered, "sqd-chart-ranges"
      assert_includes @rendered, "15 min"
      assert_includes @rendered, "24 hours"
    end

    test "includes chart data as JSON" do
      series = {
        labels: [ "10:00" ],
        completed: [ 10 ],
        failed: [ 1 ],
        enqueued: [ 15 ]
      }

      render_inline(ChartComponent.new(series: series, current_range: "24h"))

      assert_includes @rendered, "data-chart-data"
    end
  end
end
