# frozen_string_literal: true

require "test_helper"

module JobHarbor
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

    test "range buttons link to the dashboard with their range and highlight the current one" do
      series = { labels: [ "10:00" ], completed: [ 10 ], failed: [ 1 ], enqueued: [ 15 ] }

      render_inline(ChartComponent.new(series: series, current_range: "6h"))

      assert_match(%r{href="[^"]*\?chart_range=7d"}, @rendered)
      assert_match(%r{class="btn btn-default btn-xs" href="[^"]*chart_range=6h">6 hours}, @rendered)
      assert_match(%r{class="btn btn-secondary btn-xs" href="[^"]*chart_range=24h">24 hours}, @rendered)
    end

    test "the chart is handed the series it should draw as JSON" do
      series = {
        labels: [ "10:00", "11:00" ],
        completed: [ 10, 20 ],
        failed: [ 1, 0 ],
        enqueued: [ 15, 25 ]
      }

      render_inline(ChartComponent.new(series: series, current_range: "24h"))

      chart_data = Nokogiri::HTML.fragment(@rendered).at_css(".sqd-chart")["data-chart-data"]
      assert_equal series.stringify_keys, JSON.parse(chart_data)
    end
  end
end
