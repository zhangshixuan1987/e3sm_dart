#!/bin/bash
# Check that a DART build directory was compiled against the DART commit that
# this workflow's version profile (my_dart_version_profile) requires.
# quickbuild.sh writes dart_build_info.txt only after a complete build.
check_dart_build() {
  local dir="$1" profile_file expected stamp built
  profile_file="${my_repository_root:?}/config/versions/${my_dart_version_profile:?}.conf"
  [[ -r "${profile_file}" ]] || { echo "ERROR: version profile not found: ${profile_file}" >&2; return 1; }
  expected=$(sed -n 's/^DART_SHA=//p' "${profile_file}")
  stamp="${dir}/dart_build_info.txt"
  if [[ ! -r "${stamp}" ]]; then
    echo "ERROR: ${dir} has no complete build. Build it with the ${my_dart_version_profile} profile:" >&2
    echo "       tools/checkout-version ${my_dart_version_profile} && (cd ${dir} && ./quickbuild.sh)" >&2
    return 1
  fi
  built=$(sed -n 's/^dart_sha=//p' "${stamp}")
  if [[ "${built}" != "${expected}" ]]; then
    echo "ERROR: ${dir} was built with DART ${built:0:7}, but profile ${my_dart_version_profile} requires ${expected:0:7}. Rebuild it:" >&2
    echo "       tools/checkout-version ${my_dart_version_profile} && (cd ${dir} && ./quickbuild.sh)" >&2
    return 1
  fi
  if grep -q '^dart_local_changes=yes' "${stamp}"; then
    echo "WARNING: ${dir} was built from a DART checkout with local changes" >&2
  fi
  echo "DART build ${dir}: DART ${built:0:7} (${my_dart_version_profile}), $(sed -n 's/^built_at=/built /p' "${stamp}")"
}
