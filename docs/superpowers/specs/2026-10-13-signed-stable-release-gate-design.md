# Signed Stable Release Gate Design

## Context

SchneeRunner currently has a two-stage macOS release architecture:

1. `Release Build` builds and tests an unsigned application without release secrets and hands off a provenance-bound archive.
2. `Release Publisher` validates that handoff on the trusted default branch and calls the reusable macOS release workflow.

The pipeline already has source/artifact identity checks, immutable handoff validation, packaged `.app` and mounted-DMG launch smoke testing, signing/notarization support, and post-build release verification.

The remaining release blocker is that the normal publisher currently uses:

```yaml
sign_release: false
publish_github_release: true
```

Repository contract tests intentionally pin that unsigned stable-publication behavior. Historical bootstrap workflows for v0.1.0, v0.1.1, and v0.1.2 also contain dedicated unsigned publication paths.

Issue #142 originally covered both packaged startup correctness and public-distribution trust. The v0.1.2 work addressed startup correctness and added launch smoke tests, but normal stable releases remain unsigned and unnotarized.

The design problem is therefore not how to build unsigned artifacts. It is how to make the trust boundary explicit: unsigned artifacts are valid intermediate CI/test artifacts, but they must not be promoted to a normal stable GitHub Release.

## Decision

Adopt a **Signed Stable Only** policy.

The unsigned build stage remains unchanged and secret-free. The trusted publisher may publish a stable GitHub Release only after the application and DMG have been Developer ID signed, submitted for Apple notarization, stapled, and successfully verified.

Unsigned artifacts remain useful for CI, runtime proof, debugging, and development/test distribution inside Actions artifacts. They are not stable public release payloads.

Historical unsigned GitHub Releases v0.1.0, v0.1.1, and v0.1.2 remain immutable historical records. This change does not replace, delete, or rewrite those releases or tags.

## Goals

1. Preserve the existing secret-free unsigned `Release Build` stage.
2. Require Developer ID signing and Apple notarization for all future normal stable GitHub Releases.
3. Fail early when the trusted publisher is missing required signing configuration.
4. Add defense in depth so the reusable release workflow rejects `publish_github_release=true` with `sign_release=false` before entering the protected release environment.
5. Remove the historical v0.1.0/v0.1.1/v0.1.2 bootstrap workflows as executable publication entry points without altering their already-published releases or tags.
6. Reverse existing regression tests that currently require unsigned stable publication.
7. Add repository-level contract tests preventing a future caller from reintroducing an unsigned stable release path.
8. Update release/setup/secrets documentation to distinguish unsigned CI artifacts from production releases.
9. Keep Issue #142 open until an actual newly signed/notarized patch release is published and its trust verification succeeds.

## Non-goals

- Do not add Apple credentials to the untrusted/tag-triggered `Release Build` workflow.
- Do not expose signing secrets to pull-request, tag-build, or arbitrary branch contexts.
- Do not redesign artifact provenance or source-binding architecture.
- Do not replace packaged-app launch smoke tests.
- Do not delete or mutate v0.1.0, v0.1.1, or v0.1.2 releases/tags.
- Do not automatically create or purchase a Developer ID certificate.
- Do not close Issue #142 merely because the code-side release gate lands.
- Do not add a prerelease channel or general release-channel framework.

## Alternatives considered

### A. Signed Stable Only — selected

Future stable GitHub Releases require signing and notarization. Unsigned artifacts remain Actions artifacts only.

Advantages:

- matches the remaining acceptance intent of Issue #142;
- creates a simple trust invariant;
- preserves the secure two-stage release architecture;
- removes ambiguity for stable-release users;
- avoids teaching users to bypass Gatekeeper for normal releases.

Trade-off: stable publication is intentionally blocked until repository/environment signing configuration exists.

### B. Allow unsigned prereleases

Unsigned builds could be uploaded as GitHub prereleases while stable releases require signing.

Rejected. Actions artifacts already serve development/test distribution, and an extra release channel would add unnecessary policy complexity.

