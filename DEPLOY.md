# DEPLOY.md

Release runbook for publishing all `v0.1.0` artifacts in this repository:

1. `@ampersand-protocol/validate` to npm  
2. `ampersand-protocol` to PyPI  
3. `ampersand_core` to hex.pm  
4. VS Code extension to Marketplace as `@AmpersandBoxDesign`

---

## 0) Preflight (do this once)

- From repo root: `ProjectAmp2/AmpersandBoxDesign`
- Ensure clean git state: `git status`
- Ensure you are on the intended release commit/tag.
- Verify versions are `0.1.0`:
  - npm: `sdk/npm/validate/package.json` → `"version": "0.1.0"`
  - PyPI: `sdk/python/ampersand_protocol/pyproject.toml` → `version = "0.1.0"`
  - Hex: `reference/elixir/ampersand_core/mix.exs` → `version: "0.1.0"`
  - VS Code: `vscode/ampersand-json/package.json` → `"version": "0.1.0"`

---

## 1) Publish `@ampersand-protocol/validate` to npm (`v0.1.0`)

### Path
- `sdk/npm/validate`

### Commands
- `cd sdk/npm/validate`
- `npm ci`
- `npm test`
- `npm whoami` (must be logged in to the correct npm org/account)
- Dry run: `npm publish --access public --dry-run`
- Publish: `npm publish --access public`

### Verify
- `npm view @ampersand-protocol/validate version`
- Expected: `0.1.0`

---

## 2) Publish `ampersand-protocol` to PyPI (`v0.1.0`)

### Path
- `sdk/python/ampersand_protocol`

### Commands
- `cd sdk/python/ampersand_protocol`
- `python -m pip install --upgrade pip build twine`
- `python -m build`
- `python -m twine check dist/*`
- (Optional TestPyPI) `python -m twine upload --repository testpypi dist/*`
- Publish: `python -m twine upload dist/*`

### Verify
- `python -m pip index versions ampersand-protocol`
- Expected latest: `0.1.0`

---

## 3) Publish `ampersand_core` to hex.pm (`v0.1.0`)

### Path
- `reference/elixir/ampersand_core`

### Prerequisite (first-time Hex publish)
Before first publish, ensure package metadata is set in `mix.exs` under `project`:
- `description`
- `package` (at minimum: `licenses`, `links`, and maintainers as needed)

Without this metadata, `mix hex.publish` may fail validation.

### Commands
- `cd reference/elixir/ampersand_core`
- `mix deps.get`
- `mix test`
- `mix hex.info` (or authenticate first with `mix hex.user auth`)
- Dry run (optional): `mix hex.build`
- Publish package: `mix hex.publish`
- Publish docs (optional but recommended): `mix docs && mix hex.publish docs`

### Verify
- `mix hex.info ampersand_core`
- Expected version includes: `0.1.0`

---

## 4) Submit VS Code extension to Marketplace (`@AmpersandBoxDesign`)

### Path
- `vscode/ampersand-json`

### Important publisher note
Current extension manifest has `"publisher": "ampersand-protocol"`.  
If you want Marketplace publisher `AmpersandBoxDesign`, update:

- `vscode/ampersand-json/package.json`  
  - set `"publisher": "AmpersandBoxDesign"`

Publisher in manifest must match your Marketplace publisher ID.

### Commands
- `cd vscode/ampersand-json`
- `npm install`
- `npm install -g @vscode/vsce`
- `vsce --version`
- Create/login publisher in Azure DevOps + generate Personal Access Token (Marketplace publish scope).
- `vsce login AmpersandBoxDesign`
- Package check: `vsce package`
- Publish: `vsce publish 0.1.0`

### Verify
- Check extension listing in Visual Studio Marketplace.
- Confirm version is `0.1.0`.
- Confirm install from VS Code Extensions UI works.

---

## 5) Post-release checks

- Tag release commit: `git tag v0.1.0 && git push origin v0.1.0`
- Update changelog/release notes if applicable.
- Smoke-test installs:
  - npm: `npx @ampersand-protocol/validate --help`
  - PyPI: `pip install ampersand-protocol==0.1.0`
  - Hex: add `{:ampersand_core, "~> 0.1.0"}` in a test project and run `mix deps.get`
  - VS Code: install marketplace extension and validate `*.ampersand.json`

---

## Troubleshooting quick notes

- npm `403`/ownership errors: verify org/package access and `npm whoami`.
- PyPI upload conflict: version already exists; bump version and rebuild.
- Hex auth issues: rerun `mix hex.user auth`.
- VS Code publish fails on publisher mismatch: `package.json.publisher` must exactly match your publisher ID.