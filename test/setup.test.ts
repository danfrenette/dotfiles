import {
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readlink,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";

import { runSetup } from "../src/setup.js";

const temporaryDirectories: string[] = [];

async function temporaryDirectory(): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "dotfiles-setup-"));
  temporaryDirectories.push(directory);
  return directory;
}

async function createRepository(
  manifest: string,
  sources: Record<string, string>,
): Promise<string> {
  const repositoryRoot = await temporaryDirectory();
  await mkdir(join(repositoryRoot, "config"), { recursive: true });
  await writeFile(join(repositoryRoot, "config", "mappings.ts.yml"), manifest);

  for (const [relativePath, contents] of Object.entries(sources)) {
    const destination = join(repositoryRoot, relativePath);
    await mkdir(join(destination, ".."), { recursive: true });
    await writeFile(destination, contents);
  }

  return repositoryRoot;
}

afterEach(async () => {
  await Promise.all(
    temporaryDirectories
      .splice(0)
      .map((directory) => rm(directory, { force: true, recursive: true })),
  );
});

describe("runSetup", () => {
  it("presents and applies a mapping plan using injected repository and home roots", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: git/gitconfig\n    target: .gitconfig\n",
      { "git/gitconfig": "[user]\nname = Test\n" },
    );
    const homeRoot = await temporaryDirectory();

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      prompt: {
        choosePhases: async () => ["mappings"],
        confirm: async () => true,
      },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(0);
    expect(result.plan).toEqual([
      expect.objectContaining({
        action: "create-link",
        source: join(repositoryRoot, "git/gitconfig"),
        target: join(homeRoot, ".gitconfig"),
      }),
    ]);
    expect(await readlink(join(homeRoot, ".gitconfig"))).toBe(
      join(repositoryRoot, "git/gitconfig"),
    );
  });

  it("plans parent creation before linking nested targets", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: .config/example/config\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    const output: string[] = [];

    const result = await runSetup({
      command: {
        platform: () => "darwin",
        write: (message) => output.push(message),
      },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.plan.map((item) => item.action)).toEqual([
      "create-parent",
      "create-link",
    ]);
    expect(output).toEqual([
      `- create directory ${join(homeRoot, ".config/example")}\n- link ${join(homeRoot, ".config/example/config")} -> ${join(repositoryRoot, "source")}`,
    ]);
    expect(await readlink(join(homeRoot, ".config/example/config"))).toBe(
      join(repositoryRoot, "source"),
    );
  });

  it("replaces an existing backup before backing up and linking the target", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: git/gitconfig\n    target: .config/git/config\n",
      { "git/gitconfig": "new config" },
    );
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, ".config/git/config");
    await mkdir(join(homeRoot, ".config/git"), { recursive: true });
    await writeFile(target, "current config");
    await writeFile(`${target}.backup`, "stale backup");

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.plan.map((item) => item.action)).toEqual([
      "remove-backup",
      "backup-target",
      "create-link",
    ]);
    expect(await readFile(`${target}.backup`, "utf8")).toBe("current config");
    expect(await readlink(target)).toBe(join(repositoryRoot, "git/gitconfig"));
  });

  it("returns the complete replacement plan without mutation in a dry run", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { source: "new" },
    );
    const homeRoot = await temporaryDirectory();
    await writeFile(join(homeRoot, "target"), "current");
    await writeFile(join(homeRoot, "target.backup"), "backup");

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      dryRun: true,
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(0);
    expect(result.plan.map((item) => item.action)).toEqual([
      "remove-backup",
      "backup-target",
      "create-link",
    ]);
    expect(await readFile(join(homeRoot, "target"), "utf8")).toBe("current");
    expect(await readFile(join(homeRoot, "target.backup"), "utf8")).toBe(
      "backup",
    );
  });

  it("fails preflight before changing any targets when a source is missing", async () => {
    const repositoryRoot = await createRepository(
      [
        "mappings:",
        "  - operation: link",
        "    source: present",
        "    target: target",
        "  - operation: link",
        "    source: missing",
        "    target: other",
        "",
      ].join("\n"),
      { present: "new" },
    );
    const homeRoot = await temporaryDirectory();
    await writeFile(join(homeRoot, "target"), "current");

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(1);
    expect(result.warnings).toEqual([
      expect.stringContaining(join(repositoryRoot, "missing")),
    ]);
    expect(result.plan).toEqual([]);
    expect(await readFile(join(homeRoot, "target"), "utf8")).toBe("current");
    await expect(
      readFile(join(homeRoot, "target.backup")),
    ).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("rejects a target that names the home root before making changes", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: .\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    await writeFile(join(homeRoot, "sentinel"), "preserve me");

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(1);
    expect(result.plan).toEqual([]);
    expect((await lstat(homeRoot)).isDirectory()).toBe(true);
    expect(await readFile(join(homeRoot, "sentinel"), "utf8")).toBe(
      "preserve me",
    );
    await expect(lstat(`${homeRoot}.backup`)).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("rejects a source that names the repository root", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: .\n    target: target\n",
      {},
    );
    const homeRoot = await temporaryDirectory();

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(1);
    expect(result.plan).toEqual([]);
    await expect(lstat(join(homeRoot, "target"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it.each([
    {
      manifest:
        "mappings:\n  - operation: link\n    source: first\n    target: target\n  - operation: link\n    source: second\n    target: target\n",
      name: "duplicate targets",
    },
    {
      manifest:
        "mappings:\n  - operation: link\n    source: first\n    target: .config\n  - operation: link\n    source: second\n    target: .config/nested\n",
      name: "target ancestors",
    },
  ])("rejects $name before making changes", async ({ manifest }) => {
    const repositoryRoot = await createRepository(manifest, {
      first: "first contents",
      second: "second contents",
    });
    const homeRoot = await temporaryDirectory();
    await writeFile(join(homeRoot, "sentinel"), "preserve me");

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(1);
    expect(result.plan).toEqual([]);
    expect(await readFile(join(homeRoot, "sentinel"), "utf8")).toBe(
      "preserve me",
    );
  });

  it("does not apply a valid plan when confirmation is declined", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => false },
      repositoryRoot,
    });

    expect(result.exitCode).toBe(0);
    expect(result.plan).toEqual([
      expect.objectContaining({ action: "create-link" }),
    ]);
    expect(result.warnings).toEqual(["Setup cancelled; no changes were made"]);
    await expect(readlink(join(homeRoot, "target"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("leaves an already-correct link unchanged on rerun", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    const options = {
      command: { platform: () => "darwin" as const, write: () => undefined },
      homeRoot,
      phases: ["mappings" as const],
      prompt: {
        choosePhases: async () => ["mappings" as const],
        confirm: async () => true,
      },
      repositoryRoot,
    };
    await runSetup(options);

    const result = await runSetup(options);

    expect(result.plan).toEqual([
      {
        action: "unchanged",
        source: join(repositoryRoot, "source"),
        target: join(homeRoot, "target"),
      },
    ]);
    expect(await readlink(join(homeRoot, "target"))).toBe(
      join(repositoryRoot, "source"),
    );
    await expect(
      readFile(join(homeRoot, "target.backup")),
    ).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("backs up a broken target symlink after removing a broken backup symlink", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    await symlink("/missing/target", join(homeRoot, "target"));
    await symlink("/missing/backup", join(homeRoot, "target.backup"));

    const result = await runSetup({
      command: { platform: () => "darwin", write: () => undefined },
      homeRoot,
      phases: ["mappings"],
      prompt: { choosePhases: async () => [], confirm: async () => true },
      repositoryRoot,
    });

    expect(result.plan.map((item) => item.action)).toEqual([
      "remove-backup",
      "backup-target",
      "create-link",
    ]);
    expect(await readlink(join(homeRoot, "target"))).toBe(
      join(repositoryRoot, "source"),
    );
    expect(await readlink(join(homeRoot, "target.backup"))).toBe(
      "/missing/target",
    );
  });
});
