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
3. **Valid unsigned artifact-only caller:** `publish_github_release=false` with `sign_release=false` must remain policy-valid so CI/test use is not accidentally removed; Task 3 pins the exact conjunction used by the policy guard.
4. **Historical bypass surface:** none of the v0.1.0/v0.1.1/v0.1.2 bootstrap workflow paths may remain under `.github/workflows`; Task 4 pins exact absence and scans the remaining live workflow publication paths.
5. **Historical truth:** v0.1.2 documentation and README text must continue to say that v0.1.2 itself was unsigned/unnotarized; Task 5 pins and verifies that wording.

---

### Task 1: Replace the unsigned-stable production contract with a signed-stable contract

**Files:**
- Create: `scripts/release/test_signed_stable_release_contract.py`
- Modify: `scripts/release/test_release_workflow_contract.py`
- Modify: `scripts/release/test_v0_1_1_distribution_contract.py`
- Delete later in Task 4: `scripts/release/test_unsigned_release_workflow_contract.py`

**Interfaces:**
- Consumes: `.github/workflows/release-publisher.yml`, `.github/workflows/reusable-macos-release.yml`, `scripts/release/verify-release.sh`.
- Produces: `SignedStableReleaseContractTests`, imported by `scripts.release.test_release_workflow_contract`, as the canonical production-publication contract.

- [ ] **Step 1: Create failing publisher contract tests**

Add these exact methods to `SignedStableReleaseContractTests`:

```python
def test_schneerunner_publisher_requires_signed_stable_release(self): ...
def test_publisher_rejects_blank_signing_identity(self): ...
```

The first asserts:

```python
self.assertIn("Require signing identity configuration", publisher)
self.assertIn("sign_release: true", publisher)
self.assertIn("signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}", publisher)
self.assertIn("publish_github_release: true", publisher)
self.assertNotIn("sign_release: false", publisher)
```

The second isolates the `Require signing identity configuration` step and asserts it binds `MACOS_SIGNING_IDENTITY: ${{ vars.MACOS_SIGNING_IDENTITY }}` and rejects the value when `${MACOS_SIGNING_IDENTITY//[[:space:]]/}` is empty.

- [ ] **Step 2: Create failing reusable-policy contract tests**

Add these exact methods:

```python
def test_reusable_release_has_secret_free_publication_policy_job(self): ...
def test_unsigned_release_verification_remains_available_for_artifact_only_use(self): ...
```

Use a `job_block(text: str, job_id: str) -> str` helper. Assert that `policy` exists, contains no `environment: release` or Apple secret names, references both `inputs.publish_github_release` and `inputs.sign_release`, and that `release` contains `needs: policy`. Keep an assertion that `verify-release.sh` still supports `RELEASE_SIGNED=false`; this prevents the policy change from banning unsigned artifact verification itself.

- [ ] **Step 3: Remove obsolete current-production assertions from the v0.1.1 historical test**

Delete only `test_normal_release_publisher_explicitly_selects_unsigned_mode` and the now-unused `PUBLISHER` constant from `test_v0_1_1_distribution_contract.py`. Keep the bundled-resource/runtime history assertions.

- [ ] **Step 4: Wire the new contract into the aggregate module**

Replace the `UnsignedReleaseWorkflowContractTests` import in `test_release_workflow_contract.py` with:

```python
from scripts.release.test_signed_stable_release_contract import (
    SignedStableReleaseContractTests,
)
```

Do not remove bootstrap imports yet; Task 4 owns bootstrap retirement.

- [ ] **Step 5: Run the new tests and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_v0_1_1_distribution_contract \
  -v
```

Expected: RED only because the current publisher still selects unsigned stable publication and the reusable workflow lacks the policy job.

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
- Consumes: `vars.MACOS_SIGNING_IDENTITY`; existing validated artifact outputs from the `validate` job.
- Produces: the reusable-workflow call contract `sign_release: true`, `signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}`, `publish_github_release: true`.

- [ ] **Step 1: Run publisher-only contract tests and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_schneerunner_publisher_requires_signed_stable_release \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_publisher_rejects_blank_signing_identity \
  -v
```

Expected: FAIL because the signed inputs and identity gate do not yet exist.

- [ ] **Step 2: Add the secret-free signing identity configuration gate**

Add a step named exactly `Require signing identity configuration` to the existing `validate` job before its validated handoff is finalized:

```yaml
env:
  MACOS_SIGNING_IDENTITY: ${{ vars.MACOS_SIGNING_IDENTITY }}
```

The Bash body must `set -euo pipefail` and exit non-zero when:

```bash
[[ -z "${MACOS_SIGNING_IDENTITY//[[:space:]]/}" ]]
```

Use a stable diagnostic mentioning `MACOS_SIGNING_IDENTITY`. Do not reference certificate or App Store Connect secrets.

- [ ] **Step 3: Switch the normal publisher to signed publication**

Set the reusable-workflow inputs exactly to:

```yaml
sign_release: true
signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}
publish_github_release: true
```

Remove the old unsigned/empty-signing-identity behavior.

- [ ] **Step 4: Run publisher-focused tests and verify GREEN**

