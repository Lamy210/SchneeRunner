# Signed Stable Release Gate Design

## Context

SchneeRunner currently has a two-stage macOS release architecture:

1. `Release Build` builds and tests an unsigned application without release secrets and hands off a provenance-bound archive.
2. `Release Publisher` validates that handoff on the trusted default branch and calls the reusable macOS release workflow.

The release pipeline already contains strong source/artifact identity checks, immutable handoff validation, launch smoke testing for the packaged `.app` and DMG payload, signing/notarization support, and post-build release verification.

However, the normal publisher currently calls the reusable workflow with:

```yaml
sign_release: false
publish_github_release: true
```

Repository contract tests intentionally pin that unsigned stable-publication behavior. Historical bootstrap workflows for v0.1.0, v0.1.1, and v0.1.2 also contain dedicated unsigned publication paths.

Issue #142 originally covered two separate release blockers:

- packaged startup/runtime failure, now addressed by the v0.1.2 launch-safety work and packaged-app launch smoke tests;
- public-distribution trust, which remains unresolved because normal stable releases are still unsigned and unnotarized.

The remaining design problem is therefore not how to build unsigned artifacts. It is how to make the trust boundary explicit: unsigned artifacts are valid intermediate CI/test artifacts, but they must not be promoted to a normal stable GitHub Release.

## Decision

Adopt a **Signed Stable Only** policy.

The unsigned build stage remains unchanged and secret-free. The trusted publisher may publish a stable GitHub Release only after the application and DMG have been Developer ID signed, submitted for Apple notarization, stapled, and successfully verified.

Unsigned artifacts remain useful for CI, runtime proof, debugging, and development/test distribution inside Actions artifacts. They are not stable public release payloads.

Historical unsigned GitHub Releases v0.1.0, v0.1.1, and v0.1.2 remain immutable historical records. This change does not replace, delete, or silently rewrite those releases.

## Goals

1. Preserve the existing secret-free unsigned `Release Build` stage.
2. Require Developer ID signing and Apple notarization for all future normal stable GitHub Releases.
3. Fail early when the trusted publisher is missing required signing configuration.
4. Add defense in depth so the reusable release workflow itself rejects `publish_github_release=true` with `sign_release=false`.
5. Retire historical bootstrap workflows as publication entry points without altering already-published releases or tags.
6. Reverse the existing regression tests that currently require unsigned stable publication.
7. Add repository-level contract tests preventing a future caller from reintroducing an unsigned stable release path.
8. Update release/setup/secrets documentation to distinguish unsigned CI artifacts from production releases.
9. Keep Issue #142 open until an actual newly signed/notarized patch release is published and its trust verification succeeds.

## Non-goals

- Do not add Apple credentials to the untrusted/tag-triggered `Release Build` workflow.
- Do not expose signing secrets to pull-request, tag-build, or arbitrary branch contexts.
- Do not redesign the existing artifact provenance or source-binding architecture.
- Do not replace the existing packaged-app launch smoke tests.
- Do not delete or mutate v0.1.0, v0.1.1, or v0.1.2 releases/tags.
- Do not automatically create or purchase a Developer ID certificate.
- Do not close Issue #142 merely because the code-side release gate lands.
- Do not introduce a general release-channel framework unless required by the signed-stable policy.

## Alternatives considered

### A. Signed Stable Only — selected

Future stable GitHub Releases require signing and notarization. Unsigned artifacts remain Actions artifacts only.

Advantages:

- matches the remaining acceptance intent of Issue #142;
- creates a simple trust invariant;
- preserves the current secure two-stage release architecture;
- removes ambiguity for users downloading a stable release;
- avoids teaching users to bypass Gatekeeper for normal releases.

Trade-off: stable publication is blocked until repository/environment signing configuration exists.

### B. Allow unsigned prereleases

Unsigned builds could be uploaded as GitHub prereleases while stable releases require signing.

This keeps public test distribution convenient but expands the release-channel state machine and weakens the simple invariant. It is not needed for the current goal because Actions artifacts already serve development/test distribution.

Rejected for this change.

### C. Documentation only

Keep current workflows and merely document that unsigned releases may trigger Gatekeeper warnings.

Rejected because the repository currently has executable workflow and test contracts that positively preserve unsigned stable publication. Documentation cannot enforce the required boundary.

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
  - run from trusted default-branch control code
  - resolve exact upstream build artifact
  - verify repository/source/tag/artifact identity
  - verify signing configuration is present
  - re-handoff validated artifact
   |
   v
Reusable macOS Release
  - reject public publication when sign_release=false
  - import Developer ID certificate
  - sign app
  - build/sign DMG
  - notarize and staple
  - verify release / Gatekeeper-relevant trust state
  - upload verified release artifact
   |
   v
Publish job
  - reverify exact signer-produced artifact
  - create GitHub Release from verified signed payload
