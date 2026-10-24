# frozen_string_literal: true

module JobHarbor
  class JobSearchFormComponent < ApplicationComponent
    def initialize(query: nil)
      @query = query
    end
  end
end
