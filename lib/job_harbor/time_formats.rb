module JobHarbor
  # Prefixed so host app formats are never touched; reverse_merge! lets a host override ours.
  module TimeFormats
    FORMATS = {
      job_harbor_timestamp_with_zone: "%Y-%m-%d %H:%M:%S %Z",
      job_harbor_timestamp: "%Y-%m-%d %H:%M:%S",
      job_harbor_short: "%b %d, %H:%M:%S"
    }.freeze

    def self.register = Time::DATE_FORMATS.reverse_merge!(FORMATS)
  end
end
