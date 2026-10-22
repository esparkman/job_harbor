# Maintainer-only; rakelib/ is not in spec.files, so this never ships.
require "fileutils"
require "net/http"
require "uri"
require "rbconfig"

module JobHarbor
  module TailwindCLI
    VERSION = "v4.1.3"

    module_function

    def platform
      cpu = RbConfig::CONFIG["host_cpu"]
      os = RbConfig::CONFIG["host_os"]

      case os
      when /darwin/i
        cpu.match?(/arm|aarch64/) ? "macos-arm64" : "macos-x64"
      when /linux/i
        cpu.match?(/arm|aarch64/) ? "linux-arm64" : "linux-x64"
      when /mingw|mswin/i
        "windows-x64.exe"
      else
        abort "Unsupported platform: #{os} #{cpu}"
      end
    end

    def root
      File.expand_path("..", __dir__)
    end

    def vendor_dir
      File.join(root, "vendor/tailwindcss")
    end

    def exe
      path = File.join(vendor_dir, "tailwindcss")
      path += ".exe" if Gem.win_platform?
      path
    end

    def input_css
      File.join(root, "app/assets/stylesheets/job_harbor/application.tailwind.css")
    end

    def output_css
      File.join(root, "app/assets/stylesheets/job_harbor/application.css")
    end

    def ensure_installed!
      return if File.executable?(exe)

      abort <<~MSG
        Tailwind CSS CLI not found at #{exe}
        Run: bundle exec rake job_harbor:tailwind:install
      MSG
    end

    def download(url, target, limit = 5)
      abort "Too many redirects" if limit == 0

      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          case response
          when Net::HTTPRedirection
            download(response["location"], target, limit - 1)
          when Net::HTTPSuccess
            File.open(target, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          else
            abort "Download failed: #{response.code} #{response.message}"
          end
        end
      end
    end
  end
end

namespace :job_harbor do
  namespace :tailwind do
    desc "Download Tailwind CSS standalone CLI"
    task :install do
      cli = JobHarbor::TailwindCLI
      filename = "tailwindcss-#{cli.platform}"
      url = "https://github.com/tailwindlabs/tailwindcss/releases/download/#{cli::VERSION}/#{filename}"

      FileUtils.mkdir_p(cli.vendor_dir)

      puts "Downloading Tailwind CSS #{cli::VERSION} for #{cli.platform}..."
      puts "  From: #{url}"
      puts "  To:   #{cli.exe}"

      cli.download(url, cli.exe)

      FileUtils.chmod(0o755, cli.exe)
      puts "Tailwind CSS installed successfully!"
    end

    desc "Compile Tailwind CSS (minified)"
    task :build do
      cli = JobHarbor::TailwindCLI
      cli.ensure_installed!

      puts "Building Tailwind CSS..."
      system(
        cli.exe,
        "--input", cli.input_css,
        "--output", cli.output_css,
        "--minify",
        "--cwd", cli.root,
        exception: true
      )
      puts "Built: #{cli.output_css}"
    end

    desc "Watch and compile Tailwind CSS (development)"
    task :watch do
      cli = JobHarbor::TailwindCLI
      cli.ensure_installed!

      puts "Watching Tailwind CSS for changes..."
      system(
        cli.exe,
        "--input", cli.input_css,
        "--output", cli.output_css,
        "--watch",
        "--cwd", cli.root,
        exception: true
      )
    end
  end
end
