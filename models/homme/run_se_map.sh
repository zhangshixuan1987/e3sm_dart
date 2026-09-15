#!/usr/bin/env bash
#
# Script showing how to run HOMME tools.
#
# Generate NP4 SCRIP and subcell files.

TOOLDIR=/qfs/people/zhan391/e3sm_dart_work/code/HOMME/test/tool
WDIR=/qfs/people/zhan391/e3sm_dart_work/code/HOMME
MACH="$TOOLDIR/../../cmake/machineFiles/compy-intel.cmake"
exe="$WDIR/src/tool/homme_tool"

NE=30
NPTS=4  # Be sure to rerun CMake if this is changed.
mesh="ne${NE}np${NPTS}"

source ../eam-se/mach_env/env_pm-cpu_specific.sh
module load nco
module load ncl

cd "$WDIR" || exit 1
if [[ ! -x "$exe" ]]; then
    # To configure with the CIME environment, uncomment this line:
    # eval "$("$TOOLDIR/../../../../cime/CIME/Tools/get_case_env")"
    cmake -C "$MACH" -DPREQX_NP="$NPTS" -DPREQX_PLEV=26 "$TOOLDIR/../.."

    # Compile the tool.
    if ! make -j4 homme_tool; then
        echo 'Error compiling homme_tool. Ensure cmake configured properly.' >&2
        exit 1
    fi
fi

if [[ -n "${SLURM_NNODES:-}" ]]; then
    mpirun=(srun -K -c 1 -N "$SLURM_NNODES")
else
    mpirun=(mpirun -np 4)
fi

# Create namelist.
rm -f input.nl
cat > input.nl <<EOF
&ctl_nl
ne = $NE
mesh_file = "none"
/

&vert_nl
/

&analysis_nl
tool = 'grid_template_tool'

output_dir = "./"
output_timeunits=1
output_frequency=1
output_varnames1='area','corners','cv_lat','cv_lon'
output_type='netcdf'
!output_type='netcdf4p'  ! needed for ne1024
io_stride = 16
/

EOF

"${mpirun[@]}" "$exe" < input.nl

# Make the lat/lon file.
ncks -O -v lat,lon,corners,area "${mesh}_tmp1.nc" "${mesh}_tmp.nc"
ncl "$TOOLDIR/ncl/HOMME2META.ncl" "name=\"$mesh\"" "ne=$NE" "np=$NPTS"

# Make the SCRIP file.
ncks -O -v lat,lon,area,cv_lat,cv_lon "${mesh}_tmp1.nc" "${mesh}_tmp.nc"
ncl "$TOOLDIR/ncl/HOMME2SCRIP.ncl" "name=\"$mesh\"" "ne=$NE" "np=$NPTS"
rm -f "${mesh}_tmp.nc" "${mesh}_tmp1.nc"

# Make some plots (NCL defaults to the ne4np4 grid).
ncl "$TOOLDIR/ncl/plotscrip.ncl" "name=\"$mesh\"" "ne=$NE" "np=$NPTS"
ncl "$TOOLDIR/ncl/plotlatlon.ncl" "name=\"$mesh\"" "ne=$NE" "np=$NPTS"
