#!/bin/bash
#SBATCH --account=esmd
#SBATCH --time=24:00:00
#SBATCH --partition=slurm
#SBATCH --job-name=e3sm_compress_range
#SBATCH --nodes=1
#SBATCH --output=e3sm_compress_range.%j
#SBATCH --exclusive
#SBATCH --no-kill
#SBATCH --requeue

# Optional workflow step after 4_run_dart_e3sm_cycleda.sh. This independent
# range driver processes cycle timestamps through workflow_lib/compress/eam_compress_data.sh and is
# never submitted automatically by DA cycling.
set -Eeuo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

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
WORK_DIR=$(resolve_workflow_dir) || fail "cannot find create_and_setup_case.sh next to this script or in the submission directory"
echo "Using workflow configuration: ${WORK_DIR}/create_and_setup_case.sh"
cd "${WORK_DIR}"

CONFIG_FILE="${WORK_DIR}/create_and_setup_case.sh"
[[ -r "${CONFIG_FILE}" ]] || fail "missing workflow configuration: ${CONFIG_FILE}"
source "${CONFIG_FILE}"
mkdir -p "${my_log_dir}" "${my_status_dir}" "${my_lock_dir}"

for cmd in date readlink; do
  command -v "${cmd}" >/dev/null 2>&1 || fail "required command not found: ${cmd}"
done
[[ -x "${my_workflow_lib}/compress/eam_compress_data.sh" ]] || fail "missing compressor: ${my_workflow_lib}/compress/eam_compress_data.sh"
[[ $# -eq 2 ]] || fail "usage: sbatch $0 YYYY-MM-DD-SSSSS YYYY-MM-DD-SSSSS"

START_STAMP="$1"
END_STAMP="$2"
INTERVAL_HOURS="${COMPRESS_INTERVAL_HOURS:-6}"
[[ "${START_STAMP}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{5}$ ]] || fail "invalid start timestamp: ${START_STAMP}"
[[ "${END_STAMP}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{5}$ ]] || fail "invalid end timestamp: ${END_STAMP}"
[[ "${INTERVAL_HOURS}" =~ ^[1-9][0-9]*$ ]] || fail "COMPRESS_INTERVAL_HOURS must be positive"

stamp_to_epoch() {
  local stamp="$1" ymd tod hour minute second
  ymd="${stamp%-*}"
  tod="${stamp##*-}"
  (( 10#${tod} < 86400 )) || return 1
  hour=$((10#${tod} / 3600))
  minute=$(((10#${tod} % 3600) / 60))
  second=$((10#${tod} % 60))
  date -d "${ymd} $(printf '%02d:%02d:%02d' "${hour}" "${minute}" "${second}")" +%s
}

epoch_to_parts() {
  local epoch="$1" ymd hour minute second tod
  read -r ymd hour minute second < <(date -d "@${epoch}" '+%Y-%m-%d %H %M %S')
  tod=$((10#${hour} * 3600 + 10#${minute} * 60 + 10#${second}))
  printf '%s %05d\n' "${ymd}" "${tod}"
}

START_EPOCH=$(stamp_to_epoch "${START_STAMP}") || fail "invalid start timestamp: ${START_STAMP}"
END_EPOCH=$(stamp_to_epoch "${END_STAMP}") || fail "invalid end timestamp: ${END_STAMP}"
(( START_EPOCH <= END_EPOCH )) || fail "start timestamp is after end timestamp"
STEP_SECONDS=$((INTERVAL_HOURS * 3600))
(( (END_EPOCH - START_EPOCH) % STEP_SECONDS == 0 )) || fail "end timestamp is not aligned to the ${INTERVAL_HOURS}-hour interval"

for ((cycle_epoch=START_EPOCH; cycle_epoch<=END_EPOCH; cycle_epoch+=STEP_SECONDS)); do
  read -r cycle_date cycle_tod < <(epoch_to_parts "${cycle_epoch}")
  for ((member_i=1; member_i<=my_ensnum; member_i++)); do
    member=$(printf 'EN%02d' "${member_i}")
    echo "== Compressing ${member} at ${cycle_date}-${cycle_tod} =="
    STEP5_DRIVER_ACTIVE=TRUE COMPRESS_ENSTR="${member}" WORKFLOW_ROOT="${WORK_DIR}" "${my_workflow_lib}/compress/eam_compress_data.sh" "${cycle_date}" "${cycle_tod}"
  done
done

echo "Compression range completed: ${START_STAMP} through ${END_STAMP}"
