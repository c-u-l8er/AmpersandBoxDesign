/**
 * Capability composition for [&] Protocol specs.
 *
 * Merges N agent declarations into a single capability map and enforces
 * ACI properties — the same binding in two specs is idempotent (collapsed);
 * conflicting bindings for the same capability are an error.
 */
import type { AmpersandDeclaration, CapabilityBinding } from "./validate.js";

export interface ComposeConflict {
  capability: string;
  left: CapabilityBinding;
  right: CapabilityBinding;
}

export type ComposeResult =
  | {
      ok: true;
      capabilities: Record<string, CapabilityBinding>;
      normalized: string[];
      capability_count: number;
    }
  | { ok: false; conflicts: ComposeConflict[] };

function deepEqual(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

export function composeDocuments(docs: AmpersandDeclaration[]): ComposeResult {
  const merged: Record<string, CapabilityBinding> = {};
  const conflicts: ComposeConflict[] = [];

  for (const doc of docs) {
    const caps = doc.capabilities || {};
    for (const [capability, binding] of Object.entries(caps)) {
      if (!(capability in merged)) {
        merged[capability] = binding;
        continue;
      }
      if (!deepEqual(merged[capability], binding)) {
        conflicts.push({ capability, left: merged[capability], right: binding });
      }
    }
  }

  if (conflicts.length > 0) {
    return { ok: false, conflicts };
  }

  const normalized = Object.keys(merged).sort();
  return {
    ok: true,
    capabilities: merged,
    normalized,
    capability_count: normalized.length,
  };
}
