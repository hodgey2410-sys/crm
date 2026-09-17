Jev Integration + Upstream Survival Notes and Agent Implementation Plan

Destination: Thin, self-contained Jev (TypeSafe System One) decision layer inside apps/agent only. Strengthens identity/evidence classification, harness verification, and queue gating while preserving every CRM invariant (ledger owns all fact writes, fixed weights, no model confidence in facts, intelligence only in agent process, sandbox isolation). Branding remains untouched. After any future upstream sync the agent re-applies both the branding scripts and the Jev layer from the standing note in AGENTS.md.

Invariants (never violate):
•  No changes to NestJS API, evidence weights, scoreEvidence, fact-writing authority, sandbox egress, or DATABASE_URL exposure.

•  Jev never generates text, never writes facts, never lives in the browser or API.

•  Missing TYPESAFE_API_KEY → agent runs exactly as today (capability off).

•  All thresholds and composition live in code; ledger remains final authority.

•  Branding scripts stay focused solely on user-facing logo/name.

Standing instruction (add once to )AGENTS.md: After every upstream sync / merge:
1.  Re-apply branding scripts from scripts/ (logo + name only).

2.  Re-apply the thin Jev layer (client module + capability flag + helper calls in identity/evidence paths). Treat both as non-breaking optional local layers. Do this before any production push.

Tickets (vertical slices, dependency order)
01: Plumbing — SDK, env, thin client, capability flag

Blocked by: None

What it delivers: Optional TypeSafe client boots cleanly; agent logs “TYPESAFE: on/off” at startup exactly like existing optional capabilities; missing key leaves all behaviour identical to today. (Which is exactly how the app works before the Jev integration)

Acceptance:
•  bun add @typesafe-ai/sdk in apps/agent (or shared package if monorepo pattern prefers).

•  TYPESAFE_API_KEY added to root .env / .env.example (commented, same pattern as PERPLEXITY / Context / LinkedIn keys).

•  apps/agent/agent/lib/typesafe.ts exists:

import { TypeSafeClient, noul, choice, score } from "@typesafe-ai/sdk";
export const typesafe = process.env.TYPESAFE_API_KEY ? new TypeSafeClient() : null;
export { noul, choice, score };

•  Capability flag registered and printed on boot (mirror existing lib/capabilities.ts pattern).

•  Agent starts and runs full existing test suite with key absent.

•  No other files touched.

02: Core helper — judgeEvidence

Blocked by: 01

What it delivers: Single internal helper that accepts minimal structured state + atomic questions, calls typesafe.systemOne (or returns null gracefully), and returns typed results for code to consume.

Acceptance:
•  judgeEvidence(state: object, questions: Record<string, ReturnType<typeof noul | typeof choice | typeof score>>) implemented in the thin client module or adjacent helper.

•  State is filtered to only fields the questions need.

•  Missing client → returns null / empty, no throw.

•  Unit tests cover: present key + valid call, missing key, malformed state (graceful).

•  No side effects, no ledger writes, no tool changes yet.

03: Wire into identity + evidence path (highest ROI)

Blocked by: 02

What it delivers: After any observation tool that produces identity-relevant data (LinkedIn profile, signature block, thread, GitHub, web claim, etc.) and before record_fact / ledger pricing, 3–5 parallel atomic Jev questions run. Results map into existing Evidence[] or act as routing signal. Code thresholds decide auto-write vs suggestion. Ledger still owns every write.

Acceptance:
•  Calls inserted only after observation tools (identity-matching skill path, get_linkedin_profile / resolve_linkedin_profile / signature / etc.).

•  Example questions (adapt to exact observation shape; keep atomic):

	•  noul("Does this source list the exact CRM email?")

	•  noul("Do both current employer and name match the CRM contact?")

	•  noul("Do any two sources disagree on employer or title?")

	•  choice("What is the strongest evidence kind present?", { "profile.email-match": null, "linkedin.employer-and-name": null, "crm.signature-block": null, ... })

•  Results mapped in code; thresholds (e.g. noul > 0.85 + primary evidence + high confidence) live only in code.

•  Logs appear in Agent tab exactly like other tool results.

•  No new evidence kinds, no weight changes, no fact-write path changes.

•  Tests: observation → Jev call → correct Evidence mapping / suggestion path; missing key falls back to previous behaviour.

•  LinkedIn is only one source; the same helper is used for every observation source the agent already produces.

04:  AGENTS.md standing notes

Blocked by: None (can run in parallel with 01–03)

What it delivers: Permanent, visible instruction so any future agent (including after upstream sync) re-applies both branding scripts and the Jev layer without being re-prompted.

Acceptance:
•  Short, permanent section added to existing AGENTS.md:

	•  Branding is a thin user-facing-only layer (logo + name). Scripts live at scripts/ on the release branch of the fork. Re-apply after every upstream sync before production push.

	•  Jev is a thin optional layer inside apps/agent (client + capability + helper calls in identity/evidence). Re-apply the same way after every upstream sync.

	•  Both must remain non-breaking

           •  No other content changed.

           •  Note is short enough that it survives future human edits.

05: Measure + expand (post-core)

Blocked by: 03

What it delivers: Concrete metrics and next high-leverage calls only after real traces show the win.

Acceptance:
•  Logging of: false-positive rate on identity, clean auto-writes vs suggestions, research-token spend, judgment-layer latency.

•  Only after data: pre-budget gate, queue re-scoring, post-tool verification, optional calibrated confidence surface in Agent tab.

•  No expansion until 03 is measured and stable.

Execution rules for the implementing agent
•  Work one ticket at a time. Claim it, implement, test, commit, then next.

•  Use TDD at the public seams of the thin client and the identity path (judgeEvidence return shape, observation → Evidence mapping).

•  Prefer the existing optional-capability and logging patterns; copy them exactly.

•  After each ticket: full typecheck + relevant tests green.

•  Never touch branding files, NestJS API, evidence weights, or sandbox rules.