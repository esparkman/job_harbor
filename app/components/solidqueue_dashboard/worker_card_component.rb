# frozen_string_literal: true

module SolidqueueDashboard
  class WorkerCardComponent < ApplicationComponent
    STALE_THRESHOLD = 5.minutes

    def initialize(worker:)
      @worker = worker
    end

    def call
      content_tag(:div, class: "sqd-worker-card") do
        safe_join([
          header,
          details,
          queues_list
        ])
      end
    end

    private

    def header
      content_tag(:div, class: "sqd-worker-header") do
        safe_join([
          content_tag(:span, worker_name, class: "sqd-worker-name"),
          render(BadgeComponent.new(status: heartbeat_status))
        ])
      end
    end

    def worker_name
      @worker.name.presence || "Worker ##{@worker.id}"
    end

    def heartbeat_status
      if stale?
        :blocked
      else
        :active
      end
    end

    def stale?
      return true unless @worker.last_heartbeat_at

      @worker.last_heartbeat_at < STALE_THRESHOLD.ago
    end

    def details
      content_tag(:div, class: "sqd-worker-stats") do
        safe_join([
          stat("Hostname", @worker.hostname),
          stat("PID", @worker.pid),
          stat("Last Heartbeat", heartbeat_time)
        ])
      end
    end

    def stat(label, value)
      content_tag(:div, class: "sqd-worker-stat") do
        safe_join([
          content_tag(:span, value, class: "sqd-worker-stat-value"),
          content_tag(:span, label, class: "sqd-worker-stat-label")
        ])
      end
    end

    def heartbeat_time
      return "Never" unless @worker.last_heartbeat_at

      time_ago_in_words(@worker.last_heartbeat_at) + " ago"
    end

    def queues_list
      return "" unless @worker.respond_to?(:queues) && @worker.queues.present?

      content_tag(:div, style: "margin-top: 1rem;") do
        safe_join([
          content_tag(:span, "Queues: ", class: "sqd-text-muted"),
          @worker.queues.map { |q| content_tag(:code, q, class: "sqd-code", style: "margin-right: 0.5rem;") }
        ].flatten)
      end
    end
  end
end
