# Signed Stable Release Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make future stable GitHub Releases fail closed unless SchneeRunner is Developer ID signed and notarized, while preserving the secret-free unsigned build artifact path for CI and development use.

**Architecture:** Keep `Release Build` unchanged as the unprivileged unsigned producer. Enforce signed publication first in the repository-specific publisher, then again in a secret-free policy job inside `reusable-macos-release.yml`; retire historical bootstrap workflows so no alternate unsigned stable-publication path remains.

**Tech Stack:** GitHub Actions YAML, Bash, Python `unittest`, existing macOS signing/notarization shell helpers, actionlint, zizmor, ShellCheck, shfmt.

**Spec:** `docs/superpowers/specs/2026-10-13-signed-stable-release-gate-design.md`

## Global Constraints

- `Release Build` must remain secret-free and continue to produce the provenance-bound `unsigned-macos-app.tar.gz` handoff.
- Stable GitHub publication requires `sign_release == true`.
- Normal SchneeRunner publication uses `signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}` and `publish_github_release: true`.
- `publish_github_release == true && sign_release == false` must fail before the protected `release` environment is entered.
- Unsigned artifact-only reusable-workflow execution may remain valid when `publish_github_release == false`.
- Existing v0.1.0, v0.1.1, and v0.1.2 GitHub Releases and tags must not be modified or deleted.
- Historical bootstrap workflow files are removed as executable publication entry points.
- Issue #142 remains open until a later signed/notarized immutable patch release supplies operational Gatekeeper evidence.
- No Apple credential moves into source code, PR jobs, tag-build jobs, or the unprivileged build plane.

## Review Focus

1. **Blank-but-present signing identity:** whitespace-only `MACOS_SIGNING_IDENTITY` must fail the normal publisher before the reusable release workflow is called; Task 2 pins this with the exact shell guard contract.
2. **Unsafe reusable caller:** `publish_github_release=true` with `sign_release=false` must explicitly fail rather than silently skip publication; Task 3 pins the policy job and dependency ordering.
3. **Valid unsigned artifact-only caller:** `publish_github_release=false` with `sign_release=false` must remain policy-valid so CI/test use is not accidentally removed; Task 3 pins the inverse condition.
4. **Historical bypass surface:** none of the v0.1.0/v0.1.1/v0.1.2 bootstrap workflow paths may remain under `.github/workflows`; Task 4 pins exact absence and scans live workflow publication paths.
5. **Historical truth:** v0.1.2 documentation must continue to say it was unsigned/unnotarized even after production policy changes; Task 5 pins and verifies that wording remains factual.

---

### Task 1: Replace the unsigned-stable contract with a signed-stable contract

**Files:**
- Create: `scripts/release/test_signed_stable_release_contract.py`
- Modify: `scripts/release/test_release_workflow_contract.py`
- Modify: `scripts/release/test_v0_1_1_distribution_contract.py`
- Delete later in Task 4: `scripts/release/test_unsigned_release_workflow_contract.py`

**Interfaces:**
- Consumes: `.github/workflows/release-publisher.yml`, `.github/workflows/reusable-macos-release.yml`, `scripts/release/verify-release.sh`.
- Produces: `SignedStableReleaseContractTests`, imported by `scripts.release.test_release_workflow_contract`, defining the canonical production-publication contract used by later tasks.

- [ ] **Step 1: Add failing publisher contract tests**

Create `SignedStableReleaseContractTests` with tests asserting:

```python
self.assertIn("Require signing identity configuration", publisher)
self.assertIn("sign_release: true", publisher)
self.assertIn("signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}", publisher)
self.assertIn("publish_github_release: true", publisher)
self.assertNotIn("sign_release: false", publisher)
```

Also assert the configuration step binds `MACOS_SIGNING_IDENTITY: ${{ vars.MACOS_SIGNING_IDENTITY }}` and contains a non-empty/whitespace rejection before the `sign-and-publish` reusable workflow job can run.

- [ ] **Step 2: Add failing reusable-policy contract tests**

In the same test class, use a `job_block(text, job_id)` helper and assert:

- a `policy` job exists;
- the policy job has no `environment: release` and no Apple secret names;
- the policy job contains both `inputs.publish_github_release` and `inputs.sign_release` bindings and an explicit failure message for unsigned public publication;
- the `release` job has `needs: policy` and remains the only job with `environment: release`;
- `verify-release.sh` still supports `RELEASE_SIGNED=false` so unsigned artifact verification itself is not removed.

