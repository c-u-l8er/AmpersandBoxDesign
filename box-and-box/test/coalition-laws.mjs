// test/coalition-laws.mjs — run: `node test/coalition-laws.mjs`
// CC2 coalition runtime conformance: the coalition schema's clauses are enforced, not assumed.
// Same property-test harness as the 103 core + 13 compose laws: trial(n,body) returns true or
// a counter-example tag; N=2000 trials/law; exit(fail?1:0).
//
// Laws:
//   CO1  — shape: schema-valid declarations admit; invalid ones are refused by clause name
//   CO2  — agents/adversary: membership disjointness enforced
//   CO3  — ensure: decided via strategic.canEnsure, not assumed; missing game → named refusal
//   CO4  — common_knowledge: decided via epistemic.common; missing model → named refusal
//   CO5  — owns: every owner must be a coalition member
//   CO6  — shield: safety checked over joint trajectories; violation → refusal by shield name
//   CO7  — shield: liveness checked at horizon over joint trajectories; unmet → refusal
//   CO8  — floor: entrenched via reflexive; missing norms → named refusal
//   CO9  — compose: pipeline annihilation → refusal; successful → admitted
//   CO10 — provenance: when requested, certificate includes hash-linked records
//   CO11 — fail-closed: undecidable clauses refuse and name the missing substrate
//   CO12 — certificate preserves floor-then-gradient ordering
//   CO13 — ensure: canEnsure is the strategic rung's ability, not an assumption

import { admit, validateShape } from '../coalition.mjs';
import * as strategic from '../strategic.mjs';
import * as epistemic from '../epistemic.mjs';
import * as temporal from '../temporal.mjs';
import { TemporalSpec } from '../supervise.mjs';
import { Norm } from '../norm.mjs';
import { Brick, isZero, composePipe } from '../compose.mjs';
import { V, V0 } from '../value.mjs';
import { verify as evoVerify, GENESIS } from '../evolution.mjs';

const SCHEMA_URI = 'https://protocol.ampersandboxdesign.com/schema/v0.1.0/coalition.schema.json';
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[(Math.random() * arr.length) | 0];

// ---------------------------------------------------------------------------
// test-fixture builders
// ---------------------------------------------------------------------------

// A minimal 2-state game where coalition [agents] can force goal from s0
function winGame(agents, adversary) {
  const allAgents = [...agents, ...adversary];
  const states = ['s0', 's1'];
  return strategic.Game({
    states,
    agents: allAgents,
    moves: () => ['go'],
    delta: () => 's1' // every joint move → s1 (the goal state)
  });
}

// A game where agents CANNOT force goal from s0 (adversary can prevent it)
function loseGame(agents, adversary) {
  const allAgents = [...agents, ...adversary];
  const states = ['s0', 's1', 's2'];
  return strategic.Game({
    states,
    agents: allAgents,
    moves: (agent, state) => {
      if (adversary.includes(agent)) return ['block', 'allow'];
      return ['try'];
    },
    delta: (state, moves) => {
      // adversary can block: if any adversary blocks, go to s2 (not goal)
      for (const a of adversary) {
        if (moves[a] === 'block') return 's2';
      }
      return 's1';
    }
  });
}

const goalFormula = strategic.atom('goal', (s) => s === 's1');

// A minimal epistemic model where all agents have common knowledge of a fact
function commonModel(agents, facts) {
  const worlds = ['w0'];
  const access = {};
  for (const a of agents) access[a] = () => ['w0']; // reflexive: everyone sees w0
  return epistemic.Model({ worlds, actual: 'w0', access });
}

// A model where fact is NOT common knowledge
function noCommonModel(agents) {
  const worlds = ['w0', 'w1'];
  const access = {};
  // First agent sees both worlds, others see only w0
  for (let i = 0; i < agents.length; i++) {
    if (i === 0) access[agents[i]] = (w) => ['w0', 'w1'];
    else access[agents[i]] = (w) => ['w0'];
  }
  return epistemic.Model({ worlds, actual: 'w0', access });
}

// Valid base declaration
function baseDecl(overrides = {}) {
  return {
    $schema: SCHEMA_URI,
    coalition: 'testCoalition',
    version: '0.1.0',
    agents: ['a', 'b'],
    ensure: 'the_goal',
    ...overrides
  };
}

