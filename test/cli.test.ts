import { execFile } from "node:child_process";
import { chmod, lstat, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

import { afterEach, describe, expect, it } from "vitest";

import { defaultPhases } from "../src/cli.js";

const execute = promisify(execFile);
const temporaryDirectories: string[] = [];

afterEach(async () => {
  await Promise.all(
    temporaryDirectories
      .splice(0)
      .map((directory) => rm(directory, { force: true, recursive: true })),
  );
});

describe("setup executable", () => {
  it("prints help and exits successfully", async () => {
    const result = await execute(process.execPath, [
      "--import",
      "tsx",
      "src/cli.ts",
      "--help",
    ]);

    expect(result.stdout).toContain("Usage: pnpm run setup [options]");
    expect(result.stdout).toContain("--only homebrew");
    expect(result.stdout).toContain("--only mappings");
    expect(result.stderr).toBe("");
  });

  it("accepts a Homebrew-only dry run without package mutation", async () => {
    const bin = await mkdtemp(join(tmpdir(), "dotfiles-cli-"));
    temporaryDirectories.push(bin);
    const brew = join(bin, "brew");
    const marker = join(bin, "brew-was-run");
    await writeFile(brew, '#!/bin/sh\ntouch "$BREW_MARKER"\n');
    await chmod(brew, 0o755);
    const result = await execute(
      process.execPath,
      ["--import", "tsx", "src/cli.ts", "--only", "homebrew", "--dry-run"],
      {
        env: {
          ...process.env,
          BREW_MARKER: marker,
          PATH: `${bin}:${process.env.PATH ?? ""}`,
        },
      },
    );

    expect(result.stdout).toContain("brew bundle --file=");
    expect(result.stderr).toBe("");
    await expect(lstat(marker)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("selects Homebrew and mappings by default", () => {
    expect(defaultPhases).toEqual(["homebrew", "mappings"]);
  });

  it.each([undefined, "unknown"])(
    "rejects an invalid --only value: %s",
    async (phase) => {
      const args = ["--import", "tsx", "src/cli.ts", "--only"];
      if (phase) args.push(phase);

      await expect(execute(process.execPath, args)).rejects.toMatchObject({
        code: 2,
        stderr: expect.stringContaining(
          `Invalid phase for --only: ${phase ?? "missing value"}`,
        ),
      });
    },
  );

  it("reports invalid arguments with a nonzero exit status", async () => {
    await expect(
      execute(process.execPath, [
        "--import",
        "tsx",
        "src/cli.ts",
        "--not-an-option",
      ]),
    ).rejects.toMatchObject({
      code: 2,
      stderr: expect.stringContaining("Unknown argument: --not-an-option"),
    });
  });
});