- [ ] **Step 3: Remove obsolete current-production assertions from v0.1.1 historical tests**

Delete only `test_normal_release_publisher_explicitly_selects_unsigned_mode` and the now-unused `PUBLISHER` constant from `test_v0_1_1_distribution_contract.py`. Keep the resource/runtime historical assertions intact.

- [ ] **Step 4: Wire the new contract into the aggregate release contract module**

Replace the import of `UnsignedReleaseWorkflowContractTests` in `test_release_workflow_contract.py` with:

```python
from scripts.release.test_signed_stable_release_contract import (
    SignedStableReleaseContractTests,
)
```

Do not yet remove bootstrap imports; Task 4 owns bootstrap retirement.

- [ ] **Step 5: Run targeted tests and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_v0_1_1_distribution_contract \
  -v
```

Expected: failures specifically because the current publisher still selects `sign_release: false`, has no signing-identity gate, and the reusable workflow has no `policy` job.

- [ ] **Step 6: Commit the contract-first change**

```bash
git add scripts/release/test_signed_stable_release_contract.py \
  scripts/release/test_release_workflow_contract.py \
  scripts/release/test_v0_1_1_distribution_contract.py
git commit -m "test: require signed stable publication"
```

### Task 2: Require signed mode in the SchneeRunner release publisher

**Files:**
- Modify: `.github/workflows/release-publisher.yml`
- Test: `scripts/release/test_signed_stable_release_contract.py`
- Existing test: `scripts/release/test_release_publisher_workflow_contract.py`

**Interfaces:**
- Consumes: repository/environment variable `vars.MACOS_SIGNING_IDENTITY`; existing validated artifact outputs from the `validate` job.
- Produces: the reusable-workflow call contract `sign_release: true`, `signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}`, `publish_github_release: true`.

- [ ] **Step 1: Strengthen the test for whitespace-only identity**

Add an assertion that the `Require signing identity configuration` step normalizes or rejects whitespace, not only an empty string. The contract must require a shell check equivalent to testing `${MACOS_SIGNING_IDENTITY//[[:space:]]/}` for emptiness.

- [ ] **Step 2: Run the publisher contract test and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_schneerunner_publisher_requires_signed_stable_release \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_publisher_rejects_blank_signing_identity \
  -v
```

Expected: FAIL because the gate and signed inputs are not present.

- [ ] **Step 3: Add the secret-free signing identity configuration gate**

Add a step named exactly `Require signing identity configuration` to the existing `validate` job, before validated handoff completion, with:

```yaml
env:
  MACOS_SIGNING_IDENTITY: ${{ vars.MACOS_SIGNING_IDENTITY }}
```

The Bash body must `set -euo pipefail` and exit non-zero when the value is empty after removing whitespace. It must not reference certificate or App Store Connect secrets.

- [ ] **Step 4: Switch the normal publisher to signed publication**

Change the reusable-workflow inputs to exactly:

```yaml
sign_release: true
signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}
publish_github_release: true
```

Remove the old `sign_release: false` / empty signing identity behavior.

- [ ] **Step 5: Run publisher-focused tests and verify GREEN**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_release_publisher_workflow_contract \
  -v
```

Expected: publisher tests pass; reusable-policy tests from Task 1 may still fail until Task 3 when run as part of the whole module.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/release-publisher.yml scripts/release/test_signed_stable_release_contract.py
git commit -m "ci: require signed stable publisher"
```

### Task 3: Add the reusable release policy gate before the protected environment

**Files:**
- Modify: `.github/workflows/reusable-macos-release.yml`
- Modify: `scripts/release/test_signed_stable_release_contract.py`
- Modify if needed for structural assertions: `scripts/release/test_privileged_release_workflow_contract.py`

**Interfaces:**
- Consumes: boolean workflow inputs `inputs.sign_release` and `inputs.publish_github_release`.
- Produces: a `policy` job that succeeds for safe combinations and a privileged `release` job gated by `needs: policy`.

- [ ] **Step 1: Add exact policy-condition contract tests**

Pin these semantics in `test_signed_stable_release_contract.py`:

```text
publish=true, sign=false  -> explicit failure path present
publish=true, sign=true   -> policy allows release job to proceed
publish=false, sign=false -> no unsigned-publication rejection is triggered
```

Because this is a YAML contract test, assert the policy script tests the conjunction `publish == true && sign != true`, rather than banning `sign_release: false` globally.

- [ ] **Step 2: Run reusable-policy tests and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_privileged_release_workflow_contract \
  -v
```

Expected: FAIL on missing `policy` job / missing `needs: policy`.

