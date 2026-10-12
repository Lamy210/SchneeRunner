# Repository Merge Settings Doctor Design

## Status

Approved in-chat design, reviewed once, and revised to address the review findings before implementation planning.

## Context

SchneeRunner uses a trunk-based model with `main` as the only long-lived development branch. Repository documentation requires changes to reach `main` through pull requests and recommends squash-only merging with merged head branches deleted automatically.

The checked-in governance system already distinguishes between desired state and live GitHub state:

- `rulesets/main-solo.json` and `rulesets/release-tags.json` describe portable desired-state Rulesets;
- read-only doctors inspect the live default-branch Ruleset, effective branch rules, and release-tag Ruleset;
- `.github/workflows/governance-audit.yml` provides a manual, read-only hosted audit surface;
- live administration changes remain an explicit maintainer action and are not performed by pull-request workflows.

The repository-level merge settings are part of the same governance contract but are not currently covered by a live doctor. The documented policy expects:

- squash merge enabled;
- merge commits disabled;
- rebase merge disabled;
- automatic deletion of merged head branches enabled.

The live SchneeRunner repository currently differs from that documented policy. Issue #43 tracks the broader live Solo governance rollout and explicitly includes repository merge-setting alignment.

## Problem

The repository can currently drift from the documented merge model without the existing Governance Audit detecting that drift.

A successful Ruleset audit is insufficient because GitHub repository merge capabilities are exposed as repository settings and are not fully represented by the checked-in Ruleset JSON or effective default-branch rule response.

This creates two audit gaps:

1. repository-level merge settings are not validated at all;
2. the existing Governance Audit runs the live doctors as ordinary sequential steps, so the first failing doctor prevents later surfaces from being inspected.

The second gap matters for Issue #43 specifically: while the live Rulesets are still absent or otherwise non-compliant, the first Ruleset doctor is expected to fail. If the new repository-settings doctor were appended as an ordinary later step, maintainers would not receive its result in the same audit run.

The fix must preserve the current governance boundary: pull-request and audit code may inspect live settings, but it must not mutate repository administration settings.

## Goals

1. Add a deterministic, fail-closed validator for the repository merge-settings contract.
2. Add a read-only live doctor that retrieves the repository metadata and feeds it to that validator.
3. Add the doctor to the existing manual Governance Audit workflow.
4. Make the Governance Audit attempt every independent live governance doctor even when an earlier doctor reports drift, while preserving an overall failed job when any doctor fails.
5. Add direct contract coverage for the live shell wrapper so its fixed read-only API boundary cannot silently expand into mutation or arbitrary-endpoint behavior.
6. Add workflow contract tests proving the workflow remains manual-only and read-only while invoking all doctors.
7. Document the new audit and the distinction between detection and remediation.
8. Keep the implementation small, dependency-free, and consistent with the existing governance doctors.

## Non-goals

This change will not:

- modify GitHub repository settings;
- import, create, update, disable, or delete Rulesets;
- add an Administration token or fine-grained PAT to GitHub Actions;
- automatically close Issue #43 merely because the doctor exists;
- weaken the desired squash-only policy to match the current live repository;
- change the application runtime, release behavior, signing policy, or product features;
- introduce a general-purpose GitHub repository configuration reconciler;
- redesign the Governance Audit into a general matrix/orchestration framework.

## Considered Approaches

### Approach A: Read-only repository-settings doctor in Governance Audit

Add a pure validator plus a thin `gh api` wrapper and run it from the existing manual Governance Audit. Mark the independent doctor steps to run even after prior doctor failures so one manual run reports all observable governance drift.

Advantages:

- matches the existing governance architecture;
- directly detects the missing class of drift;
- requires no new credentials or write permissions;
- easy to test with local JSON fixtures and a stubbed `gh` binary;
- keeps remediation explicit and reviewable;
- preserves one simple manual audit workflow while improving diagnostic completeness.

Disadvantages:

- does not automatically repair drift;
- the Governance Audit remains red until a maintainer aligns live settings;
- the workflow needs explicit step conditions so independent audits are not skipped after a preceding failure.

### Approach B: Automatically reconcile repository settings

Have an Action or script update repository merge settings to the documented values.

Advantages:

- can converge live state automatically.

Disadvantages:

- requires Administration/write authority;
- expands the privileged attack surface;
- turns a verification workflow into an administration workflow;
- conflicts with the existing desired-state/manual-rollout governance model;
- raises the consequence of executing changed workflow code.

Rejected.

### Approach C: Documentation-only remediation

Update Issue #43 or the setup documentation with manual click-path instructions and do not add code.

