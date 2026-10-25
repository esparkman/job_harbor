require "test_helper"

class EmptyJobsPagesTest < ActionDispatch::IntegrationTest
  test "operator opens blocked jobs when nothing is blocked and sees an empty state" do
    get "/job_harbor/jobs/status/blocked"

    assert_response :success
    assert_select "h3", text: "No jobs found"
    assert_select "p", text: "There are no blocked jobs."
  end
end
