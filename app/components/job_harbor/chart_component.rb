# frozen_string_literal: true

module JobHarbor
  class ChartComponent < ApplicationComponent
    def initialize(series:, current_range:)
      @series = series
      @current_range = current_range
    end

    def call
      content_tag(:div, class: "sqd-card sqd-chart-card") do
        safe_join([
          header,
          body
        ])
      end
    end

    private

    def header
      content_tag(:div, class: "sqd-card-header sqd-chart-header") do
        safe_join([
          content_tag(:h3, "Job Activity", class: "sqd-card-title"),
          range_selector
        ])
      end
    end

    def range_selector
      content_tag(:div, class: "sqd-chart-ranges") do
        safe_join(ChartData.available_ranges.map { |range| range_button(range) })
      end
    end

    def range_button(range)
      active = range[:value] == @current_range
      css_class = "sqd-chart-range-btn#{' active' if active}"

      link_to range[:label],
        "#{root_path}?chart_range=#{range[:value]}",
        class: css_class
    end

    def body
      content_tag(:div, class: "sqd-card-body") do
        safe_join([
          legend,
          chart_container
        ])
      end
    end

    def legend
      content_tag(:div, class: "sqd-chart-legend") do
        safe_join([
          legend_item("Completed", "sqd-chart-completed"),
          legend_item("Failed", "sqd-chart-failed"),
          legend_item("Enqueued", "sqd-chart-enqueued")
        ])
      end
    end

    def legend_item(label, css_class)
      content_tag(:div, class: "sqd-legend-item") do
        safe_join([
          content_tag(:span, "", class: "sqd-legend-color #{css_class}"),
          content_tag(:span, label, class: "sqd-legend-label")
        ])
      end
    end

    def chart_container
      content_tag(:div,
        class: "sqd-chart",
        data: { chart_data: @series.to_json }
      ) do
        content_tag(:canvas, "", id: "sqd-job-chart", width: "100%", height: "200")
      end
    end
  end
end
