# frozen_string_literal: true

module OpenCodeFixtures
  def create_opencode_fork(checkout, git: false)
    FileUtils.mkdir_p(File.join(checkout, "packages/app/script"))
    File.write(
      File.join(checkout, "package.json"),
      '{"scripts":{"dev:web:live":"bun run packages/app/script/dev-web-live.ts"}}'
    )
    File.write(File.join(checkout, "packages/app/script/dev-web-live.ts"), <<~TS)
      const server = new URL(process.env.OPENCODE_DEV_SERVER_URL ?? "http://127.0.0.1:4096")
      await fetch(new URL("/api/health", server))
      const env = { OPENCODE_DEV_SERVER_URL: server.origin }
      throw new Error("Start it separately and retry.")
    TS
    return unless git

    FileUtils.mkdir_p(File.join(checkout, ".git", "objects"))
    FileUtils.mkdir_p(File.join(checkout, ".git", "refs"))
    File.write(File.join(checkout, ".git", "HEAD"), "ref: refs/heads/dan-dev\n")
  end
end