// Minimal evidence that makes baseDecl admissible (ensure only)
function baseEvidence(agents = ['a', 'b'], adversary = []) {
  return {
    game: winGame(agents, adversary),
    initialState: 's0',
    goal: goalFormula
  };
}

// A certified-poly cost cert for bricks
const freeCost = () => ({
  subject: { kind: 'weave-ir', hash: '00000000' },
  analyzer: { name: 'identity', version: '0' },
  verdict: { certified: true, total: true, oracleFree: true, costClass: 'poly' },
  policy: { resourceDecision: 'allow', reason: 'test' }
});

function trial(n, body) {
  for (let i = 0; i < n; i++) {
    const r = body();
    if (r !== true) return { pass: false, cex: r, at: i + 1 };
  }
  return { pass: true, at: n };
}

// ---------------------------------------------------------------------------
// CO1 — shape validation: valid declarations pass; invalid ones are refused by clause name
// ---------------------------------------------------------------------------
const SHAPE = [
  ['CO1', 'shape: valid declarations admit; invalid refused by clause', (n) => trial(n, () => {
    // valid minimal
    const valid = admit(baseDecl(), baseEvidence());
    if (!valid.admitted) return 'valid-rejected';

    // missing $schema
    const r1 = admit({ coalition: 'x', version: '0.1.0', agents: ['a'], ensure: 'g' });
    if (r1.admitted || r1.refused !== '$schema') return 'no-schema-not-caught';

    // bad coalition name
    const r2 = admit({ ...baseDecl(), coalition: '123bad' });
    if (r2.admitted || r2.refused !== 'coalition') return 'bad-coalition-not-caught';

    // bad version
    const r3 = admit({ ...baseDecl(), version: 'nope' });
    if (r3.admitted || r3.refused !== 'version') return 'bad-version-not-caught';

    // empty agents
    const r4 = admit({ ...baseDecl(), agents: [] });
    if (r4.admitted || r4.refused !== 'agents') return 'empty-agents-not-caught';

    // duplicate agents
    const r5 = admit({ ...baseDecl(), agents: ['a', 'a'] });
    if (r5.admitted || r5.refused !== 'agents') return 'dup-agents-not-caught';

    // empty ensure
    const r6 = admit({ ...baseDecl(), ensure: '' });
    if (r6.admitted || r6.refused !== 'ensure') return 'empty-ensure-not-caught';

    // unknown property
    const r7 = admit({ ...baseDecl(), unknownProp: true });
    if (r7.admitted) return 'unknown-prop-not-caught';

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO2 — agents/adversary disjointness
// ---------------------------------------------------------------------------
const MEMBERSHIP = [
  ['CO2', 'agents/adversary membership disjointness', (n) => trial(n, () => {
    const agents = ['a', 'b'];
    const adversary = ['b', 'c']; // 'b' overlaps
    const decl = baseDecl({ agents, adversary });
    const r = admit(decl, baseEvidence(agents, []));
    if (r.admitted) return 'overlap-admitted';
    if (r.refused !== 'adversary') return `wrong-clause: ${r.refused}`;

    // disjoint case should not fail on this clause
    const decl2 = baseDecl({ agents, adversary: ['c', 'd'] });
    const r2 = admit(decl2, baseEvidence(agents, ['c', 'd']));
    if (!r2.admitted) return `disjoint-failed: ${r2.refused}: ${r2.reason}`;
    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO3 — ensure: decided via strategic.canEnsure
// ---------------------------------------------------------------------------
const ENSURE = [
  ['CO3', 'ensure: decided via strategic.canEnsure, not assumed', (n) => trial(n, () => {
    const agents = ['a', 'b'];
    const adversary = ['env'];

    // Case 1: coalition CAN ensure → admitted
    const decl1 = baseDecl({ agents, adversary });
    const r1 = admit(decl1, {
      game: winGame(agents, adversary),
      initialState: 's0',
      goal: goalFormula
    });
    if (!r1.admitted) return `can-ensure-rejected: ${r1.reason}`;

    // Case 2: coalition CANNOT ensure → refused on 'ensure'
    const decl2 = baseDecl({ agents, adversary });
    const r2 = admit(decl2, {
      game: loseGame(agents, adversary),
      initialState: 's0',
      goal: goalFormula
    });
    if (r2.admitted) return 'cannot-ensure-admitted';
    if (r2.refused !== 'ensure') return `wrong-clause: ${r2.refused}`;

    return true;
  })],
  ['CO13', 'ensure: canEnsure is ability calculation, not assumption', (n) => trial(n, () => {
    // Ensure is decided through the strategic rung's canEnsure ability calculation
    // against all non-members from an explicit game
    const agents = ['ctrl'];
    const adversary = ['env'];
    const allAgents = [...agents, ...adversary];

    // Build a game where ctrl alone can't ensure, but ctrl+env together can
    const game = strategic.Game({
      states: ['s0', 's1', 's2'],
      agents: allAgents,
      moves: (agent, state) => agent === 'ctrl' ? ['a'] : ['block', 'pass'],
      delta: (state, moves) => moves.env === 'block' ? 's2' : 's1'
    });

    // ctrl alone cannot ensure against env
    const r1 = admit(
      baseDecl({ agents, adversary }),
      { game, initialState: 's0', goal: goalFormula }
    );
    if (r1.admitted) return 'solo-should-fail';
    if (r1.refused !== 'ensure') return `wrong-clause: ${r1.refused}`;

    // With no adversary (CC1 case), ctrl can trivially ensure
    const game2 = strategic.Game({
      states: ['s0', 's1'],
      agents: ['ctrl'],
      moves: () => ['go'],
      delta: () => 's1'
    });
    const r2 = admit(
      baseDecl({ agents: ['ctrl'], ensure: 'the_goal' }),
      { game: game2, initialState: 's0', goal: goalFormula }
    );
    if (!r2.admitted) return `cc1-should-pass: ${r2.reason}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO4 — common_knowledge: decided via epistemic.common
// ---------------------------------------------------------------------------
const COMMON = [
  ['CO4', 'common_knowledge: decided via epistemic.common; missing model → named refusal', (n) => trial(n, () => {
    const agents = ['a', 'b'];
    const factFormula = epistemic.atom('release_plan', () => true);

    // Case 1: common knowledge holds → admitted
    const decl1 = baseDecl({ agents, common_knowledge: ['release_plan'] });
    const r1 = admit(decl1, {
      ...baseEvidence(agents),
      model: commonModel(agents),
      formulas: { release_plan: factFormula }
    });
    if (!r1.admitted) return `ck-holds-rejected: ${r1.reason}`;

    // Case 2: NOT common knowledge → refused on 'common_knowledge'
    const notCommonFormula = epistemic.atom('secret', (w) => w === 'w1'); // only true in w1
    const decl2 = baseDecl({ agents, common_knowledge: ['secret'] });
    const r2 = admit(decl2, {
      ...baseEvidence(agents),
      model: noCommonModel(agents),
      formulas: { secret: notCommonFormula }
    });
    if (r2.admitted) return 'not-common-admitted';
    if (r2.refused !== 'common_knowledge') return `wrong-clause: ${r2.refused}`;

    // Case 3: missing model → named refusal
    const decl3 = baseDecl({ agents, common_knowledge: ['plan'] });
    const r3 = admit(decl3, baseEvidence(agents));
    if (r3.admitted) return 'missing-model-admitted';
    if (r3.refused !== 'common_knowledge') return `wrong-clause: ${r3.refused}`;
    if (!r3.missing) return 'no-missing-named';

    // Case 4: missing formula for a fact → named refusal
    const decl4 = baseDecl({ agents, common_knowledge: ['plan'] });
    const r4 = admit(decl4, {
      ...baseEvidence(agents),
      model: commonModel(agents),
      formulas: {} // no formula for 'plan'
    });
    if (r4.admitted) return 'missing-formula-admitted';
    if (r4.refused !== 'common_knowledge') return `wrong-clause: ${r4.refused}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO5 — owns: every owner must be a coalition member
// ---------------------------------------------------------------------------
const OWNS = [
  ['CO5', 'owns: every owner must be a coalition member', (n) => trial(n, () => {
    const agents = ['dev', 'qa'];

    // valid owns
    const decl1 = baseDecl({ agents, owns: { dev: 'build', qa: 'test' } });
    const r1 = admit(decl1, baseEvidence(agents));
    if (!r1.admitted) return `valid-owns-rejected: ${r1.reason}`;

    // non-member owner
    const decl2 = baseDecl({ agents, owns: { dev: 'build', ops: 'deploy' } });
    const r2 = admit(decl2, baseEvidence(agents));
    if (r2.admitted) return 'non-member-owner-admitted';
    if (r2.refused !== 'owns') return `wrong-clause: ${r2.refused}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO6 — shield: safety checked over joint trajectories
// ---------------------------------------------------------------------------
const SHIELD = [
  ['CO6', 'shield: safety violation on joint trajectory → refusal by shield name', (n) => trial(n, () => {
    const agents = ['a', 'b'];
    const safetyFormula = temporal.always(temporal.atom('no_leak', (s) => !s.leaked));

    // safe trajectory → admitted
    const safeTraj = [{ leaked: false }, { leaked: false }, { leaked: false }];
    const decl1 = baseDecl({ agents, shield: ['NEVER secrets_leaked'] });
    const r1 = admit(decl1, {
      ...baseEvidence(agents),
      shieldSpecs: [{ id: 'NEVER_secrets_leaked', formula: safetyFormula, kind: 'safety' }],
      trajectories: [safeTraj]
    });
    if (!r1.admitted) return `safe-rejected: ${r1.reason}`;

    // unsafe trajectory → refused on 'shield'
    const unsafeTraj = [{ leaked: false }, { leaked: true }, { leaked: false }];
    const r2 = admit(decl1, {
      ...baseEvidence(agents),
      shieldSpecs: [{ id: 'NEVER_secrets_leaked', formula: safetyFormula, kind: 'safety' }],
      trajectories: [safeTraj, unsafeTraj] // includes reachable alternative
    });
    if (r2.admitted) return 'unsafe-admitted';
    if (r2.refused !== 'shield') return `wrong-clause: ${r2.refused}`;

    return true;
  })],
  ['CO7', 'shield: liveness unmet at horizon on joint trajectory → refusal', (n) => trial(n, () => {
    const agents = ['a', 'b'];
    const livenessFormula = temporal.eventually(temporal.atom('done', (s) => s.done));

    // liveness met → admitted
    const metTraj = [{ done: false }, { done: true }];
    const decl = baseDecl({ agents, shield: ['EVENTUALLY done'] });
    const r1 = admit(decl, {
      ...baseEvidence(agents),
      shieldSpecs: [{ id: 'EVENTUALLY_done', formula: livenessFormula, kind: 'liveness' }],
      trajectories: [metTraj]
    });
    if (!r1.admitted) return `liveness-met-rejected: ${r1.reason}`;

    // liveness unmet at horizon → refused
    const unmetTraj = [{ done: false }, { done: false }, { done: false }];
    const r2 = admit(decl, {
      ...baseEvidence(agents),
      shieldSpecs: [{ id: 'EVENTUALLY_done', formula: livenessFormula, kind: 'liveness' }],
      trajectories: [unmetTraj]
    });
    if (r2.admitted) return 'liveness-unmet-admitted';
    if (r2.refused !== 'shield') return `wrong-clause: ${r2.refused}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO8 — floor: entrenched via reflexive
// ---------------------------------------------------------------------------
const FLOOR = [
  ['CO8', 'floor: entrenched via reflexive; missing norms → named refusal', (n) => trial(n, () => {
    const agents = ['a', 'b'];

    // with floor norms → admitted
    const floorNorm = Norm({ id: 'no_prod_without_qa', modality: 'forbidden', priority: 100 });
    const decl1 = baseDecl({ agents, floor: ['entrench: no_prod_without_qa'] });
    const r1 = admit(decl1, {
      ...baseEvidence(agents),
      floorNorms: [floorNorm]
    });
    if (!r1.admitted) return `floor-rejected: ${r1.reason}`;

    // without floor norms → named refusal
    const r2 = admit(decl1, baseEvidence(agents));
    if (r2.admitted) return 'missing-floor-admitted';
    if (r2.refused !== 'floor') return `wrong-clause: ${r2.refused}`;
    if (!r2.missing) return 'no-missing-named';

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO9 — compose: pipeline annihilation → refusal
// ---------------------------------------------------------------------------
const COMPOSE = [
  ['CO9', 'compose: pipeline annihilation → refusal; successful → admitted', (n) => trial(n, () => {
    const agents = ['a', 'b'];

    // valid pipeline
    const b1 = Brick({ id: 'build', value: V({ beta: 0.9, kappa: false, sigma: [], pi: 'retrieve' }),
      cost: freeCost(), contract: { accepts_from: '*', feeds_into: '*' } });
    const b2 = Brick({ id: 'verify', value: V({ beta: 0.9, kappa: false, sigma: [], pi: 'act' }),
      cost: freeCost(), contract: { accepts_from: '*', feeds_into: '*' } });
    const decl1 = baseDecl({ agents, compose: 'build |> verify' });
    const r1 = admit(decl1, {
      ...baseEvidence(agents),
      bricks: [b1, b2]
    });
    if (!r1.admitted) return `compose-rejected: ${r1.reason}`;

    // backward pipeline (act before retrieve) → annihilation → refusal
    const b3 = Brick({ id: 'step1', value: V({ beta: 0.9, kappa: false, sigma: [], pi: 'act' }),
      cost: freeCost(), contract: { accepts_from: '*', feeds_into: '*' } });
    const b4 = Brick({ id: 'step2', value: V({ beta: 0.9, kappa: false, sigma: [], pi: 'retrieve' }),
      cost: freeCost(), contract: { accepts_from: '*', feeds_into: '*' } });
    const decl2 = baseDecl({ agents, compose: 'step1 |> step2' });
    const r2 = admit(decl2, {
      ...baseEvidence(agents),
      bricks: [b3, b4]
    });
    if (r2.admitted) return 'backward-compose-admitted';
    if (r2.refused !== 'compose') return `wrong-clause: ${r2.refused}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO10 — provenance: hash-linked records in certificate
// ---------------------------------------------------------------------------
const PROVENANCE = [
  ['CO10', 'provenance: certificate includes hash-linked records when requested', (n) => trial(n, () => {
    const agents = ['a', 'b'];

    // without provenance flag
    const decl1 = baseDecl({ agents });
    const r1 = admit(decl1, baseEvidence(agents));
    if (!r1.admitted) return `base-rejected: ${r1.reason}`;
    if (r1.certificate.provenance) return 'provenance-present-when-not-requested';

    // with provenance flag
    const decl2 = baseDecl({ agents, provenance: true });
    const r2 = admit(decl2, baseEvidence(agents));
    if (!r2.admitted) return `prov-rejected: ${r2.reason}`;
    if (!r2.certificate.provenance) return 'provenance-missing';
    if (!r2.certificate.provenance.records || r2.certificate.provenance.records.length < 1) return 'no-records';
    if (!r2.certificate.provenance.verified) return 'provenance-not-verified';

    // verify the chain independently
    const v = evoVerify(r2.certificate.provenance.records, GENESIS);
    if (!v.ok) return `chain-broken: ${v.reason}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO11 — fail-closed: missing evidence → named refusal
// ---------------------------------------------------------------------------
const FAILCLOSED = [
  ['CO11', 'fail-closed: undecidable clauses refuse and name the missing substrate', (n) => trial(n, () => {
    const agents = ['a', 'b'];

    // ensure without game
    const r1 = admit(baseDecl({ agents }), {});
    if (r1.admitted) return 'no-game-admitted';
    if (r1.refused !== 'ensure') return `wrong-clause: ${r1.refused}`;
    if (r1.missing !== 'game') return `wrong-missing: ${r1.missing}`;

    // ensure without initialState
    const r2 = admit(baseDecl({ agents }), { game: winGame(agents, []) });
    if (r2.admitted) return 'no-init-admitted';
    if (r2.refused !== 'ensure') return `wrong-clause: ${r2.refused}`;
    if (r2.missing !== 'initialState') return `wrong-missing: ${r2.missing}`;

    // ensure without goal formula
    const r3 = admit(baseDecl({ agents }), { game: winGame(agents, []), initialState: 's0' });
    if (r3.admitted) return 'no-goal-admitted';
    if (r3.refused !== 'ensure') return `wrong-clause: ${r3.refused}`;
    if (r3.missing !== 'goal') return `wrong-missing: ${r3.missing}`;

    // shield without shieldSpecs
    const decl4 = baseDecl({ agents, shield: ['NEVER bad'] });
    const r4 = admit(decl4, baseEvidence(agents));
    if (r4.admitted) return 'no-shield-specs-admitted';
    if (r4.refused !== 'shield') return `wrong-clause: ${r4.refused}`;
    if (r4.missing !== 'shieldSpecs') return `wrong-missing: ${r4.missing}`;

    // shield without trajectories
    const safetyF = temporal.always(temporal.atom('ok', () => true));
    const decl5 = baseDecl({ agents, shield: ['NEVER bad'] });
    const r5 = admit(decl5, {
      ...baseEvidence(agents),
      shieldSpecs: [{ id: 's1', formula: safetyF, kind: 'safety' }]
    });
    if (r5.admitted) return 'no-traj-admitted';
    if (r5.refused !== 'shield') return `wrong-clause: ${r5.refused}`;
    if (r5.missing !== 'trajectories') return `wrong-missing: ${r5.missing}`;

    // compose without bricks
    const decl6 = baseDecl({ agents, compose: 'a |> b' });
    const r6 = admit(decl6, baseEvidence(agents));
    if (r6.admitted) return 'no-bricks-admitted';
    if (r6.refused !== 'compose') return `wrong-clause: ${r6.refused}`;
    if (r6.missing !== 'bricks') return `wrong-missing: ${r6.missing}`;

    return true;
  })]
];

// ---------------------------------------------------------------------------
// CO12 — certificate preserves floor-then-gradient ordering
// ---------------------------------------------------------------------------
const ORDERING = [
  ['CO12', 'certificate preserves floor-then-gradient feasible → permitted → best ordering', (n) => trial(n, () => {
    const agents = ['a', 'b'];
    const r = admit(baseDecl({ agents }), baseEvidence(agents));
    if (!r.admitted) return `rejected: ${r.reason}`;
    if (r.certificate.ordering !== 'feasible → permitted → best') return `wrong-ordering: ${r.certificate.ordering}`;

    // The certificate's rungs list includes the rungs used
    if (!Array.isArray(r.certificate.rungs)) return 'no-rungs';
    if (!r.certificate.rungs.includes('strategic')) return 'missing-strategic';

    return true;
  })]
];

// ---------------------------------------------------------------------------
// harness
// ---------------------------------------------------------------------------
function runSet(laws, N) {
  let pass = 0, fail = 0;
  const results = [];
  for (const [id, desc, fn] of laws) {
    const r = fn(N);
    results.push({ id, desc, pass: r.pass, cex: r.cex, at: r.at });
    if (r.pass) pass++;
    else fail++;
  }
  return { pass, fail, results };
}

const SUITES = [
  { key: 'SHAPE',      label: 'Schema shape (CO1)',                           laws: SHAPE },
  { key: 'MEMBER',     label: 'Membership (CO2)',                             laws: MEMBERSHIP },
  { key: 'ENSURE',     label: 'Ensure / strategic ability (CO3, CO13)',        laws: ENSURE },
  { key: 'COMMON',     label: 'Common knowledge / epistemic (CO4)',            laws: COMMON },
  { key: 'OWNS',       label: 'Task ownership / deontic (CO5)',               laws: OWNS },
  { key: 'SHIELD',     label: 'Shield / temporal joint trajectory (CO6–CO7)',  laws: SHIELD },
  { key: 'FLOOR',      label: 'Floor / reflexive entrenchment (CO8)',          laws: FLOOR },
  { key: 'COMPOSE',    label: 'Compose / pipeline (CO9)',                      laws: COMPOSE },
  { key: 'PROV',       label: 'Provenance (CO10)',                             laws: PROVENANCE },
  { key: 'FAILCLOSE',  label: 'Fail-closed (CO11)',                            laws: FAILCLOSED },
  { key: 'ORDER',      label: 'Ordering (CO12)',                               laws: ORDERING }
];

export { SUITES, runSet };

if (typeof process !== 'undefined' && typeof window === 'undefined') {
  const N = 2000;
  let totalLaws = 0;
  for (const suite of SUITES) totalLaws += suite.laws.length;
  console.log(`\ncoalition-runtime law harness · ${N} trials/law · ${totalLaws} laws\n${'─'.repeat(56)}`);
  let totalFail = 0;
  for (const suite of SUITES) {
    const r = runSet(suite.laws, N);
    console.log(`${suite.label}: ${r.pass}/${suite.laws.length} pass${r.fail ? ', ' + r.fail + ' fail' : ''}`);
    r.results.filter((x) => !x.pass).forEach((x) => console.log(`  ✗ ${x.id} ${x.desc} — ${x.cex} @trial ${x.at}`));
    totalFail += r.fail;
  }
  console.log('─'.repeat(56));
  console.log(totalFail === 0 ? `✓ all ${totalLaws} coalition laws hold.\n` : `✗ ${totalFail} law(s) failed.\n`);
  process.exit(totalFail === 0 ? 0 : 1);
}
