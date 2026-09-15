# E3SM_DART

E3SM–DART model interfaces, build configuration, and Slurm workflows for
ensemble data assimilation with the E3SM Atmosphere Model (EAM-SE) and
E3SM Land Model (ELM).

Integration code lives in `models/` and `scripts/`. External source trees
are managed separately as Git submodules so each repository revision can
record the exact dependency commits used for a build or experiment.

The current development goal is to establish the EAM–DART workflow using
upstream NCAR/DART before integrating the strongly coupled DART branch.
Compatibility must be verified by building and testing the model interfaces.
See [`docs/README.md`](docs/README.md) for the detailed integration and
workflow guide.

## Repository Layout

```text
E3SM_DART/
├── DART/                    DART source submodule
├── E3SM/                    E3SM maint-3.0 source submodule
├── models/
│   ├── eam-common-code/     Shared EAM interface source code
│   ├── eam-se/              EAM-SE interface and supporting source files
│   │   └── work/
│   │       ├── input.nml
│   │       └── quickbuild.sh
│   └── elm/                 ELM interface and conversion utilities
│       └── work/
│           ├── input.nml
│           └── quickbuild.sh
├── scripts/                 Experiment drivers, namelists, and Slurm scripts
├── docs/                    Additional documentation
└── README.md
```

The local directory may be named `E3SM_DART` or `e3sm_dart`; it does not
need to match the GitHub repository name.

The configured submodule URLs and upstream branches are recorded in
`.gitmodules`. The parent repository records the exact DART and E3SM commits
used by this branch.

## Getting Started

### Clone the repository

Using SSH:

```bash
git clone --recurse-submodules git@github.com:zhangshixuan1987/e3sm_dart.git E3SM_DART
cd E3SM_DART
```

Alternatively, using HTTPS:

```bash
git clone --recurse-submodules https://github.com/zhangshixuan1987/e3sm_dart.git E3SM_DART
cd E3SM_DART
```

For an existing checkout:

```bash
cd /path/to/E3SM_DART
git submodule sync --recursive
git submodule update --init --recursive
```

These commands initialize the configured submodules, including their
nested submodules.

### Verify the checkout

Run from the repository root:

```bash
git status
git remote -v
cat .gitmodules
git submodule status --recursive
```

Submodule status prefixes mean:

- A space: the checked-out commit matches the commit recorded by the parent.
- `-`: the submodule is not initialized.
- `+`: the checked-out commit differs from the recorded commit.
- `U`: the submodule has a merge conflict.

A matching commit does **not** necessarily mean the latest upstream commit.

## Understanding the DART Submodule

The upstream DART configuration is:

```ini
[submodule "DART"]
    path = DART
    url = https://github.com/NCAR/DART.git
    branch = main
```

The parent repository records a **specific DART commit**. The
`branch = main` setting specifies which branch to use for an explicit
remote update; it does not automatically keep DART at the latest `main`.

Normal cloning and this command restore the recorded commit:

```bash
git submodule update --init --recursive
```

Inspect the actual DART checkout separately from the parent repository:

```bash
git -C DART status
git -C DART log -1 --oneline
git -C DART remote -v
```

A detached HEAD inside `DART/` is normal for a pinned submodule.
The branch of the parent repository and the branch or commit inside
`DART/` are independent.

## Build Requirements

Prepare an environment with:

- A supported Fortran compiler.
- MPI for MPI-enabled DART executables.
- NetCDF-C and NetCDF-Fortran libraries compatible with the chosen compiler.
- The build tools required by the checked-out DART version.
- A DART build configuration appropriate for the target HPC system.

Building the DART interfaces does not build the E3SM forecast model. The
numbered workflow under `scripts/e3smv3.0/` or `scripts/eamv3.0/` creates and
builds an E3SM case from the top-level `E3SM/` submodule during Step 1.

### Perlmutter

Use a compiler, MPI, and NetCDF combination supported on Perlmutter.
Exact module names and versions should be recorded after a successful
build rather than assumed to work across environments.

Inspect the current environment with:

```bash
module list
command -v ftn
command -v nf-config
```

If `nf-config` is available:

```bash
nf-config --all
```

Check the local `quickbuild.sh` scripts and the DART build configuration
for compiler commands, include paths, and library paths.

