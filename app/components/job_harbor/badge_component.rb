# frozen_string_literal: true

module JobHarbor
  class BadgeComponent < ApplicationComponent
    # Statuses that belong to workers and queues rather than jobs.
    OTHER_COLORS = {
      "active" => "green",
      "paused" => "amber",
      "stale" => "zinc"
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
      "badge badge-#{color}"
    end

    def circle_class
      "circle-#{color}"
    end

    # Anything unrecognised renders as the first job status.
    def color
      JobStatus.find(@status)&.color || OTHER_COLORS.fetch(@status) { JobStatus.all.first.color }
    end

    def display_text
      @status.titleize.gsub("_", " ")
    end
  end
end
