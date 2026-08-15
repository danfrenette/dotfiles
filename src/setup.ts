import {
  applyHomebrewPlan,
  buildHomebrewPlan,
  type CommandAdapter,
  type HomebrewPlanItem,
  homebrewInstallerCommand,
} from "./homebrew.js";
import { applyMappingPlan } from "./mappings/apply.js";
import {
  buildMappingPlan,
  type MappingPlan,
  type PlanItem as MappingPlanItem,
} from "./mappings/plan.js";

export type PlanItem = HomebrewPlanItem | MappingPlanItem;

export type Phase = "homebrew" | "mappings";

export interface SetupResult {
  exitCode: number;
  plan: PlanItem[];
  warnings: string[];
}

export interface SetupOptions {
  command: CommandAdapter & {
    platform(): NodeJS.Platform;
    write(message: string): void;
  };
  dryRun?: boolean;
  homeRoot: string;
  phases?: Phase[];
  prompt: {
    choosePhases(): Promise<Phase[]>;
    confirm(): Promise<boolean>;
  };
  repositoryRoot: string;
  yes?: boolean;
}

function describePlanItem(item: PlanItem): string {
  switch (item.action) {
    case "homebrew-available":
      return `Homebrew is already available at ${item.executable}`;
    case "install-homebrew":
      return `run ${homebrewInstallerCommand}`;
    case "brew-bundle":
      return `run ${item.executable ?? "brew"} bundle --file=${item.brewfile}`;
    case "create-parent":
      return `create directory ${item.path}`;
    case "remove-backup":
      return `remove existing backup ${item.path}`;
    case "backup-target":
      return `move ${item.source} to ${item.target}`;
    case "create-link":
      return `link ${item.target} -> ${item.source}`;
    case "create-copy":
      return `copy ${item.source} to ${item.target}`;
    case "unchanged":
      return `leave correct link ${item.target}`;
    case "unchanged-copy":
      return `leave unchanged copy ${item.target}`;
    default:
      return item satisfies never;
  }
}

export async function runSetup(options: SetupOptions): Promise<SetupResult> {
  const warnings: string[] = [];
  const plan: PlanItem[] = [];
  let homebrewPlan: HomebrewPlanItem[] = [];
  let mappingPlan: MappingPlan = [];

  try {
    if (options.command.platform() !== "darwin")
      throw new Error("Setup is supported only on macOS");

    const phases = options.phases ?? (await options.prompt.choosePhases());
    if (phases.length === 0) throw new Error("No setup phases selected");

    if (phases.includes("homebrew"))
      homebrewPlan = await buildHomebrewPlan(
        options.repositoryRoot,
        options.command,
      );
    if (phases.includes("mappings"))
      mappingPlan = await buildMappingPlan(
        options.repositoryRoot,
        options.homeRoot,
      );
    plan.push(...homebrewPlan, ...mappingPlan);
    options.command.write(
      plan.map((item) => `- ${describePlanItem(item)}`).join("\n"),
    );

    if (options.dryRun) return { exitCode: 0, plan, warnings };
    if (!options.yes && !(await options.prompt.confirm())) {
      warnings.push("Setup cancelled; no changes were made");
      return { exitCode: 0, plan, warnings };
    }

    if (phases.includes("homebrew"))
      await applyHomebrewPlan(homebrewPlan, options.command);
    if (phases.includes("mappings")) await applyMappingPlan(mappingPlan);
    return { exitCode: 0, plan, warnings };
  } catch (error) {
    const warning = error instanceof Error ? error.message : String(error);
    warnings.push(warning);
    options.command.write(`Error: ${warning}`);
    return { exitCode: 1, plan, warnings };
  }
}
