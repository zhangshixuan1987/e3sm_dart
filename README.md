# example_repo

Scripts, namelists, and model interface code for running DART, developed and
maintained outside of the DART repository itself. DART is included as a git
submodule rather than copied in, so the E3SM infrastructure can be hosted 
separately from NCAR/DART.

## Layout

```
scripts/   shell scripts and input.nml files used to drive experiments
docs/      documentation
DART/      git submodule, https://github.com/NCAR/DART
elm/       DART interface for the E3SM Land Model (ELM)
  model_mod.f90
  work/
    input.nml
    quickbuild.sh   # builds DART executables for ELM; DART path set below
eam/       DART interface for the E3SM Atmosphere Model (EAM)
  model_mod.f90
  work/
    input.nml
    quickbuild.sh   # builds DART executables for EAM; DART path set below
```

## Getting started

Clone with submodules so DART comes along:

```
git clone --recurse-submodules <this-repo-url>
```

If you already cloned without that flag:

```
git submodule update --init --recursive
```

To pull in DART updates later:

```
cd DART
git pull origin main
cd ..
git add DART
git commit -m "Update DART submodule"
```

## Building

Each model's `work/quickbuild.sh` resolves `DART` as the submodule checked out
at the top level of this repo (`$(git rev-parse --show-toplevel)/DART`), so
the scripts work regardless of where this repo is cloned:

```
cd elm/work && ./quickbuild.sh
cd eam/work && ./quickbuild.sh
```
