import {
  cp,
  link,
  lstat,
  mkdir,
  mkdtemp,
  readdir,
  readFile,
  readlink,
  realpath,
  rename,
  rm,
  rmdir,
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
  | { action: "create-copy"; source: string; target: string }
  | { action: "create-link"; source: string; target: string }
  | { action: "unchanged-copy"; source: string; target: string }
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
      operation: z.enum(["link", "copy"]),
      source: relativePath,
      target: relativePath,
    }),
  ),
});

function errorCode(error: unknown): string | undefined {
  if (typeof error !== "object" || error === null || !("code" in error))
    return undefined;
  return typeof error.code === "string" ? error.code : undefined;
}

async function pathExists(path: string, followLinks = false): Promise<boolean> {
  try {
    await (followLinks ? stat(path) : lstat(path));
    return true;
  } catch (error) {
    if (errorCode(error) === "ENOENT") return false;
    throw error;
  }
}

async function copiedStateMatches(
  source: string,
  target: string,
): Promise<boolean> {
  const [sourceStat, targetStat] = await Promise.all([
    lstat(source),
    lstat(target),
  ]);

  if (sourceStat.isSymbolicLink() || targetStat.isSymbolicLink()) {
    return (
      sourceStat.isSymbolicLink() &&
      targetStat.isSymbolicLink() &&
      (await readlink(source)) === (await readlink(target))
    );
  }

  if ((sourceStat.mode & 0o7777) !== (targetStat.mode & 0o7777)) return false;

  if (sourceStat.isFile() || targetStat.isFile()) {
    return (
      sourceStat.isFile() &&
      targetStat.isFile() &&
      (await readFile(source)).equals(await readFile(target))
    );
  }

  if (!sourceStat.isDirectory() || !targetStat.isDirectory()) return false;

  const [sourceEntries, targetEntries] = await Promise.all([
    readdir(source),
    readdir(target),
  ]);
  sourceEntries.sort();
  targetEntries.sort();
  if (
    sourceEntries.length !== targetEntries.length ||
    sourceEntries.some((entry, index) => entry !== targetEntries[index])
  )
    return false;

  for (const entry of sourceEntries) {
    if (!(await copiedStateMatches(join(source, entry), join(target, entry))))
      return false;
  }
  return true;
}

async function linkResolvesTo(
  source: string,
  target: string,
): Promise<boolean> {
  try {
    const [resolvedSource, resolvedTarget] = await Promise.all([
      realpath(source),
      realpath(target),
    ]);
    return resolvedSource === resolvedTarget;
  } catch (error) {
    if (["ELOOP", "ENOENT", "ENOTDIR"].includes(errorCode(error) ?? ""))
      return false;
    throw error;
  }
}

async function installStagedCopy(copy: string, target: string): Promise<void> {
  const copyStat = await lstat(copy);
  if (copyStat.isSymbolicLink()) {
    await symlink(await readlink(copy), target);
    return;
  }
  if (copyStat.isFile()) {
    await link(copy, target);
    return;
  }
  if (!copyStat.isDirectory())
    throw new Error(`Unsupported staged copy: ${copy}`);

  await mkdir(target);
  try {
    await rename(copy, target);
  } catch (error) {
    await rmdir(target);
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
    operation: mapping.operation,
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
    if (!(await pathExists(mapping.source, mapping.operation === "link")))
      missingSources.push(mapping.source);
  }
  if (missingSources.length > 0)
    throw new Error(`Missing mapping sources:\n${missingSources.join("\n")}`);

  const plan: PlanItem[] = [];
  const plannedParents = new Set<string>();
  for (const mapping of mappings) {
    if (await pathExists(mapping.target)) {
      if (
        mapping.operation === "copy" &&
        (await copiedStateMatches(mapping.source, mapping.target))
      ) {
        plan.push({
          action: "unchanged-copy",
          source: mapping.source,
          target: mapping.target,
        });
        continue;
      }

      if (
        mapping.operation === "link" &&
        (await lstat(mapping.target)).isSymbolicLink() &&
        (await linkResolvesTo(mapping.source, mapping.target))
      ) {
        plan.push({
          action: "unchanged",
          source: mapping.source,
          target: mapping.target,
        });
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
    plan.push({
      action: mapping.operation === "link" ? "create-link" : "create-copy",
      source: mapping.source,
      target: mapping.target,
    });
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
    case "create-copy":
      return `copy ${item.source} to ${item.target}`;
    case "unchanged":
      return `leave correct link ${item.target}`;
    case "unchanged-copy":
      return `leave unchanged copy ${item.target}`;
  }
}

async function applyPlan(plan: PlanItem[]): Promise<void> {
  const stagedCopies = new Map<string, { copy: string; directory: string }>();

  try {
    for (const item of plan) {
      if (item.action === "create-parent")
        await mkdir(item.path, { recursive: true });
    }

    for (const item of plan) {
      if (item.action !== "create-copy") continue;
      const directory = await mkdtemp(
        join(dirname(item.target), ".dotfiles-setup-"),
      );
      const copy = join(directory, "copy");
      stagedCopies.set(item.target, { copy, directory });
      await cp(item.source, copy, {
        recursive: true,
        verbatimSymlinks: true,
      });
    }

    for (const item of plan) {
      switch (item.action) {
        case "create-parent":
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
        case "create-copy": {
          const stagedCopy = stagedCopies.get(item.target);
          if (!stagedCopy)
            throw new Error(`Copy was not staged: ${item.target}`);
          await installStagedCopy(stagedCopy.copy, item.target);
          break;
        }
        case "unchanged":
        case "unchanged-copy":
          break;
      }
    }
  } finally {
    await Promise.all(
      [...stagedCopies.values()].map(({ directory }) =>
        rm(directory, { force: true, recursive: true }),
      ),
    );
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
