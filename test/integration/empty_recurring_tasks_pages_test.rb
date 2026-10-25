require "test_helper"

class EmptyRecurringTasksPagesTest < ActionDispatch::IntegrationTest
  test "operator opens Recurring Tasks with none configured and sees how to add them" do
    get "/job_harbor/recurring_tasks"

    assert_response :success
    assert_select "h3", text: "No recurring tasks found"
    assert_select "p", text: /config\/recurring.yml/
  end
end
