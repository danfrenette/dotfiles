import { applyMappingPlan } from "./mappings/apply.js";
import {
  buildMappingPlan,
  type MappingPlan,
  type PlanItem,
} from "./mappings/plan.js";

export type { PlanItem } from "./mappings/plan.js";

export type Phase = "mappings";

export interface SetupResult {
  exitCode: number;
  plan: MappingPlan;
  warnings: string[];
}

export interface SetupOptions {
  command: {
    platform(): NodeJS.Platform;
    write(message: string): void;
    run?(command: string, args: string[]): Promise<number>;
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
  let plan: MappingPlan = [];

  try {
    if (options.command.platform() !== "darwin")
      throw new Error("Setup is supported only on macOS");

    const phases = options.phases ?? (await options.prompt.choosePhases());
    if (!phases.includes("mappings"))
      throw new Error("No setup phases selected");

    plan = await buildMappingPlan(options.repositoryRoot, options.homeRoot);
    options.command.write(
      plan.map((item) => `- ${describePlanItem(item)}`).join("\n"),
    );

    if (options.dryRun) return { exitCode: 0, plan, warnings };
    if (!options.yes && !(await options.prompt.confirm())) {
      warnings.push("Setup cancelled; no changes were made");
      return { exitCode: 0, plan, warnings };
    }

    await applyMappingPlan(plan);
    return { exitCode: 0, plan, warnings };
  } catch (error) {
    const warning = error instanceof Error ? error.message : String(error);
    warnings.push(warning);
    options.command.write(`Error: ${warning}`);
    return { exitCode: 1, plan, warnings };
  }
}