Run only tests whose behavior Task 2 owns:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_schneerunner_publisher_requires_signed_stable_release \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_publisher_rejects_blank_signing_identity \
  scripts.release.test_release_publisher_workflow_contract \
  -v
```

Expected: PASS. Do not require the whole `test_signed_stable_release_contract` module to be green yet; Task 3 still owns the missing reusable policy job.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release-publisher.yml
git commit -m "ci: require signed stable publisher"
```

### Task 3: Add the reusable release policy gate before the protected environment

**Files:**
- Modify: `.github/workflows/reusable-macos-release.yml`
- Modify: `scripts/release/test_signed_stable_release_contract.py`
- Modify only if structural assertions require it: `scripts/release/test_privileged_release_workflow_contract.py`

**Interfaces:**
- Consumes: boolean workflow inputs `inputs.sign_release` and `inputs.publish_github_release`.
- Produces: a secret-free `policy` job and a privileged `release` job gated by `needs: policy`.

- [ ] **Step 1: Pin the exact unsafe combination in the test**

Add:

```python
def test_policy_rejects_only_unsigned_publication(self): ...
```

Assert the policy script rejects the conjunction equivalent to:

```bash
[[ "${PUBLISH_GITHUB_RELEASE}" == "true" && "${SIGN_RELEASE}" != "true" ]]
```

This exact conjunction is the test that preserves both safe cases: signed publication and unsigned artifact-only execution.

- [ ] **Step 2: Run reusable-policy tests and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_reusable_release_has_secret_free_publication_policy_job \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_policy_rejects_only_unsigned_publication \
  -v
```

Expected: FAIL on missing `policy` / missing `needs: policy`.

- [ ] **Step 3: Add `jobs.policy`**

Add a dedicated `policy` job to `reusable-macos-release.yml` with:

- `runs-on: ubuntu-latest`;
- no `environment`;
- no Apple secret references;
- environment bindings for `inputs.sign_release` and `inputs.publish_github_release`;
- `set -euo pipefail`;
- explicit non-zero failure only for unsigned public publication;
- a stable diagnostic: `Stable GitHub Release publication requires Developer ID signing and notarization.`

- [ ] **Step 4: Gate the privileged release job on policy success**

Add:

```yaml
needs: policy
```

to `jobs.release`. Preserve the existing `environment: release`, read-only repository permissions, source/tag/artifact revalidation, signing/notarization sequence, and verified artifact handoff.

- [ ] **Step 5: Run reusable/privileged tests and verify GREEN**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_privileged_release_workflow_contract \
  scripts.release.test_release_environment_runtime_proof \
  -v
```

Expected: PASS for the signed-stable and privilege-boundary contracts. Exactly one `environment: release` remains, and the final publication job remains the separate `contents: write` boundary without Apple secrets.

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
- Modify: `scripts/release/test_bootstrap_v0_1_2_release_contract.py`
- Modify: `scripts/release/test_release_workflow_contract.py`
- Delete: `scripts/release/test_unsigned_release_workflow_contract.py`
- Modify: `scripts/release/test_signed_stable_release_contract.py`

**Interfaces:**
- Consumes: historical bootstrap provenance/publisher helpers and release notes that remain in the repository.
- Produces: no executable v0.1.x bootstrap publisher under `.github/workflows`, while keeping useful historical provenance/resource tests.

- [ ] **Step 1: Add failing retirement tests**

Add these exact methods to `SignedStableReleaseContractTests`:

```python
def test_historical_bootstrap_publishers_are_retired(self): ...
def test_live_workflows_have_no_unsigned_stable_publication_path(self): ...
```

The first asserts the three exact bootstrap workflow paths do not exist. The second inspects `.github/workflows/*.yml` and fails only when a live workflow exposes a stable GitHub Release publication path while explicitly selecting unsigned release mode; it must not reject `release-build.yml` or unsigned artifact-only behavior.

- [ ] **Step 2: Run the exact-absence test and verify RED**

Run:

```bash
python3 -m unittest \
  scripts.release.test_signed_stable_release_contract.SignedStableReleaseContractTests.test_historical_bootstrap_publishers_are_retired \
  -v
```

Expected: FAIL because all three workflow files exist.

- [ ] **Step 3: Delete the three historical bootstrap workflow files**

Delete only the workflow entry points. Do not mutate any existing GitHub Release, tag, asset, release note, bootstrap provenance format, or generalized bootstrap helper script.

- [ ] **Step 4: Remove workflow-only bootstrap test modules**

Delete:

```text
scripts/release/test_bootstrap_v0_1_0_release_contract.py
scripts/release/test_bootstrap_v0_1_1_release_contract.py
```

Remove their imports from `test_release_workflow_contract.py`. A repository search must show no remaining imports of `BootstrapV010ReleaseContractTests` or `BootstrapV011SignedReleaseContractTests`.

- [ ] **Step 5: Refactor v0.1.2 tests into historical verification**

Keep `scripts/release/test_bootstrap_v0_1_2_release_contract.py` but remove `WORKFLOW` and all tests that require the deleted workflow. Rename the class to:

