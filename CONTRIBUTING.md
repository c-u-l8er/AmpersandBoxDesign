# Contributing to the [&] Protocol

Thanks for contributing.

This repository is the canonical home for the [&] Protocol specification, schemas, examples, documentation, and reference implementation. The goal is to keep the project useful both as a **human-readable protocol spec** and as a **machine-readable implementation target**.

## What belongs in this repository

This repository includes work on:

- protocol specification and terminology
- JSON Schema artifacts
- example `ampersand.json` declarations
- capability contract and registry artifacts
- reference implementations
- CLI tooling
- MCP and A2A generation
- documentation and positioning material
- site/source files for publishing the protocol

## Guiding principles

When contributing, optimize for these priorities:

1. **Specification first**  
   The schema, examples, and protocol documents should agree.

2. **Machine-readable before magical**  
   Prefer explicit contracts, schemas, fixtures, and validation over prose-only ideas.

3. **Do not invent runtime details**  
   If a provider, protocol binding, or integration is not grounded in code or docs, leave it unresolved and document the gap.

4. **Keep the protocol provider-agnostic**  
   Capabilities are interfaces. Providers are implementations.

5. **Complement existing standards**  
   [&] compiles into MCP and A2A configurations. It does not replace them.

## Repository structure

Contributions should generally fit into one of these areas:

- `schema/` — canonical schemas
- `examples/` — validating example declarations
- `reference/` — reference implementations
- `docs/` — supporting documentation
- `site/` — website/source publishing assets
- `tools/` — scripts and developer helpers
- `prompts/` — implementation and research prompts

If you need to add a new top-level directory, explain why in your pull request.

## Before you open a pull request

Please make sure your contribution does the following where relevant:

- keeps terminology consistent with the protocol
- preserves or improves schema validity
- includes examples for new protocol concepts
- includes tests for implementation changes
- updates docs when behavior changes
- avoids unrelated formatting churn
- keeps generated artifacts out of commits unless intentionally checked in

## Specification changes

If you change the protocol itself, update all affected layers together.

For example, a change to a capability field may require updates to:

- `SPEC.md`
- `protocol.html` or site source
- `schema/v*/ampersand.schema.json`
- example declarations in `examples/`
- reference implementation logic
- CLI output or generation behavior
- docs in `docs/`

A protocol change is not complete if only the prose changes.

## Schema contribution rules

When editing schemas:

- target JSON Schema draft 2020-12 unless there is a documented reason not to
- prefer explicit validation rules over vague descriptions
- include examples where helpful
- preserve backward compatibility when possible
- if compatibility must break, document it clearly in the pull request

If you add a new schema artifact, also add at least one realistic example document that validates against it.

## Example declaration rules

Example files should be realistic, not toy placeholders.

Each example should:

- reference the canonical schema
- use realistic capability combinations
- use meaningful governance and provenance settings where appropriate
- demonstrate an actual use case
- validate successfully

Examples are both documentation and test fixtures.

## Reference implementation rules

Reference implementations should stay:

- small
- readable
- deterministic
- well-tested
- faithful to the spec

Prefer minimal, explicit implementations over premature abstraction.

If you add a new implementation feature, include tests that show:

- valid behavior
- invalid behavior
- edge cases where useful

## Documentation guidelines

Documentation should be:

- technical but accessible
- precise about what is implemented vs planned
- respectful of the surrounding ecosystem
- light on hype
- heavy on examples

Preferred framing:

- MCP handles agent-to-tool connectivity
- A2A handles agent-to-agent coordination
- [&] handles capability composition and compiles into MCP + A2A artifacts

Avoid framing the protocol as replacing other standards.

## Commit guidelines

Use clear, focused commits.

Good examples:

- `Add capability contract schema`
- `Create customer support example declaration`
- `Add MCP config generator to Elixir reference implementation`
- `Document protocol stack positioning`

Avoid vague commits like:

- `updates`
- `fix stuff`
- `misc changes`

## Pull request guidelines

A good pull request should include:

- a short summary of what changed
- why the change is needed
- which protocol layer it affects
- any follow-up work still missing
- screenshots or sample output if UI/CLI/site output changed

If the change affects schemas, generation, or validation, include example input/output in the PR description.

## Review criteria

Contributions will generally be reviewed for:

- correctness
- consistency with the protocol model
- clarity of naming
- compatibility with existing artifacts
- test coverage
- documentation completeness

## Things to avoid

Please avoid these unless explicitly discussed first:

- sweeping renames across the repo without strong justification
- speculative provider integrations with no grounding
- undocumented schema changes
- mixing protocol changes with unrelated site/design cleanup
- adding dependencies that are not clearly necessary
- using marketing copy in technical specification files

## Reporting issues

When filing an issue, include:

- what you expected
- what happened instead
- relevant file paths
- example input
- validation/test output if available
- whether the issue is about spec, schema, docs, CLI, generation, or implementation

## Security and safety

Do not commit:

- secrets
- API keys
- credentials
- private tokens
- private customer or personal data

If a contribution touches governance, provenance, auditability, or safety constraints, explain the intended behavior clearly.

## Questions before large changes

If you want to make a major change, open an issue or draft pull request first.

Examples of "major changes":

- changing the canonical schema shape
- renaming core primitives
- changing composition semantics
- changing governance model semantics
- changing generated MCP or A2A artifact structure
- introducing a new reference implementation language

## License and ownership

By contributing, you agree that your contribution may be included in the project under the repository's license once it is added or finalized.

If licensing status is in transition, call that out in the pull request when relevant.

## Practical contributor checklist

Before submitting, ask yourself:

- Does this match the protocol as written?
- Did I update schema/examples/docs together?
- Did I avoid inventing details that are not grounded?
- Did I add or update tests?
- Would another engineer understand this change in six months?

If the answer is yes, you're probably in good shape.

---

Build the protocol like infrastructure:
clear contracts, reproducible behavior, and minimal ambiguity.