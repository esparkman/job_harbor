require "rails/generators"

module JobHarbor
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a JobHarbor initializer at config/initializers/job_harbor.rb with every setting at its default."

      def copy_initializer
        template "job_harbor.rb", "config/initializers/job_harbor.rb"
      end

      def show_next_steps
        say "\nMount the dashboard in config/routes.rb:"
        say %(  mount JobHarbor::Engine, at: "/job_harbor")
        say "\nThen set config.authorize_with in config/initializers/job_harbor.rb."
        say "Until you do, the dashboard denies every request outside development and test.\n"
      end
    end
  end
end
