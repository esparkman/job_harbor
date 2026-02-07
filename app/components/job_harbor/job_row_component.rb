# frozen_string_literal: true

module JobHarbor
  class JobRowComponent < ApplicationComponent
    def initialize(job:)
      @job = job
    end

    def call
      content_tag(:tr) do
        safe_join([
          id_cell,
          class_cell,
          queue_cell,
          status_cell,
          scheduled_cell,
          actions_cell
        ])
      end
    end

    private

    def id_cell
      content_tag(:td) do
        link_to @job.id, job_path(@job), class: "link font-medium"
      end
    end

    def class_cell
      content_tag(:td) do
        safe_join([
          content_tag(:code, @job.class_name, class: "text-sm font-mono"),
          retry_badge_tag
        ].compact)
      end
    end

    def retry_badge_tag
      return nil unless @job.respond_to?(:retry_badge) && @job.retry_badge.present?

      content_tag(:span, @job.retry_badge, class: "sqd-retry-badge ml-1")
    end

    def queue_cell
      content_tag(:td) do
        link_to @job.queue_name, queue_path(@job.queue_name), class: "link"
      end
    end

    def status_cell
      content_tag(:td) do
        safe_join([
          render(BadgeComponent.new(status: @job.status)),
          running_duration_tag
        ].compact)
      end
    end

    def running_duration_tag
      return nil unless @job.respond_to?(:running_duration) && @job.running_duration.present?

      content_tag(:span, " (#{@job.running_duration})", class: "text-xs text-sky-500")
    end

    def scheduled_cell
      content_tag(:td) do
        if @job.scheduled_at
          time_tag(@job.scheduled_at, @job.scheduled_at.strftime("%b %d, %H:%M:%S"))
        else
          relative_time_tag
        end
      end
    end

    def relative_time_tag
      if @job.respond_to?(:relative_created_at)
        content_tag(:span, @job.relative_created_at, class: "text-xs text-muted-foreground")
      else
        content_tag(:span, "\u2014", class: "text-muted-foreground")
      end
    end

    def actions_cell
      content_tag(:td) do
        content_tag(:div, class: "flex items-center gap-1") do
          safe_join([
            retry_button,
            discard_button
          ].compact)
        end
      end
    end

    def retry_button
      return unless @job.can_retry?

      button_to "Retry", retry_job_path(@job), method: :post, class: "btn btn-secondary btn-xs"
    end

    def discard_button
      return unless @job.can_discard?

      button_to "Discard", discard_job_path(@job), method: :delete, class: "btn btn-destructive btn-xs",
        data: { confirm: "Are you sure you want to discard this job?" }
    end
  end
end
