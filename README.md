# example_repo

Scripts, namelists, and model interface code for running DART, for interfaces
developed and maintained outside of the DART repository itself. 
DART is included as a git submodule rather than copied in, so the E3SM infrastructure 
can be hosted  separately from NCAR/DART.

## Layout

```
scripts/   shell scripts and input.nml files used to drive experiments
docs/      documentation
DART/      git submodule, https://github.com/NCAR/DART
elm/       DART interface for the E3SM Land Model (ELM)
  model_mod.f90
  dart_to_elm.f90 
  elm_to_dart.f90
  work/
    input.nml
    quickbuild.sh   
eam-se/       DART interface for the E3SM Atmosphere Model (EAM)
  model_mod.f90
  chem_tables_mod.f90
  column_rand.f90
  eam_common_code_mod.f90
  work/
    input.nml
    quickbuild.sh   
```

## Getting started

The .gitmodules file shows the DART repo and branch (I've put NCAR/DART and main for now)

Clone with submodules so DART comes along:

```
git clone --recurse-submodules <this-repo-url>
```

If you already cloned without that flag:

```
git submodule update --init --recursive
```

To pull in DART updates later:

Note I've put in main here, but maybe you are using a different branch (e.g. strongly_coupled)

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
