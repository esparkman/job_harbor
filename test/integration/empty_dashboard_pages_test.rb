require "test_helper"

class EmptyDashboardPagesTest < ActionDispatch::IntegrationTest
  test "operator opens the dashboard on an idle queue and sees zeros and no failure list" do
    get "/job_harbor"

    assert_response :success
    [ "Pending", "Scheduled", "In Progress", "Failed", "Blocked", "Finished (24h)", "Active Workers", "Queues" ].each do |label|
      assert_stat_card label, 0
    end
    assert_stat_card "Throughput", "0/hr"
    assert_select ".card-title", text: "Recent Failures", count: 0
    assert_select ".sqd-failure-rates", count: 0
  end
end
