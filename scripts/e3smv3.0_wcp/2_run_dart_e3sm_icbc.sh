#!/bin/bash -el
#################################################################################
# This script attempts to prepare initial condition files for startup of DART DA
#################################################################################
#------------------------------------------------------------------------------
# Batch system directives
#------------------------------------------------------------------------------
#SBATCH  --job-name=e3sm_dart_ensda_init
#SBATCH  --nodes=1
#SBATCH  --output=e3sm_dart_ensda_init.%j
#SBATCH  --exclusive
#SBATCH  --account=m4849
#SBATCH  --time=00:30:00
#SBATCH  --constraint=cpu
#SBATCH  --qos=debug

fail() {
  echo "ERROR: $*"
  exit 1
}

check_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "required command not found: ${cmd}"
}

validate_positive_int() {
  local name="$1"
  local value="$2"
  if ! [[ "${value}" =~ ^[0-9]+$ ]] || (( value < 1 )); then
    fail "${name} must be a positive integer, got: ${value}"
  fi
}

SCRIPT_NAME=$(basename "$0")
RUN_START_EPOCH=$(date +%s)
on_exit_summary() {
  local exit_code=$?
  local run_end_epoch
  local elapsed
  run_end_epoch=$(date +%s)
  elapsed=$((run_end_epoch - RUN_START_EPOCH))
  if (( exit_code == 0 )); then
    echo "INFO: ${SCRIPT_NAME} completed successfully in ${elapsed}s at $(date '+%Y-%m-%d %H:%M:%S')"
  else
    echo "ERROR: ${SCRIPT_NAME} failed with exit ${exit_code} after ${elapsed}s at $(date '+%Y-%m-%d %H:%M:%S')"
  fi
}
trap on_exit_summary EXIT

