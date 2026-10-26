require "test_helper"

# A transactional test pins a leased connection, which hides the :disallowed check, so this one runs outside a transaction.
class DashboardWithoutPermanentCheckoutTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @original_checkout = ActiveRecord.permanent_connection_checkout
    ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
    ActiveRecord.permanent_connection_checkout = :disallowed
  end

  teardown { ActiveRecord.permanent_connection_checkout = @original_checkout }

  test "operator opens the dashboard on a host that disallows permanent connection checkout and sees the job chart" do
    get "/job_harbor"

    assert_response :success
    assert_select ".sqd-chart canvas#sqd-job-chart"
  end
end
