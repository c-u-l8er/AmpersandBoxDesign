/**
 * Generators that convert an [&] Protocol spec into runtime configuration
 * for MCP (Model Context Protocol) and A2A (agent-to-agent) deployments.
 *
 * Ported from the JS reference implementation in `sdk/npm/validate/`.
 */
import type { AmpersandDeclaration, CapabilityBinding } from "./validate.js";
import {
  buildProviderIndex,
  providersForCapability,
  type CapabilityRegistry,
  type RegistryProvider,
} from "./registry.js";

export interface McpServerConfig {
  command: string;
  args: string[];
  env: Record<string, string>;
  transport: string;
  url?: string;
  capabilities: string[];
}

export interface Unresolved {
  provider: string;
  capabilities: string[];
  reason: string;
}

export interface McpGenerateResult {
  agent: string;
  version: string;
  format: "zed" | "generic";
  config: Record<string, Record<string, McpServerConfig>>;
  unresolved_providers: Unresolved[];
}

function resolveProvider(
  registry: CapabilityRegistry,
  capabilityId: string,
  binding: CapabilityBinding,
):
  | { provider: string; unresolved?: undefined }
  | { provider: "auto"; unresolved: Unresolved } {
  if (binding.provider !== "auto") {
    return { provider: binding.provider };
  }
  const candidates = providersForCapability(registry, capabilityId)
    .filter((p) => typeof p.id === "string")
    .sort((a, b) => a.id.localeCompare(b.id));
  if (candidates.length === 0) {
    return {
      provider: "auto",
      unresolved: {
        provider: "auto",
        capabilities: [capabilityId],
        reason: `no registry provider found for capability ${capabilityId}`,
      },
    };
  }
  return { provider: candidates[0].id };
}

const BUILTIN_SERVERS: Record<string, (caps: string[]) => McpServerConfig> = {
  graphonomous: (caps) => ({
    command: "npx",
    args: ["-y", "graphonomous", "--db", "~/.graphonomous/knowledge.db"],
    env: {},
    transport: "stdio",
    capabilities: caps,
  }),
  "os-pulse": (caps) => ({
    command: "npx",
    args: ["-y", "os-pulse", "--db", "~/.os-pulse/manifests.db"],
    env: {},
    transport: "stdio",
    capabilities: caps,
  }),
  "os-prism": (caps) => ({
    command: "npx",
    args: ["-y", "os-prism", "--db", "~/.os-prism/benchmarks.db"],
    env: {},
    transport: "stdio",
    capabilities: caps,
  }),
  "box-and-box": (caps) => ({
    command: "npx",
    args: ["-y", "box-and-box", "--db", "~/.box-and-box/specs.db"],
    env: {},
    transport: "stdio",
    capabilities: caps,
  }),
};

function serverConfigFromProvider(
  providerId: string,
  metadata: RegistryProvider | undefined,
  capabilities: string[],
): McpServerConfig | null {
  const builtin = BUILTIN_SERVERS[providerId];
  if (builtin) return builtin(capabilities);

  if (metadata?.command) {
    return {
      command: metadata.command,
      args: Array.isArray(metadata.args) ? metadata.args : [],
      env: metadata.env ?? {},
      transport: metadata.transport ?? "custom",
      url: metadata.url ?? undefined,
      capabilities,
    };
  }

  return null;
}

export interface GenerateOptions {
  format?: "zed" | "generic";
}

export function generateMcp(
  doc: AmpersandDeclaration,
  registry: CapabilityRegistry,
  options: GenerateOptions = {},
): McpGenerateResult {
  const providerIndex = buildProviderIndex(registry);
  const grouped = new Map<string, string[]>();
  const unresolved: Unresolved[] = [];

  for (const [capabilityId, binding] of Object.entries(doc.capabilities || {})) {
    const resolved = resolveProvider(registry, capabilityId, binding);
    if (resolved.unresolved) {
      unresolved.push(resolved.unresolved);
      continue;
    }
    const bucket = grouped.get(resolved.provider) ?? [];
    bucket.push(capabilityId);
    grouped.set(resolved.provider, bucket);
  }

  const servers: Record<string, McpServerConfig> = {};
  for (const [providerId, caps] of grouped.entries()) {
    const config = serverConfigFromProvider(
      providerId,
      providerIndex.get(providerId),
      [...caps].sort(),
    );
    if (!config) {
      unresolved.push({
        provider: providerId,
        capabilities: [...caps].sort(),
        reason: "no MCP resolver registered for provider",
      });
      continue;
    }
    servers[providerId] = config;
  }

  const format = options.format === "generic" ? "generic" : "zed";
  const rootKey = format === "generic" ? "mcpServers" : "context_servers";
  return {
    agent: doc.agent,
    version: doc.version,
    format,
    config: { [rootKey]: servers },
    unresolved_providers: unresolved,
  };
}

export interface A2ACard {
  agent: string;
  version: string;
  capabilities: Array<{ id: string; provider: string }>;
  governance?: Record<string, unknown>;
  pipelines: string[];
}

export function generateA2a(doc: AmpersandDeclaration): A2ACard {
  return {
    agent: doc.agent,
    version: doc.version,
    capabilities: Object.entries(doc.capabilities || {})
      .map(([id, binding]) => ({ id, provider: binding.provider }))
      .sort((a, b) => a.id.localeCompare(b.id)),
    governance: doc.governance,
    pipelines: Object.keys(doc.pipelines ?? {}).sort(),
  };
}
