#!/usr/bin/env bash

# Set file paths for building the dynamical core (HOMME) of E3SM.

echo '-- Setting file paths...'
export e3sm=/compyfs/zhan391/e3sm_dart_work/code/E3SM-maint-2.1
export homme="$e3sm/components/homme"
export wdir=/compyfs/zhan391/e3sm_dart_work/code/HOMME
export mach="$homme/cmake/machineFiles/compy-intel.cmake"
export test3_1="$wdir/dcmip_tests/dcmip2012_test3.1_nh_gravity_waves/theta-l"

# Load the necessary modules.
echo '-- Loading necessary modules...'

# eval "$("$e3sm/cime/CIME/Tools/get_case_env")"
source ../eam-se/mach_env/env_pm-cpu_specific.sh

echo '-- Compiling HOMME...'

cd "$wdir" || exit 1

cmake -C "$mach" \
      -DBUILD_HOMME_WITHOUT_PIOLIBRARY=OFF \
      "$homme"
# Optional CMake settings:
#     -DPREQX_PLEV=26
#     -DPREQX_NP=4

make -j4 theta-l
make -j4 homme_tool
