/**
 * Resolves paths to bundled [&] Protocol artifacts.
 *
 * At publish time, `scripts/bundle.js` mirrors `protocol/schema/`,
 * `protocol/registry/`, `contracts/`, and `examples/` into the package
 * under `bundled/`. At runtime we prefer the bundled copy; during local
 * development we fall back to the sibling monorepo paths.
 */
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
// dist/ or src/ -> package root
const packageRoot = path.resolve(here, "..");
const bundledRoot = path.resolve(packageRoot, "bundled");
const monorepoRoot = path.resolve(packageRoot, "..");

function firstExisting(candidates: string[]): string {
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return candidates[0];
}

export interface ArtifactPaths {
  schemaDir: string;
  ampersandSchema: string;
  contractSchema: string;
  registrySchema: string;
  registryFile: string;
  contractsDir: string;
  examplesDir: string;
}

export function resolveArtifacts(schemaVersion: string = "v0.1.0"): ArtifactPaths {
  const schemaDir = firstExisting([
    path.join(bundledRoot, "schema", schemaVersion),
    path.join(monorepoRoot, "protocol", "schema", schemaVersion),
  ]);
  const contractsDir = firstExisting([
    path.join(bundledRoot, "contracts", schemaVersion),
    path.join(monorepoRoot, "contracts", schemaVersion),
  ]);
  const registryDir = firstExisting([
    path.join(bundledRoot, "registry", schemaVersion),
    path.join(monorepoRoot, "protocol", "registry", schemaVersion),
  ]);
  const examplesDir = firstExisting([
    path.join(bundledRoot, "examples"),
    path.join(monorepoRoot, "examples"),
  ]);

  return {
    schemaDir,
    ampersandSchema: path.join(schemaDir, "ampersand.schema.json"),
    contractSchema: path.join(schemaDir, "capability-contract.schema.json"),
    registrySchema: path.join(schemaDir, "registry.schema.json"),
    registryFile: path.join(registryDir, "capabilities.registry.json"),
    contractsDir,
    examplesDir,
  };
}
