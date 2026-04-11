/**
 * Spec inspector — returns the capability graph + pipeline topology as a
 * structured object suitable for agent consumption.
 */
import type { AmpersandDeclaration } from "./validate.js";

export interface SpecGraph {
  agent: string;
  version: string;
  capability_count: number;
  primitives: Record<string, number>;
  providers: Record<string, string[]>;
  capabilities: Array<{ id: string; provider: string; config?: unknown }>;
  pipelines: Array<{
    name: string;
    source_type: string | null;
    source_ref: string | null;
    step_count: number;
    steps: Array<{ capability: string; operation: string }>;
  }>;
  governance_keys: string[];
}

export function inspectSpec(doc: AmpersandDeclaration): SpecGraph {
  const caps = Object.entries(doc.capabilities || {});
  const primitives: Record<string, number> = {};
  const providers: Record<string, string[]> = {};

  for (const [id, binding] of caps) {
    const primitive = id.split(".")[0];
    primitives[primitive] = (primitives[primitive] ?? 0) + 1;
    const bucket = providers[binding.provider] ?? [];
    bucket.push(id);
    providers[binding.provider] = bucket;
  }
  for (const key of Object.keys(providers)) providers[key].sort();

  const pipelines = Object.entries(doc.pipelines ?? {}).map(([name, def]) => ({
    name,
    source_type: def.source_type ?? null,
    source_ref: def.source_ref ?? null,
    step_count: Array.isArray(def.steps) ? def.steps.length : 0,
    steps: Array.isArray(def.steps) ? def.steps : [],
  }));

  return {
    agent: doc.agent,
    version: doc.version,
    capability_count: caps.length,
    primitives,
    providers,
    capabilities: caps
      .map(([id, binding]) => ({ id, provider: binding.provider, config: binding.config }))
      .sort((a, b) => a.id.localeCompare(b.id)),
    pipelines,
    governance_keys: Object.keys(doc.governance ?? {}).sort(),
  };
}

export function diffSpecs(a: AmpersandDeclaration, b: AmpersandDeclaration) {
  const aCaps = new Set(Object.keys(a.capabilities || {}));
  const bCaps = new Set(Object.keys(b.capabilities || {}));
  const added = [...bCaps].filter((c) => !aCaps.has(c)).sort();
  const removed = [...aCaps].filter((c) => !bCaps.has(c)).sort();
  const changed: Array<{ capability: string; from: unknown; to: unknown }> = [];

  for (const cap of [...aCaps].filter((c) => bCaps.has(c)).sort()) {
    const left = (a.capabilities as Record<string, unknown>)[cap];
    const right = (b.capabilities as Record<string, unknown>)[cap];
    if (JSON.stringify(left) !== JSON.stringify(right)) {
      changed.push({ capability: cap, from: left, to: right });
    }
  }

  return { added, removed, changed };
}
