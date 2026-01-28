# frozen_string_literal: true

module JobHarbor
  class StatCardComponent < ApplicationComponent
    ICONS = {
      pending: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>',
      scheduled: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>',
      in_progress: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>',
      failed: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>',
      finished: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>',
      blocked: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/>',
      workers: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>',
      queues: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',
      throughput: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>'
    }.freeze

    COLORS = {
      pending: "info",
      scheduled: "warning",
      in_progress: "info",
      failed: "danger",
      finished: "success",
      blocked: nil,
      workers: "success",
      queues: "info",
      throughput: "success"
    }.freeze

    def initialize(label:, value:, type: nil, link: nil)
      @label = label
      @value = value
      @type = type&.to_sym
      @link = link
    end

    def call
      content_tag(:div, class: "sqd-stat-card") do
        safe_join([
          header,
          value_display
        ])
      end
    end

    private

    def header
      content_tag(:div, class: "sqd-stat-header") do
        safe_join([
          content_tag(:span, @label, class: "sqd-stat-label"),
          icon_svg
        ])
      end
    end

    def value_display
      color_class = COLORS[@type]
      classes = [ "sqd-stat-value" ]
      classes << color_class if color_class

      if @link
        link_to @value, @link, class: classes.join(" ")
      else
        content_tag(:span, @value, class: classes.join(" "))
      end
    end

    def icon_svg
      return "" unless @type

      icon_path = ICONS[@type]
      return "" unless icon_path

      content_tag(:svg, icon_path.html_safe, class: "sqd-stat-icon", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor")
    end
  end
end
