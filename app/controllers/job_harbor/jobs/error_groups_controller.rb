# frozen_string_literal: true

module JobHarbor
  module Jobs
    class ErrorGroupsController < ApplicationController
      def index
        @class_name = filter_param(:class_name)
        @queue_name = filter_param(:queue_name)
        @filters = { class_name: @class_name, queue_name: @queue_name }.compact_blank

        @groups = ErrorGroup.of(JobQuery.new(status: "failed", **@filters).jobs)
        @counts = JobQuery.counts
        @filter_data = JobQuery.filter_options
        set_page_title "Failed Jobs"
      end
    end
  end
end
