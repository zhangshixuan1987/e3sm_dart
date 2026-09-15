# E3SM_DART

E3SM–DART model interfaces, build files, and Slurm data-assimilation workflows.
The upstream DART and E3SM source trees are pinned Git submodules; integration
code maintained by this project lives under `models/` and `scripts/`.

## Layout

```
scripts/   shell scripts and input.nml files used to drive experiments
docs/      documentation
DART/      git submodule, https://github.com/NCAR/DART
E3SM/      git submodule, https://github.com/E3SM-Project/E3SM (maint-3.0)
models/elm/       DART interface for the E3SM Land Model (ELM)
  model_mod.f90
  dart_to_elm.f90 
  elm_to_dart.f90
  work/
    input.nml
    quickbuild.sh   
models/eam-se/       DART interface for the E3SM Atmosphere Model (EAM)
  model_mod.f90
  chem_tables_mod.f90
  column_rand.f90
  eam_common_code_mod.f90
  work/
    input.nml
    quickbuild.sh   
```

## Getting started

See [`docs/README.md`](docs/README.md) for the complete repository, build, and
workflow guide.

Clone with submodules so DART, E3SM, and E3SM's nested dependencies come along:

```
git clone --recurse-submodules <this-repo-url>
```

If you already cloned without that flag:

```
git submodule update --init --recursive
```

## Building

Each model's `work/quickbuild.sh` resolves `DART` as the submodule checked out
at the top level of this repo (`$(git rev-parse --show-toplevel)/DART`), so
the scripts work regardless of where this repo is cloned:

```
(cd models/elm/work && ./quickbuild.sh)
(cd models/eam-se/work && ./quickbuild.sh)
```