Advantages:

- smallest implementation cost.

Disadvantages:

- drift remains undetectable by audit tooling;
- future repository changes can silently reintroduce the mismatch;
- the existing Governance Audit continues to provide incomplete governance evidence.

Rejected.

### Approach D: Split every doctor into a separate GitHub Actions job

Run each live audit surface as an independent job and aggregate their results.

Advantages:

- natural failure isolation;
- per-surface job status is visually explicit.

Disadvantages:

- duplicates checkout/setup for four small read-only commands;
- adds workflow complexity and runner overhead for no current need;
- requires an aggregation pattern beyond the scope of adding one missing audit surface.

Deferred. If the Governance Audit grows materially beyond these four surfaces, job-level fan-out can be reconsidered.

## Decision

Use Approach A.

The doctor is an observer, not a reconciler. A failing audit is evidence that a maintainer must intentionally update GitHub Settings and rerun the audit.

The Governance Audit must maximize diagnostic coverage: an individual doctor may fail because it correctly detected drift, but the other independent doctors should still execute. GitHub Actions should still report the audit job as failed when any doctor step fails.

## Architecture

The implementation adds two layers matching the existing governance doctor pattern.

```text
.github/workflows/governance-audit.yml
        |
        +-- audit-live-main-ruleset.sh
        +-- audit-live-main-rules.sh
        +-- audit-live-release-tag-ruleset.sh
        +-- audit-live-repository-settings.sh   [new]
                    |
                    +-- gh api repos/<owner>/<repo>
                    |
                    +-- repository JSON
                              |
                              v
                 audit_repository_settings.py   [new]
                              |
                              v
                     Solo merge-setting policy
```

The four live doctor steps are independent observations. Each doctor step must use a GitHub Actions condition equivalent to:

```yaml
if: ${{ always() }}
```

so a policy failure in one surface does not skip the remaining surfaces. Checkout remains an ordinary prerequisite; if checkout itself fails, there is no useful repository-local doctor code to execute.

No `continue-on-error: true` is used. A doctor that exits non-zero still contributes a failed step/job outcome; `always()` only controls whether later independent observations are attempted.

### `scripts/ci/audit_repository_settings.py`

This is the deterministic validation layer.

Input:

```text
python3 scripts/ci/audit_repository_settings.py <repository-json> <expected-owner/repo>
```

Required repository identity field:

- `full_name` equals the expected `owner/repo` exactly.

`default_branch` is deliberately not part of this validator's contract. The repository-settings doctor does not use the default branch, while the effective-rules doctor already owns default-branch resolution and validation. Keeping it out preserves a narrow responsibility for this validator.

Required merge-policy fields:

```text
allow_squash_merge      == true
allow_merge_commit      == false
allow_rebase_merge      == false
delete_branch_on_merge  == true
```

The validator must fail closed when:

- the file is missing or not valid JSON;
- the top-level JSON value is not an object;
- a required field is missing;
- a required boolean field is not actually a JSON boolean;
- repository identity does not match the expected repository;
- any policy value differs from the canonical contract.

The validator should report every detected policy mismatch in one run where practical so maintainers can remediate all known drift together. Structural input failures that make further validation unsafe may terminate immediately with an actionable error.

No GitHub network access belongs in this Python module.

### `scripts/ci/audit-live-repository-settings.sh`

This is the live read-only adapter.

Interface:

```text
bash scripts/ci/audit-live-repository-settings.sh owner/repo
```

Responsibilities:

1. accept an explicit `owner/repo`, falling back to `GITHUB_REPOSITORY` only when the positional argument is absent;
2. validate the repository identifier before embedding it in an API path;
3. reject unexpected extra arguments;
4. require `gh` and `python3`;
5. create a private temporary work directory with cleanup on every exit path;
6. execute exactly the repository metadata read request shape:

```text
gh api \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  repos/<owner>/<repo>
```

7. pass the returned JSON and expected repository identity to `audit_repository_settings.py`;
8. perform no write API call;
9. accept no arbitrary API endpoint, HTTP method, hostname, or additional `gh api` argument from the caller.

The wrapper should follow the style of the existing live Ruleset doctors rather than introducing a new framework.

## Workflow Integration

`.github/workflows/governance-audit.yml` remains:

- `workflow_dispatch` only;
- `permissions: contents: read`;
- non-cancelling per-repository concurrency;
- `persist-credentials: false` checkout;
- authenticated with the ephemeral `github.token` only for read-only API calls.

Add one step to the existing audit job:

```text
Audit live repository merge settings
```

which invokes:

```text
bash scripts/ci/audit-live-repository-settings.sh "${{ github.repository }}"
```

Apply `if: ${{ always() }}` to each of the four independent live doctor steps:

1. live repository-owned default-branch Ruleset;
2. effective default-branch rules;
3. immutable release-tag Ruleset;
4. repository merge settings.

This makes a single manual run diagnostically complete even during partial rollout. The workflow must not use `continue-on-error` to turn policy drift into success. No permission expansion is permitted for this feature.

## Testing Strategy

### Validator tests

Add `scripts/ci/test_audit_repository_settings.py`.

Minimum cases:

1. canonical repository JSON passes;
2. `allow_squash_merge=false` fails;
3. `allow_merge_commit=true` fails;
4. `allow_rebase_merge=true` fails;
5. `delete_branch_on_merge=false` fails;
6. multiple drift values are all surfaced in one run;
7. missing required policy field fails;
8. string/integer/null substituted for a required boolean fails;
9. mismatched `full_name` fails;
10. invalid JSON fails;
11. non-object JSON fails.

The tests should invoke the validator through its public command-line boundary where feasible so exit status and diagnostic output are covered together.

### Live shell-wrapper contract tests

Add `scripts/ci/test_audit_live_repository_settings.py`.

The test uses a temporary directory containing a stub `gh` executable placed first on `PATH`. The stub records its argv and writes controlled repository JSON to stdout. The real shell wrapper is executed as a subprocess against that stub.

Minimum cases:

1. a valid explicit `owner/repo` invokes exactly one `gh api` repository-read request and passes the returned JSON to the validator;
2. no positional repository uses a valid `GITHUB_REPOSITORY` fallback;
3. malformed repository identifiers are rejected before `gh` executes, including extra path components and URL-like input;
4. extra positional arguments are rejected before `gh` executes;
5. the recorded `gh` invocation contains no write method option such as `-X`, `--method`, `PATCH`, `PUT`, `POST`, or `DELETE`;
6. the API endpoint is exactly `repos/<owner>/<repo>` and cannot be supplied or overridden by caller input;
7. a failing `gh` invocation produces a non-zero wrapper result rather than manufacturing validator input;
8. temporary data is not retained after normal completion; implementation-specific cleanup internals need not be asserted beyond externally observable residue if the wrapper uses a discoverable test temp root.

The test should verify argv semantically rather than relying on fragile shell source text matching. This protects the security boundary if harmless formatting changes occur later.

### Workflow contract tests

Extend `scripts/ci/test_governance_audit_workflow.py` to require:

- the new live repository-settings doctor invocation;
- `${{ github.repository }}` as the target identity;
- all four independent doctor steps are configured to run after preceding doctor failures using `always()` semantics;
- `continue-on-error` is not introduced for the doctor steps;
- the workflow remains manual-only;
- write permissions remain absent;
- checkout still does not persist credentials.

The contract test may parse or inspect the workflow using the repository's established lightweight test style, but it must be specific enough that removing `always()` from one doctor surface causes RED.

### Quality workflow integration

Add both new Python test modules to the existing `Ruleset governance validation` unittest invocation in `.github/workflows/quality.yml`:

```text
scripts.ci.test_audit_repository_settings
scripts.ci.test_audit_live_repository_settings
```

This keeps the new governance contract under the existing stable `Required gate` path rather than creating a new required check name.

### Shell quality

The implementation must remain compatible with the repository's existing shell quality gates:

- ShellCheck;
- `shfmt -d -i 2 -ci`.

## TDD Sequence

Implementation must use RED -> GREEN -> refactor.

1. Add `test_audit_repository_settings.py`, `test_audit_live_repository_settings.py`, and the new workflow contract expectations before production files/workflow changes.
2. Add the two new test modules to the Quality governance-test list.
3. Run the targeted tests and record RED caused by the missing validator/wrapper and missing workflow behavior.
4. Implement the smallest validator and shell wrapper that satisfy the contracts.
5. Wire the new doctor into Governance Audit and add `always()` semantics to all four independent doctor steps without `continue-on-error`.
6. Rerun targeted tests until green.
7. Run ShellCheck, shfmt, and actionlint for the affected surfaces.
8. Run the repository governance/Quality gate and other required checks before merge.

Do not manufacture a RED state by weakening or deleting existing implementation. The initial failure must come from the new required behavior not yet existing.

## Error Handling and Diagnostics

Diagnostics must distinguish structural failures from policy drift.

Examples of structural failures:

```text
repository settings audit failed: repository JSON must be an object
repository settings audit failed: missing boolean field 'allow_squash_merge'
repository settings audit failed: expected repository Lamy210/SchneeRunner, got owner/other
```

Examples of policy drift:

```text
repository settings drift: allow_merge_commit expected false, got true
repository settings drift: allow_rebase_merge expected false, got true
repository settings drift: delete_branch_on_merge expected true, got false
```

The exact wording may be normalized during implementation, but diagnostics must identify the field and expected/live value without exposing credentials or unrelated repository metadata.

Success should emit a concise confirmation that repository merge settings match the Solo governance contract.

## Security Model

This feature intentionally does not add a new privileged boundary.

Security requirements:

- no Administration/write permission;
- no PAT, GitHub App administration token, or repository secret;
- no `pull_request_target`;
- no mutation endpoint;
- repository input validated before use in an API path;
- temporary data cleaned on success and failure;
- no full repository JSON echoed to logs unless a future debugging change explicitly reviews the data exposure;
- no workflow-controlled arbitrary API endpoint argument;
- no caller-controlled HTTP method or extra `gh api` arguments;
- the shell-wrapper contract is regression-tested with a stubbed `gh` executable.

The current GitHub token is sufficient for the public repository metadata used by this doctor. For private adopters, the same workflow token should be used when it can read repository metadata; maintainers must not grant Administration merely to make the audit pass.

## Documentation Changes

Update `docs/GITHUB_RULESETS.md` to include the repository-settings doctor alongside the existing live doctors.

Document:

```bash
bash scripts/ci/audit-live-repository-settings.sh owner/repo
```

and explain that it validates repository-level merge capability settings, which are separate from Ruleset and effective-rule APIs.

Update the Governance Audit section to state that the hosted audit covers four surfaces and attempts all four in one run even if an earlier surface reports drift:

1. live repository-owned default-branch Ruleset;
2. effective default-branch rules;
3. immutable release-tag Ruleset;
4. repository merge settings.

A red Governance Audit means at least one governance surface is non-compliant; maintainers should inspect every doctor step result rather than assuming the first failed step is the only drift.

`docs/BRANCHING.md` should reference the doctor from the repository merge-settings section so the documented expected values have an executable verification path.

## Interaction with Issue #43

This feature advances Issue #43 but does not complete it.

After this change lands, the current SchneeRunner live repository is expected to fail the new doctor until a maintainer applies the documented settings in GitHub:

```text
allow squash merge       = enabled
allow merge commits      = disabled
allow rebase merging     = disabled
delete head branches     = enabled
```

The broader Ruleset surfaces are also expected to remain independently visible in the same Governance Audit run because each doctor executes with `always()` semantics.

Issue #43 can only be considered complete after the broader live governance rollout is performed and verified, including the repository Rulesets and a green manual Governance Audit.

The implementation must not hide the expected red state by changing the validator to accept the current drift or by marking doctor failures `continue-on-error`.

## Branch and Merge Plan

Design work uses the short-lived branch:

```text
docs/repository-merge-settings-doctor
```

Implementation planning follows only after this revised written specification is reviewed.

The eventual implementation should use a short-lived `chore/*` branch (or continue from an explicitly reviewed planning branch if the chosen execution workflow requires it), arrive through a pull request, pass all required checks, resolve review conversations, and be squash-merged in accordance with `docs/BRANCHING.md`.

No direct feature push to `main` is permitted.

## Acceptance Criteria

The implementation is complete when all of the following are true:

1. a deterministic repository-settings validator exists and is covered by drift and malformed-input tests;
2. a read-only live shell doctor fetches only repository metadata and invokes the validator;
3. direct wrapper tests prove the fixed repository endpoint, validated repository input, and absence of caller-controlled/write HTTP methods;
4. the manual Governance Audit invokes all four doctors with no permission expansion;
5. failure of one doctor does not skip the remaining independent doctor steps, while any failed doctor still leaves the audit job failed;
6. workflow contract tests prevent removal of a doctor, removal of the `always()` behavior, addition of `continue-on-error`, or introduction of write permissions;
7. documentation identifies the expected values, audit command, and multi-surface failure behavior;
8. targeted tests, shell/workflow quality checks, governance/Quality checks, and all required repository checks pass on the implementation PR;
9. no live GitHub administration setting is changed by code in this feature;
10. running the doctor against a non-compliant repository exits non-zero with actionable field-level drift diagnostics.

## Follow-up

After implementation merge, perform the explicit live administration step tracked by Issue #43, then rerun Governance Audit. A green result after that manual remediation is the evidence that documented merge policy and live repository merge settings are aligned.