# Find this workflow's own directory (the one holding create_and_setup_case.sh),
# never another workflow's:
#  1. the directory of this script when it runs in place (including salloc);
#  2. under sbatch Slurm runs a copy, so the submitted script's original path;
#  3. otherwise the submission directory, with a warning.
resolve_workflow_dir() {
  local here cmd
  here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P) || here=""
  if [[ -n "${here}" && -r "${here}/create_and_setup_case.sh" ]]; then
    printf '%s\n' "${here}"; return 0
  fi
  if [[ -n "${SLURM_JOB_ID:-}" ]] && command -v scontrol >/dev/null 2>&1; then
    cmd=$(scontrol show job -o "${SLURM_JOB_ID}" 2>/dev/null | sed -n 's/.* Command=\([^ ]*\).*/\1/p')
    [[ -z "${cmd}" || "${cmd}" == /* ]] || cmd="${SLURM_SUBMIT_DIR:-.}/${cmd}"
    if [[ -n "${cmd}" && -r "$(dirname -- "${cmd}")/create_and_setup_case.sh" ]]; then
      (cd -- "$(dirname -- "${cmd}")" && pwd -P); return 0
    fi
  fi
  if [[ -n "${SLURM_SUBMIT_DIR:-}" && -r "${SLURM_SUBMIT_DIR}/create_and_setup_case.sh" ]]; then
    echo "WARNING: could not locate this script's own directory; using the submission directory ${SLURM_SUBMIT_DIR}" >&2
    (cd -- "${SLURM_SUBMIT_DIR}" && pwd -P); return 0
  fi
  return 1
}
my_wkdir=$(resolve_workflow_dir) || fail "cannot find create_and_setup_case.sh next to this script or in the submission directory"
echo "Using workflow configuration: ${my_wkdir}/create_and_setup_case.sh"
cd "${my_wkdir}"
source "${my_wkdir}/create_and_setup_case.sh"

source "${my_workflow_lib:?}/common/analysis_env.sh"
load_analysis_env || fail "could not load the analysis environment"
mkdir -p "${my_log_dir}" "${my_status_dir}" "${my_lock_dir}"
# Members read the same reference files concurrently. HDF5 (netCDF-4) file
# locking can fail on shared file systems, and no two members write one file.
export HDF5_USE_FILE_LOCKING=FALSE

for cmd in awk bc ncks ncap2 ncrename ncdump dirname flock mkdir cp mv readlink rm touch; do
  check_command "${cmd}"
done

validate_positive_int "my_ensnum" "${my_ensnum}"
exec 8>"${my_lock_dir}/step2_icbc.lock"
flock -n 8 || fail "another step-2 IC/BC generation is already running"

mkdir -p "${my_status_dir}"
icbc_status="${my_status_dir}/icbc_complete.${my_refdate}-${my_reftod}"
icbc_in_progress="${my_status_dir}/icbc_in_progress.${my_refdate}-${my_reftod}"
rm -f -- "${icbc_status}"
printf 'valid_time=%s-%s\ncase=%s\nensemble_size=%s\nslurm_job_id=%s\nstarted_at=%s\n' "${my_refdate}" "${my_reftod}" "${my_casename}" "${my_ensnum}" "${SLURM_JOB_ID:-none}" "$(date '+%Y-%m-%d %H:%M:%S')" > "${icbc_in_progress}"

case "${my_runtype}" in
  Full-CPL|AMIP)
    ;;
  *)
    fail "my_runtype must be either Full-CPL or AMIP, got: ${my_runtype:-unset}"
    ;;
esac

for req in my_refeam_in my_refeam_ic my_refelm_in my_refrof_in my_refocn_in my_refice_in my_refcpl_in; do
  [[ -n "${!req:-}" ]] || fail "required variable is unset or empty: ${req}"
done


# Run options
REF_DATE=${my_refdate}
REF_TOD=${my_reftod}
REF_CASE=${my_refcase}
REF_DIR=${my_refdir}
REF_HOUR=`echo "${REF_TOD}" / 3600 | bc`
REF_HOUR=`printf "%02d" $REF_HOUR`
echo "valid time is $REF_DATE $REF_TOD (seconds) $REF_HOUR (hours)"

# Each member owns its raw CIME initial-condition archive.

# ==============================================================================
# machine-specific dereferencing
# suppress "rm" warnings if wildcard does not match anything
source "${my_workflow_lib:?}/common/file_commands.sh"
# ==============================================================================

prepare_mpas_restart() {
  local source_file="$1"
  local destination_file="$2"
  local tmp_file="${destination_file}.tmp.${SLURM_JOB_ID:-$$}"
  # Also clear leftovers from a job killed mid-write; the step-2 lock guarantees
  # no other job is writing this member now.
  rm -f -- "${destination_file}".tmp.*
  ncks -O --hdr_pad=10000 "${source_file}" "${tmp_file}" || return 1
  ncrename -v .xtime,xtime.orig "${tmp_file}" || return 1
  ncdump -h "${tmp_file}" >/dev/null 2>&1 || return 1
  touch --reference="${source_file}" "${tmp_file}" || return 1
  mv -f "${tmp_file}" "${destination_file}"
}
# Prepare one member's initial conditions. Members write only to their own
# archive directory and read the shared reference files, so they run in parallel.
prepare_member_ic() {
  local i="$1"
  echo === Member ${i} ===
  ENSTR=EN`printf "%02d" ${i}`
  DART_CASE=${my_casename}.${ENSTR}
  MEMBER_ARCHIVE_DIR="${my_modeldir}/${ENSTR}/archive"
  CASE_ARCHIVE_DIR="${MEMBER_ARCHIVE_DIR}/rest/${REF_DATE}-${REF_TOD}"
  echo "Run Case: ${DART_CASE}"
  echo "Run Directory: ${CASE_ARCHIVE_DIR}"
  [[ -d "${CASE_ARCHIVE_DIR}" ]] || { echo "ERROR: member directory was not created: ${CASE_ARCHIVE_DIR}"; exit 1; }
  for scomp in "atm" "lnd" "rof" "ocn" "ice" "drv"; do
     echo === E3SM component ${scomp} ===
     cd ${CASE_ARCHIVE_DIR}
     if [[ ${scomp} == "atm" ]]; then
        smod="eam"
        REF_DATE_EXT=${REF_DATE}-${REF_TOD}
        ATM_INITIAL_FILENAME=${DART_CASE}.${smod}.i.${REF_DATE_EXT}.nc
        echo "process ${smod} ic: ${ATM_INITIAL_FILENAME}"
        if [ -f "${my_refeam_in}" ];then
          ${COPY} ${my_refeam_in} ${ATM_INITIAL_FILENAME} || exit 01
          echo "reference file: ${my_refeam_ic}"
          ncks -A -v PS,U,V,T,Q,CLDLIQ,CLDICE ${my_refeam_ic} ${ATM_INITIAL_FILENAME} || exit 02
          ATM_DATE=( `echo $REF_DATE_EXT | sed -e "s#-# #g"` )
          mdate=`echo ${REF_DATE} | sed "s/-//g"`
          mtods=${REF_TOD}
          ncap2 -O -s "date=${mdate};datesec=${mtods}" ${ATM_INITIAL_FILENAME} ${ATM_INITIAL_FILENAME} || exit 03
        else
          echo "ERROR: initial condition file not found: ${my_refeam_in}"
          exit 1
        fi
        ATM_REST_FILENAME="${DART_CASE}.${smod}.r.${REF_DATE_EXT}.nc"
        echo "${ATM_REST_FILENAME}"   >  rpointer.atm
        if [ ! -f "${ATM_REST_FILENAME}" ];then
          touch ${ATM_REST_FILENAME}
        fi
     elif [[ ${scomp} == "lnd" ]]; then
        smod="elm"
        REF_DATE_EXT=${REF_DATE}-${REF_TOD}
        LND_INITIAL_FILENAME=${DART_CASE}.${smod}.r.${REF_DATE_EXT}.nc
        echo "process ${smod} ic: ${LND_INITIAL_FILENAME}"
        if [ -f "${my_refelm_in}" ];then
          ${COPY} ${my_refelm_in} ${LND_INITIAL_FILENAME} || exit 04
        else
          echo "ERROR: initial condition file not found: ${my_refelm_in}"
          exit 1
        fi
        echo "./${LND_INITIAL_FILENAME}"   >  rpointer.lnd
     elif [[ ${scomp} == "rof" ]]; then
        smod="mosart"
        REF_DATE_EXT=${REF_DATE}-${REF_TOD}
        ROF_INITIAL_FILENAME=${DART_CASE}.${smod}.r.${REF_DATE_EXT}.nc
        echo "process ${smod} ic: ${ROF_INITIAL_FILENAME}"
        if [ -f "${my_refrof_in}" ];then
          ${COPY} ${my_refrof_in} ${ROF_INITIAL_FILENAME} || exit 05
        else
          echo "ERROR: initial condition file not found: ${my_refrof_in}"
          exit 1
        fi
        echo "./${ROF_INITIAL_FILENAME}"   >  rpointer.rof
     elif [[ ${scomp} == "ocn"  &&  ${my_runtype} == "Full-CPL" ]]; then
        smod="mpaso"
        REF_DATE_EXT=${REF_DATE}_${REF_TOD}
        OCN_INITIAL_FILENAME=${DART_CASE}.${smod}.rst.${REF_DATE_EXT}.nc
        echo "process ${smod} ic: ${OCN_INITIAL_FILENAME}"
        if [ -f "${my_refocn_in}" ];then
          prepare_mpas_restart "${my_refocn_in}" "${OCN_INITIAL_FILENAME}" || exit 07
        else
          echo "ERROR: initial condition file not found: ${my_refocn_in}"
          exit 1
        fi
        echo "${REF_DATE}_`printf "%02d" ${REF_HOUR}`:00:00"  > rpointer.ocn
     elif [[ ${scomp} == "ocn"  && ${my_runtype} == "AMIP" ]]; then
        smod="docn"
        REF_DATE_EXT=${REF_DATE}_${REF_TOD}
        OCN_INITIAL_FILENAME1="${DART_CASE}.${smod}.r.${REF_DATE_EXT}.nc"
        OCN_INITIAL_FILENAME2="${DART_CASE}.${smod}.rs1.${REF_DATE_EXT}.bin"
        echo "process ${smod} ic: ${OCN_INITIAL_FILENAME1}"
        echo "process ${smod} ic: ${OCN_INITIAL_FILENAME2}"
        if [ ! -f "${OCN_INITIAL_FILENAME1}" ];then
          touch ${OCN_INITIAL_FILENAME1}
        fi
        if [ ! -f "${OCN_INITIAL_FILENAME2}" ];then
          touch ${OCN_INITIAL_FILENAME2}
        fi
        echo "${OCN_INITIAL_FILENAME1}"  >  rpointer.ocn
        echo "${OCN_INITIAL_FILENAME2}"  >> rpointer.ocn
     elif [[ ${scomp} == "ice" ]]; then
        smod="mpassi"
        REF_DATE_EXT=${REF_DATE}_${REF_TOD}
        ICE_INITIAL_FILENAME=${DART_CASE}.${smod}.rst.${REF_DATE_EXT}.nc
        echo "process ${smod} ic: ${ICE_INITIAL_FILENAME}"
        if [ -f "${my_refice_in}" ];then
          prepare_mpas_restart "${my_refice_in}" "${ICE_INITIAL_FILENAME}" || exit 10
        else
          echo "ERROR: initial condition file not found: ${my_refice_in}"
          exit 1
        fi
        echo "${REF_DATE}_`printf "%02d" ${REF_HOUR}`:00:00"  > rpointer.ice
     else
        smod="cpl"
        REF_DATE_EXT=${REF_DATE}-${REF_TOD}
        CPL_INITIAL_FILENAME=${DART_CASE}.${smod}.r.${REF_DATE_EXT}.nc
        echo "process ${smod} ic: ${CPL_INITIAL_FILENAME}"
        if [ -f "${my_refcpl_in}" ];then
          ${COPY} ${my_refcpl_in} ${CPL_INITIAL_FILENAME} || exit 12
        else
          echo "ERROR: initial condition file not found: ${my_refcpl_in}"
          exit 1
        fi
        echo "${CPL_INITIAL_FILENAME}"  >  rpointer.drv
     fi
  done
}

# Build every member's archive directory first, in order, so path or permission
# problems stop the stage before any large file is copied.
for i in $(seq 1 "${my_ensnum}"); do
  member_rest_dir="${my_modeldir}/$(printf 'EN%02d' "${i}")/archive/rest/${REF_DATE}-${REF_TOD}"
  mkdir -p "${member_rest_dir}" || fail "cannot create member directory: ${member_rest_dir}"
done
echo "Created archive directories for ${my_ensnum} members"

MAX_PARALLEL_ICBC=${my_max_parallel_icbc:-4}
validate_positive_int "my_max_parallel_icbc" "${MAX_PARALLEL_ICBC}"
echo "Preparing ${my_ensnum} members, up to ${MAX_PARALLEL_ICBC} at a time; per-member logs in ${my_log_dir}"
icbc_pids=()
icbc_members=()
failed_members=()

# Wait for the oldest running member and record whether it succeeded.
wait_oldest_member() {
  local pid="${icbc_pids[0]}"
  local enstr="${icbc_members[0]}"
  local log="${my_log_dir}/step2_icbc.${enstr}.${SLURM_JOB_ID:-$$}.log"
  icbc_pids=("${icbc_pids[@]:1}")
  icbc_members=("${icbc_members[@]:1}")
  if wait "${pid}"; then
    echo "Member ${enstr} prepared"
  else
    echo "ERROR: member ${enstr} failed; last lines of ${log}:"
    tail -n 20 "${log}" || true
    failed_members+=("${enstr}")
  fi
}

for i in $(seq 1 "${my_ensnum}"); do
  ENSTR=$(printf 'EN%02d' "${i}")
  ( prepare_member_ic "${i}" ) > "${my_log_dir}/step2_icbc.${ENSTR}.${SLURM_JOB_ID:-$$}.log" 2>&1 &
  icbc_pids+=("$!")
  icbc_members+=("${ENSTR}")
  if (( ${#icbc_pids[@]} >= MAX_PARALLEL_ICBC )); then
    wait_oldest_member
  fi
done
while (( ${#icbc_pids[@]} > 0 )); do
  wait_oldest_member
done
(( ${#failed_members[@]} == 0 )) || fail "initial-condition preparation failed for ${#failed_members[@]} member(s): ${failed_members[*]}"

# Validate every required component before declaring step 2 complete.
for i in `seq 1 ${my_ensnum}`; do
  ENSTR=EN`printf "%02d" ${i}`
  MEMBER_ARCHIVE_DIR="${my_modeldir}/${ENSTR}/archive"
  member_prefix="${MEMBER_ARCHIVE_DIR}/rest/${REF_DATE}-${REF_TOD}/${my_casename}.${ENSTR}"
  required_files=("${member_prefix}.eam.i.${REF_DATE}-${REF_TOD}.nc" "${member_prefix}.elm.r.${REF_DATE}-${REF_TOD}.nc" "${member_prefix}.mosart.r.${REF_DATE}-${REF_TOD}.nc" "${member_prefix}.mpassi.rst.${REF_DATE}_${REF_TOD}.nc" "${member_prefix}.cpl.r.${REF_DATE}-${REF_TOD}.nc")
  [[ "${my_runtype}" == "Full-CPL" ]] && required_files+=("${member_prefix}.mpaso.rst.${REF_DATE}_${REF_TOD}.nc")
  for component_file in "${required_files[@]}"; do
    if [ ! -s "${component_file}" ] || ! ncdump -h "${component_file}" >/dev/null 2>&1; then
      fail "invalid generated restart for ${ENSTR}: ${component_file}"
    fi
  done
done

# A successful regeneration makes any failed member-local Step 3 marker stale.
for i in $(seq 1 "${my_ensnum}"); do
  ENSTR=$(printf 'EN%02d' "${i}")
  MEMBER_ARCHIVE_DIR="${my_modeldir}/${ENSTR}/archive"
  perturb_marker="${MEMBER_ARCHIVE_DIR}/rest/${REF_DATE}-${REF_TOD}/.dart_perturb_in_progress"
  if [[ -e "${perturb_marker}" ]]; then
    rm -f -- "${perturb_marker}" || fail "could not clear stale perturbation marker for ${ENSTR}"
    echo "Cleared stale perturbation marker for ${ENSTR}"
  fi
done
icbc_tmp="${icbc_status}.tmp.${SLURM_JOB_ID:-$$}"
printf 'valid_time=%s-%s\ncase=%s\nensemble_size=%s\narchive_layout=%s\ndart_root=%s\nslurm_job_id=%s\ncompleted_at=%s\n' "${REF_DATE}" "${REF_TOD}" "${my_casename}" "${my_ensnum}" "per_member" "${my_dart_root}" "${SLURM_JOB_ID:-none}" "$(date '+%Y-%m-%d %H:%M:%S')" > "${icbc_tmp}"
mv -f "${icbc_tmp}" "${icbc_status}"
rm -f -- "${icbc_in_progress}"
echo "Wrote step-2 completion record: ${icbc_status}"
wait

exit
