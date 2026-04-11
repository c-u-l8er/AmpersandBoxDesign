#!/usr/bin/env node
// Thin shim — defers to the compiled CLI under dist/.
import("../dist/cli.js").catch((err) => {
  console.error("[box-and-box] failed to start:", err?.stack ?? err);
  process.exit(1);
});
