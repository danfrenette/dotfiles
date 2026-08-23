# frozen_string_literal: true

require "open3"

class CommandRunner
  def find_executable(name, candidates: [], search_path: true)
    directories = search_path ? ENV.fetch("PATH", "").split(File::PATH_SEPARATOR, -1) : []
    directories = [""] if search_path && directories.empty?
    search_paths = directories.map do |directory|
      directory.empty? ? name : File.join(directory, name)
    end
    (search_paths + candidates).find { |path| File.file?(path) && File.executable?(path) }&.then { |path| File.expand_path(path) }
  end

  def run(*command, env: {}, **options)
    return Kernel.system(*command, **options) if env.empty?

    Kernel.system(env, *command, **options)
  end

  def capture(*command)
    output, status = Open3.capture2e(*command)
    status.success? ? output : nil
  rescue SystemCallError
    nil
  end
end
