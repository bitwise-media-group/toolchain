#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# kubeconform with the house schema catalog — a helper for a repo's own Flux
# validation harness:
#
#   kubeconform.sh [kubeconform flags...] <file>...
#
# Strict, with a summary, against three schema locations in order: the
# default Kubernetes catalog, the community Flux catalog (Kustomization,
# HelmRelease, OCIRepository, ResourceSet, …), and the repo's vendored CRD
# schemas, named <kind>-<group>-<version>.json (refresh one with:
#   curl <crd.yaml> | yq -o=json '.spec.versions[0].schema.openAPIV3Schema'
# ). The catalogs carry no schema for CustomResourceDefinition itself, so it
# is skipped by default. Your own flags and files follow the house ones.
#
#   KUBECONFORM_SCHEMAS  vendored schema directory (default tests/schemas)
#   KUBECONFORM_SKIP     kinds to skip, comma-separated (default
#                        CustomResourceDefinition; empty skips nothing)
set -eu

schemas=${KUBECONFORM_SCHEMAS:-tests/schemas}
skip=${KUBECONFORM_SKIP-CustomResourceDefinition}

[ $# -ge 1 ] || {
  echo "usage: kubeconform.sh [kubeconform flags...] <file>..." >&2
  exit 2
}

if [ -n "$skip" ]; then
  set -- -skip "$skip" "$@"
fi

# The {{ … }} are kubeconform's own schema-location templates.
exec kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/{{ .ResourceKind }}{{ .KindSuffix }}.json' \
  -schema-location "$schemas/{{ .ResourceKind }}-{{ .Group }}-{{ .ResourceAPIVersion }}.json" \
  "$@"
