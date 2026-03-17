(() => {
  "use strict";

  // -----------------------------
  // Constants / defaults
  // -----------------------------
  const DEFAULT_DECLARATION = {
    $schema: "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
    agent: "InfraOperator",
    version: "1.0.0",
    capabilities: {
      "&memory.graph": {
        provider: "graphonomous",
        config: { instance: "infra-ops" },
      },
      "&time.anomaly": {
        provider: "ticktickclock",
        config: { streams: ["cpu", "mem"] },
      },
      "&reason.argument": {
        provider: "deliberatic",
        config: { governance: "constitutional" },
      },
    },
    pipelines: {
      incident_triage: {
        source_type: "stream_data",
        source_ref: "raw_data",
        steps: [
          { capability: "&time.anomaly", operation: "detect" },
          { capability: "&memory.graph", operation: "enrich" },
          { capability: "&reason.argument", operation: "evaluate" },
        ],
      },
    },
    governance: {
      hard: ["Never scale beyond 3x in a single action"],
      soft: ["Prefer gradual scaling over spikes"],
      escalate_when: { confidence_below: 0.7, cost_exceeds_usd: 1000 },
    },
    provenance: true,
  };

  const DEFAULT_PIPELINE =
    "stream_data |> &time.anomaly.detect() |> &memory.graph.enrich() |> &reason.argument.evaluate()";

  const REGISTRY = {
    "&memory": {
      providers: [
        {
          id: "graphonomous",
          subtypes: ["graph", "episodic"],
          protocol: "mcp_v1",
          transport: "stdio",
        },
        {
          id: "neo4j-memory",
          subtypes: ["graph"],
          protocol: "mcp_v1",
          transport: "custom",
        },
        {
          id: "pgvector",
          subtypes: ["vector"],
          protocol: "mcp_v1",
          transport: "custom",
        },
        {
          id: "weaviate",
          subtypes: ["vector"],
          protocol: "mcp_v1",
          transport: "custom",
        },
      ],
    },
    "&reason": {
      providers: [
        {
          id: "deliberatic",
          subtypes: ["argument", "plan", "vote"],
          protocol: "mcp_v1",
          transport: "custom",
        },
      ],
    },
    "&time": {
      providers: [
        {
          id: "ticktickclock",
          subtypes: ["anomaly", "forecast", "pattern"],
          protocol: "mcp_v1",
          transport: "custom",
        },
      ],
    },
    "&space": {
      providers: [
        {
          id: "geofleetic",
          subtypes: ["fleet", "route", "geofence"],
          protocol: "mcp_v1",
          transport: "custom",
        },
      ],
    },
  };

  // -----------------------------
  // DOM helpers
  // -----------------------------
  function byId(id) {
    return document.getElementById(id);
  }

  function firstExisting(ids) {
    for (const id of ids) {
      const el = byId(id);
      if (el) return el;
    }
    return null;
  }

  function ensureElement(id, tag, parent = document.body) {
    let el = byId(id);
    if (!el) {
      el = document.createElement(tag);
      el.id = id;
      parent.appendChild(el);
    }
    return el;
  }

  function setText(el, value) {
    if (!el) return;
    el.textContent =
      typeof value === "string" ? value : JSON.stringify(value, null, 2);
  }

  function setJSON(el, value) {
    setText(el, JSON.stringify(value, null, 2));
  }

  // -----------------------------
  // URL encode/decode (share links)
  // -----------------------------
  function base64UrlEncode(input) {
    const utf8 = new TextEncoder().encode(input);
    let binary = "";
    for (let i = 0; i < utf8.length; i += 1)
      binary += String.fromCharCode(utf8[i]);
    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "");
  }

  function base64UrlDecode(input) {
    const padded =
      input.replace(/-/g, "+").replace(/_/g, "/") +
      "===".slice((input.length + 3) % 4);
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return new TextDecoder().decode(bytes);
  }

  function encodeStateToHash(stateObj) {
    return "#" + base64UrlEncode(JSON.stringify(stateObj));
  }

  function decodeStateFromHash(hash) {
    try {
      if (!hash || hash.length < 2 || hash[0] !== "#") return null;
      const decoded = base64UrlDecode(hash.slice(1));
      const parsed = JSON.parse(decoded);
      if (!parsed || typeof parsed !== "object") return null;
      return parsed;
    } catch {
      return null;
    }
  }

  // -----------------------------
  // Schema validation
  // -----------------------------
  async function loadSchema() {
    const candidates = [
      "../protocol/schema/v0.1.0/ampersand.schema.json",
      "/protocol/schema/v0.1.0/ampersand.schema.json",
      "./protocol/schema/v0.1.0/ampersand.schema.json",
    ];

    for (const url of candidates) {
      try {
        const res = await fetch(url, { cache: "no-store" });
        if (!res.ok) continue;
        const data = await res.json();
        if (data && typeof data === "object") return data;
      } catch {
        // continue
      }
    }

    throw new Error("Unable to load protocol schema JSON");
  }

  function createAjvValidator(schema) {
    const g = window;
    let AjvCtor = null;
    let ajv = null;

    // Try common global exports depending on CDN bundle variant.
    if (g.Ajv2020) {
      AjvCtor = g.Ajv2020;
      ajv = new AjvCtor({ allErrors: true, strict: false });
    } else if (g.ajv2020 && typeof g.ajv2020.default === "function") {
      ajv = new g.ajv2020.default({ allErrors: true, strict: false });
    } else if (g.Ajv) {
      AjvCtor = g.Ajv;
      ajv = new AjvCtor({ allErrors: true, strict: false });
    }

    if (!ajv) {
      throw new Error(
        "AJV not found on window. Include an AJV script in index.html (Ajv2020 or Ajv global).",
      );
    }

    // Optional formats plugin support.
    if (typeof g.ajvFormats === "function") {
      try {
        g.ajvFormats(ajv);
      } catch {
        // non-fatal
      }
    }

    return ajv.compile(schema);
  }

  function formatAjvErrors(errors) {
    if (!Array.isArray(errors)) return [];
    return errors.map((err) =>
      `${err.instancePath || "/"} ${err.message || "schema error"}`.trim(),
    );
  }

  function createFallbackValidator() {
    const validate = (document) => {
      const errors = [];

      if (
        !document ||
        typeof document !== "object" ||
        Array.isArray(document)
      ) {
        errors.push({
          instancePath: "/",
          message: "must be an object",
        });
      } else {
        if (!document.$schema) {
          errors.push({ instancePath: "/$schema", message: "is required" });
        }
        if (!document.agent) {
          errors.push({ instancePath: "/agent", message: "is required" });
        }
        if (!document.version) {
          errors.push({ instancePath: "/version", message: "is required" });
        }
        if (
          !document.capabilities ||
          typeof document.capabilities !== "object" ||
          Array.isArray(document.capabilities)
        ) {
          errors.push({
            instancePath: "/capabilities",
            message: "must be an object",
          });
        }
      }

      validate.errors = errors;
      return errors.length === 0;
    };

    validate.errors = [];
    return validate;
  }

  // -----------------------------
  // Domain helpers
  // -----------------------------
  function stableStringify(value) {
    if (value === null || typeof value !== "object")
      return JSON.stringify(value);
    if (Array.isArray(value))
      return `[${value.map(stableStringify).join(",")}]`;
    const keys = Object.keys(value).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`).join(",")}}`;
  }

  function deepEqual(a, b) {
    return stableStringify(a) === stableStringify(b);
  }

  function getCapabilities(doc) {
    return doc &&
      typeof doc === "object" &&
      doc.capabilities &&
      typeof doc.capabilities === "object"
      ? doc.capabilities
      : {};
  }

  function composeCapabilities(documents) {
    const merged = {};
    const conflicts = [];

    for (const doc of documents) {
      const caps = getCapabilities(doc);
      for (const [capability, binding] of Object.entries(caps)) {
        if (!(capability in merged)) {
          merged[capability] = binding;
          continue;
        }
        if (!deepEqual(merged[capability], binding)) {
          conflicts.push({
            capability,
            existing: merged[capability],
            incoming: binding,
          });
        }
      }
    }

    return {
      ok: conflicts.length === 0,
      composed: merged,
      normalized: Object.keys(merged).sort(),
      conflicts,
    };
  }

  function parseCapability(capabilityId) {
    if (typeof capabilityId !== "string" || !capabilityId.startsWith("&"))
      return null;
    const parts = capabilityId.split(".");
    return {
      primitive: parts[0],
      subtype: parts[1] || null,
    };
  }

  function providersForCapability(capabilityId) {
    const parsed = parseCapability(capabilityId);
    if (!parsed) return [];

    const primitiveEntry = REGISTRY[parsed.primitive];
    if (!primitiveEntry || !Array.isArray(primitiveEntry.providers)) return [];

    if (!parsed.subtype) return [...primitiveEntry.providers];

    return primitiveEntry.providers.filter(
      (provider) =>
        Array.isArray(provider.subtypes) &&
        provider.subtypes.includes(parsed.subtype),
    );
  }

  function resolveProvider(capability, binding) {
    const explicit = binding && binding.provider;
    if (explicit !== "auto") {
      return {
        provider: explicit,
        provider_resolution: {
          status: "explicit",
          provider: explicit,
        },
      };
    }

    const candidates = providersForCapability(capability)
      .filter((p) => p && typeof p.id === "string")
      .sort((a, b) => a.id.localeCompare(b.id));

    if (candidates.length === 0) {
      return {
        provider: "auto",
        unresolved: {
          provider: "auto",
          capability,
          reason: `no registry provider found for capability ${capability}`,
        },
        provider_resolution: {
          status: "unresolved-auto",
          provider: "auto",
          capability,
          reason: `no registry provider found for capability ${capability}`,
        },
      };
    }

    const selected = candidates[0];
    return {
      provider: selected.id,
      provider_resolution: {
        status: "resolved-from-registry",
        provider: "auto",
        selected_provider: selected.id,
        protocol: selected.protocol || null,
        transport: selected.transport || null,
      },
    };
  }

  function buildMcpConfig(doc, format = "zed") {
    const caps = getCapabilities(doc);
    const grouped = {};
    const unresolved = [];

    for (const [capability, binding] of Object.entries(caps)) {
      const resolved = resolveProvider(capability, binding || {});
      if (resolved.unresolved) {
        unresolved.push(resolved.unresolved);
        continue;
      }
      if (!grouped[resolved.provider]) grouped[resolved.provider] = [];
      grouped[resolved.provider].push(capability);
    }

    const servers = {};
    for (const provider of Object.keys(grouped).sort()) {
      const capabilities = grouped[provider].sort();

      if (provider === "graphonomous") {
        servers[provider] = {
          command: "npx",
          args: [
            "-y",
            "graphonomous",
            "--db",
            "~/.graphonomous/knowledge.db",
            "--embedder-backend",
            "fallback",
          ],
          env: {
            GRAPHONOMOUS_EMBEDDING_MODEL:
              "sentence-transformers/all-MiniLM-L6-v2",
          },
          transport: "stdio",
          capabilities,
        };
        continue;
      }

      if (provider === "ticktickclock") {
        servers[provider] = {
          command: "npx",
          args: ["-y", "@ampersand-protocol/ticktickclock-mcp"],
          env: {},
          transport: "stdio",
          capabilities,
        };
        continue;
      }

      unresolved.push({
        provider,
        capability_count: capabilities.length,
        capabilities,
        reason: "no resolver implemented in playground",
      });
    }

    const rootKey = format === "generic" ? "mcpServers" : "context_servers";
    return {
      format: rootKey,
      config: { [rootKey]: servers },
      unresolved_providers: unresolved,
    };
  }

  function buildA2ACard(doc) {
    const caps = getCapabilities(doc);
    const skills = Object.keys(caps)
      .sort()
      .map((capability) => {
        const binding = caps[capability] || {};
        const prettyName = capability.replace(/^&/, "").replace(/\./g, " ");
        return {
          id: `${capability}.skill`,
          capability,
          name: prettyName.replace(/\b\w/g, (m) => m.toUpperCase()),
          provider: binding.provider || null,
          tags: ["ampersand", capability, binding.provider].filter(Boolean),
        };
      });

    return {
      protocol: "A2A",
      name: doc.agent || "UnknownAgent",
      version: doc.version || "0.0.0",
      skills,
      metadata: {
        capabilities: Object.keys(caps).sort(),
        providers: Array.from(
          new Set(
            Object.values(caps)
              .map((v) => v && v.provider)
              .filter(Boolean),
          ),
        ).sort(),
        governance: doc.governance || null,
        provenance: doc.provenance ?? null,
      },
    };
  }

  function parsePipelineExpression(pipelineText) {
    const expression = String(pipelineText || "").trim();
    if (!expression) {
      return { ok: false, errors: ["pipeline string cannot be empty"] };
    }

    const tokens = expression
      .split(/\s*\|>\s*/)
      .map((s) => s.trim())
      .filter(Boolean);
    if (tokens.length < 2) {
      return {
        ok: false,
        errors: ["pipeline must include source token and at least one step"],
      };
    }

    const source = tokens[0].startsWith("&") ? null : tokens[0];
    const stepTokens = source ? tokens.slice(1) : tokens;
    const steps = [];

    for (const token of stepTokens) {
      const clean = token.replace(/\(\)\s*$/, "");
      const parts = clean.split(".").filter(Boolean);
      if (parts.length < 3 || !parts[0].startsWith("&")) {
        return {
          ok: false,
          errors: [`invalid pipeline step ${JSON.stringify(token)}`],
        };
      }
      steps.push({
        capability: parts.slice(0, -1).join("."),
        operation: parts[parts.length - 1],
      });
    }

    return {
      ok: true,
      value: {
        source_type: source,
        source_ref: source || "raw_data",
        steps,
      },
    };
  }

  function checkPipelineAgainstDeclaration(doc, pipelineExpr) {
    const parsed = parsePipelineExpression(pipelineExpr);
    if (!parsed.ok) return parsed;

    const capabilities = getCapabilities(doc);
    const errors = [];

    parsed.value.steps.forEach((step, index) => {
      if (!capabilities[step.capability]) {
        errors.push(
          `step ${index + 1}: undeclared capability ${step.capability}`,
        );
      }
      if (!step.operation || typeof step.operation !== "string") {
        errors.push(`step ${index + 1}: invalid operation`);
      }
    });

    if (errors.length > 0) return { ok: false, errors };

    return {
      ok: true,
      value: {
        valid: true,
        source: {
          type: parsed.value.source_type || "stream_data",
          ref: parsed.value.source_ref || "raw_data",
        },
        step_count: parsed.value.steps.length,
        steps: parsed.value.steps,
      },
    };
  }

  // -----------------------------
  // App state / UI wiring
  // -----------------------------
  const state = {
    schema: null,
    validateFn: null,
    declaration: null,
    declarationText: "",
    pipelineText: "",
    validationErrors: [],
  };

  const ui = {
    declarationInput: null,
    pipelineInput: null,
    validationOut: null,
    composeOut: null,
    checkOut: null,
    mcpOut: null,
    a2aOut: null,
    urlOut: null,
    copyUrlBtn: null,
    statusOut: null,
  };

  function bindUi() {
    ui.declarationInput = firstExisting([
      "declaration-input",
      "declaration-editor",
      "editor",
      "ampersand-input",
    ]);
    ui.pipelineInput = firstExisting(["pipeline-input", "pipeline-editor"]);
    ui.validationOut = firstExisting(["validation-output", "validate-output"]);
    ui.composeOut = firstExisting(["compose-output"]);
    ui.checkOut = firstExisting(["check-output"]);
    ui.mcpOut = firstExisting(["mcp-output"]);
    ui.a2aOut = firstExisting(["a2a-output"]);
    ui.urlOut = firstExisting(["share-url-output", "url-output"]);
    ui.copyUrlBtn = firstExisting(["copy-share-url", "copy-url-btn"]);
    ui.statusOut = firstExisting(["status-output", "status"]);

    // Create minimal fallback UI if page has no expected elements.
    if (!ui.declarationInput) {
      const container = ensureElement("playground-fallback", "div");
      container.style.padding = "16px";

      ui.declarationInput = ensureElement(
        "declaration-input",
        "textarea",
        container,
      );
      ui.declarationInput.style.width = "100%";
      ui.declarationInput.style.minHeight = "220px";

      ui.pipelineInput = ensureElement("pipeline-input", "input", container);
      ui.pipelineInput.style.width = "100%";
      ui.pipelineInput.style.marginTop = "8px";

      ui.statusOut = ensureElement("status-output", "pre", container);
      ui.validationOut = ensureElement("validation-output", "pre", container);
      ui.composeOut = ensureElement("compose-output", "pre", container);
      ui.checkOut = ensureElement("check-output", "pre", container);
      ui.mcpOut = ensureElement("mcp-output", "pre", container);
      ui.a2aOut = ensureElement("a2a-output", "pre", container);
      ui.urlOut = ensureElement("url-output", "pre", container);
    }

    if (!ui.pipelineInput) {
      ui.pipelineInput = ensureElement(
        "pipeline-input",
        "input",
        ui.declarationInput.parentElement || document.body,
      );
      ui.pipelineInput.style.width = "100%";
      ui.pipelineInput.style.marginTop = "8px";
    }
  }

  function setStatus(message, kind = "info") {
    if (!ui.statusOut) return;
    ui.statusOut.textContent = message;
    ui.statusOut.dataset.kind = kind;
  }

  function loadInitialState() {
    const fromHash = decodeStateFromHash(location.hash);
    if (fromHash && typeof fromHash === "object") {
      const declaration =
        typeof fromHash.declaration === "object" &&
        fromHash.declaration !== null
          ? fromHash.declaration
          : DEFAULT_DECLARATION;
      const pipeline =
        typeof fromHash.pipeline === "string"
          ? fromHash.pipeline
          : DEFAULT_PIPELINE;

      state.declaration = declaration;
      state.declarationText = JSON.stringify(declaration, null, 2);
      state.pipelineText = pipeline;
      return;
    }

    state.declaration = DEFAULT_DECLARATION;
    state.declarationText = JSON.stringify(DEFAULT_DECLARATION, null, 2);
    state.pipelineText = DEFAULT_PIPELINE;
  }

  function writeCurrentUrlState() {
    const shareState = {
      declaration: state.declaration,
      pipeline: state.pipelineText,
    };
    const hash = encodeStateToHash(shareState);
    if (location.hash !== hash) {
      history.replaceState(null, "", hash);
    }

    const fullUrl = location.origin + location.pathname + hash;
    setText(ui.urlOut, fullUrl);
  }

  function validateCurrentDeclaration() {
    const raw = state.declarationText;
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (err) {
      state.declaration = null;
      state.validationErrors = [`JSON parse error: ${err.message}`];
      return false;
    }

    if (!state.validateFn) {
      state.validateFn = createFallbackValidator();
    }

    const valid = state.validateFn(parsed);
    state.declaration = parsed;
    state.validationErrors = valid
      ? []
      : formatAjvErrors(state.validateFn.errors);
    return valid;
  }

  function render() {
    const valid = validateCurrentDeclaration();

    if (valid) {
      setJSON(ui.validationOut, { status: "ok", valid: true });
    } else {
      setJSON(ui.validationOut, {
        status: "error",
        valid: false,
        errors: state.validationErrors,
      });
    }

    if (!state.declaration || !valid) {
      setJSON(ui.composeOut, {
        status: "skipped",
        reason: "declaration invalid",
      });
      setJSON(ui.checkOut, {
        status: "skipped",
        reason: "declaration invalid",
      });
      setJSON(ui.mcpOut, { status: "skipped", reason: "declaration invalid" });
      setJSON(ui.a2aOut, { status: "skipped", reason: "declaration invalid" });
      setStatus("Invalid declaration", "error");
      writeCurrentUrlState();
      return;
    }

    const compose = composeCapabilities([state.declaration]);
    setJSON(ui.composeOut, {
      status: compose.ok ? "ok" : "error",
      capability_count: compose.normalized.length,
      capabilities: compose.normalized,
      conflicts: compose.conflicts,
    });

    const checked = checkPipelineAgainstDeclaration(
      state.declaration,
      state.pipelineText,
    );
    setJSON(
      ui.checkOut,
      checked.ok
        ? { status: "ok", ...checked.value }
        : { status: "error", errors: checked.errors },
    );

    const mcp = buildMcpConfig(state.declaration, "zed");
    setJSON(ui.mcpOut, mcp);

    const a2a = buildA2ACard(state.declaration);
    setJSON(ui.a2aOut, a2a);

    setStatus("Valid declaration", "ok");
    writeCurrentUrlState();
  }

  function debounce(fn, delay = 220) {
    let timer = null;
    return (...args) => {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => fn(...args), delay);
    };
  }

  function wireEvents() {
    const reRender = debounce(render, 180);

    ui.declarationInput.addEventListener("input", () => {
      state.declarationText = ui.declarationInput.value;
      reRender();
    });

    ui.pipelineInput.addEventListener("input", () => {
      state.pipelineText = ui.pipelineInput.value;
      reRender();
    });

    if (ui.copyUrlBtn) {
      ui.copyUrlBtn.addEventListener("click", async () => {
        const value = (ui.urlOut && ui.urlOut.textContent) || location.href;
        try {
          await navigator.clipboard.writeText(value);
          setStatus("Share URL copied to clipboard", "ok");
        } catch {
          setStatus("Unable to copy URL (clipboard permission denied)", "warn");
        }
      });
    }

    window.addEventListener("hashchange", () => {
      const parsed = decodeStateFromHash(location.hash);
      if (!parsed) return;

      if (parsed.declaration && typeof parsed.declaration === "object") {
        state.declaration = parsed.declaration;
        state.declarationText = JSON.stringify(parsed.declaration, null, 2);
        ui.declarationInput.value = state.declarationText;
      }

      if (typeof parsed.pipeline === "string") {
        state.pipelineText = parsed.pipeline;
        ui.pipelineInput.value = parsed.pipeline;
      }

      render();
    });
  }

  async function init() {
    bindUi();
    loadInitialState();

    ui.declarationInput.value = state.declarationText;
    ui.pipelineInput.value = state.pipelineText;

    setStatus("Loading schema...", "info");

    try {
      state.schema = await loadSchema();
      state.validateFn = createAjvValidator(state.schema);
      setStatus("Schema loaded", "ok");
    } catch (err) {
      state.validateFn = createFallbackValidator();
      setStatus(
        `Schema load error: ${err.message || String(err)}. Using fallback validator.`,
        "warn",
      );
    }

    wireEvents();
    render();
  }

  // Boot
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
