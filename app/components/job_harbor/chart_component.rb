# frozen_string_literal: true

module JobHarbor
  class ChartComponent < ApplicationComponent
    def initialize(series:, current_range:)
      @series = series
      @current_range = current_range
    end

    def call
      content_tag(:div, class: "card") do
        safe_join([
          header,
          body
        ])
      end
    end

    private

    def header
      content_tag(:div, class: "card-header") do
        content_tag(:div, class: "flex items-center justify-between") do
          safe_join([
            content_tag(:h3, "Job Activity", class: "card-title"),
            range_selector
          ])
        end
      end
    end

    def range_selector
      content_tag(:div, class: "sqd-chart-ranges flex gap-1") do
        safe_join(ChartData.available_ranges.map { |range| range_button(range) })
      end
    end

    def range_button(range)
      active = range[:value] == @current_range
      css_class = active ? "btn btn-default btn-xs" : "btn btn-secondary btn-xs"

      link_to range[:label],
        "#{root_path}?chart_range=#{range[:value]}",
        class: css_class
    end

    def body
      content_tag(:div, class: "card-content") do
        safe_join([
          legend,
          chart_container
        ])
      end
    end

    def legend
      content_tag(:div, class: "flex gap-4 mb-3") do
        safe_join([
          legend_item("Completed", "circle-green"),
          legend_item("Failed", "circle-red"),
          legend_item("Enqueued", "circle-sky")
        ])
      end
    end

    def legend_item(label, circle_class)
      content_tag(:div, class: "flex items-center gap-1.5 text-xs") do
        safe_join([
          content_tag(:span, "", class: "circle #{circle_class}"),
          content_tag(:span, label, class: "text-muted-foreground")
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