### C. Documentation only

Keep current workflows and merely document Gatekeeper warnings.

Rejected because executable workflow and test contracts currently preserve unsigned stable publication. Documentation cannot enforce the boundary.

## Architecture

The release architecture remains split into an unprivileged build plane and a privileged publication plane.

```text
stable tag
   |
   v
Release Build
  - checkout tag
  - build/test unsigned app
  - package unsigned-macos-app.tar.gz
  - produce build provenance
  - upload source artifact
  - NO release secrets
   |
   v
Release Publisher: validate
  - trusted default-branch control code
  - resolve exact upstream artifact
  - verify repository/source/tag/artifact identity
  - verify non-secret signing identity configuration
  - re-handoff validated artifact
   |
   v
Reusable macOS Release: policy
  - secret-free
  - no protected release environment
  - reject publish=true + sign=false
   |
   v
Reusable macOS Release: release
  - protected release environment
  - import Developer ID certificate
  - sign app
  - build/sign DMG
  - notarize and staple
  - verify signed release
  - upload exact verified artifact
   |
   v
Publish job
  - reverify exact signer-produced artifact
  - create GitHub Release
```

No signing secret crosses into `Release Build`, repository-specific publisher validation, or the reusable policy job.

## Stable publication invariant

The repository SHALL enforce:

```text
publish stable GitHub Release => sign_release == true
```

For the SchneeRunner normal publisher:

```text
sign_release == true
signing_identity == vars.MACOS_SIGNING_IDENTITY
publish_github_release == true
```

The invariant is enforced independently at two layers:

1. `release-publisher.yml` selects signed mode and validates the required signing identity configuration;
2. `reusable-macos-release.yml` has a secret-free policy job that rejects public publication in unsigned mode.

The reusable policy job prevents a future caller from bypassing the repository-specific publisher.

## Release Publisher changes

### Configuration

The normal publisher SHALL call `reusable-macos-release.yml` with:

```yaml
sign_release: true
signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}
publish_github_release: true
```

The current unsigned/empty-signing-identity configuration SHALL be removed.

### Early signing-identity gate

The existing secret-free `validate` job SHALL reject a missing or blank `MACOS_SIGNING_IDENTITY` before invoking the reusable privileged workflow.

The gate checks only non-secret configuration. Certificate material and App Store Connect credentials remain confined to the existing protected `release` environment.

### Required configuration

The privileged release path already expects these secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_P8`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`

The non-secret signing identity is:

- `MACOS_SIGNING_IDENTITY`

This change does not move any credential into source code or unprivileged jobs.

## Reusable macOS release policy job

`reusable-macos-release.yml` SHALL add a dedicated secret-free `policy` job.

The job SHALL:

- run without the protected `release` environment;
- require no signing/notarization secrets;
- fail when `publish_github_release == true && sign_release == false`;
- succeed for signed publication;
- continue to permit unsigned artifact-only execution when `publish_github_release == false`.

The existing privileged `release` job SHALL depend on `policy` and SHALL not start when policy validation fails.

This placement is deliberate: an unsafe caller must fail before the workflow enters the release environment or makes signing secrets available to a job.

The guard must produce an explicit failure. Silently skipping publication is not sufficient because a misconfigured caller should be visible in CI.

## Signing and notarization flow

The existing privileged sequence remains authoritative:

1. verify exact publisher-owned handoff artifact;
2. extract and revalidate application metadata;
3. rebind tag/source before secrets;
4. import Developer ID certificate;
5. sign `.app`;
6. create DMG;
7. sign DMG;
8. notarize and staple;
9. run `verify-release.sh` with signed mode enabled;
10. write final release provenance;
11. upload exact verified artifact;
12. publish only that verified artifact.

No new signing implementation is introduced unless existing scripts prove insufficient during implementation.

## Historical bootstrap workflow retirement

The following temporary bootstrap workflow files SHALL be deleted:

- `.github/workflows/bootstrap-v0.1.0-release.yml`
- `.github/workflows/bootstrap-v0.1.1-release.yml`
- `.github/workflows/bootstrap-v0.1.2-release.yml`

