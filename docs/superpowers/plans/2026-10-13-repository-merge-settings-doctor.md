# Repository Merge Settings Doctor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only live repository merge-settings doctor that detects drift from SchneeRunner's Solo squash-only governance contract without gaining repository administration authority.

**Architecture:** Keep GitHub I/O in a thin Bash adapter and policy evaluation in a deterministic Python validator. Integrate the adapter into the existing manual Governance Audit so all four governance surfaces run even when an earlier doctor fails, while preserving the overall failing result. Pin the observer-only boundary with validator, shell-contract, workflow-contract, and Quality-gate tests.

**Tech Stack:** Python 3 `unittest`, Bash with `set -euo pipefail`, GitHub CLI `gh api`, GitHub Actions YAML, ShellCheck, shfmt, actionlint.

**Spec:** `docs/superpowers/specs/2026-10-12-repository-merge-settings-doctor-design.md`

## Global Constraints

- Repository merge policy is exactly: `allow_squash_merge=true`, `allow_merge_commit=false`, `allow_rebase_merge=false`, `delete_branch_on_merge=true`.
- Repository identity validation is limited to exact `full_name == owner/repo`; this doctor does not validate `default_branch`.
- The live doctor is read-only: no Administration/write permission, PAT, GitHub App administration token, repository secret, mutation endpoint, or arbitrary workflow-controlled API endpoint.
- `.github/workflows/governance-audit.yml` remains `workflow_dispatch` only with `permissions: contents: read` and `persist-credentials: false`.
- All four governance doctor steps use `if: ${{ always() }}` so every surface is attempted; `continue-on-error` must not be introduced, so drift still makes the job fail.
- The implementation must not modify live GitHub repository settings or close Issue #43.
- Shell changes must pass ShellCheck and `shfmt -d -i 2 -ci`; workflow changes must pass actionlint.
- Implementation follows RED -> GREEN -> refactor and keeps each commit reviewable.

## Review Focus

- A repository JSON field containing `"false"`, `0`, `1`, or `null` instead of a JSON boolean must fail as malformed policy input, not be coerced.
- Multiple merge-setting mismatches in one valid repository response must all be reported in one run.
- Repository identifiers containing extra path components, URL syntax, percent-encoded separators, or an extra positional argument must be rejected before `gh api` runs.
- The shell adapter must invoke only the fixed repository metadata GET endpoint and must never pass `-X`, `--method`, `PATCH`, `PUT`, `POST`, or `DELETE` to `gh`.
- A failure in any earlier Governance Audit doctor must not skip later doctors; all four run, but the overall job must still fail when any doctor fails.

---

### Task 1: Deterministic repository-settings validator

**Files:**
- Create: `scripts/ci/audit_repository_settings.py`
- Create: `scripts/ci/test_audit_repository_settings.py`

**Interfaces:**
- Consumes: repository metadata JSON from a file path or `-`, plus an expected `owner/repo` string.
- Produces: `validate_repository_settings(document: object, *, expected_repository: str) -> list[str]` and CLI `main(argv: list[str] | None = None) -> int`.

- [ ] **Step 1: Write validator tests that define the canonical policy and malformed-input behavior**

Add `unittest` cases covering:

```text
canonical values -> exit 0
allow_squash_merge=false -> exit 1
allow_merge_commit=true -> exit 1
allow_rebase_merge=true -> exit 1
delete_branch_on_merge=false -> exit 1
three simultaneous drift values -> every field appears in stderr
missing required setting -> exit 1
"false" / 0 / 1 / null in boolean fields -> exit 1
full_name mismatch -> exit 1
invalid JSON -> non-zero with actionable parse error
JSON array/string/null as top level -> exit 1
```

Exercise the public CLI boundary with `subprocess` for exit code and diagnostics; direct function tests may supplement it where they reduce duplication.

- [ ] **Step 2: Run the new tests and verify RED**

Run:

```bash
python3 -m unittest scripts.ci.test_audit_repository_settings -v
```

Expected: FAIL because `scripts/ci/audit_repository_settings.py` and its public behavior do not yet exist.

- [ ] **Step 3: Implement the minimal validator**

Create:

```python
EXPECTED_SETTINGS: dict[str, bool]

def validate_repository_settings(
    document: object,
    *,
    expected_repository: str,
) -> list[str]: ...

def _load_json(path: str) -> object: ...

def main(argv: list[str] | None = None) -> int: ...
```

