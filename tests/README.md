# Test cases for operator subscription VAPs

## Subscription hierarchy (cluster allows)

- **OKE cluster**: Only operators that list **OpenShift Kubernetes Engine** in `valid-subscription` are allowed.
- **OCP cluster**: Operators that list **OpenShift Kubernetes Engine** or **OpenShift Container Platform** are allowed.
- **OPP cluster**: Operators that list **OpenShift Kubernetes Engine**, **OpenShift Container Platform**, or **OpenShift Platform Plus** are allowed.

Missing `operators.openshift.io/valid-subscription` annotation always allows installation. When present, the value must be non-empty and list at least one of OKE, OCP, OPP (enforced by `operator-valid-subscription`).

## Test runs

The test script runs **three suites**, one per cluster subscription type (OKE, OCP, OPP). For each suite it applies the corresponding ConfigMap and runs the fixtures with the expected pass/fail below.

## Test matrix

| Fixture | valid-subscription | OKE cluster | OCP cluster | OPP cluster |
|--------|--------------------|-------------|-------------|-------------|
| `csv-valid-all-three.yaml` | OKE, OCP, OPP | PASS | PASS | PASS |
| `csv-valid-ocp-opp-only.yaml` | OCP, OPP | FAIL | PASS | PASS |
| `csv-valid-opp-only.yaml` | OPP only | FAIL | FAIL | PASS |
| `csv-valid-missing-annotation.yaml` | (none) | PASS | PASS | PASS |
| `csv-invalid-empty-annotation.yaml` | "" | FAIL | FAIL | FAIL |
| `csv-invalid-unknown-subscription.yaml` | ["Some Other Product"] | FAIL | FAIL | FAIL |

- **PASS** = `kubectl apply --dry-run=server` succeeds (operator allowed).
- **FAIL** = request denied by a VAP (operator not allowed).

## Running tests

Requires Kubernetes 1.28+ (ValidatingAdmissionPolicy) or OpenShift 4.14+.

```bash
chmod +x tests/run-tests.sh
./tests/run-tests.sh my-namespace
```

This will:

1. Apply both ValidatingAdmissionPolicies and bindings.
2. Run **OKE** suite: apply `config/cluster-subscription-oke.yaml`, then run all fixtures (expect pass/fail as in matrix).
3. Run **OCP** suite: apply `config/cluster-subscription-ocp.yaml`, then run all fixtures.
4. Run **OPP** suite: apply `config/cluster-subscription-opp.yaml`, then run all fixtures.
