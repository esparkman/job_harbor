require_relative "lib/solidqueue_dashboard/version"

Gem::Specification.new do |spec|
  spec.name        = "solidqueue_dashboard"
  spec.version     = SolidqueueDashboard::VERSION
  spec.authors     = [ "Evan Sparkman" ]
  spec.email       = [ "evan@mountaingapcoffee.com" ]
  spec.homepage    = "https://github.com/mountaingapcoffee/solidqueue_dashboard"
  spec.summary     = "A modern dashboard for monitoring and managing Solid Queue jobs"
  spec.description = "A mountable Rails engine providing a beautiful, self-contained dashboard for Solid Queue. Monitor jobs, queues, workers, and recurring tasks with a modern UI built on ViewComponents."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mountaingapcoffee/solidqueue_dashboard"
  spec.metadata["changelog_uri"] = "https://github.com/mountaingapcoffee/solidqueue_dashboard/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "solid_queue", ">= 0.3"
  spec.add_dependency "view_component", ">= 3.0"
end
