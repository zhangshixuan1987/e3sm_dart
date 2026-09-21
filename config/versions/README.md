# Dependency version profiles

Profiles select exact DART and E3SM commits without changing their stable
`DART/` and `E3SM/` paths. They are intended for testing candidate dependency
combinations.

## Source of truth

- A profile is the source of truth while evaluating a candidate combination.
- The parent repository's DART and E3SM gitlinks are the source of truth for a
  validated combination.
- A production run should use a committed combination and pass
  `tools/validate-repository --require-recorded PROFILE`.

A normal `git submodule update --init --recursive` always restores the gitlinks
recorded by the parent commit. It does not read a version profile.

## Profile format

Profiles contain only the eight supported `KEY=VALUE` fields. They are parsed
as data and cannot execute shell commands. Blank lines and lines beginning with
`#` are allowed. Quotes are not required and are treated as literal characters.

```text
PROFILE_FORMAT=1
PROFILE_NAME=example
DART_URL=https://github.com/NCAR/DART.git
DART_REF=main
DART_SHA=<full-40-character-commit-sha>
E3SM_URL=https://github.com/E3SM-Project/E3SM.git
E3SM_REF=maint-3.0
E3SM_SHA=<full-40-character-commit-sha>
```

The refs identify what to fetch. The SHAs, rather than moving branch tips,
select the source versions.

## Candidate workflow

Preview and select a profile:

```bash
tools/checkout-version --dry-run baseline
tools/checkout-version baseline
tools/validate-repository baseline
```

Use `--no-fetch` when both commits are already present and network access is
unavailable. Checkout automatically restores the original top-level submodule
states if a later checkout or nested-submodule initialization step fails.

After testing succeeds, commit the gitlinks on an integration branch:

```bash
git add DART E3SM config/versions/<name>.conf
git commit -m "Pin tested DART and E3SM combination"
tools/validate-repository --require-recorded <name>
```

Generate a profile from clean, currently checked-out submodules with:

```bash
tools/create-version-profile <name>
```

Review its refs and URLs before committing it, especially when the commits came
from development forks rather than the URLs in `.gitmodules`.
