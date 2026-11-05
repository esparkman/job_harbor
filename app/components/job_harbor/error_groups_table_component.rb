# frozen_string_literal: true

module JobHarbor
  class ErrorGroupsTableComponent < ApplicationComponent
    def initialize(groups:, filters:)
      @groups = groups
      @filters = filters
    end

    def call
      content_tag(:div, class: "card") do
        content_tag(:div, class: "table-wrapper") do
          content_tag(:table, class: "sqd-table sqd-error-groups") do
            safe_join([ header, content_tag(:tbody, safe_join(@groups.map { |group| row(group) })) ])
          end
        end
      end
    end

    private

    def header
      content_tag(:thead) do
        content_tag(:tr, safe_join([ "Exception", "Failures", "First Seen", "Last Seen", "Latest Message", "Actions" ].map { |label| content_tag(:th, label) }))
      end
    end

    def row(group)
      content_tag(:tr) do
        safe_join([
          content_tag(:td, content_tag(:code, group.exception_class, class: "text-sm font-mono")),
          content_tag(:td, group.count, class: "font-medium"),
          content_tag(:td, group.first_seen_at.to_fs(:job_harbor_short), class: "text-sm"),
          content_tag(:td, group.last_seen_at.to_fs(:job_harbor_short), class: "text-sm"),
          content_tag(:td, truncate(group.latest_failure.error_message.to_s, length: 80), class: "text-sm"),
          content_tag(:td, actions(group))
        ])
      end
    end

    def actions(group)
      group_params = { status: "failed", **@filters, error_class: group.exception_class }
      jobs_label = pluralize(group.count, "failed job")
      return_to = failed_job_groups_path(@filters)

      content_tag(:div, class: "flex items-center gap-2") do
        safe_join([
          link_to("View", jobs_path(group_params), class: "btn btn-secondary btn-xs"),
          button_to("Retry all", retry_all_jobs_path(group_params.merge(return_to: return_to)), method: :post,
            class: "btn btn-secondary btn-xs", form: { data: { confirm: "Retry #{jobs_label}? Automatic retry counts are not reset." } }),
          button_to("Discard all", discard_all_jobs_path(group_params.merge(return_to: return_to)), method: :delete,
            class: "btn btn-destructive btn-xs", form: { data: { confirm: "Discard #{jobs_label}? This cannot be undone." } })
        ])
      end
    end
  end
end
