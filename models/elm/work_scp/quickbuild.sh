#!/usr/bin/env bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

main() {

# DART is a submodule of this repo (checked out at the top level as DART/),
export DART="$(git rev-parse --show-toplevel)/DART"
source "$DART"/build_templates/buildfunctions.sh

# This is where the model directory is relative to DART
MODEL="../../models/elm"
LOCATION=threed_sphere

programs=(
filter
model_mod_check
perfect_model_obs
perturb_single_instance
)

serial_programs=(
advance_time
create_fixed_network_seq
create_obs_sequence
fill_inflation_restart
obs_diag
obs_seq_to_netcdf
obs_sequence_tool
)

model_serial_programs=(
elm_to_dart
dart_to_elm
)

arguments "$@"

# clean the directory; a build that does not finish leaves no build stamp
\rm -f -- *.o *.mod Makefile .cppdefs dart_build_info.txt

# build and run preprocess before making any other DART executables
buildpreprocess

# build DART
buildit

# clean up
\rm -f -- *.o *.mod

# Record the DART version these executables were built with. The E3SM-DART
# workflows compare it with their version profile before running.
{
  echo "dart_sha=$(git -C "$DART" rev-parse HEAD)"
  echo "dart_local_changes=$( [[ -n "$(git -C "$DART" status --porcelain --untracked-files=no)" ]] && echo yes || echo no )"
  echo "built_at=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "build_dir=$(pwd -P)"
} > dart_build_info.txt

}

main "$@"
