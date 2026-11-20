#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# helm lint + kubescape misconfiguration scan for every chart under helm/ or
# charts/ (one chart per directory: helm/*/Chart.yaml, charts/*/Chart.yaml).
# kubescape renders helm charts natively with their default values. A chart
# whose defaults render nothing kubescape can scan (for example, only custom
# resources, or nothing at all until values opt in) still gets helm lint; its
# kubescape scan is reported as skipped rather than failed. No charts →
# silent no-op. Repos silence
# accepted findings with a .kubescape/exceptions.json (auto-loaded here, the
# .grype.yaml spirit). KUBECONFIG points at nothing: kubescape otherwise
# contacts whatever cluster the developer's kubeconfig names, and a lint of
# local files must never touch a live cluster. --logger warning: at info level
# kubescape points its UI printer at /dev/null, appends .txt, and warns on
# every run when /dev/null.txt cannot be created; warning level swaps in the
# silent printer and avoids it (results still print via the results printer).
set -eu

: "${KUBESCAPE_SEVERITY:=high}"
export KUBECONFIG=/nonexistent

kubescape_scan() {
  if [ -f .kubescape/exceptions.json ]; then
    kubescape scan "$1" --logger warning --severity-threshold "$KUBESCAPE_SEVERITY" --exceptions .kubescape/exceptions.json
  else
    kubescape scan "$1" --logger warning --severity-threshold "$KUBESCAPE_SEVERITY"
  fi
}

# kubescape exits non-zero with "no scannable Kubernetes resources found" when
# a chart's defaults render nothing it understands. That is not a finding, so
# report it and move on; every other failure still fails the lint. Output is
# captured to tell the two apart, then printed as kubescape wrote it.
scan_chart() {
  log="$(mktemp "${TMPDIR:-/tmp}/lint-helm.XXXXXX")"
  status=0
  kubescape_scan "$1" >"$log" 2>&1 || status=$?
  cat "$log"
  if [ "$status" -ne 0 ] && grep -q 'no scannable Kubernetes resources found' "$log"; then
    echo "lint-helm: $1 renders no scannable resources with its default values; kubescape skipped"
    status=0
  fi
  rm -f "$log"
  return "$status"
}

for chart in helm/*/Chart.yaml charts/*/Chart.yaml; do
  [ -f "$chart" ] || continue
  d="${chart%/Chart.yaml}"
  echo "lint-helm: helm lint $d"
  helm lint "$d"
  echo "lint-helm: kubescape scan $d"
  scan_chart "$d"
done
