class ViewComponentTestCase < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include JobHarbor::Engine.routes.url_helpers

  def render_inline(component)
    controller = JobHarbor::ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    @rendered = component.render_in(controller.view_context)
  end
end