Git history and release documentation preserve how those historical releases were produced. Keeping executable bootstrap publishers is unnecessary and would leave an alternate unsigned stable-publication surface.

Deletion SHALL NOT:

- delete or modify the existing v0.1.0/v0.1.1/v0.1.2 tags;
- delete or modify their GitHub Releases or assets;
- republish those versions as signed replacements.

Historical bootstrap helper code may remain when still used by tests/history tooling, but no live workflow with `contents: write` may remain capable of recreating those unsigned releases.

Tests that exist only to enforce executable bootstrap workflow structure SHALL be removed or rewritten as historical-data tests if they still protect useful immutable facts.

## Existing unsigned artifact paths

Unsigned artifacts remain first-class internal build products:

- `unsigned-macos-app.tar.gz` remains the Release Build handoff;
- runtime proof and artifact identity validators may continue to refer to unsigned source archives;
- release provenance continues to bind the unsigned input archive before privileged transformation;
- CI may launch-smoke unsigned packaged applications where needed for runtime correctness.

The policy concerns **promotion**, not creation.

Tests must not broadly ban the string `unsigned` or unsigned artifact creation. They must specifically prohibit unsigned stable GitHub publication.

## Contract test changes

### Reverse obsolete unsigned-publication assertions

Tests including:

- `scripts/release/test_unsigned_release_workflow_contract.py`
- `scripts/release/test_v0_1_1_distribution_contract.py`

currently assert that the normal publisher uses `sign_release: false` with public publication.

Those assertions SHALL be replaced by the signed-stable contract:

- normal publisher selects `sign_release: true`;
- normal publisher passes `signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}`;
- normal publisher still requests GitHub Release publication;
- publisher validation rejects blank signing identity before the reusable workflow is called.

Historical-version-specific assertions that only preserve the obsolete executable publication path SHALL be removed or narrowed to immutable historical release facts.

### Reusable workflow policy tests

Add coverage proving:

- `publish_github_release=true` + `sign_release=false` fails in the policy job;
- the privileged release job depends on successful policy validation;
- policy validation itself does not use the `release` environment or signing secrets;
- unsigned artifact-only execution with publication disabled remains permitted;
- signed publication retains certificate import, app signing, DMG signing, notarization/stapling, verification, and final artifact handoff.

### Repository-wide publication regression

Add a focused contract test for release workflow entry points.

It SHALL verify:

- normal stable publisher selects signed mode;
- reusable publication rejects unsigned public publication;
- the three historical bootstrap workflow files no longer exist;
- no replacement bootstrap publisher with an unsigned `contents: write` release path is introduced by this change.

The test should reason about relevant release workflows rather than banning every `sign_release: false` occurrence, because unsigned artifact-only execution remains valid.

## Error handling

The release pipeline SHALL fail closed on:

- missing/blank `MACOS_SIGNING_IDENTITY` for normal stable publication;
- public publication requested while `sign_release` is false;
- missing certificate secrets;
- missing App Store Connect notarization credentials;
- signing failure;
- notarization failure;
- stapling failure;
- signed release verification failure;
- source/tag/artifact identity drift.

A failed policy/signing/notarization/verification run must leave the GitHub Release unpublished. Existing source/artifact immutability guarantees remain in force.

## Security boundary

### Unprivileged build plane

- stable tag input;
- no signing secrets;
- no repository contents write permission;
- produces unsigned artifact + provenance only.

### Trusted validation and policy plane

- trusted default-branch control code;
- revalidates source/tag/artifact identity;
- validates non-secret signing identity configuration;
- reusable policy job validates safe input combination;
- no protected release environment;
- no signing/notarization secrets.

### Privileged release plane

- starts only after policy succeeds;
- uses protected `release` environment;
- reads signing/notarization secrets only when needed;
- signs, notarizes, staples, and verifies;
- final publication job receives contents write permission;
- publishes only the exact verified signed artifact.

