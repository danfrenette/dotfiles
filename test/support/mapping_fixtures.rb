# frozen_string_literal: true

module MappingFixtures
  def create_mapping(name, content = "test content")
    source = create_file("dotfiles/#{name}", content)
    target = tmp_path("home", name)
    [source, target]
  end

  def create_repo_link(home:, source:, target:)
    source_path = File.expand_path("../../#{source}", __dir__)
    target_path = File.join(home, target)
    FileUtils.mkdir_p(File.dirname(target_path))
    File.symlink(source_path, target_path)
    [source_path, target_path]
  end
end
