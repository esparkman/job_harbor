# frozen_string_literal: true

module JobHarbor
  class StatusTabsComponent < ApplicationComponent
    # status is the key of the open tab, or nil for "All"; counts is keyed "all" and by status key.
    def initialize(status:, counts:)
      @status = status
      @counts = counts
    end

    def call
      content_tag(:div, class: "flex gap-1 mb-4 flex-wrap") do
        safe_join([ all_tab, *JobStatus.all.map { |job_status| status_tab(job_status) } ])
      end
    end

    private

    def all_tab
      link_to jobs_path, class: tab_classes(selected: !@status) do
        safe_join([ "All ", count_tag("all", "ml-1 opacity-75") ])
      end
    end

    def status_tab(job_status)
      link_to public_send(job_status.path_helper), class: tab_classes(selected: @status == job_status.key) do
        safe_join([
          content_tag(:span, "", class: "circle #{job_status.circle_class}"),
          " #{job_status.label} ",
          count_tag(job_status.key, "opacity-75")
        ])
      end
    end

    def count_tag(key, css_class)
      content_tag(:span, @counts[key], class: css_class)
    end

    def tab_classes(selected:)
      "badge #{selected ? 'badge-primary' : 'badge-secondary'}"
    end
  end
end
