# frozen_string_literal: true

module JobHarbor
  class JobsTableComponent < ApplicationComponent
    def initialize(jobs:, title: nil)
      @jobs = jobs
      @title = title
    end
  end
end
