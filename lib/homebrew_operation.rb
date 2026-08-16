# frozen_string_literal: true

HomebrewOperation = Data.define(:type, :meta, :command) do
  def self.available(path)
    new(type: :available, meta: {path: path}, command: nil)
  end

  def self.bundle(executable, brewfile)
    command = [executable, "bundle", "--file=#{brewfile}"]
    new(
      type: :bundle,
      meta: {
        command: command,
        brewfile: brewfile,
        effect: "install or update declared packages"
      },
      command: command
    )
  end
end

class << HomebrewOperation
  private :new
end
