#!/usr/bin/env bash
TOPDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC2034
CI_PLATFORM="vagrant" SSH_USER="${USER}"
# shellcheck disable=SC2034
UPGRADE_TEST="false" CI_JOB_NAME="local"
"${TOPDIR}/tests/scripts/testcases_run.sh"
