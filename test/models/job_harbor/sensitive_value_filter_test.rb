# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class SensitiveValueFilterTest < ActiveSupport::TestCase
    teardown { JobHarbor.configuration.filter_parameters = nil }

    test "values under filtered keys are masked at any depth, including hashes inside arrays" do
      payload = { "arguments" => [ { "user" => { "token" => "abc" } }, [ { "password" => "hunter2", "plan" => "pro" } ] ] }

      filtered = SensitiveValueFilter.filter(payload)

      assert_equal "[FILTERED]", filtered.dig("arguments", 0, "user", "token")
      assert_equal "[FILTERED]", filtered.dig("arguments", 1, 0, "password")
      assert_equal "pro", filtered.dig("arguments", 1, 0, "plan")
    end

    test "Active Job markers survive a filter that would match them, such as :_key" do
      JobHarbor.configuration.filter_parameters = [ :_key, :secret ]
      payload = { "arguments" => [ { "api_key" => "k", "_aj_symbol_keys" => [ "api_key" ], "_aj_ruby2_keywords" => [ "api_key" ],
                                     "_aj_hash_with_indifferent_access" => true, "_aj_serialized" => "ActiveJob::Serializers::TimeSerializer",
                                     "_aj_globalid" => "gid://app/User/1" } ] }

      filtered = SensitiveValueFilter.filter(payload).dig("arguments", 0)

      assert_equal "[FILTERED]", filtered["api_key"]
      assert_equal payload["arguments"][0].except("api_key"), filtered.except("api_key")
    end

    test "a marker value that a host Proc partly scrubbed keeps the scrubbed text" do
      JobHarbor.configuration.filter_parameters = [ ->(_key, value) { value.gsub!("sk_live_x", "[SCRUBBED]") if value.is_a?(String) } ]

      filtered = SensitiveValueFilter.filter({ "arguments" => [ { "_aj_globalid" => "gid://app/ApiKey/sk_live_x" } ] })

      assert_equal "gid://app/ApiKey/[SCRUBBED]", filtered.dig("arguments", 0, "_aj_globalid")
    end

    test "a user key that merely starts with _aj_ is still masked" do
      JobHarbor.configuration.filter_parameters = [ :secret ]

      filtered = SensitiveValueFilter.filter({ "arguments" => [ { "_aj_secret" => "shh", "_aj_symbol_keys" => [ "_aj_secret" ] } ] })

      assert_equal "[FILTERED]", filtered.dig("arguments", 0, "_aj_secret")
      assert_equal [ "_aj_secret" ], filtered.dig("arguments", 0, "_aj_symbol_keys")
    end

    test "a hash masked as a whole stays masked" do
      JobHarbor.configuration.filter_parameters = [ :credentials ]

      filtered = SensitiveValueFilter.filter({ "credentials" => { "user" => "u", "_aj_symbol_keys" => [] } })

      assert_equal({ "credentials" => "[FILTERED]" }, filtered)
    end

    test "a filter that raises hides the whole value instead of showing it" do
      JobHarbor.configuration.filter_parameters = [ ->(_key, _value) { raise "boom" } ]

      assert_equal "[FILTERED]", SensitiveValueFilter.filter({ "arguments" => [ "hunter2" ] })
    end

    test "a value that is not a hash or array is hidden while filtering is on" do
      assert_equal "[FILTERED]", SensitiveValueFilter.filter("hunter2")
      assert_equal "[FILTERED]", SensitiveValueFilter.filter(nil)
    end

    test "filtering a value does not change the original" do
      JobHarbor.configuration.filter_parameters = [ ->(_key, value) { value.gsub!("hunter2", "x") if value.is_a?(String) } ]
      payload = { "arguments" => [ "hunter2" ] }

      assert_equal [ "x" ], SensitiveValueFilter.filter(payload)["arguments"]
      assert_equal [ "hunter2" ], payload["arguments"]
    end

    test "with filtering off the value comes back untouched" do
      JobHarbor.configuration.filter_parameters = false
      payload = { "password" => "hunter2" }

      assert_same payload, SensitiveValueFilter.filter(payload)
      assert_equal "hunter2", SensitiveValueFilter.filter("hunter2")
    end

    test "the host app's filter_parameters is read at call time" do
      Rails.application.config.filter_parameters << :plan
      assert_equal "[FILTERED]", SensitiveValueFilter.filter({ "plan" => "pro" })["plan"]
    ensure
      Rails.application.config.filter_parameters.delete(:plan)
    end

    test "configured filter_parameters replace the host list" do
      JobHarbor.configuration.filter_parameters = [ :plan ]

      filtered = SensitiveValueFilter.filter({ "plan" => "pro", "password" => "hunter2" })

      assert_equal({ "plan" => "[FILTERED]", "password" => "hunter2" }, filtered)
    end

    test "a marker key holding something Active Job never writes there stays masked" do
      JobHarbor.configuration.filter_parameters = [ :password ]

      filtered = SensitiveValueFilter.filter({ "arguments" => [ { "_aj_serialized" => { "password" => "leak" } } ] })

      assert_equal({ "password" => "[FILTERED]" }, filtered.dig("arguments", 0, "_aj_serialized"))
    end

    test "a filter that matches only part of a word does not mask a whole top-level array" do
      JobHarbor.configuration.filter_parameters = [ :val, :arg ]

      assert_equal [ "a", { "plan" => "pro" } ], SensitiveValueFilter.filter([ "a", { "plan" => "pro" } ])
    end

    test "an empty list masks nothing, so values come back as they are" do
      JobHarbor.configuration.filter_parameters = []

      assert_equal [ { "password" => "hunter2" } ], SensitiveValueFilter.filter([ { "password" => "hunter2" } ])
    end

    test "pretty_generate prints the filtered value as JSON" do
      output = SensitiveValueFilter.pretty_generate([ { "token" => "abc", "plan" => "pro" } ])

      assert_equal [ { "token" => "[FILTERED]", "plan" => "pro" } ], JSON.parse(output)
    end
  end
end
