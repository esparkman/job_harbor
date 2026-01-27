# frozen_string_literal: true

module SolidqueueDashboard
  class PerPageSelectorComponent < ApplicationComponent
    PAGE_SIZES = [ 10, 25, 50, 100 ].freeze

    def initialize(current_per_page:, current_path:, params: {})
      @current_per_page = current_per_page.to_i
      @current_path = current_path
      @params = params.to_h.symbolize_keys.except(:per_page, :page, :controller, :action)
    end

    def call
      content_tag(:div, class: "sqd-per-page-selector") do
        safe_join([
          content_tag(:span, "Show", class: "sqd-per-page-label"),
          content_tag(:select,
            class: "sqd-per-page-select",
            data: { action: "change->per-page#change" }
          ) do
            safe_join(PAGE_SIZES.map { |size| option_tag(size) })
          end
        ])
      end
    end

    private

    def option_tag(size)
      url = build_url(size)
      selected = size == @current_per_page
      content_tag(:option, size, value: url, selected: selected)
    end

    def build_url(per_page)
      query_params = @params.merge(per_page: per_page)
      "#{@current_path}?#{query_params.to_query}"
    end
  end
end
