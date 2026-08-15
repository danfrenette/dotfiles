import {
  cp,
  link,
  lstat,
  mkdir,
  mkdtemp,
  readlink,
  rename,
  rm,
  rmdir,
  symlink,
} from "node:fs/promises";
import { dirname, join } from "node:path";

import type { MappingPlan } from "./plan.js";

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

export async function applyMappingPlan(plan: MappingPlan): Promise<void> {
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
        default:
          return item satisfies never;
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
