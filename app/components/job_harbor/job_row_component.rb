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
        link_to @job.id, job_path(@job), class: "sqd-table-link"
      end
    end

    def class_cell
      content_tag(:td) do
        safe_join([
          content_tag(:code, @job.class_name, class: "sqd-code"),
          retry_badge_tag
        ].compact)
      end
    end

    def retry_badge_tag
      return nil unless @job.respond_to?(:retry_badge) && @job.retry_badge.present?

      content_tag(:span, @job.retry_badge, class: "sqd-retry-badge")
    end

    def queue_cell
      content_tag(:td) do
        link_to @job.queue_name, queue_path(@job.queue_name), class: "sqd-table-link"
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

      content_tag(:span, " (#{@job.running_duration})", class: "sqd-running-duration")
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
        content_tag(:span, @job.relative_created_at, class: "sqd-text-muted sqd-relative-time")
      else
        content_tag(:span, "—", class: "sqd-text-muted")
      end
    end

    def actions_cell
      content_tag(:td, class: "sqd-actions") do
        safe_join([
          retry_button,
          discard_button
        ].compact)
      end
    end

    def retry_button
      return unless @job.can_retry?

      button_to "Retry", retry_job_path(@job), method: :post, class: "sqd-btn sqd-btn-sm sqd-btn-secondary"
    end

    def discard_button
      return unless @job.can_discard?

      button_to "Discard", discard_job_path(@job), method: :delete, class: "sqd-btn sqd-btn-sm sqd-btn-danger",
        data: { confirm: "Are you sure you want to discard this job?" }
    end
  end
end
