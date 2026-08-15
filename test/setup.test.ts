import { execFileSync } from "node:child_process";
import {
  chmod,
  lstat,
  mkdir,
  mkdtemp,
  readdir,
  readFile,
  readlink,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import { afterEach, describe, expect, it } from "vitest";

import { runSetup, type SetupOptions } from "../src/setup.js";

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

function mappingSetupOptions(
  repositoryRoot: string,
  homeRoot: string,
): SetupOptions {
  return {
    command: { platform: () => "darwin", write: () => undefined },
    homeRoot,
    phases: ["mappings"],
    prompt: { choosePhases: async () => [], confirm: async () => true },
    repositoryRoot,
  };
}

afterEach(async () => {
  await Promise.all(
    temporaryDirectories
      .splice(0)
      .map((directory) => rm(directory, { force: true, recursive: true })),
  );
});

describe("runSetup", () => {
  it("copies a regular file while preserving its mode", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: script\n    target: bin/script\n",
      { script: "#!/bin/sh\necho test\n" },
    );
    const source = join(repositoryRoot, "script");
    await chmod(source, 0o751);
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "bin/script");
    const output: string[] = [];

    const result = await runSetup({
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      command: {
        platform: () => "darwin",
        write: (message) => output.push(message),
      },
    });
    expect(output.join("\n")).toContain(`copy ${source} to ${target}`);

    expect(result.exitCode).toBe(0);
    expect(result.plan).toContainEqual({
      action: "create-copy",
      source,
      target,
    });
    expect(await readFile(target, "utf8")).toBe("#!/bin/sh\necho test\n");
    expect((await stat(target)).mode & 0o7777).toBe(0o751);
  });

  it("copies a nested directory recursively", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: app\n    target: .config/app\n",
      {
        "app/config.json": '{"enabled":true}\n',
        "app/nested/value.txt": "nested contents\n",
      },
    );
    const homeRoot = await temporaryDirectory();

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.exitCode).toBe(0);
    expect(
      await readFile(join(homeRoot, ".config/app/config.json"), "utf8"),
    ).toBe('{"enabled":true}\n');
    expect(
      await readFile(join(homeRoot, ".config/app/nested/value.txt"), "utf8"),
    ).toBe("nested contents\n");
  });

  it("preserves a symlink inside a copied directory", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: app\n    target: .config/app\n",
      { "app/shared.txt": "shared contents\n" },
    );
    await symlink("shared.txt", join(repositoryRoot, "app/current.txt"));
    const homeRoot = await temporaryDirectory();

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.exitCode).toBe(0);
    const copiedLink = join(homeRoot, ".config/app/current.txt");
    expect((await lstat(copiedLink)).isSymbolicLink()).toBe(true);
    expect(await readlink(copiedLink)).toBe("shared.txt");
  });

  it("copies a top-level broken source symlink verbatim", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
      {},
    );
    await symlink("missing", join(repositoryRoot, "source"));
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.exitCode).toBe(0);
    expect((await lstat(target)).isSymbolicLink()).toBe(true);
    expect(await readlink(target)).toBe("missing");
  });

  it("leaves an unchanged copy in place without creating a backup", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
      { "source/nested/file": "contents\n" },
    );
    await chmod(join(repositoryRoot, "source/nested"), 0o751);
    await symlink("nested/file", join(repositoryRoot, "source/current"));
    const homeRoot = await temporaryDirectory();
    const output: string[] = [];
    const options: SetupOptions = {
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      command: {
        platform: () => "darwin",
        write: (message: string) => output.push(message),
      },
    };
    await runSetup(options);

    const result = await runSetup(options);

    expect(result.plan).toEqual([
      {
        action: "unchanged-copy",
        source: join(repositoryRoot, "source"),
        target: join(homeRoot, "target"),
      },
    ]);
    expect(await readlink(join(homeRoot, "target/current"))).toBe(
      "nested/file",
    );
    expect(output.at(-1)).toBe(
      `- leave unchanged copy ${join(homeRoot, "target")}`,
    );
    await expect(lstat(join(homeRoot, "target.backup"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("backs up and replaces a changed copy", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
      { source: "new contents\n" },
    );
    await chmod(join(repositoryRoot, "source"), 0o751);
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");
    await writeFile(target, "new contents\n");
    await chmod(target, 0o644);

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.plan.map((item) => item.action)).toEqual([
      "backup-target",
      "create-copy",
    ]);
    expect(await readFile(target, "utf8")).toBe("new contents\n");
    expect((await stat(target)).mode & 0o7777).toBe(0o751);
    expect((await stat(`${target}.backup`)).mode & 0o7777).toBe(0o644);
  });

  it("dry-runs a copy replacement without mutation", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
      { source: "new contents\n" },
    );
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");
    await writeFile(target, "old contents\n");
    await writeFile(`${target}.backup`, "existing backup\n");

    const result = await runSetup({
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      dryRun: true,
    });

    expect(result.plan.map((item) => item.action)).toEqual([
      "remove-backup",
      "backup-target",
      "create-copy",
    ]);
    expect(await readFile(target, "utf8")).toBe("old contents\n");
    expect(await readFile(`${target}.backup`, "utf8")).toBe(
      "existing backup\n",
    );
  });

  it.each([
    {
      difference: "nested file bytes",
      mutate: async (target: string) =>
        writeFile(join(target, "nested/file"), "changed\n"),
    },
    {
      difference: "directory entries",
      mutate: async (target: string) =>
        writeFile(join(target, "additional"), "added\n"),
    },
    {
      difference: "entry types",
      mutate: async (target: string) => {
        await rm(join(target, "nested/file"));
        await mkdir(join(target, "nested/file"));
      },
    },
    {
      difference: "symlink text",
      mutate: async (target: string) => {
        await rm(join(target, "current"));
        await symlink("other", join(target, "current"));
      },
    },
  ])(
    "plans replacement for changed recursive copy $difference",
    async ({ mutate }) => {
      const repositoryRoot = await createRepository(
        "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
        {
          "source/nested/file": "contents\n",
          "source/other": "other\n",
        },
      );
      await symlink("nested/file", join(repositoryRoot, "source/current"));
      const homeRoot = await temporaryDirectory();
      const target = join(homeRoot, "target");
      const options = mappingSetupOptions(repositoryRoot, homeRoot);
      await runSetup(options);
      await mutate(target);

      const result = await runSetup({ ...options, dryRun: true });

      expect(result.plan.map((item) => item.action)).toEqual([
        "backup-target",
        "create-copy",
      ]);
    },
  );

  it("preserves the target and backup when a copy fails across retries", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
      { "source/file": "copy me\n" },
    );
    execFileSync("mkfifo", [join(repositoryRoot, "source/unsupported")]);
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");
    await writeFile(target, "current target\n");
    await writeFile(`${target}.backup`, "existing backup\n");
    const options = mappingSetupOptions(repositoryRoot, homeRoot);

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const result = await runSetup(options);

      expect(result.exitCode).toBe(1);
      expect(await readFile(target, "utf8")).toBe("current target\n");
      expect(await readFile(`${target}.backup`, "utf8")).toBe(
        "existing backup\n",
      );
      expect((await readdir(homeRoot)).sort()).toEqual([
        "target",
        "target.backup",
      ]);
    }
  });

  it("does not overwrite a copy target created after planning", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: copy\n    source: source\n    target: target\n",
      { source: "copied contents\n" },
    );
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");

    const result = await runSetup({
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      prompt: {
        choosePhases: async () => [],
        confirm: async () => {
          await writeFile(target, "concurrent contents\n");
          return true;
        },
      },
    });

    expect(result.exitCode).toBe(1);
    expect(await readFile(target, "utf8")).toBe("concurrent contents\n");
    await expect(lstat(`${target}.backup`)).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

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
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      command: {
        platform: () => "darwin",
        write: (message) => output.push(message),
      },
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

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

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
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      dryRun: true,
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

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

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

  it("rejects a broken source symlink for a link mapping", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      {},
    );
    const source = join(repositoryRoot, "source");
    await symlink("missing", source);
    const homeRoot = await temporaryDirectory();

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.exitCode).toBe(1);
    expect(result.plan).toEqual([]);
    expect(result.warnings).toEqual([expect.stringContaining(source)]);
    await expect(lstat(join(homeRoot, "target"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("rejects unsupported mapping operations during preflight", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: move\n    source: source\n    target: target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.exitCode).toBe(1);
    expect(result.plan).toEqual([]);
    expect(result.warnings[0]).toContain("Invalid option");
    await expect(lstat(join(homeRoot, "target"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("rejects a target that names the home root before making changes", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: .\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    await writeFile(join(homeRoot, "sentinel"), "preserve me");

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

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

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

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

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

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
      ...mappingSetupOptions(repositoryRoot, homeRoot),
      prompt: { choosePhases: async () => [], confirm: async () => false },
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
    const options = mappingSetupOptions(repositoryRoot, homeRoot);
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

  it("leaves a relative symlink unchanged when it resolves to the source", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: nested/target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    const source = join(repositoryRoot, "source");
    const target = join(homeRoot, "nested/target");
    await mkdir(dirname(target), { recursive: true });
    const relativeSource = relative(dirname(target), source);
    await symlink(relativeSource, target);

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.plan).toEqual([{ action: "unchanged", source, target }]);
    expect(await readlink(target)).toBe(relativeSource);
    await expect(lstat(`${target}.backup`)).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("backs up a symlink that resolves to a different source", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { other: "other contents", source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");
    await symlink(join(repositoryRoot, "other"), target);

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.plan.map((item) => item.action)).toEqual([
      "backup-target",
      "create-link",
    ]);
    expect(await readlink(target)).toBe(join(repositoryRoot, "source"));
    expect(await readlink(`${target}.backup`)).toBe(
      join(repositoryRoot, "other"),
    );
  });

  it("backs up a broken target symlink after removing a broken backup symlink", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    await symlink("/missing/target", join(homeRoot, "target"));
    await symlink("/missing/backup", join(homeRoot, "target.backup"));

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

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

  it("backs up a looping target symlink as broken", async () => {
    const repositoryRoot = await createRepository(
      "mappings:\n  - operation: link\n    source: source\n    target: target\n",
      { source: "contents" },
    );
    const homeRoot = await temporaryDirectory();
    const target = join(homeRoot, "target");
    await symlink("target", target);

    const result = await runSetup(
      mappingSetupOptions(repositoryRoot, homeRoot),
    );

    expect(result.plan.map((item) => item.action)).toEqual([
      "backup-target",
      "create-link",
    ]);
    expect(await readlink(target)).toBe(join(repositoryRoot, "source"));
    expect(await readlink(`${target}.backup`)).toBe("target");
  });
});
