# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "view_component"
require "view_component/test_helpers"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

# ViewComponent test support
class ViewComponentTestCase < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include JobHarbor::Engine.routes.url_helpers

  def render_inline(component)
    controller = JobHarbor::ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    @rendered = component.render_in(controller.view_context)
  end
end
