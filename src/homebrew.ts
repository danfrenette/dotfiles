import { constants } from "node:fs";
import { access, stat } from "node:fs/promises";
import { join } from "node:path";

export interface CommandResult {
  exitCode: number;
}

export interface CommandAdapter {
  detect(executable: string): Promise<string | undefined>;
  run(command: string, args: string[]): Promise<CommandResult>;
}

export const homebrewInstallerCommand =
  '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';

export type HomebrewPlanItem =
  | { action: "homebrew-available"; executable: string }
  | { action: "install-homebrew" }
  | { action: "brew-bundle"; brewfile: string; executable?: string };

export type HomebrewPlan =
  | { kind: "available"; brewfile: string; executable: string }
  | { kind: "install"; brewfile: string };

export async function buildHomebrewPlan(
  repositoryRoot: string,
  command: CommandAdapter,
): Promise<HomebrewPlan> {
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

  const executable = await command.detect("brew");
  return executable
    ? { kind: "available", brewfile, executable }
    : { kind: "install", brewfile };
}

export function homebrewPlanItems(plan: HomebrewPlan): HomebrewPlanItem[] {
  return plan.kind === "available"
    ? [
        { action: "homebrew-available", executable: plan.executable },
        {
          action: "brew-bundle",
          brewfile: plan.brewfile,
          executable: plan.executable,
        },
      ]
    : [
        { action: "install-homebrew" },
        { action: "brew-bundle", brewfile: plan.brewfile },
      ];
}

async function findHomebrew(
  command: CommandAdapter,
): Promise<string | undefined> {
  let executable = await command.detect("brew");
  for (const candidate of ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]) {
    executable ??= await command.detect(candidate);
  }
  return executable;
}

async function installHomebrew(command: CommandAdapter): Promise<string> {
  const result = await command.run("/bin/bash", [
    "-c",
    homebrewInstallerCommand,
  ]);
  if (result.exitCode !== 0)
    throw new Error(
      `Homebrew installer failed with exit code ${result.exitCode}`,
    );

  const executable = await findHomebrew(command);
  if (executable) return executable;
  throw new Error(
    "Homebrew installation completed, but the brew executable could not be found",
  );
}

export async function applyHomebrewPlan(
  plan: HomebrewPlan,
  command: CommandAdapter,
): Promise<void> {
  const executable =
    plan.kind === "available"
      ? plan.executable
      : await installHomebrew(command);

  const result = await command.run(executable, [
    "bundle",
    `--file=${plan.brewfile}`,
  ]);
  if (result.exitCode !== 0)
    throw new Error(`brew bundle failed with exit code ${result.exitCode}`);
}
