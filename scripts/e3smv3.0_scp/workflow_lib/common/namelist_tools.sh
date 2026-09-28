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

# Set <key> in namelist group <group> of <file> to <value>, replacing any
# existing (possibly multi-line) assignment. <value> is written verbatim, so
# it may be a multi-line array. The value is passed through the environment
# so backslashes and quotes are not reinterpreted.
nml_set_value() {
  local file="$1" group="$2" key="$3" tmp
  nml_print_group "${file}" "${group}" | grep -q . || { echo "ERROR: &${group} not found in ${file}" >&2; return 1; }
  tmp="${file}.tmp.$$"
  NML_VALUE="$4" awk -v g="${group}" -v k="${key}" '
    tolower($0) ~ "^[[:space:]]*&" tolower(g) "([[:space:]]|$)" { ingroup = 1; print; next }
    ingroup && $0 ~ /^[[:space:]]*\/[[:space:]]*$/ {
      printf "   %s = %s\n", k, ENVIRON["NML_VALUE"]; print; ingroup = 0; skip = 0; next }
    ingroup && tolower($0) ~ "^[[:space:]]*" tolower(k) "[[:space:]]*=" { skip = 1; next }
    ingroup && skip && $0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_%]*[[:space:]]*=/ { skip = 0 }
    ingroup && skip { next }
    { print }
  ' "${file}" > "${tmp}" && mv -f "${tmp}" "${file}"
}
