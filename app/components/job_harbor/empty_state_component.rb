# frozen_string_literal: true

module JobHarbor
  class EmptyStateComponent < ApplicationComponent
    ICONS = {
      jobs: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>',
      queues: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',
      workers: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>',
      search: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>',
      recurring: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>'
    }.freeze

    def initialize(title:, description: nil, icon: :jobs)
      @title = title
      @description = description
      @icon = icon.to_sym
    end

    def call
      content_tag(:div, class: "text-center py-12") do
        safe_join([
          icon_svg,
          content_tag(:h3, @title, class: "text-lg font-semibold mt-4"),
          description_tag
        ].compact)
      end
    end

    private

    def icon_svg
      icon_path = ICONS[@icon] || ICONS[:jobs]
      content_tag(:svg, icon_path.html_safe,
        class: "w-12 h-12 mx-auto text-muted-foreground",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor"
      )
    end

    def description_tag
      return unless @description

      content_tag(:p, @description, class: "text-sm text-muted-foreground mt-1")
    end
  end
end
