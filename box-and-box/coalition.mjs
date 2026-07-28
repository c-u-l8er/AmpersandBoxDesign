// coalition.mjs — CC2 coalition runtime (v0.1)
// The thing the schema describes and nothing enforces — until now.
//
// A coalition declaration (coalition.schema.json) groups agents, names a goal they must ENSURE,
// optional adversaries, common-knowledge prerequisites, per-agent task ownership, safety/liveness
// shields over the JOINT trajectory, an entrenched floor, a compose pipeline, and a provenance flag.
//
// This module validates the schema shape, then orchestrates the existing rungs to decide each clause.
// Every clause that references a semantic string (ensure, shield, floor, common_knowledge) requires
// the caller to supply an explicit evaluator/model — the kernel cannot parse natural-language goal
// descriptions. A missing evaluator produces a named refusal identifying the missing substrate,
// never an assumption.
//
// Returns either:
//   { admitted: true, certificate: { ... } }   — the coalition governs to a certificate
//   { admitted: false, refused: clause, reason: string, missing?: string }   — named refusal
//
// Pure library, zero deps, no bundled HTML.

import * as strategic from './strategic.mjs';
import * as epistemic from './epistemic.mjs';
import * as temporal from './temporal.mjs';
import { TemporalSpec, supervise } from './supervise.mjs';
import { Policy, entrench, admissible as reflexiveAdmissible } from './reflexive.mjs';
import { Norm } from './norm.mjs';
import { composePipe, composeTree, Brick, isZero } from './compose.mjs';
import { record as evoRecord, hash as evoHash, canon as evoCanon, GENESIS, chain as evoChain, verify as evoVerify } from './evolution.mjs';

// ---------------------------------------------------------------------------
// schema shape validation — checks structural requirements from coalition.schema.json
// ---------------------------------------------------------------------------
const ID_RE = /^[A-Za-z][A-Za-z0-9_-]*$/;
const SEMVER_RE = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;
const SCHEMA_URI = 'https://protocol.ampersandboxdesign.com/schema/v0.1.0/coalition.schema.json';

