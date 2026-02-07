# frozen_string_literal: true

module JobHarbor
  class QueueCardComponent < ApplicationComponent
    def initialize(queue:)
      @queue = queue
    end

    def call
      content_tag(:div, class: "card") do
        safe_join([
          content_tag(:div, class: "card-header") do
            content_tag(:div, class: "flex items-center justify-between") do
              safe_join([
                link_to(@queue.name, queue_path(@queue.name), class: "card-title link"),
                render(BadgeComponent.new(status: @queue.paused? ? :paused : :active))
              ])
            end
          end,
          content_tag(:div, class: "card-content") do
            safe_join([
              stats,
              actions
            ])
          end
        ])
      end
    end

    private

    def stats
      content_tag(:div, class: "grid grid-cols-3 gap-4 mb-4") do
        safe_join([
          stat("Pending", @queue.pending_count),
          stat("Scheduled", @queue.scheduled_count),
          stat("In Progress", @queue.in_progress_count)
        ])
      end
    end

    def stat(label, value)
      content_tag(:div, class: "text-center") do
        safe_join([
          content_tag(:div, value, class: "text-xl font-bold"),
          content_tag(:div, label, class: "text-xs text-muted-foreground uppercase tracking-wide")
        ])
      end
    end

    def actions
      if @queue.paused?
        button_to "Resume", resume_queue_path(@queue.name), method: :delete, class: "btn btn-default btn-sm w-full"
      else
        button_to "Pause", pause_queue_path(@queue.name), method: :post, class: "btn btn-secondary btn-sm w-full"
      end
    end
  end
end
