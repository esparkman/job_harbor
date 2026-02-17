namespace :job_harbor do
  namespace :tailwind do
    TAILWIND_VERSION = "v4.1.3"

    def tailwind_platform
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

    def vendor_dir
      File.join(engine_root, "vendor/tailwindcss")
    end

    def tailwind_exe
      exe = File.join(vendor_dir, "tailwindcss")
      exe += ".exe" if Gem.win_platform?
      exe
    end

    def engine_root
      File.expand_path("../..", __dir__)
    end

    def input_css
      File.join(engine_root, "app/assets/stylesheets/job_harbor/application.tailwind.css")
    end

    def output_css
      File.join(engine_root, "app/assets/stylesheets/job_harbor/application.css")
    end

    desc "Download Tailwind CSS standalone CLI"
    task :install do
      require "fileutils"
      require "net/http"
      require "uri"

      platform = tailwind_platform
      filename = "tailwindcss-#{platform}"
      url = "https://github.com/tailwindlabs/tailwindcss/releases/download/#{TAILWIND_VERSION}/#{filename}"

      FileUtils.mkdir_p(vendor_dir)
      target = tailwind_exe

      puts "Downloading Tailwind CSS #{TAILWIND_VERSION} for #{platform}..."
      puts "  From: #{url}"
      puts "  To:   #{target}"

      download_with_redirects(url, target)

      FileUtils.chmod(0o755, target)
      puts "Tailwind CSS installed successfully!"
    end

    desc "Compile Tailwind CSS (minified)"
    task :build do
      ensure_cli_installed!

      puts "Building Tailwind CSS..."
      system(
        tailwind_exe,
        "--input", input_css,
        "--output", output_css,
        "--minify",
        "--cwd", engine_root,
        exception: true
      )
      puts "Built: #{output_css}"
    end

    desc "Watch and compile Tailwind CSS (development)"
    task :watch do
      ensure_cli_installed!

      puts "Watching Tailwind CSS for changes..."
      system(
        tailwind_exe,
        "--input", input_css,
        "--output", output_css,
        "--watch",
        "--cwd", engine_root,
        exception: true
      )
    end

    private

    def ensure_cli_installed!
      return if File.executable?(tailwind_exe)

      abort <<~MSG
        Tailwind CSS CLI not found at #{tailwind_exe}
        Run: rake job_harbor:tailwind:install
      MSG
    end

    def download_with_redirects(url, target, limit = 5)
      abort "Too many redirects" if limit == 0

      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request) do |response|
          case response
          when Net::HTTPRedirection
            download_with_redirects(response["location"], target, limit - 1)
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
