# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "tmpdir"

class OpencodeBetaInstaller
  ARCHIVE_PREFIX = "https://github.com/anomalyco/opencode-beta/releases/latest/download"

  def initialize(output: $stdout, dry_run: false)
    @output = output
    @dry_run = dry_run
  end

  def install
    return log("  [OK]   opencode already installed") if installed?
    return log("  [SKIP] opencode beta install is only implemented for macOS") unless supported?

    if dry_run
      log("  [DRY]  would install opencode beta (#{asset_name})")
      log("        #{download_url}")
      log("        -> #{binary_path}")
      return
    end

    FileUtils.mkdir_p(bin_dir)
    return log("  [SKIP] opencode beta download failed") unless download_archive
    return log("  [SKIP] opencode beta unzip failed") unless unzip_archive
    return log("  [SKIP] opencode binary missing in archive") unless extracted_binary?

    FileUtils.mv(extracted_binary_path, binary_path)
    FileUtils.chmod(0o755, binary_path)
    log("  [OK]   installed opencode beta -> #{binary_path}")
  ensure
    cleanup
  end

  private

  attr_reader :output, :dry_run

  def log(message)
    output.puts(message)
  end

  def installed?
    system("command -v opencode >/dev/null 2>&1")
  end

  def supported?
    !asset_name.nil?
  end

  def asset_name
    return "opencode-darwin-arm64.zip" if darwin? && arm64?
    return "opencode-darwin-x64.zip" if darwin? && x64?

    nil
  end

  def darwin?
    RbConfig::CONFIG["host_os"].include?("darwin")
  end

  def arm64?
    RbConfig::CONFIG["host_cpu"] == "arm64"
  end

  def x64?
    RbConfig::CONFIG["host_cpu"] == "x86_64"
  end

  def download_url
    "#{ARCHIVE_PREFIX}/#{asset_name}"
  end

  def download_archive
    system("curl -fsSL #{download_url} -o #{archive_path}")
  end

  def unzip_archive
    system("unzip -qo #{archive_path} -d #{extract_dir}")
  end

  def extracted_binary?
    File.exist?(extracted_binary_path)
  end

  def extracted_binary_path
    File.join(extract_dir, "opencode")
  end

  def bin_dir
    File.join(Dir.home, ".opencode", "bin")
  end

  def binary_path
    File.join(bin_dir, "opencode")
  end

  def archive_path
    File.join(Dir.tmpdir, "opencode-beta.zip")
  end

  def extract_dir
    File.join(Dir.tmpdir, "opencode-beta")
  end

  def cleanup
    FileUtils.rm_f(archive_path)
    FileUtils.rm_rf(extract_dir)
  end
end