No broad PAT, permanent bypass actor, or signing secret is added to repository source.

## Documentation changes

### `docs/RELEASE.md`

Clarify that:

- Release Build always creates an unsigned intermediate artifact;
- stable public release requires Developer ID signing + notarization;
- unsigned Actions artifacts are development/test artifacts;
- publication remains blocked until signing configuration exists.

### `docs/SETUP.md`

Make signing configuration an explicit prerequisite for production publication, separate from ordinary CI artifact validation.

### `docs/SECRETS.md`

Document secret values versus the non-secret signing identity variable and preserve the trust-boundary explanation showing that tag-build jobs cannot access release credentials.

### README / release history

Keep v0.1.2 historical documentation accurate: it was unsigned and unnotarized. Do not rewrite historical releases as if they were signed.

## Issue #142 lifecycle

Landing the code-side policy gate advances Issue #142 but does not complete it.

Issue #142 may be closed only after operational evidence exists for a later immutable patch release that:

1. was produced by the normal signed stable publisher;
2. used Developer ID signing;
3. completed Apple notarization and stapling;
4. passed repository release verification in signed mode;
5. passed packaged `.app` and mounted-DMG launch smoke tests;
6. was published as a new immutable GitHub Release rather than replacing v0.1.2;
7. passes the expected Gatekeeper validation path without the manual unsigned-build override.

If credentials are not configured, the correct result is a blocked production release, not fallback to unsigned stable publication.

## Migration sequence

1. Change contract tests to the signed-stable expectations and observe the intended RED failures.
2. Add publisher signing-identity validation and switch the normal publisher to signed mode.
3. Add the secret-free reusable policy job and make privileged release depend on it.
4. Delete the three historical bootstrap workflow files and update affected tests.
5. Update release/setup/secrets documentation.
6. Run Quality, workflow security, release isolation, artifact/provenance, and launch-smoke contract suites.
7. Configure `MACOS_SIGNING_IDENTITY` plus release-environment secrets outside source control.
8. Publish a new patch release through the normal signed path.
9. Verify signing/notarization/stapling/Gatekeeper evidence.
10. Only then close Issue #142.

Steps 7-10 are operational rollout and are not prerequisites for merging the code-side policy gate. Stable publication is intentionally blocked until they are complete.

## Testing strategy

Implementation SHALL use TDD for contract changes.

Expected layers:

1. Python/unit workflow-contract tests for publisher and reusable policy semantics.
2. tests for removal of historical bootstrap workflow entry points.
3. `actionlint` for workflow syntax and expressions.
4. `zizmor` / existing Actions security checks.
5. ShellCheck/shfmt for modified shell helpers, if any.
6. release isolation tests proving secrets remain confined to the privileged plane.
7. artifact identity/provenance suites.
8. packaged-app launch smoke contract.

Where tests currently encode unsigned normal publication, change them first and confirm the expected RED state before modifying workflows.

## Acceptance criteria

The code-side implementation is complete when:

- `Release Build` still produces unsigned, provenance-bound artifacts without release secrets;
- normal `Release Publisher` selects signed mode;
- normal publisher consumes `MACOS_SIGNING_IDENTITY` from trusted configuration;
- blank/missing signing identity fails before the reusable privileged workflow starts;
- reusable macOS release has a secret-free policy job;
- policy explicitly rejects unsigned public GitHub Release publication;
- privileged release depends on successful policy validation;
- unsigned artifact-only usage remains available when publication is disabled;
- v0.1.0/v0.1.1/v0.1.2 bootstrap workflow files are deleted;
- no existing historical release/tag is changed;
- regression tests prevent restoration of unsigned stable publication;
- workflow security, Quality, release isolation, and relevant release tests pass;
- documentation clearly distinguishes unsigned CI artifacts from signed production releases;
- Issue #142 remains open until a later signed/notarized release provides operational trust evidence.

## Scope boundary

This design is limited to release trust and publication policy. It does not redesign application features, packaging layout, source provenance, Rulesets, repository merge settings, or the existing notification/runtime fix.
