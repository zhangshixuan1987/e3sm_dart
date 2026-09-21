#!/usr/bin/env bash

# Shared parsing and validation for dependency version profiles.
# Profiles are parsed as data; they are never evaluated as shell code.

profile_fail() {
  printf 'ERROR: %s\n' "$*" >&2
  return 1
}

trim_profile_value() {
  local value=$1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

resolve_profile() {
  local repository_root=$1
  local requested=${2:-baseline}

  if [[ -f "${requested}" ]]; then
    readlink -f -- "${requested}"
  elif [[ -f "${repository_root}/config/versions/${requested}.conf" ]]; then
    readlink -f -- "${repository_root}/config/versions/${requested}.conf"
  else
    profile_fail "version profile not found: ${requested}"
  fi
}

load_profile() {
  local profile_file=$1
  local raw_line line key value line_number=0
  local -A seen=()

  unset PROFILE_FORMAT PROFILE_NAME
  unset DART_URL DART_REF DART_SHA
  unset E3SM_URL E3SM_REF E3SM_SHA

  while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
    line_number=$((line_number + 1))
    line=$(trim_profile_value "${raw_line}")
    [[ -z "${line}" || "${line}" == \#* ]] && continue

    if [[ ! "${line}" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      profile_fail "${profile_file}:${line_number}: expected KEY=VALUE" || return 1
    fi
    key=${BASH_REMATCH[1]}
    value=$(trim_profile_value "${BASH_REMATCH[2]}")

    case "${key}" in
      PROFILE_FORMAT|PROFILE_NAME|DART_URL|DART_REF|DART_SHA|E3SM_URL|E3SM_REF|E3SM_SHA) ;;
      *) profile_fail "${profile_file}:${line_number}: unknown key ${key}" || return 1 ;;
    esac
    [[ -z "${seen[${key}]:-}" ]] || \
      profile_fail "${profile_file}:${line_number}: duplicate key ${key}" || return 1
    [[ -n "${value}" ]] || \
      profile_fail "${profile_file}:${line_number}: ${key} may not be empty" || return 1

    printf -v "${key}" '%s' "${value}"
    seen[${key}]=1
  done < "${profile_file}"

  local variable
  for variable in \
    PROFILE_FORMAT PROFILE_NAME \
    DART_URL DART_REF DART_SHA \
    E3SM_URL E3SM_REF E3SM_SHA; do
    [[ -n "${!variable:-}" ]] || \
      profile_fail "${profile_file}: required key ${variable} is missing" || return 1
  done

  [[ "${PROFILE_FORMAT}" == 1 ]] || \
    profile_fail "${profile_file}: unsupported PROFILE_FORMAT=${PROFILE_FORMAT}" || return 1
  [[ "${PROFILE_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
    profile_fail "${profile_file}: invalid PROFILE_NAME=${PROFILE_NAME}" || return 1
  [[ "${DART_SHA}" =~ ^[0-9a-fA-F]{40}$ ]] || \
    profile_fail "${profile_file}: DART_SHA must be a full 40-character commit SHA" || return 1
  [[ "${E3SM_SHA}" =~ ^[0-9a-fA-F]{40}$ ]] || \
    profile_fail "${profile_file}: E3SM_SHA must be a full 40-character commit SHA" || return 1
  [[ "${DART_URL}" != -* && "${DART_REF}" != -* ]] || \
    profile_fail "${profile_file}: DART URL and ref may not begin with '-'" || return 1
  [[ "${E3SM_URL}" != -* && "${E3SM_REF}" != -* ]] || \
    profile_fail "${profile_file}: E3SM URL and ref may not begin with '-'" || return 1

  DART_SHA=${DART_SHA,,}
  E3SM_SHA=${E3SM_SHA,,}
}

submodule_recorded_sha() {
  local repository_root=$1
  local submodule=$2
  git -C "${repository_root}" ls-tree HEAD -- "${submodule}" | awk '{print $3}'
}
