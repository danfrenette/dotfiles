import {
  lstat,
  mkdir,
  readFile,
  readlink,
  rename,
  rm,
  stat,
  symlink,
} from "node:fs/promises";
import { dirname, isAbsolute, join, normalize, sep } from "node:path";

import { parse } from "yaml";
import { z } from "zod";

export type Phase = "mappings";

export type PlanItem =
  | { action: "create-parent"; path: string }
  | { action: "remove-backup"; path: string }
  | { action: "backup-target"; source: string; target: string }
  | { action: "create-link"; source: string; target: string }
  | { action: "unchanged"; source: string; target: string };

export interface SetupResult {
  exitCode: number;
  plan: PlanItem[];
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

const relativePath = z
  .string()
  .min(1)
  .refine((path) => {
    const normalized = normalize(path);
    return (
      !isAbsolute(path) &&
      normalized !== "." &&
      normalized !== ".." &&
      !normalized.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`)
    );
  }, "must be a path within its root");

const manifestSchema = z.object({
  mappings: z.array(
    z.object({
      operation: z.literal("link"),
      source: relativePath,
      target: relativePath,
    }),
  ),
});

async function pathExists(path: string, followLinks = false): Promise<boolean> {
  try {
    await (followLinks ? stat(path) : lstat(path));
    return true;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
    throw error;
  }
}

async function buildPlan(
  repositoryRoot: string,
  homeRoot: string,
): Promise<PlanItem[]> {
  const manifestPath = join(repositoryRoot, "config", "mappings.ts.yml");
  const manifest = manifestSchema.parse(
    parse(await readFile(manifestPath, "utf8")),
  );
  const mappings = manifest.mappings.map((mapping) => ({
    source: join(repositoryRoot, mapping.source),
    target: join(homeRoot, mapping.target),
  }));

  const targets = new Set<string>();
  for (const { target } of mappings) {
    if (
      targets.has(target) ||
      [...targets].some(
        (existing) =>
          target.startsWith(`${existing}${sep}`) ||
          existing.startsWith(`${target}${sep}`),
      )
    ) {
      throw new Error(`Mapping targets overlap: ${target}`);
    }
    targets.add(target);
  }

  const missingSources: string[] = [];
  for (const mapping of mappings) {
    if (!(await pathExists(mapping.source, true)))
      missingSources.push(mapping.source);
  }
  if (missingSources.length > 0)
    throw new Error(`Missing mapping sources:\n${missingSources.join("\n")}`);

  const plan: PlanItem[] = [];
  const plannedParents = new Set<string>();
  for (const mapping of mappings) {
    if (await pathExists(mapping.target)) {
      const linkedSource = (await lstat(mapping.target)).isSymbolicLink()
        ? await readlink(mapping.target)
        : undefined;
      if (linkedSource === mapping.source) {
        plan.push({ action: "unchanged", ...mapping });
        continue;
      }

      const backup = `${mapping.target}.backup`;
      if (await pathExists(backup))
        plan.push({ action: "remove-backup", path: backup });
      plan.push({
        action: "backup-target",
        source: mapping.target,
        target: backup,
      });
    }

    const parent = dirname(mapping.target);
    if (!(await pathExists(parent, true)) && !plannedParents.has(parent)) {
      plan.push({ action: "create-parent", path: parent });
      plannedParents.add(parent);
    }
    plan.push({ action: "create-link", ...mapping });
  }
  return plan;
}

function describe(item: PlanItem): string {
  switch (item.action) {
    case "create-parent":
      return `create directory ${item.path}`;
    case "remove-backup":
      return `remove existing backup ${item.path}`;
    case "backup-target":
      return `move ${item.source} to ${item.target}`;
    case "create-link":
      return `link ${item.target} -> ${item.source}`;
    case "unchanged":
      return `leave correct link ${item.target}`;
  }
}

async function applyPlan(plan: PlanItem[]): Promise<void> {
  for (const item of plan) {
    switch (item.action) {
      case "create-parent":
        await mkdir(item.path, { recursive: true });
        break;
      case "remove-backup":
        await rm(item.path, { force: true, recursive: true });
        break;
      case "backup-target":
        await rename(item.source, item.target);
        break;
      case "create-link":
        await symlink(item.source, item.target);
        break;
      case "unchanged":
        break;
    }
  }
}

export async function runSetup(options: SetupOptions): Promise<SetupResult> {
  const warnings: string[] = [];
  let plan: PlanItem[] = [];

  try {
    if (options.command.platform() !== "darwin")
      throw new Error("Setup is supported only on macOS");

    const phases = options.phases ?? (await options.prompt.choosePhases());
    if (!phases.includes("mappings"))
      throw new Error("No setup phases selected");

    plan = await buildPlan(options.repositoryRoot, options.homeRoot);
    options.command.write(plan.map((item) => `- ${describe(item)}`).join("\n"));

    if (options.dryRun) return { exitCode: 0, plan, warnings };
    if (!options.yes && !(await options.prompt.confirm())) {
      warnings.push("Setup cancelled; no changes were made");
      return { exitCode: 0, plan, warnings };
    }

    await applyPlan(plan);
    return { exitCode: 0, plan, warnings };
  } catch (error) {
    const warning = error instanceof Error ? error.message : String(error);
    warnings.push(warning);
    options.command.write(`Error: ${warning}`);
    return { exitCode: 1, plan, warnings };
  }
}
