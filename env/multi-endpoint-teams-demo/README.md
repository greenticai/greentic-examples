# Multi-Endpoint Teams Demo (Phase M1)

Demonstrates the M1 messaging-endpoint model: one environment hosts
TWO Teams bot instances (`teams-legal-bot` and `teams-accounting-bot`),
each with curated `linked_bundles`. A lawyer's question to
`teams-legal-bot` CANNOT reach Accounting flows, and vice versa.

## Hard isolation

Isolation is enforced at two layers:

1. **Admit gate** (M1.4, `greentic-start` / `greentic-runner-host`) --
   inbound requests are matched to a `MessagingEndpoint` by
   `provider_id`. If the resolved deployment's `bundle_id` is NOT in
   the endpoint's `linked_bundles`, the request is rejected (401/404)
   before any flow dispatch.

2. **Scoped Fast2Flow index** (M1.3, `greentic-fast2flow`) -- the
   per-endpoint corpus contains ONLY flows from bundles in
   `linked_bundles`. The Legal endpoint's index physically does not
   contain Accounting flows; a similarity search against "submit an
   invoice" yields zero matches -- there is nothing to route to.

Cross-endpoint flow handoff ("I'll ask Legal" from inside Accounting)
is a Phase M non-goal. Each endpoint is a self-contained universe.

## First-contact welcome flow

When a user messages an endpoint for the first time (no prior session
turns), the runner bypasses Fast2Flow and dispatches directly to the
endpoint's `welcome_flow` (M1.5). In this demo:

- `teams-legal-bot` dispatches to `nda_intake` (the NDA form)
- `teams-accounting-bot` dispatches to `invoice_intake` (the invoice form)

Subsequent messages route through Fast2Flow normally.

In a production setup the welcome flow would be a dedicated "main menu"
card listing all available actions. This demo reuses each pack's primary
flow as the welcome target to keep the worked example minimal.

## Packs

| Pack | Directory | Purpose |
|------|-----------|---------|
| `greentic.legal.nda.demo` | `pack/legal-nda-demo/` | NDA intake (existing M2.4 example) |
| `greentic.accounting.invoice.demo` | `pack/accounting-invoice-demo/` | Invoice intake (new, minimal) |

Each pack is bundled separately and deployed to the environment as an
independent `BundleDeployment`. The `linked_bundles` field on each
`MessagingEndpoint` references bundle IDs, not pack IDs -- linking is
bundle-grained per the deploy-spec design.

## How to run

### Prerequisites

- `gtc` installed (`cargo binstall gtc`)
- Packs built:
  ```sh
  (cd pack/legal-nda-demo && make build)
  (cd pack/accounting-invoice-demo && make build)
  ```
- Environment bootstrapped: `gtc op env init`
- Both bundles deployed into the environment

### Register endpoints

```sh
# Set bundle IDs (replace with your actual IDs from `gtc op bundles list`):
export LEGAL_BUNDLE_ID="legal-nda-bundle"
export ACCOUNTING_BUNDLE_ID="accounting-invoice-bundle"

bash env/multi-endpoint-teams-demo/setup.sh
```

The script calls these CLI verbs in order:

1. `gtc op messaging endpoint add` -- creates `teams-legal-bot`
2. `gtc op messaging endpoint add` -- creates `teams-accounting-bot`
3. `gtc op messaging endpoint link-bundle` -- links Legal bundle to Legal endpoint
4. `gtc op messaging endpoint link-bundle` -- links Accounting bundle to Accounting endpoint
5. `gtc op messaging endpoint set-welcome-flow` -- sets `nda_intake` on Legal
6. `gtc op messaging endpoint set-welcome-flow` -- sets `invoice_intake` on Accounting

### Verify

```sh
gtc op messaging endpoint list local
```

Shows both endpoints with their linked bundles and welcome flows.

```sh
gtc op messaging endpoint show local <ENDPOINT_ID>
```

Shows one endpoint in detail, including `secret_refs` and generation.

### What's on disk

After setup, the environment directory contains:

```
~/.greentic/environments/local/
  environment.json              # source-of-truth (messaging_endpoints[])
  messaging/
    <legal-endpoint-ulid>.json  # materialized projection
    <acct-endpoint-ulid>.json   # materialized projection
    index.json                  # endpoint summary index
```

## What's demonstrated vs. not

| Demonstrated | Not demonstrated |
|-------------|------------------|
| Two Teams endpoints in one environment | Actual Teams webhook delivery |
| Per-endpoint `linked_bundles` isolation | Per-endpoint Fast2Flow index build (requires runtime) |
| Welcome-flow dispatch target | Welcome-flow bypass of Fast2Flow (runtime behavior) |
| `secret://` refs per endpoint | Secret resolution at runtime |
| CLI verbs: add, link-bundle, set-welcome-flow, list, show | Cross-endpoint flow handoff (M non-goal) |

## M1 cross-references

- deployer #235 -- `MessagingEndpoint` typed entity + CLI verbs (M1.2)
- fast2flow #26 -- per-endpoint scoped corpus (M1.3)
- runner #379 -- endpoint_id propagation through ingress + welcome flow dispatch (M1.4 + M1.5)
