# frozen_string_literal: true

module JobHarbor
  class JobQuery
    LIKE_ESCAPE = "!"
    UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    class << self
      def search(text)
        new(search: text)
      end

      def filter_options
        {
          class_names: SolidQueue::Job.distinct.pluck(:class_name).sort,
          queue_names: SolidQueue::Job.distinct.pluck(:queue_name).sort
        }
      end

      def counts
        { "all" => SolidQueue::Job.count }.merge(JobStatus.all.to_h { |job_status| [ job_status.key, job_status.count ] })
      end
    end

    def initialize(status: nil, class_name: nil, queue_name: nil, search: nil)
      @status = status
      @class_name = class_name
      @queue_name = queue_name
      @search = search
    end

    def jobs
      filtered(status_scope)
    end

    # Nil for tabs without bulk actions.
    def bulk_jobs
      job_status = JobStatus.find(@status)
      return unless job_status&.bulk_actions

      filtered(SolidQueue::Job.where(id: job_status.execution_class.select(:job_id)))
    end

    def page(number, per_page:)
      scope = jobs
      total = scope.count
      pages = (total.to_f / per_page).ceil
      current = [ [ number.to_i, 1 ].max, [ pages, 1 ].max ].min
      offset = (current - 1) * per_page

      presenters = scope.preload(*JobStatus.execution_associations).order(id: :desc).limit(per_page).offset(offset).map { |job| JobPresenter.new(job) }
      [ PageInfo.new(page: current, per_page: per_page, count: total), presenters ]
    end

    private

    def status_scope
      JobStatus.find(@status)&.jobs || SolidQueue::Job.all
    end

    def filtered(scope)
      scope = scope.where(class_name: @class_name) if @class_name.present?
      scope = scope.where(queue_name: @queue_name) if @queue_name.present?
      scope = scope.merge(matching_search) if @search.present?
      scope
    end

    def matching_search
      jobs = SolidQueue::Job
      pattern = "%#{jobs.sanitize_sql_like(@search, LIKE_ESCAPE)}%"
      scope = jobs.where("LOWER(class_name) LIKE LOWER(:pattern) ESCAPE :escape", pattern: pattern, escape: LIKE_ESCAPE)
      # Matching argument text would let a search reveal values the page masks.
      unless JobHarbor.configuration.filtering_parameters?
        scope = scope.or(jobs.where("LOWER(arguments) LIKE LOWER(:pattern) ESCAPE :escape", pattern: pattern, escape: LIKE_ESCAPE))
      end
      scope = scope.or(jobs.where(id: @search)) if @search.match?(/\A\d+\z/)
      scope = scope.or(jobs.where(active_job_id: @search)) if @search.match?(UUID_FORMAT)
      scope
    end
  end
end
