#!/usr/bin/env node
/**
 * Mirror the [&] Protocol artifacts (schema, contracts, registry, examples)
 * into box-and-box/bundled/ so the published npm tarball is self-contained.
 *
 * Runs as part of `npm run build` before tsc. Safe to re-run; outputs under
 * `bundled/` are overwritten.
 */
import { mkdirSync, copyFileSync, readdirSync, statSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.resolve(here, "..");
const protocolRoot = path.resolve(packageRoot, "..");
const bundled = path.resolve(packageRoot, "bundled");

function ensureDir(p) {
  mkdirSync(p, { recursive: true });
}

function copyDir(srcDir, destDir) {
  ensureDir(destDir);
  for (const entry of readdirSync(srcDir)) {
    const srcPath = path.join(srcDir, entry);
    const destPath = path.join(destDir, entry);
    const s = statSync(srcPath);
    if (s.isDirectory()) {
      copyDir(srcPath, destPath);
    } else if (s.isFile()) {
      copyFileSync(srcPath, destPath);
    }
  }
}

// Clean destination so stale files from a prior schema version don't linger.
try {
  rmSync(bundled, { recursive: true, force: true });
} catch {
  // ignore
}
ensureDir(bundled);

const sources = [
  { from: "protocol/schema/v0.1.0", to: "schema/v0.1.0" },
  { from: "protocol/registry/v0.1.0", to: "registry/v0.1.0" },
  { from: "contracts/v0.1.0", to: "contracts/v0.1.0" },
  { from: "examples", to: "examples" },
];

for (const { from, to } of sources) {
  const srcPath = path.resolve(protocolRoot, from);
  const destPath = path.resolve(bundled, to);
  try {
    copyDir(srcPath, destPath);
    console.log(`[bundle] ${from} -> bundled/${to}`);
  } catch (err) {
    console.warn(`[bundle] skipped ${from}: ${err.message}`);
  }
}

console.log("[bundle] done");
