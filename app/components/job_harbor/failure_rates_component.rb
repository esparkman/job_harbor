# frozen_string_literal: true

module JobHarbor
  class FailureRatesComponent < ApplicationComponent
    def initialize(stats:)
      @stats = stats
    end

    def call
      content_tag(:div, class: "card sqd-failure-rates") do
        safe_join([
          header,
          body
        ])
      end
    end

    private

    def header
      content_tag(:div, class: "card-header") do
        content_tag(:h3, "Failure Rates (24h)", class: "card-title")
      end
    end

    def body
      content_tag(:div, class: "card-content") do
        if @stats.empty?
          empty_state
        else
          stats_table
        end
      end
    end

    def empty_state
      content_tag(:p, "No jobs in the last 24 hours", class: "text-sm text-muted-foreground")
    end

    def stats_table
      content_tag(:table, class: "sqd-table sqd-failure-table") do
        safe_join([
          table_header,
          table_body
        ])
      end
    end

    def table_header
      content_tag(:thead) do
        content_tag(:tr) do
          safe_join([
            content_tag(:th, "Job Class"),
            content_tag(:th, "Total"),
            content_tag(:th, "Failed"),
            content_tag(:th, "Rate")
          ])
        end
      end
    end

    def table_body
      content_tag(:tbody) do
        safe_join(@stats.first(10).map { |stat| stat_row(stat) })
      end
    end

    def stat_row(stat)
      content_tag(:tr) do
        safe_join([
          content_tag(:td, content_tag(:code, stat[:class_name], class: "text-sm font-mono")),
          content_tag(:td, stat[:total]),
          content_tag(:td, stat[:failed]),
          content_tag(:td, rate_badge(stat[:rate]))
        ])
      end
    end

    def rate_badge(rate)
      css_class = FailureStats.rate_badge_class(rate)
      content_tag(:span, "#{rate}%", class: "badge #{css_class}")
    end
  end
end
