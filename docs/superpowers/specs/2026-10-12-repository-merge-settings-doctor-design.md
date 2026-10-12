# Repository Merge Settings Doctor Design

## Status

Approved in-chat design, promoted to a repository design specification before implementation planning.

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

This creates a gap:

1. the repository documentation can say “squash-only” while GitHub still offers merge-commit or rebase paths;
2. the documentation can require merged branch cleanup while `delete_branch_on_merge` remains disabled;
3. maintainers can run the existing Governance Audit and receive no direct result for these repository-level settings.

The fix must preserve the current governance boundary: pull-request and audit code may inspect live settings, but it must not mutate repository administration settings.

## Goals

1. Add a deterministic, fail-closed validator for the repository merge-settings contract.
2. Add a read-only live doctor that retrieves the repository metadata and feeds it to that validator.
3. Add the doctor to the existing manual Governance Audit workflow.
4. Add contract tests proving the workflow remains manual-only and read-only while invoking the new doctor.
5. Document the new audit and the distinction between detection and remediation.
6. Keep the implementation small, dependency-free, and consistent with the existing governance doctors.

## Non-goals

This change will not:

- modify GitHub repository settings;
- import, create, update, disable, or delete Rulesets;
- add an Administration token or fine-grained PAT to GitHub Actions;
- automatically close Issue #43 merely because the doctor exists;
- weaken the desired squash-only policy to match the current live repository;
- change the application runtime, release behavior, signing policy, or product features;
- introduce a general-purpose GitHub repository configuration reconciler.

## Considered Approaches

### Approach A: Read-only repository-settings doctor in Governance Audit

Add a pure validator plus a thin `gh api` wrapper and run it from the existing manual Governance Audit.

Advantages:

- matches the existing governance architecture;
- directly detects the missing class of drift;
- requires no new credentials or write permissions;
- easy to test with local JSON fixtures;
- keeps remediation explicit and reviewable.

Disadvantages:

- does not automatically repair drift;
- the Governance Audit remains red until a maintainer aligns live settings.

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

- drift remains undetectable by CI/audit tooling;
- future repository changes can silently reintroduce the mismatch;
- the existing Governance Audit continues to provide incomplete governance evidence.

Rejected.

## Decision

Use Approach A.

The doctor is an observer, not a reconciler. A failing audit is evidence that a maintainer must intentionally update GitHub Settings and rerun the audit.

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

### `scripts/ci/audit_repository_settings.py`

This is the deterministic validation layer.

Input:

```text
python3 scripts/ci/audit_repository_settings.py <repository-json> <expected-owner/repo>
```

Required repository identity fields:

- `full_name` equals the expected `owner/repo` exactly;
- `default_branch` is a non-empty string.

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
6. execute a read-only request:

```text
gh api \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  repos/<owner>/<repo>
```

7. pass the returned JSON and expected repository identity to `audit_repository_settings.py`;
8. perform no write API call.

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

No permission expansion is permitted for this feature.

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

### Workflow contract tests

Extend `scripts/ci/test_governance_audit_workflow.py` to require:

- the new live repository-settings doctor invocation;
- `${{ github.repository }}` as the target identity;
- the workflow remains manual-only;
- write permissions remain absent;
- checkout still does not persist credentials.

### Shell contract

The implementation must remain compatible with the repository's existing shell quality gates:

- ShellCheck;
- `shfmt -d -i 2 -ci`.

A dedicated shell-unit-test harness is not required unless implementation complexity grows beyond the existing thin-wrapper pattern. Input and policy semantics belong in the Python validator so they can be tested deterministically without network access.

## TDD Sequence

Implementation must use RED -> GREEN -> refactor.

1. Add validator tests and workflow contract expectations before production files/workflow changes.
2. Run the targeted tests and record failure caused by the missing validator / missing workflow invocation.
3. Implement the smallest validator and shell wrapper that satisfy the contract.
4. Wire the new doctor into Governance Audit.
5. Rerun targeted tests until green.
6. Run format/lint checks for changed Python, shell, and workflow surfaces as applicable.
7. Run the repository governance/Quality gate and other required checks before merge.

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
- no workflow-controlled arbitrary API endpoint argument.

The current GitHub token is sufficient for the public repository metadata used by this doctor. For private adopters, the same workflow token should be used when it can read repository metadata; maintainers must not grant Administration merely to make the audit pass.

## Documentation Changes

Update `docs/GITHUB_RULESETS.md` to include the repository-settings doctor alongside the existing live doctors.

Document:

```bash
bash scripts/ci/audit-live-repository-settings.sh owner/repo
```

and explain that it validates repository-level merge capability settings, which are separate from Ruleset and effective-rule APIs.

Update the Governance Audit section to state that the hosted audit covers four surfaces:

1. live repository-owned default-branch Ruleset;
2. effective default-branch rules;
3. immutable release-tag Ruleset;
4. repository merge settings.

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

Issue #43 can only be considered complete after the broader live governance rollout is performed and verified, including the repository Rulesets and a green manual Governance Audit.

The implementation must not hide the expected red state by changing the validator to accept the current drift.

## Branch and Merge Plan

Design work uses the short-lived branch:

```text
docs/repository-merge-settings-doctor
```

Implementation planning follows only after this written specification is reviewed.

The eventual implementation should use a short-lived `chore/*` branch (or continue from an explicitly reviewed planning branch if the chosen execution workflow requires it), arrive through a pull request, pass all required checks, resolve review conversations, and be squash-merged in accordance with `docs/BRANCHING.md`.

No direct feature push to `main` is permitted.

## Acceptance Criteria

The implementation is complete when all of the following are true:

1. a deterministic repository-settings validator exists and is covered by drift and malformed-input tests;
2. a read-only live shell doctor fetches only repository metadata and invokes the validator;
3. the manual Governance Audit invokes the doctor with no permission expansion;
4. workflow contract tests prevent removal of the doctor or introduction of write permissions;
5. documentation identifies the expected values and audit command;
6. targeted tests, shell quality checks, governance/Quality checks, and all required repository checks pass on the implementation PR;
7. no live GitHub administration setting is changed by code in this feature;
8. running the doctor against a non-compliant repository exits non-zero with actionable field-level drift diagnostics.

## Follow-up

After implementation merge, perform the explicit live administration step tracked by Issue #43, then rerun Governance Audit. A green result after that manual remediation is the evidence that documented merge policy and live repository merge settings are aligned.
