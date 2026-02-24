#!/usr/bin/env bash
# Run VAP tests against a live OpenShift/Kubernetes cluster (1.28+ with ValidatingAdmissionPolicy).
# Runs three test suites: cluster subscription OKE, OCP, and OPP.
# Prerequisites: oc (OpenShift CLI), cluster with VAP support, cluster-admin.
# Usage: ./tests/run-tests.sh [namespace]
set -euo pipefail

NAMESPACE="${1:-vap-test-ns}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
CONFIG="$REPO_ROOT/config"

echo "Using namespace: $NAMESPACE"
oc create namespace "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
oc create namespace operator-subscription --dry-run=client -o yaml | oc apply -f -

echo "Applying ValidatingAdmissionPolicies and bindings..."
oc apply -f "$REPO_ROOT/policies/operator-valid-subscription.yaml"
oc apply -f "$REPO_ROOT/policies/operator-subscription-matches-cluster.yaml"
oc apply -f "$REPO_ROOT/bindings/operator-valid-subscription-binding.yaml"
oc apply -f "$REPO_ROOT/bindings/operator-subscription-matches-cluster-binding.yaml"

# Helpers: expect pass or fail for a fixture
apply_expect_pass() {
  local f="$1"
  local name=$(basename "$f")
  if oc apply -f "$f" --namespace "$NAMESPACE" --dry-run=server 2>&1; then
    echo "  PASS: $name"
    return 0
  else
    echo "  FAIL (expected pass): $name"
    return 1
  fi
}

apply_expect_fail() {
  local f="$1"
  local name=$(basename "$f")
  if ! oc apply -f "$f" --namespace "$NAMESPACE" --dry-run=server 2>&1; then
    echo "  PASS (rejected): $name"
    return 0
  else
    echo "  FAIL (expected reject): $name"
    return 1
  fi
}

run_oke_tests() {
  echo ""
  echo "========== Cluster subscription: OKE (only OKE in valid-subscription allowed) =========="
  oc apply -f "$CONFIG/cluster-subscription-oke.yaml"
  # OKE cluster: only csv-valid-all-three (has OKE), csv-valid-missing-annotation, and csv-valid-subscription-none pass
  apply_expect_pass "$FIXTURES/csv-valid-all-three.yaml" || exit 1
  apply_expect_pass "$FIXTURES/csv-valid-subscription-none.yaml" || exit 1  # valid-subscription: none always allowed
  apply_expect_fail "$FIXTURES/csv-valid-ocp-opp-only.yaml" || exit 1   # no OKE
  apply_expect_fail "$FIXTURES/csv-valid-opp-only.yaml" || exit 1      # no OKE
  apply_expect_pass "$FIXTURES/csv-valid-missing-annotation.yaml" || exit 1
  apply_expect_fail "$FIXTURES/csv-invalid-empty-annotation.yaml" || exit 1
  apply_expect_fail "$FIXTURES/csv-invalid-unknown-subscription.yaml" || exit 1
}

run_ocp_tests() {
  echo ""
  echo "========== Cluster subscription: OCP (OKE or OCP in valid-subscription allowed) =========="
  oc apply -f "$CONFIG/cluster-subscription-ocp.yaml"
  apply_expect_pass "$FIXTURES/csv-valid-all-three.yaml" || exit 1
  apply_expect_pass "$FIXTURES/csv-valid-subscription-none.yaml" || exit 1  # valid-subscription: none always allowed
  apply_expect_pass "$FIXTURES/csv-valid-ocp-opp-only.yaml" || exit 1   # has OCP
  apply_expect_fail "$FIXTURES/csv-valid-opp-only.yaml" || exit 1      # only OPP, no OKE/OCP
  apply_expect_pass "$FIXTURES/csv-valid-missing-annotation.yaml" || exit 1
  apply_expect_fail "$FIXTURES/csv-invalid-empty-annotation.yaml" || exit 1
  apply_expect_fail "$FIXTURES/csv-invalid-unknown-subscription.yaml" || exit 1
}

run_opp_tests() {
  echo ""
  echo "========== Cluster subscription: OPP (OKE, OCP, or OPP in valid-subscription allowed) =========="
  oc apply -f "$CONFIG/cluster-subscription-opp.yaml"
  apply_expect_pass "$FIXTURES/csv-valid-all-three.yaml" || exit 1
  apply_expect_pass "$FIXTURES/csv-valid-subscription-none.yaml" || exit 1  # valid-subscription: none always allowed
  apply_expect_pass "$FIXTURES/csv-valid-ocp-opp-only.yaml" || exit 1
  apply_expect_pass "$FIXTURES/csv-valid-opp-only.yaml" || exit 1
  apply_expect_pass "$FIXTURES/csv-valid-missing-annotation.yaml" || exit 1
  apply_expect_fail "$FIXTURES/csv-invalid-empty-annotation.yaml" || exit 1
  apply_expect_fail "$FIXTURES/csv-invalid-unknown-subscription.yaml" || exit 1
}

run_oke_tests
run_ocp_tests
run_opp_tests

echo ""
echo "All tests completed successfully (OKE, OCP, OPP)."
