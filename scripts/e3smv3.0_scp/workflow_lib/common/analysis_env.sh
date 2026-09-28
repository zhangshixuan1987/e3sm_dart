#!/bin/bash
# Load the analysis environment (NCO and related tools) named by
# my_analysis_env_file, for the stages that rewrite or post-process NetCDF
# files (Steps 2, 7 and 8).
#
# The E3SM-Unified activation scripts read variables that may be unset, so the
# environment is loaded with `nounset` temporarily off and restored afterwards.
load_analysis_env() {
  local restore_nounset=FALSE
  [[ -n "${my_analysis_env_file:-}" ]] || { echo "ERROR: my_analysis_env_file is unset" >&2; return 1; }
  [[ -r "${my_analysis_env_file}" ]] || { echo "ERROR: analysis environment is not readable: ${my_analysis_env_file}" >&2; return 1; }
  echo "Loading analysis environment: ${my_analysis_env_file}"
  [[ $- == *u* ]] && restore_nounset=TRUE
  set +u
  source "${my_analysis_env_file}" || { [[ "${restore_nounset}" == TRUE ]] && set -u; echo "ERROR: could not load analysis environment: ${my_analysis_env_file}" >&2; return 1; }
  if [[ "${restore_nounset}" == TRUE ]]; then
    set -u
  fi
  command -v ncks >/dev/null 2>&1 || { echo "ERROR: analysis environment does not provide NCO (ncks): ${my_analysis_env_file}" >&2; return 1; }
}