export function validateShape(decl) {
  if (!decl || typeof decl !== 'object') return { ok: false, clause: '$schema', reason: 'declaration must be an object' };
  if (decl.$schema !== SCHEMA_URI) return { ok: false, clause: '$schema', reason: `$schema must be "${SCHEMA_URI}"` };
  if (typeof decl.coalition !== 'string' || !ID_RE.test(decl.coalition))
    return { ok: false, clause: 'coalition', reason: 'coalition must be an identifier matching /^[A-Za-z][A-Za-z0-9_-]*$/' };
  if (typeof decl.version !== 'string' || !SEMVER_RE.test(decl.version))
    return { ok: false, clause: 'version', reason: 'version must be a semantic version string' };

  // agents: non-empty array of unique identifiers
  if (!Array.isArray(decl.agents) || decl.agents.length < 1)
    return { ok: false, clause: 'agents', reason: 'agents must be a non-empty array' };
  for (const a of decl.agents) {
    if (typeof a !== 'string' || !ID_RE.test(a))
      return { ok: false, clause: 'agents', reason: `agent "${a}" is not a valid identifier` };
  }
  if (new Set(decl.agents).size !== decl.agents.length)
    return { ok: false, clause: 'agents', reason: 'agents must be unique' };

  // ensure: non-empty string (required)
  if (typeof decl.ensure !== 'string' || decl.ensure.length < 1)
    return { ok: false, clause: 'ensure', reason: 'ensure must be a non-empty string' };

  // optional adversary: unique identifiers
  if (decl.adversary !== undefined) {
    if (!Array.isArray(decl.adversary))
      return { ok: false, clause: 'adversary', reason: 'adversary must be an array' };
    for (const a of decl.adversary) {
      if (typeof a !== 'string' || !ID_RE.test(a))
        return { ok: false, clause: 'adversary', reason: `adversary "${a}" is not a valid identifier` };
    }
    if (new Set(decl.adversary).size !== decl.adversary.length)
      return { ok: false, clause: 'adversary', reason: 'adversary members must be unique' };
  }

  // optional common_knowledge: unique non-empty strings
  if (decl.common_knowledge !== undefined) {
    if (!Array.isArray(decl.common_knowledge))
      return { ok: false, clause: 'common_knowledge', reason: 'common_knowledge must be an array' };
    for (const f of decl.common_knowledge) {
      if (typeof f !== 'string' || f.length < 1)
        return { ok: false, clause: 'common_knowledge', reason: 'common_knowledge entries must be non-empty strings' };
    }
    if (new Set(decl.common_knowledge).size !== decl.common_knowledge.length)
      return { ok: false, clause: 'common_knowledge', reason: 'common_knowledge entries must be unique' };
  }

  // optional owns: object mapping agent identifiers to non-empty task strings
  if (decl.owns !== undefined) {
    if (typeof decl.owns !== 'object' || Array.isArray(decl.owns) || decl.owns === null)
      return { ok: false, clause: 'owns', reason: 'owns must be an object' };
    if (Object.keys(decl.owns).length < 1)
      return { ok: false, clause: 'owns', reason: 'owns must have at least one entry' };
    for (const [agent, task] of Object.entries(decl.owns)) {
      if (!ID_RE.test(agent))
        return { ok: false, clause: 'owns', reason: `owns key "${agent}" is not a valid identifier` };
      if (typeof task !== 'string' || task.length < 1)
        return { ok: false, clause: 'owns', reason: `owns["${agent}"] must be a non-empty string` };
    }
  }

  // optional shield: array of non-empty strings
  if (decl.shield !== undefined) {
    if (!Array.isArray(decl.shield))
      return { ok: false, clause: 'shield', reason: 'shield must be an array' };
    for (const s of decl.shield) {
      if (typeof s !== 'string' || s.length < 1)
        return { ok: false, clause: 'shield', reason: 'shield entries must be non-empty strings' };
    }
  }

  // optional floor: array of non-empty strings
  if (decl.floor !== undefined) {
    if (!Array.isArray(decl.floor))
      return { ok: false, clause: 'floor', reason: 'floor must be an array' };
    for (const f of decl.floor) {
      if (typeof f !== 'string' || f.length < 1)
        return { ok: false, clause: 'floor', reason: 'floor entries must be non-empty strings' };
    }
  }

  // optional compose: non-empty string
  if (decl.compose !== undefined) {
    if (typeof decl.compose !== 'string' || decl.compose.length < 1)
      return { ok: false, clause: 'compose', reason: 'compose must be a non-empty string' };
  }

  // optional provenance: boolean
  if (decl.provenance !== undefined && typeof decl.provenance !== 'boolean')
    return { ok: false, clause: 'provenance', reason: 'provenance must be a boolean' };

  // no additional properties
  const KNOWN = new Set(['$schema', 'coalition', 'version', 'agents', 'ensure',
    'adversary', 'common_knowledge', 'owns', 'shield', 'floor', 'compose', 'provenance']);
  for (const k of Object.keys(decl)) {
    if (!KNOWN.has(k))
      return { ok: false, clause: k, reason: `unknown property "${k}" (additionalProperties: false)` };
  }

  return { ok: true };
}

// ---------------------------------------------------------------------------
// refuse helper — deterministic named refusal
// ---------------------------------------------------------------------------
export function refuse(clause, reason, missing) {
  const r = { admitted: false, refused: clause, reason };
  if (missing) r.missing = missing;
  return r;
}

