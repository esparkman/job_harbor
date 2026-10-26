# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class QueuePauseFormComponentTest < ViewComponentTestCase
    test "operator sees a queue name field capped at the maximum length that posts to the pauses path" do
      render_inline(QueuePauseFormComponent.new)

      form = fragment.at_css("form")
      assert_equal "post", form["method"]
      assert_equal queues_pauses_path, form["action"]

      input = form.at_css("input[name=name]")
      assert_equal QueueStats::MAX_NAME_LENGTH.to_s, input["maxlength"]
      assert_equal "Queue name", input["placeholder"]
      assert input.key?("required"), "Operator should not be able to submit an empty queue name"
      assert_equal "off", input["autocomplete"], "Browser form restoration would refill this field and hold the queues page content indefinitely"
      assert_equal "Pause", form.at_css("button[type=submit]").text.strip
    end
  end
end
