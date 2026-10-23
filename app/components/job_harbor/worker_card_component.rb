# frozen_string_literal: true

module JobHarbor
  class WorkerCardComponent < ApplicationComponent
    def initialize(worker:)
      @worker = worker
    end

    def call
      content_tag(:div, class: "card") do
        safe_join([
          content_tag(:div, class: "card-header") do
            content_tag(:div, class: "flex items-center justify-between") do
              safe_join([
                content_tag(:div, class: "flex items-center gap-2") do
                  safe_join([
                    content_tag(:span, worker_name, class: "card-title"),
                    content_tag(:span, kind_label, class: "badge badge-secondary", data: { kind: @worker.kind })
                  ])
                end,
                content_tag(:span, render(BadgeComponent.new(status: heartbeat_status)), data: { heartbeat: true })
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

    # Solid Queue 1.7 reports supervisors as "Supervisor(fork)" or "Supervisor(async)".
    def kind_label
      @worker.kind.sub(/\(.*\)\z/, "")
    end

    def heartbeat_status
      Processes.alive?(@worker) ? :active : :stale
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

    # Workers record the queues they poll as a comma-joined string in metadata.
    def queues
      @queues ||= @worker.metadata["queues"].to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def queues_list
      return "".html_safe if queues.empty?

      content_tag(:div, class: "mt-3 flex items-center gap-1 flex-wrap") do
        safe_join([
          content_tag(:span, "Queues:", class: "text-xs text-muted-foreground"),
          queues.map { |q| content_tag(:code, q, class: "badge badge-secondary text-xs font-mono") }
        ].flatten)
      end
    end
  end
end
