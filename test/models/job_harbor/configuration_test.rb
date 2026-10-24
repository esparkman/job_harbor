# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class ConfigurationTest < ActiveSupport::TestCase
    setup { @configuration = Configuration.new }

    test "filter_parameters accepts nil, false and an array" do
      assert_nil @configuration.filter_parameters

      [ false, [], [ :password ] ].each do |value|
        @configuration.filter_parameters = value
        assert_equal value, @configuration.filter_parameters
      end

      @configuration.filter_parameters = nil
      assert_nil @configuration.filter_parameters
    end

    test "filter_parameters = true raises instead of quietly masking nothing" do
      error = assert_raises(ArgumentError) { @configuration.filter_parameters = true }

      assert_match(/filter_parameters/, error.message)
      assert_match(/nil, false or an Array/, error.message)
    end

    test "filter_parameters rejects a string, a symbol and a hash" do
      [ "password", :password, { password: true } ].each do |value|
        assert_raises(ArgumentError, "#{value.inspect} should be rejected") { @configuration.filter_parameters = value }
      end
    end

    test "filter_parameters rejects an array holding something that is not a pattern" do
      [ [ true ], [ 1 ], [ Object.new ], [ [ :password ] ], [ {} ], [ :password, nil ] ].each do |value|
        assert_raises(ArgumentError, "#{value.inspect} should be rejected") { @configuration.filter_parameters = value }
      end
    end

    test "a rejected array leaves the previous setting in place" do
      @configuration.filter_parameters = [ :token ]
      assert_raises(ArgumentError) { @configuration.filter_parameters = [ :password, true ] }

      assert_equal [ :token ], @configuration.filter_parameters
    end

    test "filter_parameters accepts strings, symbols, regexps and procs together" do
      list = [ :password, "secret", /token/, ->(key, value) { } ]

      @configuration.filter_parameters = list

      assert_equal list, @configuration.filter_parameters
    end

    test "a rejected value leaves the previous setting in place" do
      @configuration.filter_parameters = [ :token ]
      assert_raises(ArgumentError) { @configuration.filter_parameters = true }

      assert_equal [ :token ], @configuration.filter_parameters
    end

    test "filtering is on by default and for a list, off for false and for an empty list" do
      assert_predicate @configuration, :filtering_parameters?

      @configuration.filter_parameters = [ :token ]
      assert_predicate @configuration, :filtering_parameters?

      @configuration.filter_parameters = false
      assert_not_predicate @configuration, :filtering_parameters?

      @configuration.filter_parameters = []
      assert_not_predicate @configuration, :filtering_parameters?
    end

    test "assigning primary_color warns that it has no effect and still stores the value" do
      assert_deprecated(/primary_color has no effect.*removed/, JobHarbor.deprecator) do
        @configuration.primary_color = "indigo"
      end

      assert_equal "indigo", @configuration.primary_color
    end

    test "leaving primary_color alone does not warn" do
      assert_not_deprecated(JobHarbor.deprecator) { Configuration.new }
    end
  end
end
