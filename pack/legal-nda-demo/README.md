# Legal NDA Demo — M2 prefill worked example

Demonstrates the canonical Phase M2 chain from a user's natural-language
utterance to an Adaptive Card that opens with fields already filled.

## The story

A lawyer messages the assistant on Teams:

> NDA between Acme Corp and us by 2026-07-15

Fast2Flow routes the message to `nda_intake` and dispatches with
`utterance` = the original text. The card opens with
**Counterparty: Acme Corp** and **Due date: 2026-07-15** already populated —
the lawyer just confirms and clicks Generate draft.

## The chain

```
inbound utterance
    │
    ▼
Fast2Flow → Dispatch{ target: nda_intake, utterance }
    │
    ▼
nda_intake.extract_slots
  component: ai.greentic.component-slot-extractor
  in:  { utterance, slot_definitions: [counterparty, due_date] }
  out: { slots: [...], values: { counterparty: "Acme Corp", due_date: "2026-07-15" } }
    │
    ▼
nda_intake.render_form
  component: ai.greentic.component-adaptive-card
  prefill: { counterparty, due_date }
  → Input.Text.value = "Acme Corp"
  → Input.Date.value = "2026-07-15"
```

## Slot schema (flow-level)

```yaml
slot_schema:
  - name: counterparty
    slot_type: string
    pattern: 'between\s+([A-Z][\w&. ]*?)\s+and'
    required: true
  - name: due_date
    slot_type: date
    required: true
```

- `counterparty` — string slot; the regex captures the proper-noun token
  between `"between"` and `"and"`. Case-sensitive on the first letter to
  avoid greedily matching common nouns.
- `due_date` — date slot; the extractor's default scan picks up ISO 8601
  (`2026-07-15`), US (`07/15/2026`), and EU (`15/07/2026`) date formats
  and normalises every match to ISO 8601 for the card.

## Component versions

| Component      | Floor |
|----------------|-------|
| `ai.greentic.component-slot-extractor` | `0.1.x` (regex extraction landed in M2.1 PR 2) |
| `ai.greentic.component-adaptive-card`  | floor that includes the `prefill` field (M2.3 PR #50) |
| `greentic-runner`                      | `1.1.26775859893` (Phase D `slot_schema` → `slot_definitions` injection) |

## How runtime wiring works

The flow declares `slot_schema` once, at the top level. At execute time
the runner detects `ai.greentic.component-slot-extractor` nodes and
injects the flow-level definitions into the invocation as
`slot_definitions` — the `extract_slots` node only has to forward the
utterance. An explicit `slot_definitions` key on the node still wins
(back-compat), but the canonical authoring pattern is the flow-level
field shown here.