// ---------------------------------------------------------------------------
// admit — the main coalition admissibility check
// ---------------------------------------------------------------------------
// evidence: {
//   game?:          strategic.Game — for ensure (the concurrent game structure)
//   initialState?:  any — starting state of the game
//   goal?:          strategic formula — parsed ensure goal
//   model?:         epistemic.Model — for common_knowledge checks
//   formulas?:      { [factName]: epistemic formula } — parsed common_knowledge facts
//   shieldSpecs?:   [{ id, formula, kind }] — parsed temporal formulas for shield
//   trajectories?:  [[state]] — joint coalition trajectories (including reachable alternatives)
//   floorNorms?:    [Norm] — parsed floor constraints as norms
//   floorSpecs?:    [TemporalSpec] — parsed floor constraints as temporal specs
//   bricks?:        [Brick] — parsed compose steps as bricks (in pipeline order)
//   composeTree?:   object — AST for composeTree ({ op, a, b })
// }
export function admit(decl, evidence = {}) {
  // ---- step 0: schema shape ----
  const shape = validateShape(decl);
  if (!shape.ok) return refuse(shape.clause, shape.reason);

  const clauseEvidence = {};
  const agents = decl.agents;
  const adversary = decl.adversary || [];

  // ---- step 1: agents membership — disjointness with adversary ----
  for (const a of adversary) {
    if (agents.includes(a))
      return refuse('adversary', `agent "${a}" appears in both agents and adversary — membership must be disjoint`);
  }
  clauseEvidence.agents = { checked: true, members: agents, adversary };

  // ---- step 2: ensure — strategic canEnsure (rung 7) ----
  // The ensure clause requires a Game, an initial state, and a parsed goal formula.
  // Without these, the kernel cannot decide whether the coalition can force the goal.
  if (!evidence.game)
    return refuse('ensure', 'cannot decide ensure without a game structure', 'game');
  if (evidence.initialState === undefined)
    return refuse('ensure', 'cannot decide ensure without an initial state', 'initialState');
  if (!evidence.goal)
    return refuse('ensure', 'cannot decide ensure without a parsed goal formula', 'goal');

  const canForce = strategic.canEnsure(evidence.game, agents, evidence.goal, evidence.initialState);
  if (!canForce) {
    // ought-implies-can: the coalition cannot force its goal
    const verdict = strategic.oblige(evidence.game, agents, evidence.goal, evidence.initialState);
    return refuse('ensure',
      `coalition "${decl.coalition}" cannot ensure "${decl.ensure}" — ⟨⟨${agents.join(',')}⟩⟩◊goal does not hold from the initial state (verdict: ${verdict})`);
  }
  clauseEvidence.ensure = { checked: true, canForce: true, goal: decl.ensure };

  // ---- step 3: common_knowledge — epistemic common (rung 6) ----
  if (decl.common_knowledge && decl.common_knowledge.length > 0) {
    if (!evidence.model)
      return refuse('common_knowledge', 'cannot decide common_knowledge without an epistemic model', 'model');
    if (!evidence.formulas)
      return refuse('common_knowledge', 'cannot decide common_knowledge without parsed formulas for each fact', 'formulas');

    for (const fact of decl.common_knowledge) {
      const f = evidence.formulas[fact];
      if (!f)
        return refuse('common_knowledge', `no parsed formula supplied for fact "${fact}"`, `formulas["${fact}"]`);
      const isCommon = epistemic.common(evidence.model, agents, f);
      if (!isCommon)
        return refuse('common_knowledge',
          `"${fact}" is not common knowledge among [${agents.join(', ')}] — coordination requires common knowledge (Aumann 1976)`);
    }
    clauseEvidence.common_knowledge = { checked: true, facts: decl.common_knowledge };
  }

  // ---- step 4: owns — deontic obligation (rung 3) ----
  if (decl.owns) {
    for (const agent of Object.keys(decl.owns)) {
      if (!agents.includes(agent))
        return refuse('owns', `owner "${agent}" is not a member of agents [${agents.join(', ')}]`);
    }
    clauseEvidence.owns = { checked: true, assignments: decl.owns };
  }

  // ---- step 5: shield — temporal supervision over JOINT trajectories (rung 4) ----
  if (decl.shield && decl.shield.length > 0) {
    if (!evidence.shieldSpecs || evidence.shieldSpecs.length === 0)
      return refuse('shield', 'cannot decide shield without parsed temporal formulas', 'shieldSpecs');
    if (!evidence.trajectories || evidence.trajectories.length === 0)
      return refuse('shield', 'cannot decide shield without joint coalition trajectories (including reachable alternatives)', 'trajectories');

    // Build specs from evidence
    const specs = evidence.shieldSpecs;

    // Check shields over ALL trajectories (joint, including reachable alternatives).
    // A shield is a property of the JOINT trajectory, not per-agent.
    // Any reachable violation refuses the coalition by shield name.
    for (const traj of evidence.trajectories) {
      const result = supervise(traj, specs);
      if (!result.safe) {
        const violated = result.reports.find(r => r.kind === 'safety' && r.verdict === 'violated');
        return refuse('shield',
          `safety shield "${violated.id}" violated at step ${violated.violatedAt} on a reachable joint trajectory — coalition inadmissible`);
      }
      // Liveness failures at horizon also refuse
      if (result.escalation && result.escalation.required) {
        const unmet = result.escalation.specs[0];
        return refuse('shield',
          `liveness shield "${unmet.id}" unmet at horizon on a reachable joint trajectory — ${unmet.reason}`);
      }
    }
    clauseEvidence.shield = { checked: true, specs: decl.shield, trajectoriesChecked: evidence.trajectories.length };
  }

  // ---- step 6: floor — reflexive entrenchment (rung 5) ----
  if (decl.floor && decl.floor.length > 0) {
    if (!evidence.floorNorms && !evidence.floorSpecs)
      return refuse('floor', 'cannot decide floor without parsed norms or temporal specs to entrench', 'floorNorms');

    // Build a policy with entrenched floor items
    const norms = evidence.floorNorms || [];
    const specs = evidence.floorSpecs || [];
    let policy = Policy({ norms, specs });

    // Entrench every floor item
    const allIds = [...norms.map(n => n.id), ...specs.map(s => s.id)];
    for (const id of allIds) {
      policy = entrench(policy, id);
    }

    // Verify that every expected floor id is entrenched
    for (let i = 0; i < decl.floor.length; i++) {
      const expected = allIds[i];
      if (!expected || !policy.entrenched.has(expected))
        return refuse('floor', `floor constraint "${decl.floor[i]}" could not be entrenched — no matching norm or spec supplied`, `floorNorms[${i}]`);
    }

    clauseEvidence.floor = { checked: true, entrenched: [...policy.entrenched], constraints: decl.floor };
  }

  // ---- step 7: compose — pipeline composition (alethic + axiological) ----
  if (decl.compose) {
    if (!evidence.bricks && !evidence.composeTree)
      return refuse('compose', 'cannot decide compose without parsed bricks or a compose tree', 'bricks');

    let result;
    if (evidence.composeTree) {
      result = composeTree(evidence.composeTree);
    } else {
      // Sequential pipeline from bricks array
      result = evidence.bricks[0];
      for (let i = 1; i < evidence.bricks.length; i++) {
        result = composePipe(result, evidence.bricks[i]);
        if (isZero(result)) break;
      }
    }

    if (isZero(result))
      return refuse('compose', `compose pipeline "${decl.compose}" annihilated to 0̲ — a step is infeasible, type-mismatched, or uncertified`);

    clauseEvidence.compose = { checked: true, expression: decl.compose, annihilated: false, compositeId: result.id };
  }

  // ---- step 8: provenance — build hash-linked records if requested ----
  let provenance = null;
  if (decl.provenance) {
    const payload = {
      coalition: decl.coalition,
      version: decl.version,
      agents,
      ensure: decl.ensure,
      clauseEvidence
    };
    const rec = evoRecord(payload, GENESIS);
    const chain = [rec];
    const verified = evoVerify(chain, GENESIS);
    provenance = { records: chain, verified: verified.ok, head: verified.head };
  }

  // ---- build certificate ----
  const certificate = {
    admitted: true,
    coalition: decl.coalition,
    version: decl.version,
    agents,
    adversary,
    ensure: decl.ensure,
    clauses: clauseEvidence,
    ordering: 'feasible → permitted → best',
    floor: decl.floor || [],
    rungs: ['strategic', 'epistemic', 'deontic', 'temporal', 'reflexive', 'alethic', 'axiological']
  };
  if (provenance) certificate.provenance = provenance;

  return { admitted: true, certificate };
}

// ---------------------------------------------------------------------------
// exports
// ---------------------------------------------------------------------------
export default { validateShape, refuse, admit };
