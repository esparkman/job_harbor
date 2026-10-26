module HostFilterParametersTestHelper
  # The first request precompiles this list in place, so delete(:added) can miss; restore the whole list.
  def with_host_filter_parameters(*extra)
    filters = Rails.application.config.filter_parameters
    original = filters.dup
    filters.concat(extra)
    yield
  ensure
    filters.replace(original) if original
  end
end
