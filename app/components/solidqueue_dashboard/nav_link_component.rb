# frozen_string_literal: true

module SolidqueueDashboard
  class NavLinkComponent < ApplicationComponent
    ICONS = {
      dashboard: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>',
      jobs: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>',
      queues: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',
      workers: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>',
      recurring: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>'
    }.freeze

    def initialize(path:, label:, icon:, active: false, badge: nil)
      @path = path
      @label = label
      @icon = icon.to_sym
      @active = active
      @badge = badge
    end

    def call
      link_to @path, class: css_classes do
        safe_join([
          icon_svg,
          content_tag(:span, @label, class: "sqd-nav-label"),
          badge_tag
        ].compact)
      end
    end

    private

    def css_classes
      classes = [ "sqd-nav-link" ]
      classes << "active" if @active
      classes.join(" ")
    end

    def icon_svg
      icon_path = ICONS[@icon] || ICONS[:dashboard]
      content_tag(:svg, icon_path.html_safe, class: "sqd-nav-icon", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor")
    end

    def badge_tag
      return nil unless @badge.present? && @badge.to_i > 0

      content_tag(:span, @badge, class: "sqd-nav-badge")
    end
  end
end
