# frozen_string_literal: true

module JobHarbor
  # Masks sensitive values in job payloads with the host app's parameter filter.
  module ArgumentFilter
    MASK = "[FILTERED]"

    # Active Job's own markers; a filter like :_key would otherwise mask them and break the payload's shape.
    MARKER_KEYS = %w[_aj_globalid _aj_symbol_keys _aj_ruby2_keywords _aj_hash_with_indifferent_access _aj_serialized].freeze

    class << self
      # Fails closed: anything the filter can't safely handle is hidden, never shown.
      def filter(value)
        parameter_filter = JobHarbor.configuration.parameter_filter
        return value unless parameter_filter
        return MASK unless value.is_a?(Hash) || value.is_a?(Array)

        restore_markers(apply(parameter_filter, value.deep_dup), value)
      rescue StandardError
        MASK
      end

      def pretty_generate(value)
        JSON.pretty_generate(filter(value))
      end

      private

      # ParameterFilter only takes a hash, so an array travels inside one.
      def apply(parameter_filter, value)
        return parameter_filter.filter(value) if value.is_a?(Hash)

        parameter_filter.filter("value" => value).fetch("value")
      end

      def restore_markers(filtered, original)
        case [ filtered, original ]
        in [ Hash, Hash ]
          filtered.each_key.to_a.each do |key|
            filtered[key] = MARKER_KEYS.include?(key) && original.key?(key) ? original[key] : restore_markers(filtered[key], original[key])
          end
        in [ Array, Array ]
          filtered.each_index { |index| filtered[index] = restore_markers(filtered[index], original[index]) }
        else
          nil
        end
        filtered
      end
    end
  end
end
