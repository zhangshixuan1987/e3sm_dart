#!/bin/bash
# Namelist helpers shared by the EAM and ELM DART workers.

# Print one namelist group (from "&name" through its closing "/" line).
nml_print_group() {
  local file="$1" group="$2"
  awk -v g="${group}" '
    tolower($0) ~ "^[[:space:]]*&" tolower(g) "([[:space:]]|$)" { f = 1 }
    f { print }
    f && /^[[:space:]]*\/[[:space:]]*$/ { exit }
  ' "${file}"
}

# Replace group <group> in <target> with the same group from <source>.
# Strongly coupled cross passes use this to assimilate the observation types
# of the component that produced the observations.
nml_replace_group() {
  local target="$1" group="$2" source="$3" block tmp
  block=$(nml_print_group "${source}" "${group}")
  [[ -n "${block}" ]] || { echo "ERROR: &${group} not found in ${source}" >&2; return 1; }
  nml_print_group "${target}" "${group}" | grep -q . || { echo "ERROR: &${group} not found in ${target}" >&2; return 1; }
  tmp="${target}.tmp.$$"
  awk -v g="${group}" -v blk="${block}" '
    !done && tolower($0) ~ "^[[:space:]]*&" tolower(g) "([[:space:]]|$)" { print blk; skip = 1; done = 1; next }
    skip { if ($0 ~ /^[[:space:]]*\/[[:space:]]*$/) skip = 0; next }
    { print }
  ' "${target}" > "${tmp}" && mv -f "${tmp}" "${target}"
}
