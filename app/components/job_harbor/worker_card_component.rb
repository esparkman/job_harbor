# frozen_string_literal: true

module JobHarbor
  class WorkerCardComponent < ApplicationComponent
    STALE_THRESHOLD = 5.minutes

    def initialize(worker:)
      @worker = worker
    end

    def call
      content_tag(:div, class: "card") do
        safe_join([
          content_tag(:div, class: "card-header") do
            content_tag(:div, class: "flex items-center justify-between") do
              safe_join([
                content_tag(:span, worker_name, class: "card-title"),
                render(BadgeComponent.new(status: heartbeat_status))
              ])
            end
          end,
          content_tag(:div, class: "card-content") do
            safe_join([
              details,
              queues_list
            ])
          end
        ])
      end
    end

    private

    def worker_name
      @worker.name.presence || "Worker ##{@worker.id}"
    end

    def heartbeat_status
      stale? ? :blocked : :active
    end

    def stale?
      return true unless @worker.last_heartbeat_at

      @worker.last_heartbeat_at < STALE_THRESHOLD.ago
    end

    def details
      content_tag(:div, class: "space-y-1") do
        safe_join([
          info_line("Hostname", @worker.hostname),
          info_line("PID", @worker.pid),
          info_line("Last Heartbeat", heartbeat_time)
        ])
      end
    end

    def info_line(label, value)
      content_tag(:div, class: "info-line") do
        safe_join([
          content_tag(:span, label, class: "info-line-label"),
          content_tag(:span, "", class: "info-line-separator"),
          content_tag(:span, value, class: "info-line-value")
        ])
      end
    end

    def heartbeat_time
      return "Never" unless @worker.last_heartbeat_at

      time_ago_in_words(@worker.last_heartbeat_at) + " ago"
    end

    def queues_list
      return "".html_safe unless @worker.respond_to?(:queues) && @worker.queues.present?

      content_tag(:div, class: "mt-3 flex items-center gap-1 flex-wrap") do
        safe_join([
          content_tag(:span, "Queues:", class: "text-xs text-muted-foreground"),
          @worker.queues.map { |q| content_tag(:code, q, class: "badge badge-secondary text-xs font-mono") }
        ].flatten)
      end
    end
  end
end
