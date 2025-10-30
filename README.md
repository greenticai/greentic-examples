# greentic-examples

Example configuration and content for Greentic tenants.

## Layout

- `bindings/` — ready-to-use tenant bindings for messaging, MCP tooling, and LLM access.
- `pack/weather-demo/` — a minimal weather assistant pack with flows, templates, and build metadata.

## Weather demo pack

From inside `pack/weather-demo/` run:

```sh
make build
```

This compiles the pack sources into `dist/weather_pack.wasm` along with a manifest and SBOM that can be deployed with `greentic-runner`.

> **Prerequisites**
> - `packc` installed (`cargo install --git https://github.com/greentic-ai/greentic-pack packc --locked`). The crates.io build currently lacks the embedded workspace and will error with `could not find Cargo.toml`.
> - Flow schema available at `~/.cargo/registry/src/schemas/ygtc.flow.schema.json`. A copy is checked into `schemas/` for convenience—copy it into place before building.
> - Rust target `wasm32-unknown-unknown` via `rustup target add wasm32-unknown-unknown`.