```python
class V012HistoricalDistributionContractTests(unittest.TestCase):
```

Keep tests for:

- `verify-app-resources.sh` and both localizations;
- build/release helpers still sharing the resource verifier;
- exact v0.1.2 bootstrap provenance writer/verifier support;
- `docs/releases/v0.1.2.md` accurately describing v0.1.1 startup failure, v0.1.2 fix, `unsigned`, and `not notarized`.

Update the aggregate import to `V012HistoricalDistributionContractTests`.

- [ ] **Step 6: Delete the obsolete unsigned production contract module**

Delete `scripts/release/test_unsigned_release_workflow_contract.py`. Its valid unsigned-verifier coverage now lives in `test_signed_stable_release_contract.py`; its normal-publisher assertions are intentionally obsolete.

- [ ] **Step 7: Run aggregate release contracts and verify GREEN**

Run:

```bash
python3 -m unittest \
  scripts.release.test_release_workflow_contract \
  scripts.release.test_signed_stable_release_contract \
  scripts.release.test_bootstrap_release_provenance \
  scripts.release.test_bootstrap_release_publisher \
  -v
```

Expected: PASS, with no import errors and no executable historical bootstrap publisher.

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
- Modify: `README.md`
- Verify historical truth: `docs/releases/v0.1.2.md`
- Verify workflows/tests from Tasks 1-4.

**Interfaces:**
- Consumes: the final signed-stable workflow contract.
- Produces: operator/user documentation separating unsigned CI artifacts from signed production releases and describing the external credential rollout required before the next stable release.

- [ ] **Step 1: Update `docs/RELEASE.md`**

Document these exact operational facts:

- `Release Build` still produces an unsigned intermediate archive without Apple secrets;
- stable public publication is blocked unless signing/notarization is enabled;
- unsigned Actions artifacts are CI/development artifacts, not normal stable downloads;
- normal stable publication signs the app, signs the DMG, notarizes/staples, runs signed verification, and only then publishes the GitHub Release.

- [ ] **Step 2: Update `docs/SETUP.md`**

Make production-release readiness require:

```text
MACOS_SIGNING_IDENTITY
MACOS_CERTIFICATE_P12_BASE64
MACOS_CERTIFICATE_PASSWORD
APP_STORE_CONNECT_API_KEY_P8
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
```

State explicitly that `MACOS_SIGNING_IDENTITY` is non-secret configuration and the remaining values belong to the protected `release` environment.

- [ ] **Step 3: Update `docs/SECRETS.md`**

Document that the unprivileged tag build cannot access Apple credentials and that the reusable `policy` job executes before the protected `release` environment is entered.

- [ ] **Step 4: Update README without rewriting history**

Keep v0.1.2 described as the existing unsigned/unnotarized historical release until a later signed release actually exists. Add a forward-looking note that normal future stable publication is signed/notarized and that CI artifacts may still be unsigned.

- [ ] **Step 5: Add/retain historical-truth assertions**

In `V012HistoricalDistributionContractTests`, assert `docs/releases/v0.1.2.md` contains both `unsigned` and `not notarized`. Add a focused README assertion that v0.1.2 remains described as unsigned/unnotarized rather than falsely claiming it was signed.

- [ ] **Step 6: Run targeted release suites**

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

- [ ] **Step 7: Run repository workflow/security gates**

Run the repository's existing commands for:

```text
actionlint
zizmor
ShellCheck
shfmt
Quality release-isolation contract suite
Release Isolation TDD contract suite
```

Do not weaken or skip a gate. If a tool is unavailable locally, record that limitation and require the exact-head PR CI result before merge.

- [ ] **Step 8: Verify final workflow surface**

Confirm:

- normal publisher uses signed mode;
- reusable workflow has the pre-environment policy job;
- no `bootstrap-v0.1.x-release.yml` files remain;
- no live workflow contains an unsigned stable GitHub publication path;
- `release-build.yml` remains secret-free/read-only;
- v0.1.0/v0.1.1/v0.1.2 remote releases/tags were not changed by this code work.

- [ ] **Step 9: Commit docs/final contract updates**

```bash
git add README.md docs scripts/release
git commit -m "docs: require signed production releases"
```

- [ ] **Step 10: Open the implementation PR**

Create a focused PR to `main`, reference Issue #142 without closing it, and state that code-side policy is complete but operational closure still requires configured Apple signing credentials plus a later signed/notarized patch release.

- [ ] **Step 11: Merge only after exact-head required checks are green**

Confirm the PR head SHA has green required workflows, no unresolved review threads, and remains mergeable. Use squash merge. Do not close Issue #142 as part of the merge.

## Operational follow-up after code merge

These actions are deliberately outside the code implementation plan and require repository/environment configuration plus Apple credentials:

1. configure `MACOS_SIGNING_IDENTITY`;
2. configure `MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, and `APP_STORE_CONNECT_ISSUER_ID` in the protected `release` environment;
3. create a new patch tag through the normal release path;
4. confirm signed-mode release verification, notarization, stapling, packaged launch smoke, and expected Gatekeeper acceptance;
5. only then close Issue #142.
