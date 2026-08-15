import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { confirm, isCancel, multiselect } from "@clack/prompts";

import { type Phase, runSetup } from "./setup.js";

const help = `Usage: pnpm run setup [options]

Options:
  --dry-run        Print the complete plan without making changes
  --yes            Apply the plan without confirmation
  --only mappings  Run only the mappings phase
  --help            Show this help`;

interface CliOptions {
  dryRun: boolean;
  help: boolean;
  phases?: Phase[];
  yes: boolean;
}

function parseArguments(args: string[]): CliOptions {
  const options: CliOptions = { dryRun: false, help: false, yes: false };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--dry-run") options.dryRun = true;
    else if (argument === "--yes") options.yes = true;
    else if (argument === "--help" || argument === "-h") options.help = true;
    else if (argument === "--only") {
      const phase = args[index + 1];
      if (phase !== "mappings")
        throw new Error(
          `Invalid phase for --only: ${phase ?? "missing value"}`,
        );
      options.phases = [phase];
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

export async function main(args = process.argv.slice(2)): Promise<number> {
  let options: CliOptions;
  try {
    options = parseArguments(args);
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    console.error(help);
    return 2;
  }

  if (options.help) {
    console.log(help);
    return 0;
  }

  const result = await runSetup({
    command: {
      platform: () => process.platform,
      write: (message) => console.log(message),
    },
    dryRun: options.dryRun,
    homeRoot: homedir(),
    phases: options.phases,
    prompt: {
      choosePhases: async () => {
        const answer = await multiselect({
          initialValues: ["mappings"],
          message: "Select setup phases",
          options: [{ label: "Dotfile mappings", value: "mappings" }],
          required: true,
        });
        return isCancel(answer) ? [] : (answer as Phase[]);
      },
      confirm: async () => {
        const answer = await confirm({ message: "Apply this plan?" });
        return !isCancel(answer) && answer;
      },
    },
    repositoryRoot: resolve(dirname(fileURLToPath(import.meta.url)), ".."),
    yes: options.yes,
  });

  for (const warning of result.warnings) console.error(warning);
  return result.exitCode;
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  process.exitCode = await main();
}
