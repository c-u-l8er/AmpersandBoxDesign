# Ampersand JSON VS Code Extension

This extension provides editor-first support for [`*.ampersand.json`](../../examples) declarations in the [&] Protocol.

## What it adds

- JSON Schema validation for Ampersand declaration files
- Autocomplete for canonical declaration structure
- Inline validation errors in the editor
- Starter snippets for common capability bindings

---

## Extension folder

This README belongs to:

- `vscode/ampersand-json/`

Expected extension assets:

- `package.json`
- `schemas/ampersand.schema.json`
- `snippets/ampersand.code-snippets`

---

## Install (local development)

### 1) Open this extension folder in VS Code

From repository root:

```bash
code vscode/ampersand-json
```

### 2) Install dependencies (if any)

If `package.json` includes dependencies:

```bash
npm install
```

### 3) Run the extension in Development Host

- Press `F5` in VS Code
- This opens a new Extension Development Host window
- Open any `*.ampersand.json` file to verify schema validation is active

---

## Install as VSIX (manual)

### 1) Package extension

From `vscode/ampersand-json`:

```bash
npm install -g @vscode/vsce
vsce package
```

This generates a `.vsix` file.

### 2) Install in VS Code

- Open Command Palette
- Run: `Extensions: Install from VSIX...`
- Select generated `.vsix`

---

## Verify it works

Open one of the reference declarations:

- `examples/infra-operator.ampersand.json`
- `examples/fleet-manager.ampersand.json`
- `examples/research-agent.ampersand.json`
- `examples/customer-support.ampersand.json`

You should see:

- schema-backed hover/help text
- autocomplete for known fields
- inline errors on invalid keys/types

---

## Schema source of truth

The protocol schema is maintained at:

- `schema/v0.1.0/ampersand.schema.json`

The extension bundles a copy at:

- `vscode/ampersand-json/schemas/ampersand.schema.json`

When schema changes, sync the bundled copy before publishing.

---

## Publish (optional)

If publishing to Marketplace:

```bash
vsce login <publisher-id>
vsce publish
```

---

## Troubleshooting

### Schema not applied

- Confirm filename matches `*.ampersand.json`
- Check extension is enabled
- Reload window (`Developer: Reload Window`)

### Stale validation behavior

- Rebuild/reinstall VSIX after schema changes
- Ensure bundled schema path in `package.json` points to `schemas/ampersand.schema.json`

---

## Related project components

- Protocol docs: `docs/`
- Schema artifacts: `schema/v0.1.0/`
- Reference runtime: `reference/elixir/ampersand_core/`
