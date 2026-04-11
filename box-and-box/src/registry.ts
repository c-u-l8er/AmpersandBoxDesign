/**
 * Capability registry loader. Reads the bundled
 * `capabilities.registry.json` and exposes primitive/provider lookups used
 * by both `generate_mcp` and the `registry_list` / `registry_providers` MCP
 * tools.
 */
import { readJsonFile } from "./validate.js";

export interface RegistryProvider {
  id: string;
  protocol?: string;
  transport?: string;
  url?: string | null;
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  subtypes?: string[];
  [key: string]: unknown;
}

export interface RegistryPrimitive {
  providers: RegistryProvider[];
  [key: string]: unknown;
}

export type CapabilityRegistry = Record<string, RegistryPrimitive>;

export function loadRegistry(registryPath: string): CapabilityRegistry {
  return readJsonFile<CapabilityRegistry>(registryPath);
}

export function parseCapability(
  capabilityId: string,
): { primitive: string; subtype: string | null } | null {
  const parts = String(capabilityId).split(".");
  if (!parts[0] || !parts[0].startsWith("&")) return null;
  return { primitive: parts[0], subtype: parts[1] ?? null };
}

export function providersForCapability(
  registry: CapabilityRegistry,
  capabilityId: string,
): RegistryProvider[] {
  const parsed = parseCapability(capabilityId);
  if (!parsed) return [];
  const entry = registry[parsed.primitive];
  if (!entry || !Array.isArray(entry.providers)) return [];
  if (!parsed.subtype) return [...entry.providers];
  return entry.providers.filter((p) =>
    Array.isArray(p.subtypes) ? p.subtypes.includes(parsed.subtype!) : false,
  );
}

export function buildProviderIndex(
  registry: CapabilityRegistry,
): Map<string, RegistryProvider> {
  const index = new Map<string, RegistryProvider>();
  for (const [key, entry] of Object.entries(registry)) {
    if (!key.startsWith("&")) continue;
    const providers = Array.isArray(entry.providers) ? entry.providers : [];
    for (const provider of providers) {
      if (provider && typeof provider.id === "string" && !index.has(provider.id)) {
        index.set(provider.id, provider);
      }
    }
  }
  return index;
}

export function listCapabilities(registry: CapabilityRegistry): string[] {
  return Object.keys(registry)
    .filter((k) => k.startsWith("&"))
    .sort();
}
