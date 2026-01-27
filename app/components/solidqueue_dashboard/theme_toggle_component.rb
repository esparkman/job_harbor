# frozen_string_literal: true

module SolidqueueDashboard
  class ThemeToggleComponent < ApplicationComponent
    SUN_ICON = '<circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>'
    MOON_ICON = '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>'

    def call
      content_tag(:button,
        class: "sqd-theme-toggle",
        type: "button",
        aria: { label: "Toggle theme" },
        data: { action: "click->theme-toggle#toggle" }
      ) do
        safe_join([
          sun_icon,
          moon_icon
        ])
      end
    end

    private

    def sun_icon
      content_tag(:svg, SUN_ICON.html_safe,
        class: "sqd-theme-icon sqd-theme-icon-sun",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        "stroke-width": "2",
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      )
    end

    def moon_icon
      content_tag(:svg, MOON_ICON.html_safe,
        class: "sqd-theme-icon sqd-theme-icon-moon",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        "stroke-width": "2",
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      )
    end
  end
end
