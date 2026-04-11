/**
 * Schema validation for ampersand.json declarations, capability contracts,
 * and the registry. Built on Ajv 2020-12 against the bundled JSON Schemas.
 *
 * Ports the `sdk/npm/validate` CJS module to TypeScript with explicit types.
 */
import { Ajv2020 } from "ajv/dist/2020.js";
import type { ErrorObject, Plugin, ValidateFunction } from "ajv";
import addFormatsImport from "ajv-formats";
import { readFileSync } from "node:fs";
import { resolveArtifacts } from "./paths.js";

const addFormats = addFormatsImport as unknown as Plugin<string[] | undefined>;

export interface AmpersandDeclaration {
  $schema?: string;
  agent: string;
  version: string;
  capabilities: Record<string, CapabilityBinding>;
  governance?: Record<string, unknown>;
  pipelines?: Record<string, PipelineDefinition>;
  provenance?: boolean;
}

export interface CapabilityBinding {
  provider: string;
  config?: Record<string, unknown>;
}

export interface PipelineDefinition {
  source_type?: string | null;
  source_ref?: string | null;
  steps: PipelineStep[];
}

export interface PipelineStep {
  capability: string;
  operation: string;
}

export interface ValidationError {
  path: string;
  message: string;
  keyword: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
}

function toErrors(raw: ErrorObject[] | null | undefined): ValidationError[] {
  if (!raw) return [];
  return raw.map((e) => ({
    path: e.instancePath || "/",
    message: e.message ?? "unknown error",
    keyword: e.keyword,
  }));
}

export class AmpersandValidator {
  private readonly ajv: Ajv2020;
  public readonly artifacts: ReturnType<typeof resolveArtifacts>;
  private readonly specValidator: ValidateFunction;
  private readonly contractValidator: ValidateFunction;
  private readonly registryValidator: ValidateFunction;

  constructor(schemaVersion: string = "v0.1.0") {
    this.artifacts = resolveArtifacts(schemaVersion);
    this.ajv = new Ajv2020({
      strict: false,
      allErrors: true,
      allowUnionTypes: true,
    });
    addFormats(this.ajv);

    const specSchema = JSON.parse(readFileSync(this.artifacts.ampersandSchema, "utf8"));
    const contractSchema = JSON.parse(readFileSync(this.artifacts.contractSchema, "utf8"));
    const registrySchema = JSON.parse(readFileSync(this.artifacts.registrySchema, "utf8"));

    this.specValidator = this.ajv.compile(specSchema);
    this.contractValidator = this.ajv.compile(contractSchema);
    this.registryValidator = this.ajv.compile(registrySchema);
  }

  validateSpec(doc: unknown): ValidationResult {
    const valid = this.specValidator(doc) as boolean;
    return { valid, errors: toErrors(this.specValidator.errors) };
  }

  validateContract(doc: unknown): ValidationResult {
    const valid = this.contractValidator(doc) as boolean;
    return { valid, errors: toErrors(this.contractValidator.errors) };
  }

  validateRegistry(doc: unknown): ValidationResult {
    const valid = this.registryValidator(doc) as boolean;
    return { valid, errors: toErrors(this.registryValidator.errors) };
  }
}

export function readJsonFile<T = unknown>(filePath: string): T {
  const raw = readFileSync(filePath, "utf8");
  return JSON.parse(raw) as T;
}
