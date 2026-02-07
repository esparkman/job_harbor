# frozen_string_literal: true

module JobHarbor
  class BadgeComponent < ApplicationComponent
    VALID_STATUSES = %w[pending scheduled in_progress failed finished blocked active paused].freeze

    STATUS_COLORS = {
      "pending" => "badge-sky",
      "scheduled" => "badge-yellow",
      "in_progress" => "badge-amber",
      "failed" => "badge-red",
      "finished" => "badge-green",
      "blocked" => "badge-zinc",
      "active" => "badge-green",
      "paused" => "badge-amber"
    }.freeze

    STATUS_CIRCLES = {
      "pending" => "circle-sky",
      "scheduled" => "circle-yellow",
      "in_progress" => "circle-amber",
      "failed" => "circle-red",
      "finished" => "circle-green",
      "blocked" => "circle-zinc",
      "active" => "circle-green",
      "paused" => "circle-amber"
    }.freeze

    def initialize(status:)
      @status = status.to_s.downcase
    end

    def call
      content_tag(:span, class: css_classes) do
        safe_join([
          content_tag(:span, "", class: "circle #{circle_class}"),
          display_text
        ])
      end
    end

    private

    def css_classes
      status_key = VALID_STATUSES.include?(@status) ? @status : "pending"
      "badge #{STATUS_COLORS[status_key]}"
    end

    def circle_class
      status_key = VALID_STATUSES.include?(@status) ? @status : "pending"
      STATUS_CIRCLES[status_key]
    end

    def display_text
      @status.titleize.gsub("_", " ")
    end
  end
end
