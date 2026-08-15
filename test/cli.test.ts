import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { describe, expect, it } from "vitest";

const execute = promisify(execFile);

describe("setup executable", () => {
  it("prints help and exits successfully", async () => {
    const result = await execute(process.execPath, [
      "--import",
      "tsx",
      "src/cli.ts",
      "--help",
    ]);

    expect(result.stdout).toContain("Usage: pnpm run setup [options]");
    expect(result.stdout).toContain("--only mappings");
    expect(result.stderr).toBe("");
  });

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
