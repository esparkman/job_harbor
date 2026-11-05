# frozen_string_literal: true

module JobHarbor
  # SQL reading one top-level key of a JSON text column as text. It is NULL for a row that isn't valid JSON
  # or lacks the key, so a bad row can't break the query. Nil on an adapter we don't know.
  module JsonColumn
    KEY = /\A\w+\z/

    def self.value(model, column, key)
      raise ArgumentError, "unsafe JSON key: #{key.inspect}" unless key.match?(KEY)

      model.with_connection do |connection|
        sql = "#{model.quoted_table_name}.#{connection.quote_column_name(column)}"

        case connection.adapter_name
        when /postg/i
          # pg_input_is_valid arrived in PostgreSQL 16; below that the guard is a best effort.
          valid = connection.database_version >= 160_000 ? "pg_input_is_valid(#{sql}, 'jsonb')" : "#{sql} ~ '^\\s*\\{.*\\}\\s*$'"
          "CASE WHEN #{valid} THEN #{sql}::jsonb ->> '#{key}' END"
        when /mysql|trilogy/i
          "CASE WHEN JSON_VALID(#{sql}) THEN JSON_UNQUOTE(JSON_EXTRACT(#{sql}, '$.#{key}')) END"
        when /sqlite/i
          "CASE WHEN json_valid(#{sql}) THEN json_extract(#{sql}, '$.#{key}') END"
        end
      end
    end
  end
end