Requirements:

- require a JSON object;
- require `full_name` to equal the supplied repository exactly;
- for each canonical merge setting, require the field to exist and `type(value) is bool`;
- aggregate independent policy drift messages where safe;
- keep network access out of this module;
- emit concise success text and field-level failure diagnostics.

- [ ] **Step 4: Run validator tests and verify GREEN**

Run:

```bash
python3 -m unittest scripts.ci.test_audit_repository_settings -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit the validator slice**

```bash
git add scripts/ci/audit_repository_settings.py scripts/ci/test_audit_repository_settings.py
git commit -m "test: add repository merge settings validator"
```

---

### Task 2: Read-only live adapter and its boundary tests

**Files:**
- Create: `scripts/ci/audit-live-repository-settings.sh`
- Create: `scripts/ci/test_audit_live_repository_settings.py`

**Interfaces:**
- Consumes: positional `owner/repo`, or `GITHUB_REPOSITORY` only when the positional argument is absent; Task 1 CLI at `scripts/ci/audit_repository_settings.py`.
- Produces: `bash scripts/ci/audit-live-repository-settings.sh owner/repo`, returning the validator's success/failure without mutating GitHub.

- [ ] **Step 1: Write shell-adapter contract tests with stub executables**

Use a temporary directory added to `PATH` containing a stub `gh` that records argv and emits fixture repository JSON. Cover:

```text
valid owner/repo -> stub gh is called once and validator result is propagated
missing positional arg + valid GITHUB_REPOSITORY -> accepted
owner/repo/extra -> rejected before gh invocation
https://github.com/owner/repo -> rejected before gh invocation
owner%2Frepo -> rejected before gh invocation
extra positional argument -> rejected before gh invocation
recorded gh argv contains exactly repos/<owner>/<repo> as the endpoint
recorded gh argv contains no -X or --method
recorded gh argv contains no PATCH, PUT, POST, or DELETE token
```

The fixture used for the success path must contain the canonical Task 1 settings.

- [ ] **Step 2: Run adapter tests and verify RED**

Run:

```bash
python3 -m unittest scripts.ci.test_audit_live_repository_settings -v
```

Expected: FAIL because the shell adapter does not yet exist.

- [ ] **Step 3: Implement the thin Bash adapter**

Required shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Implementation requirements:

- repository regex: `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`;
- reject more than one positional argument;
- require `gh` and `python3`;
- resolve repository root relative to `BASH_SOURCE[0]`;
- create a private temporary work directory with `mktemp -d` and `trap` cleanup;
- run only:

```bash
gh api \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "repos/${repository}"
```

- save the response to a temporary JSON file and invoke Task 1's validator with the expected repository.

- [ ] **Step 4: Run adapter tests and shell quality checks**

Run:

```bash
python3 -m unittest scripts.ci.test_audit_live_repository_settings -v
shellcheck scripts/ci/audit-live-repository-settings.sh
shfmt -d -i 2 -ci scripts/ci/audit-live-repository-settings.sh
```

Expected: all tests PASS and both shell tools report no findings/diff.

- [ ] **Step 5: Commit the live adapter slice**

```bash
git add scripts/ci/audit-live-repository-settings.sh scripts/ci/test_audit_live_repository_settings.py
git commit -m "feat: add live repository merge settings doctor"
```

---

### Task 3: Governance Audit and Quality integration

**Files:**
- Modify: `.github/workflows/governance-audit.yml`
- Modify: `.github/workflows/quality.yml`
- Modify: `scripts/ci/test_governance_audit_workflow.py`

**Interfaces:**
- Consumes: Task 2 command `bash scripts/ci/audit-live-repository-settings.sh "${{ github.repository }}"`.
- Produces: a manual Governance Audit that attempts all four governance surfaces and a Quality job that continuously runs both new test modules.

- [ ] **Step 1: Extend workflow contract tests first**

Add tests requiring:

```text
new repository-settings doctor command is present
new doctor receives ${{ github.repository }}
all four doctor steps contain if: ${{ always() }}
workflow contains no continue-on-error
workflow remains workflow_dispatch-only
permissions remain contents: read only
checkout remains persist-credentials: false
GH_TOKEN remains github.token
```

Make the `always()` assertion bind to the four doctor steps rather than merely counting unrelated occurrences.

- [ ] **Step 2: Run workflow contract tests and verify RED**

Run:

```bash
python3 -m unittest scripts.ci.test_governance_audit_workflow -v
```

Expected: FAIL because the fourth doctor and `always()` behavior are not wired yet.

- [ ] **Step 3: Update Governance Audit**

In `.github/workflows/governance-audit.yml`:

- add `if: ${{ always() }}` to each of the existing three doctor steps;
- add a fourth step named `Audit live repository merge settings`;
- give the fourth step `if: ${{ always() }}` and run Task 2's command;
- do not add `continue-on-error` or any permission.

- [ ] **Step 4: Add both new test modules to the existing Ruleset governance validation block**

In `.github/workflows/quality.yml`, add:

```text
scripts.ci.test_audit_repository_settings
scripts.ci.test_audit_live_repository_settings
```

to the existing `python3 -m unittest` invocation for governance validation. Do not create a separate CI job.

- [ ] **Step 5: Run workflow/validator/adapter tests and workflow linters**

Run:

```bash
python3 -m unittest \
  scripts.ci.test_audit_repository_settings \
  scripts.ci.test_audit_live_repository_settings \
  scripts.ci.test_governance_audit_workflow \
  -v
