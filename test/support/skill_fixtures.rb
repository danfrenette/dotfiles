# frozen_string_literal: true

module SkillFixtures
  def create_skill(path, root: tmp_path("skills"))
    skill_dir = File.join(root, path)
    create_file(File.join(skill_dir, "SKILL.md"), "---\nname: #{File.basename(path)}\n---\n")
    skill_dir
  end

  def write_skills_manifest(path, local_skills: [])
    create_file(path, YAML.dump("local_skills" => local_skills))
  end
end
