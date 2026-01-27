# frozen_string_literal: true

module SolidqueueDashboard
  class JobFiltersComponent < ApplicationComponent
    def initialize(class_names:, queue_names:, current_class:, current_queue:, current_path:, params: {})
      @class_names = class_names
      @queue_names = queue_names
      @current_class = current_class
      @current_queue = current_queue
      @current_path = current_path
      @params = params.to_h.symbolize_keys.except(:class_name, :queue_name, :page, :controller, :action)
    end

    def call
      content_tag(:div, class: "sqd-filters") do
        safe_join([
          class_filter,
          queue_filter
        ])
      end
    end

    private

    def class_filter
      content_tag(:div, class: "sqd-filter-group") do
        safe_join([
          content_tag(:label, "Class", class: "sqd-filter-label", for: "class_filter"),
          content_tag(:select,
            class: "sqd-filter-select",
            id: "class_filter",
            data: { filter_type: "class_name" }
          ) do
            safe_join([
              class_option_tag("All Classes", "", @current_class.blank?),
              *@class_names.map { |name| class_option_tag(name, name, name == @current_class) }
            ])
          end
        ])
      end
    end

    def queue_filter
      content_tag(:div, class: "sqd-filter-group") do
        safe_join([
          content_tag(:label, "Queue", class: "sqd-filter-label", for: "queue_filter"),
          content_tag(:select,
            class: "sqd-filter-select",
            id: "queue_filter",
            data: { filter_type: "queue_name" }
          ) do
            safe_join([
              queue_option_tag("All Queues", "", @current_queue.blank?),
              *@queue_names.map { |name| queue_option_tag(name, name, name == @current_queue) }
            ])
          end
        ])
      end
    end

    def class_option_tag(label, value, selected)
      url = build_filter_url(:class_name, value)
      content_tag(:option, label, value: url, selected: selected)
    end

    def queue_option_tag(label, value, selected)
      url = build_filter_url(:queue_name, value)
      content_tag(:option, label, value: url, selected: selected)
    end

    def build_filter_url(filter_key, value)
      query_params = @params.dup

      # Preserve the other filter if set
      query_params[:class_name] = @current_class if @current_class.present? && filter_key != :class_name
      query_params[:queue_name] = @current_queue if @current_queue.present? && filter_key != :queue_name

      # Set the new filter value
      if value.present?
        query_params[filter_key] = value
      else
        query_params.delete(filter_key)
      end

      if query_params.empty?
        @current_path
      else
        "#{@current_path}?#{query_params.to_query}"
      end
    end
  end
end
