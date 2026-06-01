#!/usr/bin/env bash
# Multi-endpoint Teams demo — environment setup.
#
# Registers two Teams bot endpoints in a single environment, each
# linked to its own bundle. Demonstrates the M1 hard-isolation model:
# the legal endpoint can only route to legal flows; the accounting
# endpoint can only route to accounting flows.
#
# Prerequisites:
#   - `gtc` installed and on PATH (`cargo binstall gtc`)
#   - An environment named "local" bootstrapped (`gtc op env init`)
#   - Both bundles deployed:
#       gtc op bundles add --answers legal-bundle-answers.json
#       gtc op bundles add --answers accounting-bundle-answers.json
#
# Usage:
#   bash setup.sh
#
# The script is idempotent — safe to re-run.

set -euo pipefail

ENV_ID="local"
UPDATED_BY="demo-setup"

# --- Bundle IDs ---------------------------------------------------------------
# Replace these with the actual bundle IDs from your environment.
LEGAL_BUNDLE_ID="${LEGAL_BUNDLE_ID:-legal-nda-bundle}"
ACCOUNTING_BUNDLE_ID="${ACCOUNTING_BUNDLE_ID:-accounting-invoice-bundle}"

# --- Pack and flow IDs --------------------------------------------------------
LEGAL_PACK_ID="greentic.legal.nda.demo"
LEGAL_WELCOME_FLOW_ID="nda_intake"

ACCOUNTING_PACK_ID="greentic.accounting.invoice.demo"
ACCOUNTING_WELCOME_FLOW_ID="invoice_intake"

echo "=== Multi-endpoint Teams demo setup ==="
echo ""

# --- 1. Add the legal endpoint ------------------------------------------------
echo "[1/6] Adding legal endpoint..."
LEGAL_RESULT=$(gtc op messaging endpoint add --answers /dev/stdin <<EOF
{
  "environment_id": "${ENV_ID}",
  "provider_id": "teams-legal-bot",
  "provider_type": "teams",
  "display_name": "Legal Assistant on Teams",
  "secret_refs": [
    "secret://${ENV_ID}/${LEGAL_BUNDLE_ID}/teams-legal-bot/bot_token",
    "secret://${ENV_ID}/${LEGAL_BUNDLE_ID}/teams-legal-bot/signing_secret"
  ],
  "idempotency_key": "demo-setup-legal-add",
  "updated_by": "${UPDATED_BY}"
}
EOF
)
echo "${LEGAL_RESULT}"
LEGAL_ENDPOINT_ID=$(echo "${LEGAL_RESULT}" | grep -oP '"endpoint_id"\s*:\s*"\K[^"]+' | head -1)
echo "  -> endpoint_id: ${LEGAL_ENDPOINT_ID}"
echo ""

# --- 2. Add the accounting endpoint -------------------------------------------
echo "[2/6] Adding accounting endpoint..."
ACCOUNTING_RESULT=$(gtc op messaging endpoint add --answers /dev/stdin <<EOF
{
  "environment_id": "${ENV_ID}",
  "provider_id": "teams-accounting-bot",
  "provider_type": "teams",
  "display_name": "Accounting Assistant on Teams",
  "secret_refs": [
    "secret://${ENV_ID}/${ACCOUNTING_BUNDLE_ID}/teams-accounting-bot/bot_token",
    "secret://${ENV_ID}/${ACCOUNTING_BUNDLE_ID}/teams-accounting-bot/signing_secret"
  ],
  "idempotency_key": "demo-setup-accounting-add",
  "updated_by": "${UPDATED_BY}"
}
EOF
)
echo "${ACCOUNTING_RESULT}"
ACCOUNTING_ENDPOINT_ID=$(echo "${ACCOUNTING_RESULT}" | grep -oP '"endpoint_id"\s*:\s*"\K[^"]+' | head -1)
echo "  -> endpoint_id: ${ACCOUNTING_ENDPOINT_ID}"
echo ""

# --- 3. Link legal bundle to legal endpoint -----------------------------------
echo "[3/6] Linking legal bundle to legal endpoint..."
gtc op messaging endpoint link-bundle --answers /dev/stdin <<EOF
{
  "environment_id": "${ENV_ID}",
  "endpoint_id": "${LEGAL_ENDPOINT_ID}",
  "bundle_id": "${LEGAL_BUNDLE_ID}",
  "idempotency_key": "demo-setup-legal-link",
  "updated_by": "${UPDATED_BY}"
}
EOF
echo ""

# --- 4. Link accounting bundle to accounting endpoint -------------------------
echo "[4/6] Linking accounting bundle to accounting endpoint..."
gtc op messaging endpoint link-bundle --answers /dev/stdin <<EOF
{
  "environment_id": "${ENV_ID}",
  "endpoint_id": "${ACCOUNTING_ENDPOINT_ID}",
  "bundle_id": "${ACCOUNTING_BUNDLE_ID}",
  "idempotency_key": "demo-setup-accounting-link",
  "updated_by": "${UPDATED_BY}"
}
EOF
echo ""

# --- 5. Set welcome flow on legal endpoint ------------------------------------
echo "[5/6] Setting welcome flow on legal endpoint..."
gtc op messaging endpoint set-welcome-flow --answers /dev/stdin <<EOF
{
  "environment_id": "${ENV_ID}",
  "endpoint_id": "${LEGAL_ENDPOINT_ID}",
  "bundle_id": "${LEGAL_BUNDLE_ID}",
  "pack_id": "${LEGAL_PACK_ID}",
  "flow_id": "${LEGAL_WELCOME_FLOW_ID}",
  "idempotency_key": "demo-setup-legal-welcome",
  "updated_by": "${UPDATED_BY}"
}
EOF
echo ""

# --- 6. Set welcome flow on accounting endpoint -------------------------------
echo "[6/6] Setting welcome flow on accounting endpoint..."
gtc op messaging endpoint set-welcome-flow --answers /dev/stdin <<EOF
{
  "environment_id": "${ENV_ID}",
  "endpoint_id": "${ACCOUNTING_ENDPOINT_ID}",
  "bundle_id": "${ACCOUNTING_BUNDLE_ID}",
  "pack_id": "${ACCOUNTING_PACK_ID}",
  "flow_id": "${ACCOUNTING_WELCOME_FLOW_ID}",
  "idempotency_key": "demo-setup-accounting-welcome",
  "updated_by": "${UPDATED_BY}"
}
EOF
echo ""

# --- Verify -------------------------------------------------------------------
echo "=== Endpoint listing ==="
gtc op messaging endpoint list "${ENV_ID}"
echo ""
echo "=== Done ==="
echo ""
echo "What was created:"
echo "  - teams-legal-bot      (endpoint ${LEGAL_ENDPOINT_ID})"
echo "    linked to: ${LEGAL_BUNDLE_ID}"
echo "    welcome:   ${LEGAL_PACK_ID}/${LEGAL_WELCOME_FLOW_ID}"
echo ""
echo "  - teams-accounting-bot (endpoint ${ACCOUNTING_ENDPOINT_ID})"
echo "    linked to: ${ACCOUNTING_BUNDLE_ID}"
echo "    welcome:   ${ACCOUNTING_PACK_ID}/${ACCOUNTING_WELCOME_FLOW_ID}"
echo ""
echo "A lawyer messaging teams-legal-bot will ONLY reach Legal flows."
echo "An accountant messaging teams-accounting-bot will ONLY reach Accounting flows."
echo "The Fast2Flow index for each endpoint physically excludes the other's flows."
