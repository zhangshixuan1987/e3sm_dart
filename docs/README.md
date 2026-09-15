# E3SM–DART integration guide

This repository combines pinned E3SM and DART source trees with E3SM-specific
DART model interfaces and experiment workflows. E3SM and DART are included as
Git submodules, while the integration code is maintained in this repository.

## Repository organization

```text
E3SM_DART/
├── DART/                  # Pinned strongly coupled DART submodule
├── E3SM/                  # Pinned E3SM maint-3.0 Git submodule
├── models/                # E3SM-specific model interfaces and supporting data
│   ├── eam-se/            # EAM-SE DART interface, namelists, and build directory
│   ├── elm/               # ELM DART interface, SourceMods, and build directory
│   ├── eam-common-code/   # Code shared by EAM-related interfaces
│   ├── homme/             # HOMME grids, maps, and helper scripts
│   ├── mach_env/          # Machine environment examples
│   └── topo/              # Topography files used by the interfaces
├── scripts/               # Slurm experiment setup and cycling workflows
└── docs/                  # Repository-level documentation
```

The ownership boundary is intentional:

- Put EAM, ELM, or other E3SM model-interface code under `models/`.
- Put experiment drivers, Slurm scripts, diagnostics, and post-processing
  workflows under `scripts/`.
- Treat `DART/` and `E3SM/` as upstream source. Do not copy locally maintained
  interface or workflow files into either submodule.
- Put repository-wide explanations and development procedures under `docs/`.

## Pinned upstream dependencies

The parent repository records exact Git commits for reproducibility. The
`branch` entries in `.gitmodules` identify the upstream line from which future
updates should be selected; they do not make a normal checkout follow a moving
branch automatically.

| Dependency | Upstream branch | Pinned commit |
| --- | --- | --- |
| zhangshixuan1987/DART | `eam-strongly-coupled` | `9e0ae41b2a910224cd5dcf913620e35319ddf23d` |
| E3SM-Project/E3SM | `maint-3.0` | `34bd782d18dda06d2ed5945f9b276770f946f200` |

Update this table whenever either gitlink is deliberately advanced and tested.

## Clone the repository

Clone recursively so that the pinned DART and E3SM revisions, including E3SM's
nested dependencies, are checked out with the main repository:

```bash
git clone --recurse-submodules git@github.com:zhangshixuan1987/e3sm_dart.git
cd e3sm_dart
```

Use a project or scratch filesystem with adequate quota. The E3SM working tree
and its recursively checked-out component repositories are substantially larger
than this integration repository.

On Perlmutter, a suitable layout is:

```text
$PSCRATCH/e3sm_dart/code/E3SM_DART/
```

For an existing clone with uninitialized submodules, run:

```bash
git submodule update --init --recursive
```

Confirm the checkout with:

```bash
git submodule status --recursive
```

A leading `-` means a submodule is not initialized. A leading `+` means its
working tree is not at the commit recorded by its parent. Resolve either state
before building a production case.

The following preflight checks the files required to start model-interface and
E3SM case builds:

```bash
test -f DART/build_templates/buildfunctions.sh
test -x E3SM/cime/scripts/create_newcase
test -x models/eam-se/work/quickbuild.sh
test -x models/elm/work/quickbuild.sh
```

The commits printed for `DART` and `E3SM` are the revisions recorded by this
repository. A detached HEAD inside either directory is normal for a submodule
checkout. On this parent branch, `.gitmodules` tracks the project DART fork's
`eam-strongly-coupled` branch and E3SM-Project/E3SM `maint-3.0`, but
reproducible clones use the exact commits recorded by the parent repository.

All maintained workflow code paths are derived from the location of
`create_and_setup_case.sh`. The checkout may therefore be moved to a different
filesystem without editing `my_e3sm_code`, `my_dart_code`, or the local model
interface paths. Experiment data, observations, reference restarts, software
environments, and Slurm account settings remain site-specific and must still be
reviewed in the selected workflow configuration.

## Build the model interfaces

Before building, load a compiler, MPI implementation, and NetCDF libraries
compatible with the target machine. Machine environment examples are available
under `models/mach_env/`, but they may require updates for the local software
stack.

The maintained workflow resolves the E3SM source directly from the top-level
`E3SM/` submodule. E3SM's own nested submodules must be initialized before
Step 1 creates and builds a case.

Build EAM-SE:

```bash
(cd models/eam-se/work && ./quickbuild.sh)
```

Build ELM:

```bash
(cd models/elm/work && ./quickbuild.sh)
```

Both scripts find DART from the top level of the Git checkout, run DART
`preprocess`, and then compile the interface-specific executables in the
corresponding `work/` directory. They may therefore be run from any clone
location; no hard-coded path to the DART submodule is required.

Useful build variants are:

```bash
./quickbuild.sh help
./quickbuild.sh clean
./quickbuild.sh nompi filter
./quickbuild.sh mpi filter
./quickbuild.sh mpif08 filter
```

The EAM-SE build includes the EAM interface and the sources in
`models/eam-common-code/`. The ELM build also creates the `elm_to_dart` and
`dart_to_elm` conversion programs.

After a build, at minimum confirm that the expected executable exists and run
the interface check appropriate for the available test data, for example:

