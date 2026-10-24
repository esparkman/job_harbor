# frozen_string_literal: true

module JobHarbor
  # Masks sensitive values in job payloads, errors, backtraces and recurring task
  # arguments with the host app's parameter filter.
  module SensitiveValueFilter
    MASK = "[FILTERED]"

    # Active Job's own markers; a filter like :_key would otherwise mask them and break the payload's shape.
    MARKER_KEYS = %w[_aj_globalid _aj_symbol_keys _aj_ruby2_keywords _aj_hash_with_indifferent_access _aj_serialized].freeze

    # No host filter should match this, or it would mask a whole top-level array.
    ROOT_KEY = "__job_harbor_root__"

    # class << self, not module_function: the private helpers below must stay callable from the public methods.
    class << self
      # Fails closed: anything the filter can't safely handle is hidden, never shown.
      def filter(value)
        return value unless JobHarbor.configuration.filtering_parameters?
        return MASK unless value.is_a?(Hash) || value.is_a?(Array)

        restore_markers(apply(value.deep_dup), value)
      rescue StandardError
        MASK
      end

      def pretty_generate(value)
        JSON.pretty_generate(filter(value))
      end

      private

      def parameter_filter
        configured = JobHarbor.configuration.filter_parameters
        ActiveSupport::ParameterFilter.new(configured.nil? ? Rails.application.config.filter_parameters : configured)
      end

      # ParameterFilter only takes a hash, so an array travels inside one.
      def apply(value)
        return parameter_filter.filter(value) if value.is_a?(Hash)

        parameter_filter.filter(ROOT_KEY => value).fetch(ROOT_KEY)
      end

      def restore_markers(filtered, original)
        case [ filtered, original ]
        in [ Hash, Hash ]
          filtered.each_key.to_a.each do |key|
            filtered[key] = restorable_marker?(key, original) ? original[key] : restore_markers(filtered[key], original[key])
          end
        in [ Array, Array ]
          filtered.each_index { |index| filtered[index] = restore_markers(filtered[index], original[index]) }
        else
          nil
        end
        filtered
      end

      # Only the shapes Active Job writes under a marker; anything else is user data that happens to use the key.
      def restorable_marker?(key, original)
        return false unless MARKER_KEYS.include?(key) && original.key?(key)

        value = original[key]
        value.is_a?(String) || value == true || (value.is_a?(Array) && value.all?(String))
      end
    end
  end
end
