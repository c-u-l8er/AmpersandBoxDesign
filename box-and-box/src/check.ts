/**
 * Pipeline checker — parses `|>` pipeline expressions (or reads named
 * pipeline definitions from a spec) and asserts every step references
 * a capability declared on the spec.
 */
import type { AmpersandDeclaration, PipelineStep } from "./validate.js";

export interface NormalizedPipeline {
  source_type: string | null;
  source_ref: string;
  steps: PipelineStep[];
}

export interface CheckIssue {
  step: number;
  message: string;
}

export type CheckResult =
  | {
      ok: true;
      source: { type: string | null; ref: string };
      steps: PipelineStep[];
      step_count: number;
    }
  | { ok: false; errors: CheckIssue[] };

export function parsePipelineExpression(
  expression: string,
):
  | { ok: true; value: NormalizedPipeline }
  | { ok: false; errors: string[] } {
  if (typeof expression !== "string" || expression.trim() === "") {
    return { ok: false, errors: ["pipeline expression must be a non-empty string"] };
  }

  const tokens = expression
    .split(/\s*\|>\s*/)
    .map((s) => s.trim())
    .filter(Boolean);

  if (tokens.length < 2) {
    return { ok: false, errors: ["pipeline must include a source token and at least one step"] };
  }

  const sourceType = tokens[0].startsWith("&") ? null : tokens[0];
  const stepTokens = sourceType ? tokens.slice(1) : tokens;

  const steps: PipelineStep[] = [];
  for (const token of stepTokens) {
    const clean = token.trim().replace(/\(\)\s*$/, "");
    const parts = clean.split(".").filter(Boolean);
    if (parts.length < 3 || !parts[0].startsWith("&")) {
      return { ok: false, errors: [`Invalid pipeline token: ${token}`] };
    }
    const operation = parts[parts.length - 1];
    const capability = parts.slice(0, -1).join(".");
    steps.push({ capability, operation });
  }

  return {
    ok: true,
    value: {
      source_type: sourceType,
      source_ref: sourceType ?? "raw_data",
      steps,
    },
  };
}

export interface CheckOptions {
  pipelineName?: string;
  pipelineExpression?: string;
}

export function checkPipeline(
  doc: AmpersandDeclaration,
  options: CheckOptions,
): CheckResult {
  let normalized: NormalizedPipeline;

  if (options.pipelineName) {
    const named = doc.pipelines?.[options.pipelineName];
    if (!named) {
      return {
        ok: false,
        errors: [
          {
            step: 0,
            message: `pipeline "${options.pipelineName}" is not defined in document.pipelines`,
          },
        ],
      };
    }
    normalized = {
      source_type: named.source_type ?? null,
      source_ref: named.source_ref ?? named.source_type ?? "raw_data",
      steps: Array.isArray(named.steps) ? named.steps : [],
    };
  } else if (options.pipelineExpression) {
    const parsed = parsePipelineExpression(options.pipelineExpression);
    if (!parsed.ok) {
      return { ok: false, errors: parsed.errors.map((m) => ({ step: 0, message: m })) };
    }
    normalized = parsed.value;
  } else {
    return {
      ok: false,
      errors: [{ step: 0, message: "either pipelineName or pipelineExpression is required" }],
    };
  }

  const capabilities = doc.capabilities || {};
  const issues: CheckIssue[] = [];

  if (normalized.steps.length === 0) {
    return { ok: false, errors: [{ step: 0, message: "pipeline must contain at least one step" }] };
  }

  normalized.steps.forEach((step, i) => {
    if (!step?.capability) {
      issues.push({ step: i + 1, message: "missing capability" });
      return;
    }
    if (!step.operation) {
      issues.push({ step: i + 1, message: "missing operation" });
      return;
    }
    if (!capabilities[step.capability]) {
      issues.push({
        step: i + 1,
        message: `capability ${step.capability} is not declared in document.capabilities`,
      });
    }
  });

  if (issues.length > 0) return { ok: false, errors: issues };

  return {
    ok: true,
    source: { type: normalized.source_type, ref: normalized.source_ref },
    steps: normalized.steps,
    step_count: normalized.steps.length,
  };
}