```

No signing secret crosses into the `Release Build` stage.

## Stable publication invariant

The repository SHALL enforce this invariant:

```text
publish stable GitHub Release => sign_release == true
```

For the SchneeRunner normal publisher specifically:

```text
sign_release == true
signing_identity == repository/environment configured MACOS_SIGNING_IDENTITY
publish_github_release == true
```

The invariant is enforced at two independent layers:

1. the repository-specific `release-publisher.yml` selects signed mode and validates its required configuration;
2. the generic reusable macOS release workflow refuses public publication in unsigned mode.

The second layer prevents a future repository caller from bypassing the first by calling the reusable workflow directly with an unsafe input combination.

## Release Publisher changes

### Configuration

The normal publisher SHALL call `reusable-macos-release.yml` with:

```yaml
sign_release: true
signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}
publish_github_release: true
```

The existing empty signing identity / unsigned configuration SHALL be removed.

### Early configuration gate

The publisher SHALL fail during its secret-free validation phase if the required non-secret signing identity configuration is absent or blank.

The check belongs before the privileged reusable workflow so configuration mistakes fail quickly and do not consume the signing environment unnecessarily.

The gate SHALL validate only non-secret configuration. Certificate material and App Store Connect credentials remain accessible only in the existing `release` Environment / privileged release workflow.

### Required secrets/configuration

The existing release implementation expects the privileged workflow to access:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_P8`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`

and a non-secret signing identity variable:

- `MACOS_SIGNING_IDENTITY`

This change does not move those credentials into source code or unprivileged jobs.

## Reusable macOS release gate

`reusable-macos-release.yml` SHALL contain a fail-closed contract check before any publication-capable work:

- if `publish_github_release` is true and `sign_release` is false, fail;
- signed-but-artifact-only operation may remain allowed;
- unsigned artifact-only operation may remain allowed for tests or development callers when `publish_github_release` is false.

This preserves reusability while making the public publication trust boundary unambiguous.

The guard SHALL not rely solely on conditional skipping of the publish job. It must produce an explicit failure for the unsafe input combination so a misconfigured caller is visible rather than silently succeeding without publication.

## Signing and notarization flow

The existing privileged sequence remains authoritative:

1. validate the exact publisher-owned handoff artifact;
2. extract and revalidate the application bundle;
3. rebind tag/source immediately before secrets are used;
4. import Developer ID certificate;
5. sign the `.app`;
6. create the DMG;
7. sign the DMG;
8. notarize and staple;
9. run `verify-release.sh` with signed mode enabled;
10. write final release provenance;
11. upload the exact verified artifact;
12. publish only that verified artifact.

No new signing implementation is introduced unless existing scripts prove insufficient during implementation.

## Historical bootstrap workflows

The dedicated workflows for v0.1.0, v0.1.1, and v0.1.2 were temporary release bootstrap mechanisms. They currently encode unsigned public publication and therefore conflict with the new stable-publication invariant if left runnable.

They SHALL be retired as publication entry points.

Preferred retirement behavior:

- remove automatic triggers that could publish;
- remove or disable manual publication execution;
- keep enough source/history/documentation to explain how the historical releases were produced;
- do not delete existing GitHub Releases or tags;
- do not attempt to republish historical versions as signed builds.

Implementation may either delete obsolete workflow files or convert them to inert historical documentation, whichever produces the clearest repository state while preserving useful historical context. The implementation plan must choose one strategy and add regression tests for it.

A retired bootstrap workflow must not retain a `contents: write` path capable of creating a GitHub Release.

## Existing unsigned artifact paths

Unsigned artifacts remain first-class internal build products:

- `unsigned-macos-app.tar.gz` remains the Release Build handoff;
- runtime proof and artifact identity validators may continue to refer to unsigned source archives;
- release provenance continues to bind the unsigned input archive before privileged transformation;
- CI may launch-smoke unsigned packaged applications where that is part of runtime correctness testing.

The policy concerns **promotion**, not creation.

Tests must therefore avoid broadly banning the string `unsigned` or banning unsigned artifact creation. They must specifically ban **unsigned stable GitHub publication**.

## Contract test changes

### Reverse obsolete unsigned-publication assertions

Tests such as:

- `scripts/release/test_unsigned_release_workflow_contract.py`
- `scripts/release/test_v0_1_1_distribution_contract.py`

currently assert that the normal publisher uses `sign_release: false` and `publish_github_release: true`.

Those assertions SHALL be replaced with the signed-stable contract:

- normal publisher selects `sign_release: true`;
- normal publisher passes `signing_identity` from the expected trusted variable;
- normal publisher still requests public GitHub Release publication;
- missing signing identity is rejected before entering the privileged release workflow.

Historical-version-specific tests that no longer describe current production behavior should either be narrowed to immutable historical facts or retired.

### Reusable workflow contract tests

Add coverage proving:

- `publish_github_release=true` + `sign_release=false` is rejected;
- unsigned artifact-only execution with publication disabled remains possible if the reusable workflow continues to support it;
- signed publication path retains certificate import, app signing, DMG signing, notarization/stapling, verification, and final artifact handoff.

### Repository-wide publication-path regression

Add a focused test that inspects release workflow entry points and prevents a future workflow from restoring an unsigned stable-publication path.

The test SHOULD reason about workflow semantics rather than simply grep for `sign_release: false`, because unsigned artifact-only workflows remain valid.

At minimum it must cover:

- the normal release publisher;
- reusable stable publication semantics;
- historical bootstrap workflows after retirement.

## Error handling

The release pipeline SHALL fail closed on:

- missing/blank `MACOS_SIGNING_IDENTITY` for normal stable publication;
- public publication requested while `sign_release` is false;
- missing certificate secrets;
- missing App Store Connect notarization credentials;
- signing failure;
- notarization failure;
- stapling failure;
- release verification failure;
- source/tag/artifact identity drift;
- attempt to use a retired bootstrap workflow for publication.

A failed signing/notarization run must leave the GitHub Release unpublished. Existing artifact immutability/source-binding guarantees remain in force.

## Security boundary

The security model remains intentionally asymmetric:

### Unprivileged build plane

- triggered by stable tag input;
- no signing secrets;
- no repository contents write permission;
- produces unsigned artifact + provenance only.

### Trusted publication plane

- control code comes from trusted default-branch publisher state;
- revalidates source/tag/artifact identity before secrets;
- uses the protected `release` environment;
- reads signing/notarization secrets only when needed;
- receives contents write permission only in the final publication job;
- may publish only a verified signed/notarized artifact.

No broad personal access token, permanent bypass actor, or signing secret is added to repository source.

## Documentation changes

### `docs/RELEASE.md`

Clarify the production contract:

- Release Build always creates an unsigned intermediate artifact;
- stable public release requires Developer ID signing + notarization;
- unsigned Actions artifacts are development/test artifacts, not normal release downloads;
- publication does not begin until signing configuration exists.

### `docs/SETUP.md`

Make signing configuration an explicit prerequisite for the first production release. Separate CI artifact verification from production publication readiness.

### `docs/SECRETS.md`

Document which values are secrets versus repository/environment variables, and preserve the trust-boundary explanation showing that tag-build jobs cannot access signing credentials.

### release history / README

Existing v0.1.2 documentation must continue to state accurately that v0.1.2 was unsigned/unnotarized. Do not rewrite historical truth to imply otherwise.

## Issue #142 lifecycle

Landing this design and its implementation advances Issue #142 but does not complete it.

Issue #142 may be closed only after operational evidence exists for a later immutable patch release that:

1. was produced by the signed stable publisher;
2. used Developer ID signing;
3. completed Apple notarization and stapling;
4. passed the repository release verifier in signed mode;
5. passed the packaged `.app` and mounted-DMG launch smoke tests;
6. was published as a new immutable GitHub Release rather than replacing v0.1.2;
7. is accepted by the expected Gatekeeper validation path without relying on the manual unsigned-build override.

If credentials are not yet configured, the correct state is a blocked production release, not fallback to unsigned stable publication.

## Migration sequence

1. Land contract tests that describe signed-stable behavior and initially fail against the current workflows.
2. Change the normal publisher to signed mode and require the trusted signing identity variable.
3. Add the reusable-workflow publication guard.
4. Retire historical unsigned bootstrap publication entry points.
5. Update docs and operator setup requirements.
6. Run repository Quality / workflow security / release isolation / release contract tests.
7. Configure the `release` environment and repository/environment variable outside source control.
8. Publish a new patch release through the normal signed path.
9. Verify notarization/stapling/Gatekeeper evidence.
10. Only then close Issue #142.

Steps 7-10 are operational rollout and are not prerequisites for merging the code-side policy gate, but stable release publication will intentionally remain blocked until they are complete.

## Testing strategy

Implementation SHALL use TDD for contract changes.

Expected layers:

1. Python/unit workflow-contract tests for input combinations and required workflow text/semantics.
2. `actionlint` for workflow syntax and expression correctness.
3. `zizmor` / existing GitHub Actions security checks.
4. ShellCheck/shfmt for any modified shell helpers.
5. existing release isolation tests to ensure secrets remain confined to the trusted publication plane.
6. existing artifact identity/provenance suites.
7. existing packaged-app launch smoke contract.

Where tests currently encode unsigned normal publication, first change them to the new contract and observe the intended RED state before modifying the workflows.

## Acceptance criteria

The implementation is complete on the code side when all of the following are true:

- `Release Build` still produces unsigned, provenance-bound artifacts without release secrets;
- the normal `Release Publisher` cannot publish without signed mode;
- the normal publisher consumes `MACOS_SIGNING_IDENTITY` from trusted configuration;
- blank/missing signing identity causes an early failure;
- `reusable-macos-release.yml` explicitly rejects unsigned public GitHub Release publication;
- unsigned artifact-only usage remains available only where publication is disabled;
- historical bootstrap workflows can no longer create new unsigned stable GitHub Releases;
- no existing historical release/tag is changed;
- regression tests prevent restoration of the old unsigned stable-publication contract;
- workflow security, Quality, release isolation, and relevant release tests pass;
- documentation clearly distinguishes unsigned CI artifacts from signed production releases;
- Issue #142 remains open until a later signed/notarized release provides runtime and Gatekeeper evidence.

## Scope boundary

This design is intentionally limited to release trust and publication policy. It does not redesign application features, packaging layout, source provenance, Rulesets, repository merge settings, or the existing notification/runtime fix.