- [ ] **Step 3: Add a secret-free `policy` job**

In `reusable-macos-release.yml`, add `jobs.policy` using `ubuntu-latest`, no `environment`, and no Apple secrets. Bind the two boolean inputs to environment variables and fail with a stable diagnostic such as:

```text
Stable GitHub Release publication requires Developer ID signing and notarization.
```

The policy must reject only `publish_github_release=true` combined with `sign_release=false`.

- [ ] **Step 4: Gate the privileged release job on policy success**

Add:

```yaml
needs: policy
```

to `jobs.release`. Preserve `environment: release`, its existing read-only repository permissions, signing/notarization steps, source revalidation, and artifact handoff.

- [ ] **Step 5: Verify privileged/publication boundaries remain unchanged**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_privileged_release_workflow_contract \
  scripts.release.test_release_environment_runtime_proof \
  -v
```

Expected: PASS. The contract should still show exactly one `environment: release`; the publication job remains the separate `contents: write` boundary without Apple secrets.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/reusable-macos-release.yml \
  scripts/release/test_signed_stable_release_contract.py \
  scripts/release/test_privileged_release_workflow_contract.py
git commit -m "ci: block unsigned stable publication"
```

### Task 4: Retire historical bootstrap publication workflows without deleting historical evidence

**Files:**
- Delete: `.github/workflows/bootstrap-v0.1.0-release.yml`
- Delete: `.github/workflows/bootstrap-v0.1.1-release.yml`
- Delete: `.github/workflows/bootstrap-v0.1.2-release.yml`
- Delete: `scripts/release/test_bootstrap_v0_1_0_release_contract.py`
- Delete: `scripts/release/test_bootstrap_v0_1_1_release_contract.py`
- Modify or replace: `scripts/release/test_bootstrap_v0_1_2_release_contract.py`
- Modify: `scripts/release/test_release_workflow_contract.py`
- Modify: `scripts/release/test_signed_stable_release_contract.py`

**Interfaces:**
- Consumes: historical helper scripts/provenance modules and release notes that remain in the repository.
- Produces: repository workflow surface with no executable v0.1.x unsigned bootstrap publisher and preserved historical v0.1.2 resource/provenance tests.

- [ ] **Step 1: Add failing exact-absence tests before deleting workflows**

In `test_signed_stable_release_contract.py`, assert these paths do not exist:

```python
.github/workflows/bootstrap-v0.1.0-release.yml
.github/workflows/bootstrap-v0.1.1-release.yml
.github/workflows/bootstrap-v0.1.2-release.yml
```

Also scan `.github/workflows/*.yml` and fail if a live workflow combines a GitHub-release publication path with an explicitly unsigned stable-release configuration. The scan must allow unsigned build/artifact-only workflows.

- [ ] **Step 2: Run the retirement test and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_historical_bootstrap_publishers_are_retired \
  -v
```

Expected: FAIL because all three workflow files still exist.

- [ ] **Step 3: Delete the three historical bootstrap workflow files**

Remove only the executable workflow files. Do not delete historical release notes, tags, release assets, provenance formats, or generalized bootstrap helper modules in this task.

- [ ] **Step 4: Remove workflow-only bootstrap contract tests**

Delete `test_bootstrap_v0_1_0_release_contract.py` and `test_bootstrap_v0_1_1_release_contract.py`, then remove their imports from `test_release_workflow_contract.py` and from any other test module that imports them.

- [ ] **Step 5: Preserve useful v0.1.2 historical verification without requiring the deleted workflow**

Refactor `test_bootstrap_v0_1_2_release_contract.py` so it no longer requires `WORKFLOW` or asserts executable workflow behavior. Keep tests for:

- shared packaged resource verifier behavior;
- exact v0.1.2 bootstrap provenance writer/verifier support;
- release notes describing the v0.1.1 startup failure and v0.1.2 unsigned/notarized status accurately;
- relevant runtime/localization historical assertions that do not require the deleted workflow.

Rename the test class to `V012HistoricalDistributionContractTests` and update the aggregate import accordingly.

- [ ] **Step 6: Delete the obsolete unsigned production contract test module**

Delete `scripts/release/test_unsigned_release_workflow_contract.py`; its valid unsigned-verifier assertions are already covered by `test_signed_stable_release_contract.py`, while its normal-publisher assertions are intentionally obsolete.

- [ ] **Step 7: Run the aggregate release contract suite and verify GREEN**

Run:

```bash
python3 -m unittest \
  scripts.release.test_release_workflow_contract \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_bootstrap_release_provenance \
  scripts.release.test_bootstrap_release_publisher \
  -v
