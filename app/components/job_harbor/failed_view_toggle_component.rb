# frozen_string_literal: true

module JobHarbor
  class FailedViewToggleComponent < ApplicationComponent
    def initialize(grouped:, filters:, error_class: nil)
      @grouped = grouped
      @filters = filters
      @error_class = error_class.presence
    end

    def call
      content_tag(:div, class: "flex flex-wrap items-center gap-2 mb-4") do
        safe_join([
          link_to("List", failed_jobs_path(@filters), class: tab_classes(selected: !@grouped)),
          link_to("Grouped", failed_job_groups_path(@filters), class: tab_classes(selected: @grouped)),
          error_class_note
        ])
      end
    end

    private

    def error_class_note
      return unless @error_class

      content_tag(:span, class: "text-sm text-muted-foreground") do
        safe_join([ "Only ", content_tag(:code, @error_class, class: "font-mono"), " failures · ",
          link_to("Show all", failed_jobs_path(@filters), class: "link") ])
      end
    end

    def tab_classes(selected:)
      "btn btn-sm #{selected ? 'btn-default' : 'btn-secondary'}"
    end
  end
end
