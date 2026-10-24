# frozen_string_literal: true

module JobHarbor
  class StatCardComponent < ApplicationComponent
    # Cards that are not about a job status.
    OTHER_COLORS = {
      workers: "green",
      queues: "sky",
      throughput: "green"
    }.freeze

    def initialize(label:, value:, type: nil, link: nil)
      @label = label
      @value = value
      @type = type&.to_sym
      @link = link
    end

    def call
      tag = @link ? :a : :div
      opts = { class: "stat-card" }
      opts[:href] = @link if @link

      content_tag(tag, **opts) do
        safe_join([
          label_display,
          value_display
        ])
      end
    end

    private

    def label_display
      content_tag(:div, class: "stat-card-label") do
        safe_join([
          circle_indicator,
          content_tag(:span, @label)
        ].compact)
      end
    end

    def circle_indicator
      return nil unless @type

      color = JobStatus.find(@type)&.color || OTHER_COLORS[@type]
      return nil unless color

      content_tag(:span, "", class: "circle circle-#{color}")
    end

    def value_display
      content_tag(:div, @value, class: "stat-card-value")
    end
  end
end
