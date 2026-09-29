#!/bin/bash
# Shared file-operation commands for the E3SM-DART workflow.
#
# Every stage and worker sources this file instead of defining MOVE, COPY,
# LINK, LIST, and REMOVE locally, so file handling is identical on every
# machine and in every script. Machine-specific settings, such as MPI launch
# commands, stay in the calling script.

VERBOSE='-v'
MOVE='/usr/bin/mv'
COPY='/usr/bin/cp --preserve=timestamps'
LINK='/usr/bin/ln -fs'
LINKV=TRUE
LIST='/usr/bin/ls'
REMOVE=workflow_remove

# Remove files, links, or directories. A missing path is not an error, so the
# "remove, then relink" pattern is safe under `set -e`. Symbolic links are
# removed without following them. Empty paths and absolute paths shallower
# than four levels (for example /, /usr/bin, or /pscratch/sd/z) are refused,
# so an unset variable such as "${REMOVE} ${DIR}/*" cannot widen the target.
workflow_remove() {
  local target resolved depth
  for target in "$@"; do
    if [[ -z "${target}" ]]; then
      echo "ERROR: workflow_remove refused an empty path" >&2
      return 1
    fi
    resolved=$(/usr/bin/realpath -ms -- "${target}") || return 1
    depth=$(tr -cd '/' <<< "${resolved}" | wc -c)
    if (( depth < 4 )); then
      echo "ERROR: workflow_remove refused a top-level path: ${target} (${resolved})" >&2
      return 1
    fi
    /usr/bin/rm -fr -- "${target}" || return 1
  done
}
