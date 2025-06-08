#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# profile_host_binary.sh
#
# One-file VTune Hotspots profiler for a host-built binary.  Contains three
# runnable recipes; only the least-privilege one (A) is active.
#
#   A) non-root + CAP_SYS_PTRACE + CAP_PERFMON  (default, recommended)
#   B) privileged container, auto-chown results
#   C) privileged container, manual chown required
#
# Edit BIN/RES below if your paths differ.
# ----------------------------------------------------------------------------
set -euo pipefail

# ---- host-side paths -------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/build/prime_counter"    # <-- change if needed
RES="${SCRIPT_DIR}/vtune_results"

mkdir -p "${RES}"                          # ensure writable dir exists
docker pull --quiet intel/oneapi-vtune:latest

###############################################################################
#  A) NON-ROOT + CAPABILITIES  (default, safest)                              #
#                                                                             #
#  • Needs one-time host tweak:                                               #
#       sudo sysctl -w kernel.yama.ptrace_scope=0                             #
#  • Hardware events via CAP_PERFMON (use CAP_SYS_ADMIN on < 5.8 kernels).    #
###############################################################################
docker run --rm \
  -u "$(id -u):$(id -g)" \
  --cap-add=SYS_PTRACE --cap-add=PERFMON \
  --security-opt seccomp=unconfined \
  -v "${BIN}":/opt/app/prime_counter:ro \
  -v "${RES}":/home/vtune \
  -w /home/vtune \
  -e HOME=/home/vtune \
  intel/oneapi-vtune:latest \
  vtune -collect hotspots \
        -result-dir results \
        -- /opt/app/prime_counter

###############################################################################
#  B) PRIVILEGED + INLINE CHOWN  (convenient, a bit wider attack surface)     #
###############################################################################
: '
docker run --rm --privileged \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "${BIN}":/opt/app/prime_counter:ro \
  -v "${RES}":/results \
  intel/oneapi-vtune:latest \
  bash -c "
    set -euo pipefail
    vtune -collect hotspots -result-dir /results -- /opt/app/prime_counter
    chown -R \"\${HOST_UID}:\${HOST_GID}\" /results
  "
'

###############################################################################
#  C) RAW ROOT  (fastest to paste, leaves results as root)                    #
###############################################################################
: '
docker run --rm --privileged \
  -v "${BIN}":/opt/app/prime_counter:ro \
  -v "${RES}":/results \
  intel/oneapi-vtune:latest \
  vtune -collect hotspots -result-dir /results -- /opt/app/prime_counter
'

echo -e "\n✅ VTune run complete.  Reports in: ${RES}/results"
