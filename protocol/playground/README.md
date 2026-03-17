# Ampersand Playground

This directory contains a lightweight web playground for the [&] Protocol.

The playground is designed to let you:

- edit an `ampersand.json` declaration quickly
- validate it against the schema
- view normalized capability composition output
- preview generated MCP/A2A-style artifacts
- share scenarios via URL state (if enabled in the app)

---

## Prerequisites

You only need one of the following to serve static files locally:

- Python 3
- Node.js (with any static file server)
- Any local web server you already use

---

## Run locally

From the repository root (`ProjectAmp2/AmpersandBoxDesign`), choose one option.

### Option 1: Python (quickest)

```bash
python3 -m http.server 8080
```

Then open:

- `http://localhost:8080/playground/`

### Option 2: Node.js (`npx serve`)

```bash
npx serve . -l 8080
```

Then open:

- `http://localhost:8080/playground/`

---

## Expected folder layout

This README assumes the playground assets are in:

- `playground/index.html`
- `playground/app.js`
- `playground/styles.css`

And that schema/artifacts are available at repository-relative paths such as:

- `protocol/schema/v0.1.0/ampersand.schema.json`
- `protocol/registry/v0.1.0/capabilities.registry.json`

---

## Development notes

- Keep the playground static-first (no backend required).
- Avoid hardcoding absolute filesystem paths.
- Prefer repository-relative fetch paths so local and hosted previews behave the same.
- If you add new protocol fields, update both:
  - runtime/schema artifacts
  - playground rendering/validation logic

---

## Troubleshooting

### Blank page or missing assets
- Confirm you opened the served URL, not a `file://` path.
- Check browser DevTools console for missing script/style files.

### Validation not loading
- Verify `protocol/schema/v0.1.0/ampersand.schema.json` is reachable from the served root.
- Confirm your local server root is the repository root.

### CORS/fetch issues
- Use a local HTTP server (not direct file open).
- Ensure relative paths in `app.js` match repository layout.

---

## Suggested next improvements

- Monaco editor integration with JSON schema diagnostics
- One-click example loader from `examples/*.ampersand.json`
- shareable URL compression for larger declarations
- side-by-side diff mode between two declarations
- export buttons for MCP and A2A artifacts
