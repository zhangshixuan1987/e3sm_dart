#!/bin/bash
# Stable, workflow-owned runtime environment for DART on Perlmutter CPU.
# Module versions match models/mach_env/env_pm-cpu_specific.sh used to build DART.

[[ -r /opt/cray/pe/lmod/lmod/init/bash ]] || {
  echo "ERROR: Lmod initialization is unavailable" >&2
  return 1 2>/dev/null || exit 1
}

source /opt/cray/pe/lmod/lmod/init/bash
module unload cpe cray-hdf5-parallel cray-netcdf-hdf5parallel cray-parallel-netcdf cray-netcdf cray-hdf5 PrgEnv-gnu PrgEnv-intel PrgEnv-nvidia PrgEnv-cray PrgEnv-aocc gcc-native intel intel-oneapi nvidia aocc cudatoolkit climate-utils cray-libsci matlab craype-accel-nvidia80 craype-accel-host perftools-base perftools darshan
module load PrgEnv-intel/8.5.0
module unload cray-libsci
module load intel/2024.1.0 craype-accel-host craype/2.7.32 cray-mpich/8.1.30 cray-hdf5-parallel/1.14.3.7 cray-netcdf-hdf5parallel/4.9.2.1 cray-parallel-netcdf/1.12.3.19 cmake/3.30.2
module load craype-x86-milan

export HDF5_USE_FILE_LOCKING=FALSE
export FI_MR_CACHE_MONITOR=kdreg2
export MPICH_COLL_SYNC=MPI_Bcast
export MPICH_SMP_SINGLE_COPY_MODE=CMA
export MKLROOT=/global/common/software/nersc9/intel/oneapi/mkl/2024.1
export LD_LIBRARY_PATH="${MKLROOT}/lib/intel64:/global/common/software/nersc9/intel/oneapi/compiler/2024.1/lib:${LD_LIBRARY_PATH:-}"