## Building the Model Interfaces

Run the following commands from the repository root.

### Inspect the build scripts

```bash
sed -n '1,200p' models/eam-se/work/quickbuild.sh
sed -n '1,200p' models/elm/work/quickbuild.sh
```

Confirm that source paths point to:

- The top-level `DART/` submodule.
- The integration code under this repository's `models/`.
- Shared code under `models/eam-common-code/`, where required.

Copying interface code from a full DART source tree may leave paths that
need adjustment for this repository layout.

For shell-based build scripts executed from within the parent repository,
a repository-relative DART path can be constructed as:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
DART_ROOT="${REPO_ROOT}/DART"
```

Verify the actual script implementation before relying on this behavior.

### Build EAM-SE

```bash
(cd models/eam-se/work && ./quickbuild.sh)
```

### Build ELM

```bash
(cd models/elm/work && ./quickbuild.sh)
```

The parentheses keep your terminal in the repository root after each build.

Review the build output and confirm that the expected executables were
produced. Executable names and available build options depend on the
local scripts.

Both interface scripts use DART's shared build functions and support
`./quickbuild.sh clean`. Run `./quickbuild.sh help` for the complete option
summary provided by the pinned DART revision.

### Review namelists

Review each model's `work/input.nml` before testing.

Most namelist settings control runtime behavior. DART preprocessing settings
may also affect generated observation support during the build. Use the
documentation for the pinned DART version to distinguish these settings.

## Data Assimilation Workflow

A typical cycling experiment follows this sequence:

1. Prepare the ensemble, observations, namelists, and model configuration.
2. Advance the E3SM ensemble to the assimilation time.
3. Prepare the model-state files required by the DART interface.
4. Run DART `filter`.
5. Apply the analysis to the model restart files.
6. Validate the outputs before advancing to the next cycle.

```text
Ensemble forecast
        |
        v
Prepare model states and observations
        |
        v
DART assimilation
        |
        v
Update and validate ensemble restarts
        |
        v
Next ensemble forecast
```

The state-transfer mechanism depends on the interface and DART version.
Some workflows use conversion utilities; others read and update NetCDF
state files directly. Do not assume every model requires both
`<model>_to_dart` and `dart_to_<model>` executables.

Common inputs and outputs include:

| Item | Purpose |
| --- | --- |
| `input.nml` | DART runtime and interface configuration |
| Observation sequence input | Observations for the assimilation window |
| Ensemble state or restart files | Prior states and updated analysis states |
| Observation sequence output | Observation-space diagnostics |
| DART and model logs | Completion checks and debugging |
| Inflation files, when enabled | Inflation state carried between cycles |

Observation sequence filenames are controlled by the namelist.
`obs_seq.out` commonly contains observation-space diagnostics, not the
updated model restart states.

## Running on Slurm

Keep machine-specific submission scripts and experiment drivers under
`scripts/`.

Before submitting an experiment, verify:

- Allocation account, partition, constraint, and wall time.
- MPI task counts and threading settings.
- Executable paths and loaded modules.
- Ensemble size and member-to-file mapping.
- Observation times and assimilation-window settings.
- Restart paths, output directories, and storage capacity.
- Exit-status checks that stop cycling after a failed forecast or analysis.

Choose the maintained workflow before submitting jobs:

- `scripts/e3smv3.0/` enables coupled EAM and ELM assimilation.
- `scripts/eamv3.0/` enables EAM-only assimilation.

Review every setting in the selected `create_and_setup_case.sh`, then submit
the numbered stages from that workflow directory:

```bash
cd scripts/e3smv3.0  # or scripts/eamv3.0
mkdir -p runtmp/logs

