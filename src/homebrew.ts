import { constants } from "node:fs";
import { access, stat } from "node:fs/promises";
import { join } from "node:path";

export interface CommandResult {
  exitCode: number;
}

export interface CommandAdapter {
  detect?(executable: string): Promise<string | undefined>;
  run?(command: string, args: string[]): Promise<CommandResult>;
}

export const homebrewInstallerCommand =
  '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';

export type HomebrewPlanItem =
  | { action: "homebrew-available"; executable: string }
  | { action: "install-homebrew" }
  | { action: "brew-bundle"; brewfile: string; executable?: string };

export async function buildHomebrewPlan(
  repositoryRoot: string,
  command: CommandAdapter,
): Promise<HomebrewPlanItem[]> {
  const brewfile = join(repositoryRoot, "Brewfile");
  let brewfileStat: Awaited<ReturnType<typeof stat>>;
  try {
    brewfileStat = await stat(brewfile);
  } catch {
    throw new Error(`Missing Brewfile: ${brewfile}`);
  }
  try {
    if (!brewfileStat.isFile()) throw new Error();
    await access(brewfile, constants.R_OK);
  } catch {
    throw new Error(`Brewfile must be a readable file: ${brewfile}`);
  }

  if (!command.detect) throw new Error("Homebrew detection is not configured");
  const executable = await command.detect("brew");
  return [
    ...(executable
      ? [{ action: "homebrew-available" as const, executable }]
      : [{ action: "install-homebrew" as const }]),
    { action: "brew-bundle", brewfile, executable },
  ];
}

export async function applyHomebrewPlan(
  plan: HomebrewPlanItem[],
  command: CommandAdapter,
): Promise<void> {
  if (!command.detect || !command.run)
    throw new Error("Homebrew command execution is not configured");

  let executable = plan.find(
    (
      item,
    ): item is Extract<HomebrewPlanItem, { action: "homebrew-available" }> =>
      item.action === "homebrew-available",
  )?.executable;
  if (plan.some((item) => item.action === "install-homebrew")) {
    const result = await command.run("/bin/bash", [
      "-c",
      homebrewInstallerCommand,
    ]);
    if (result.exitCode !== 0)
      throw new Error(
        `Homebrew installer failed with exit code ${result.exitCode}`,
      );
    executable = await command.detect("brew");
    for (const candidate of ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]) {
      executable ??= await command.detect(candidate);
    }
    if (!executable)
      throw new Error(
        "Homebrew installation completed, but the brew executable could not be found",
      );
  }

  const bundle = plan.find((item) => item.action === "brew-bundle");
  if (!bundle || !executable) return;
  const result = await command.run(executable, [
    "bundle",
    `--file=${bundle.brewfile}`,
  ]);
  if (result.exitCode !== 0)
    throw new Error(`brew bundle failed with exit code ${result.exitCode}`);
}