```bash
test -x filter
test -x model_mod_check
./model_mod_check
```

`model_mod_check` requires a valid `input.nml` and any model data referenced by
that namelist.

## ELM SourceMods

ELM assimilation with E3SM maint-3.0 requires the compatible source overrides
under:

```text
models/elm/DART_SourceMods/e3sm_maint_3.0/src.elm/
```

The files must be copied directly into the E3SM case directory before the case
is built:

```bash
cp -p models/elm/DART_SourceMods/e3sm_maint_3.0/src.elm/*.F90 \
  <case-root>/SourceMods/src.elm/
```

Do not reproduce ELM source subdirectories beneath `SourceMods/src.elm/`.
Compatibility information and the purpose of each modification are documented
in `models/elm/DART_SourceMods/e3sm_maint_3.0/README.txt`. The maintained
coupled workflow installs these files automatically during case creation.

## Select an experiment workflow

The maintained workflows are documented in [`scripts/README.md`](../scripts/README.md):

| Workflow | Purpose |
| --- | --- |
| [`scripts/e3smv3.0/`](../scripts/e3smv3.0/README.md) | Coupled EAM and ELM assimilation with E3SM maint-3.0 |
| [`scripts/eamv3.0/`](../scripts/eamv3.0/README.md) | EAM-SE-only assimilation with E3SM maint-3.0 |
| `scripts/eamv2.0/` | Legacy EAM/E3SM v2 workflow retained for reference |

For either maintained workflow, first review every setting in its
`create_and_setup_case.sh`. Paths, project IDs, queues, case dates, ensemble
size, observation locations, restart locations, and Slurm resources are
experiment- and machine-specific. Do not run a workflow with configuration or
`workflow_lib/` files copied from the other workflow directory.

The normal Slurm sequence is:

```bash
cd scripts/e3smv3.0             # or scripts/eamv3.0
mkdir -p runtmp/logs

sbatch 1_run_e3sm_ensemble_setup.sh
sbatch 2_run_dart_e3sm_icbc.sh
sbatch 3_run_dart_eam_perturb.sh
sbatch 4_run_dart_e3sm_cycleda.sh
```

Wait for each of Steps 1–3 to finish successfully before submitting the next
step. Step 4 performs forecast–assimilation cycling and manages its own
continuation jobs. Optional Steps 5–8 compress results, produce diagnostics,
post-process history output, and extract restart variables.

The workflow records validated state under `runtmp/status/` and uses locks
under `runtmp/locks/`. Do not fabricate completion records or delete the entire
`runtmp/` directory to bypass a failed stage. Correct the failed input or
configuration and rerun the stage that owns the record.

## Add or update a model interface

Keep a model contribution self-contained beneath `models/<model-name>/` where
possible. A typical interface contains:

```text
models/<model-name>/
├── model_mod.f90
├── model_mod.nml
├── additional interface sources
├── DART_SourceMods/       # only when the E3SM component needs overrides
├── nml_template/          # maintained runtime namelist templates, if needed
└── work/
    ├── input.nml
    └── quickbuild.sh
```

When adding a source file, also update the appropriate `quickbuild.sh` or
preprocess configuration so the file is actually compiled. Keep the maintained
E3SM interfaces under this repository's `models/`; make DART core changes in
the configured DART fork and then advance the recorded submodule commit.

Before committing an interface change:

1. Initialize DART, E3SM, and E3SM's nested submodules at their recorded
   revisions.
2. Clean and rebuild each affected interface.
3. Run `model_mod_check` with representative model data.
4. Syntax-check any changed workflow shell scripts with `bash -n`.
5. Document required E3SM versions, SourceMods, data files, and namelist
   changes.

## Update the DART submodule

Updating DART changes a repository dependency and may affect every interface.
Make the update explicitly and record the tested revision:

```bash
git -C DART fetch origin
git -C DART checkout <tested-dart-commit>
git add DART
git commit -m "Update DART submodule to <revision>"
```

After changing the submodule revision, rebuild and test both EAM-SE and ELM.
Do not commit an untested moving branch tip merely because `.gitmodules`
declares `branch = eam-strongly-coupled`; ordinary clones use the exact commit
recorded by the parent repository.

## Update the E3SM submodule

The E3SM submodule follows the official `maint-3.0` branch. To test and record
a newer revision:

```bash
git -C E3SM fetch origin maint-3.0
git -C E3SM checkout maint-3.0
git -C E3SM merge --ff-only origin/maint-3.0
git -C E3SM submodule update --init --recursive
git add E3SM
git commit -m "Update E3SM maint-3.0 submodule"
```

An E3SM update is not only a pointer change. Rebuild representative cases and
revalidate the model interfaces and ELM SourceMods before accepting it. The
current ELM SourceMods documentation records the older E3SM revision against
which those overrides were originally verified; that compatibility claim must
be updated after testing the newly pinned maint-3.0 revision.

## What belongs in a commit

Commit source code, build scripts, maintained namelists, small required static
data, and documentation. Do not commit generated executables, object/module
files, experiment archives, Slurm logs, runtime status records, handoff
snapshots, or machine-specific scratch output.

When changing model code and workflow behavior together, describe both parts
in the commit or pull request and state which E3SM and DART revisions were used
for validation.
