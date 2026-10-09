# CI incident containment — 2026-10-09

Repository: `ThreeAndTwo/BLS-TSS-Network`
Branch: `main`
Inspected head: `5932a833d62b1b30099c619e80e9a3e6ab5ecd92`

Actions were disabled before this cleanup. Keep them disabled until the repository owner explicitly approves restoration.

The owner confirmed that this personal repository must not contain GitHub Actions workflows. This change removes every file under `.github/workflows` on this branch, regardless of its name.

Files removed in this change:

- `.github/workflows/contract-unit-tests-from-fork.yml` — original Git object `5f4f63ba541d797da62c30121b97138c8b180332`.
- `.github/workflows/docker-publish-eigenlayer.yml` — original Git object `6149e6737a08b97b3505186c64bed98372600eb6`.
- `.github/workflows/docker-publish.yml` — original Git object `539000a6b52360b646f1726d635e7785675a2d2a`.
- `.github/workflows/lint-from-fork.yml` — original Git object `3c656fd7396b799495ea24f79e5b7ecb75c11698`.
- `.github/workflows/scenario-tests-layer2.yml` — original Git object `bbee38838756a3eb2f7bbd20520e4379a69be9a3`.
- `.github/workflows/scenario-tests.yml` — original Git object `c0d6cf5e4d2cc1864632711ba556faee2b6c8b3a`.
- `.github/workflows/unit-tests-from-fork.yml` — original Git object `c24514ec885501eb79eed06ac3bc4111dd68082c`.

Evidence and limits

- Unauthorized workflows were observed attempting credential or repository-history disclosure. A successful workflow run alone does not prove data receipt or credential validity.
- Existing Git history is retained as evidence. No release, tag, force push, or history rewrite is part of this cleanup.
- Revoking a GitHub token does not rotate credentials issued by other services.
- The initial credential compromise and the authentication method used for the mass write remain under investigation.
- This record supersedes any earlier note suggesting that personal-repository workflows should be retained.
