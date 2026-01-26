# frozen_string_literal: true

module SolidqueueDashboard
  class BadgeComponent < ApplicationComponent
    VALID_STATUSES = %w[pending scheduled in_progress failed finished blocked active paused].freeze

    def initialize(status:)
      @status = status.to_s.downcase
    end

    def call
      content_tag(:span, display_text, class: css_classes)
    end

    private

    def css_classes
      status_class = VALID_STATUSES.include?(@status) ? @status : "pending"
      "sqd-badge sqd-badge-#{status_class}"
    end

    def display_text
      @status.titleize.gsub("_", " ")
    end
  end
end