```

Expected: PASS, with no import referring to deleted bootstrap workflow-contract modules.

- [ ] **Step 8: Commit**

```bash
git add -A .github/workflows scripts/release
git commit -m "ci: retire unsigned bootstrap publishers"
```

### Task 5: Update operator documentation and run full release/security verification

**Files:**
- Modify: `docs/RELEASE.md`
- Modify: `docs/SETUP.md`
- Modify: `docs/SECRETS.md`
- Verify unchanged historical truth: `docs/releases/v0.1.2.md`
- Verify workflows/tests from Tasks 1-4.

**Interfaces:**
- Consumes: the final signed-stable workflow contract.
- Produces: operator documentation that distinguishes unsigned CI artifacts from signed production releases and states the external credential rollout needed before the next release.

- [ ] **Step 1: Update release documentation**

Document these exact operational facts in `docs/RELEASE.md`:

- `Release Build` still produces an unsigned intermediate archive without Apple secrets;
- stable public publication is blocked unless signing/notarization is enabled;
- unsigned artifacts are CI/development artifacts, not normal stable downloads;
- normal stable publication runs through Developer ID signing, DMG signing, notarization, stapling, signed verification, and only then GitHub Release publication.

- [ ] **Step 2: Update setup documentation**

In `docs/SETUP.md`, make production-release readiness require:

```text
MACOS_SIGNING_IDENTITY
MACOS_CERTIFICATE_P12_BASE64
MACOS_CERTIFICATE_PASSWORD
APP_STORE_CONNECT_API_KEY_P8
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
```

Clearly distinguish the non-secret identity variable from protected release-environment secrets.

- [ ] **Step 3: Update secret-boundary documentation**

In `docs/SECRETS.md`, document that the unprivileged tag build cannot access Apple credentials and that reusable-policy validation happens before the protected `release` environment.

- [ ] **Step 4: Pin historical truth**

Add/retain a test assertion that `docs/releases/v0.1.2.md` still contains both `unsigned` and `not notarized`. Do not rewrite v0.1.2 as if it had been signed.

- [ ] **Step 5: Run targeted Python release suites**

Run at minimum:

```bash
python3 -m unittest \
  scripts.release.test_release_workflow_contract \
  scripts.release.test_release_publisher_workflow_contract \
  scripts.release.test_privileged_release_workflow_contract \
  scripts.release.test_release_environment_runtime_proof \
  scripts.release.test_packaged_app_launch_smoke_contract \
  scripts.release.test_bootstrap_release_provenance \
  scripts.release.test_bootstrap_release_publisher \
  -v
```

Expected: PASS.

- [ ] **Step 6: Run repository workflow/security gates**

Run the repository's existing commands for:

```text
actionlint
zizmor
ShellCheck
shfmt
Quality release-isolation contract suite
Release Isolation TDD contract suite
```

Do not weaken or skip a gate to make this change pass. If a tool is unavailable locally, record that limitation and require the exact-head PR CI result before merge.

- [ ] **Step 7: Verify the branch contains no alternate unsigned stable-publication workflow**

Inspect `.github/workflows` and confirm:

- normal publisher is signed;
- reusable workflow has the pre-environment policy job;
- no `bootstrap-v0.1.x-release.yml` files remain;
- no new workflow uses an unsigned public stable publication path;
- `release-build.yml` remains secret-free/read-only.

- [ ] **Step 8: Commit docs/final contract updates**

```bash
git add docs scripts/release
git commit -m "docs: require signed production releases"
```

- [ ] **Step 9: Open the implementation PR**

Create a focused PR from the implementation branch to `main`, referencing Issue #142 without closing it. The PR body must state that code-side policy is complete but operational closure still requires configured signing credentials and a later signed/notarized patch release.

- [ ] **Step 10: Merge only after exact-head required checks are green**

Confirm the PR head SHA has green required workflows, no unresolved review threads, and remains mergeable. Use squash merge. Do not close Issue #142 as part of the merge.

## Operational follow-up after code merge

These actions are deliberately outside the code implementation plan and require repository/environment configuration plus Apple credentials:

1. configure `MACOS_SIGNING_IDENTITY`;
2. configure the existing certificate and App Store Connect secrets in the protected `release` environment;
3. create a new patch tag through the normal release path;
4. confirm signed-mode release verification, notarization, stapling, launch smoke, and expected Gatekeeper acceptance;
5. only then close Issue #142.