actionlint .github/workflows/governance-audit.yml .github/workflows/quality.yml
```

Expected: all tests PASS and actionlint reports no findings.

- [ ] **Step 6: Commit workflow integration**

```bash
git add .github/workflows/governance-audit.yml .github/workflows/quality.yml scripts/ci/test_governance_audit_workflow.py
git commit -m "ci: audit repository merge settings"
```

---

### Task 4: Documentation and full verification

**Files:**
- Modify: `docs/GITHUB_RULESETS.md`
- Modify: `docs/BRANCHING.md`

**Interfaces:**
- Consumes: the completed doctor command and workflow behavior from Tasks 1-3.
- Produces: operator documentation that distinguishes detection from manual remediation and an implementation branch ready for PR review.

- [ ] **Step 1: Document the fourth governance surface**

In `docs/GITHUB_RULESETS.md`:

- document `bash scripts/ci/audit-live-repository-settings.sh owner/repo`;
- state the exact four canonical repository merge values;
- state that repository merge settings are separate from Ruleset/effective-rule APIs;
- update the Governance Audit description from three to four surfaces;
- state that all surfaces are attempted even when one fails, while any failure keeps the run failed;
- preserve manual administrator remediation and explicitly avoid suggesting an administration token for the workflow.

- [ ] **Step 2: Link executable verification from branching policy**

In `docs/BRANCHING.md`, in the repository merge-settings guidance, reference the new doctor command and keep the canonical values unchanged.

- [ ] **Step 3: Run targeted governance suite**

Run:

```bash
python3 -m unittest \
  scripts.ci.test_validate_rulesets \
  scripts.ci.test_validate_rulesets_portability \
  scripts.ci.test_audit_effective_rules \
  scripts.ci.test_audit_main_ruleset \
  scripts.ci.test_audit_release_tag_ruleset \
  scripts.ci.test_audit_repository_settings \
  scripts.ci.test_audit_live_repository_settings \
  scripts.ci.test_governance_audit_workflow \
  scripts.ci.test_release_tag_immutability_proof \
  -v
python3 scripts/ci/validate_rulesets.py
```

Expected: all tests PASS and canonical Ruleset validation succeeds.

- [ ] **Step 4: Run repository hygiene checks for touched surfaces**

Run:

```bash
actionlint
shellcheck scripts/ci/*.sh
shfmt -d -i 2 -ci scripts
```

Expected: no findings/diff.

- [ ] **Step 5: Run the repository's required local gates available in the development environment**

Run the same governance/Quality commands documented by the repository for a pre-PR check. If a platform-specific gate cannot execute in the current environment, record that limitation and rely on the exact-head GitHub Actions gate rather than weakening/skipping its contract.

Expected: every executable local gate passes.

- [ ] **Step 6: Commit documentation**

```bash
git add docs/GITHUB_RULESETS.md docs/BRANCHING.md
git commit -m "docs: document repository settings audit"
```

- [ ] **Step 7: Review the full branch before opening the implementation PR**

Compare the implementation branch against its base and verify:

```text
no live GitHub administration mutation was added
no privilege expansion was added
all four Governance Audit doctors use always()
continue-on-error is absent
Issue #43 remains open pending administrator rollout
only spec/plan plus intended implementation/test/workflow/doc files changed
```

Then request whole-branch review before merge.
