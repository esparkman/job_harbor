require "test_helper"
require "generators/job_harbor/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests JobHarbor::Generators::InstallGenerator
  destination File.expand_path("../dummy/tmp/generators", __dir__)

  setup do
    prepare_destination
    JobHarbor.reset_configuration!
  end

  teardown { JobHarbor.reset_configuration! }

  test "it installs the initializer" do
    run_generator

    assert_file "config/initializers/job_harbor.rb", /JobHarbor\.configure do \|config\|/
  end

  test "the initializer documents every setting, so a new one cannot ship unmentioned" do
    run_generator

    settings = JobHarbor::Configuration.public_instance_methods(false).grep(/\A\w+=\z/).map { |setter| setter.to_s.delete_suffix("=") }
    settings -= %w[primary_color]

    assert_file "config/initializers/job_harbor.rb" do |content|
      missing = settings.reject { |setting| content.include?("config.#{setting} =") }

      assert_empty missing, "the template does not mention #{missing.join(", ")}"
    end
  end

  test "the initializer leaves out the deprecated primary_color setting" do
    run_generator

    assert_file "config/initializers/job_harbor.rb" do |content|
      assert_no_match(/primary_color/, content)
    end
  end

  test "the untouched initializer keeps every default, so installing it changes nothing" do
    run_generator
    settings = ->(config) { config.instance_variables.to_h { |name| [ name, config.instance_variable_get(name) ] } }
    defaults = settings.call(JobHarbor::Configuration.new)

    load File.join(destination_root, "config/initializers/job_harbor.rb")

    assert_equal defaults, settings.call(JobHarbor.configuration)
  end
end
