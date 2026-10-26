module HostFilterParametersTestHelper
  # The first request folds this list into Regexps in place, so restore the whole list rather than delete what was added.
  def with_host_filter_parameters(*extra)
    filters = Rails.application.config.filter_parameters
    original = filters.dup
    filters.concat(extra)
    yield
  ensure
    filters.replace(original)
  end
end
