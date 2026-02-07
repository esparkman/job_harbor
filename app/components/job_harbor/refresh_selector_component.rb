# frozen_string_literal: true

module JobHarbor
  class RefreshSelectorComponent < ApplicationComponent
    INTERVALS = [
      { label: "Off", value: 0 },
      { label: "15s", value: 15 },
      { label: "30s", value: 30 },
      { label: "1m", value: 60 },
      { label: "5m", value: 300 }
    ].freeze

    REFRESH_ICON = '<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>'

    def initialize(default_interval: nil)
      @default_interval = default_interval || sq_config.poll_interval
    end

    def call
      content_tag(:div, class: "sqd-refresh-selector flex items-center gap-1.5") do
        safe_join([
          refresh_icon,
          interval_select
        ])
      end
    end

    private

    def refresh_icon
      content_tag(:svg, REFRESH_ICON.html_safe,
        class: "w-3.5 h-3.5 text-muted-foreground",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        "stroke-width": "2",
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      )
    end

    def interval_select
      content_tag(:select,
        class: "sqd-refresh-select select",
        style: "width: 5rem;",
        data: { action: "change->refresh-selector#change" },
        "aria-label": "Auto-refresh interval"
      ) do
        safe_join(INTERVALS.map { |interval| option_tag(interval) })
      end
    end

    def option_tag(interval)
      selected = interval[:value] == @default_interval
      content_tag(:option, interval[:label], value: interval[:value], selected: selected)
    end
  end
end
