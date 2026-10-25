# Serialize runs: they share one SQLite file and reload the SQ schema on boot.
require "fileutils"
FileUtils.mkdir_p(File.expand_path("dummy/tmp", __dir__))
TEST_SUITE_LOCK = File.open(File.expand_path("dummy/tmp/test-suite.lock", __dir__), File::RDWR | File::CREAT)
unless TEST_SUITE_LOCK.flock(File::LOCK_EX | File::LOCK_NB)
  $stderr.puts "Waiting for another test run to finish (lock: #{TEST_SUITE_LOCK.path})…"
  TEST_SUITE_LOCK.flock(File::LOCK_EX)
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"
require "view_component/test_helpers"

# Load after rails/test_help so maintain_test_schema! can't wipe these tables.
module SolidQueueTestSchema
  PATH = File.join(Gem.loaded_specs["solid_queue"].full_gem_path,
    "lib/generators/solid_queue/install/templates/db/queue_schema.rb")

  def self.load!
    unless SolidQueue::Record.connection_pool.equal?(ActiveRecord::Base.connection_pool)
      raise "SolidQueue::Record has its own connects_to database; load #{PATH} into that database instead"
    end

    ActiveRecord::Migration.suppress_messages { load PATH }
  end
end

SolidQueueTestSchema.load!

require_relative "test_helpers/solid_queue_test_helper"
require_relative "test_helpers/page_test_helper"
require_relative "test_helpers/view_component_test_case"

class ActionDispatch::IntegrationTest
  include SolidQueueTestHelper, PageTestHelper
end
