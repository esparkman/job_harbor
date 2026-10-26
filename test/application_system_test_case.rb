require "test_helper"

Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SolidQueueTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]
end
