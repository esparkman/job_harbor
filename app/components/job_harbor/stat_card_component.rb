# frozen_string_literal: true

module JobHarbor
  class StatCardComponent < ApplicationComponent
    CIRCLE_COLORS = {
      pending: "circle-sky",
      scheduled: "circle-yellow",
      in_progress: "circle-amber",
      failed: "circle-red",
      finished: "circle-green",
      blocked: "circle-zinc",
      workers: "circle-green",
      queues: "circle-sky",
      throughput: "circle-green"
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

      circle_class = CIRCLE_COLORS[@type]
      return nil unless circle_class

      content_tag(:span, "", class: "circle #{circle_class}")
    end

    def value_display
      content_tag(:div, @value, class: "stat-card-value")
    end
  end
end
