require "test_helper"

class GemspecTest < ActiveSupport::TestCase
  ROOT = File.expand_path("..", __dir__)
  RUNTIME_PATHS = %r{\A(app|lib)/|\A(config/routes\.rb|MIT-LICENSE|README\.md)\z}

  setup do
    @spec = Gem::Specification.load(File.join(ROOT, "job_harbor.gemspec"))
  end

  test "the packaged gem carries its license text, README and routes" do
    { "MIT-LICENSE" => "the MIT license text the gem declares",
      "README.md" => "the installation and configuration docs",
      "config/routes.rb" => "the engine's routes, so every dashboard page 404s" }.each do |path, loss|
      assert @spec.files.include?(path), "#{path} is not packaged; users would lose #{loss}"
    end
  end

  test "every file the gem packages exists, so a release cannot silently drop one" do
    missing = @spec.files.reject { |path| File.exist?(File.join(ROOT, path)) }

    assert_empty missing, "the gemspec packages #{missing.join(", ")} but nothing is there; gem build would refuse to ship"
  end

  test "the packaged gem ships only runtime files" do
    leaked = @spec.files.grep_v(RUNTIME_PATHS)

    assert_empty leaked, "users would download maintainer-only files: #{leaked.join(", ")}"
  end

  test "the gem declares the MIT license" do
    assert_equal "MIT", @spec.license, "users would see the wrong license on rubygems.org"
  end
end
