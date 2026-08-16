# frozen_string_literal: true

class CommandRunner
  def find_executable(name, candidates: [])
    directories = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR, -1)
    directories = [""] if directories.empty?
    search_paths = directories.map do |directory|
      directory.empty? ? name : File.join(directory, name)
    end
    (search_paths + candidates).find { |path| File.file?(path) && File.executable?(path) }&.then { |path| File.expand_path(path) }
  end

  def run(*command, **options)
    Kernel.system(*command, **options)
  end
end
