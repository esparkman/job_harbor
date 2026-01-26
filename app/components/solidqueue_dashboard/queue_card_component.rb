# frozen_string_literal: true

module SolidqueueDashboard
  class QueueCardComponent < ApplicationComponent
    def initialize(queue:)
      @queue = queue
    end

    def call
      content_tag(:div, class: "sqd-queue-card") do
        safe_join([
          header,
          stats,
          actions
        ])
      end
    end

    private

    def header
      content_tag(:div, class: "sqd-queue-header") do
        safe_join([
          link_to(@queue.name, queue_path(@queue.name), class: "sqd-queue-name"),
          render(BadgeComponent.new(status: @queue.paused? ? :paused : :active))
        ])
      end
    end

    def stats
      content_tag(:div, class: "sqd-queue-stats") do
        safe_join([
          stat("Pending", @queue.pending_count),
          stat("Scheduled", @queue.scheduled_count),
          stat("In Progress", @queue.in_progress_count)
        ])
      end
    end

    def stat(label, value)
      content_tag(:div, class: "sqd-queue-stat") do
        safe_join([
          content_tag(:span, value, class: "sqd-queue-stat-value"),
          content_tag(:span, label, class: "sqd-queue-stat-label")
        ])
      end
    end

    def actions
      content_tag(:div, class: "sqd-actions", style: "margin-top: 1rem;") do
        if @queue.paused?
          button_to "Resume", resume_queue_path(@queue.name), method: :delete, class: "sqd-btn sqd-btn-sm sqd-btn-primary"
        else
          button_to "Pause", pause_queue_path(@queue.name), method: :post, class: "sqd-btn sqd-btn-sm sqd-btn-secondary"
        end
      end
    end
  end
end