sbatch 1_run_e3sm_ensemble_setup.sh
sbatch 2_run_dart_e3sm_icbc.sh
sbatch 3_run_dart_eam_perturb.sh
sbatch 4_run_dart_e3sm_cycleda.sh
```

Wait for each of Steps 1–3 to complete successfully before starting the next.
Step 4 manages forecast–assimilation cycling and its continuation jobs. Steps
5–8 provide optional compression, diagnostics, and post-processing.

Validate one forecast–assimilation–restart cycle before enabling automatic
multi-cycle submission. Keep experiment output outside the source tree.

## Updating Dependencies

Before updating or switching submodules, inspect the working trees and
save any local work:

```bash
git status
git -C DART status
git -C E3SM status
```

### Update DART to the configured branch tip

Run from the repository root:

```bash
git submodule update --init --remote DART
git submodule update --init --recursive DART
git -C DART log -1 --oneline
git diff --submodule=log
```

Build and test the interfaces. If the new revision is suitable, record it:

```bash
git add DART
git commit -m "Update pinned DART revision"
git push
```

This is an intentional dependency update, not a required step for every build.

### Switch to strongly coupled DART

The strongly coupled development source is:

- Repository: https://github.com/zhangshixuan1987/DART
- Branch: `eam-strongly-coupled`

When ready to test it, run from the repository root with clean working trees:

```bash
git config -f .gitmodules submodule.DART.url https://github.com/zhangshixuan1987/DART.git
git config -f .gitmodules submodule.DART.branch eam-strongly-coupled

git submodule sync -- DART
git submodule update --init --remote DART
git submodule update --init --recursive DART

git -C DART log -1 --oneline
git diff --submodule=log
```

After building and validating the workflow:

```bash
git add .gitmodules DART
git commit -m "Use strongly coupled DART revision"
git push
```

This changes the dependency referenced by `E3SM_DART`; it does not copy the
DART source history into the parent repository.

### Switch parent-repository branches

Different parent branches may record different submodule URLs or commits.
After saving local work and switching branches, run:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

### Update E3SM from maint-3.0

E3SM is configured from the official E3SM repository's `maint-3.0` branch.
Initialize its recorded revision and nested dependencies with:

```bash
git submodule update --init --recursive E3SM
```

To deliberately advance the pinned revision, fetch and test a newer
`origin/maint-3.0` commit, recursively initialize its dependencies, and then
record the E3SM gitlink in the parent repository. Validate every E3SM revision
change against the model interfaces, ELM SourceMods, and experiment
configuration before pushing it.

## Troubleshooting

### Missing DART source files

```bash
git submodule update --init --recursive
git -C DART status
```

Confirm that the build script references the top-level `DART/` directory.

### Shared EAM module not found

Check the source lists or path-generation logic used by `quickbuild.sh`.

Confirm that the required files under `models/eam-common-code/` are included
and that paths are interpreted relative to the correct directory.

### Compiler or NetCDF errors

Check that compiler wrappers, MPI, NetCDF-C, and NetCDF-Fortran are compatible.
Review compiler flags and library paths in the DART build configuration.

After changing compilers or libraries, use the build script's documented
cleanup procedure before rebuilding.

### Interface API errors against upstream DART

Interface code copied from the strongly coupled branch may depend on APIs
not present in the pinned upstream DART revision.

Check the missing routines, types, or namelist settings against both source
versions. A repository-layout fix alone will not resolve an API mismatch.

### Submodule appears modified

Inspect the cause before taking action:

```bash
git diff --submodule=log
git -C DART status --short
git -C E3SM status --short
```

A changed commit, modified tracked files, and untracked build products are
different conditions. Do not discard changes or run destructive cleanup
commands without reviewing them.

### Repository not found when pushing

```bash
git remote -v
ssh -T git@github.com
```

Confirm that the destination repository exists and your GitHub account has
write access. GitHub's successful SSH authentication message also states
that shell access is unavailable; this is expected.

## Reproducibility

For each validated experiment, record:

- Parent repository commit.
- DART and E3SM commits.
- Compiler, MPI, and NetCDF versions.
- Loaded modules and build configuration.
- Namelists, case configuration, and submission scripts.
- Ensemble initialization and observation-data provenance.

Useful commands include:

```bash
git rev-parse HEAD
git submodule status --recursive
module list
```

Avoid committing credentials, large restart datasets, executables, or
routine experiment output.

## Contact

Shixuan Zhang, PNNL<br>
shixuan.zhang@pnnl.gov

## Acknowledgments

Repository organization is adapted from the DART-as-a-submodule example
provided by Helen Kershaw (NCAR):

https://github.com/hkershaw-brown/example_dart_as_submodule

DART and E3SM retain their respective licenses and attribution requirements.
Preserve applicable license and copyright notices when incorporating source
files into this repository.
