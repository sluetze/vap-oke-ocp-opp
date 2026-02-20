# Validation Admission Policies for Operator Subscription (OKE, OCP, OPP)

Kubernetes [Validating Admission Policies (VAPs)](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/) that enforce **ClusterServiceVersion (CSV)** resources to declare a valid OpenShift subscription for **OpenShift Kubernetes Engine (OKE)**, **OpenShift Container Platform (OCP)**, or **OpenShift Platform Plus (OPP)**.

This ensures only operators that are entitled for your cluster’s subscription can be installed via OLM.

---

> **Limitations and caveats**
>
> - **Operator metadata is not guaranteed.** This approach assumes operators declare `operators.openshift.io/valid-subscription` in their CSV. In practice, not all operators might do so correctly, and the data can be missing, outdated, or incorrect. This policy is the best available mechanism for OKE/OCP/OPP subscription checks and should catch most cases, but it cannot be relied on as a complete guarantee.
>
> - **Cluster subscription type is not exposed by the platform.** OpenShift does not expose the cluster’s subscription type (OKE vs OCP vs OPP) in the API. Therefore the second policy requires a **ConfigMap** (provided by you) that states the current subscription. You must create and maintain this ConfigMap yourself; the CEL expressions may be reused as-is or with small changes (e.g. in OpenShift) once the subscription source is defined.

---

## Source

Feature differences between OKE, OCP, and OPP are taken from Red Hat’s official documentation:

- [About OpenShift Kubernetes Engine | OpenShift Container Platform 4.21](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/overview/oke-about)

## Policies

| Policy | Purpose |
|--------|--------|
| **operator-valid-subscription** | When a CSV has the `operators.openshift.io/valid-subscription` annotation, its value must be a non-empty list containing at least one of: `OpenShift Kubernetes Engine`, `OpenShift Container Platform`, `OpenShift Platform Plus`. **If the annotation is missing, the operator is allowed.** |
| **operator-subscription-matches-cluster** | (Optional) When a cluster subscription type is supplied via a ConfigMap param and the CSV has `valid-subscription`, the CSV must list a type allowed for that cluster: **OKE cluster** allows only OKE; **OCP cluster** allows OKE or OCP; **OPP cluster** allows OKE, OCP, or OPP. **If the CSV has no `valid-subscription` annotation, the operator is allowed.** |

## Quick start

1. **Apply policies and the binding that only checks annotation format (no cluster type):**

   ```bash
   kubectl apply -f policies/operator-valid-subscription.yaml
   kubectl apply -f bindings/operator-valid-subscription-binding.yaml
   ```

2. **Optional – enforce cluster subscription type:**

   Create the ConfigMap that describes your cluster’s subscription (choose one):

   ```bash
   # OKE
   kubectl apply -f config/cluster-subscription-oke.yaml

   # OCP
   kubectl apply -f config/cluster-subscription-ocp.yaml

   # OPP
   kubectl apply -f config/cluster-subscription-opp.yaml
   ```

   Then apply the second policy and its binding:

   ```bash
   kubectl apply -f policies/operator-subscription-matches-cluster.yaml
   kubectl apply -f bindings/operator-subscription-matches-cluster-binding.yaml
   ```

   The binding’s `paramRef` must point to the ConfigMap name/namespace you used (default: `cluster-subscription-type` in `default`).

## Cluster subscription hierarchy

When the second policy is used with a cluster subscription ConfigMap:

- **OKE** — Only operators whose `valid-subscription` includes **OpenShift Kubernetes Engine** are allowed.
- **OCP** — Operators whose `valid-subscription` includes **OpenShift Kubernetes Engine** or **OpenShift Container Platform** are allowed.
- **OPP** — Operators whose `valid-subscription` includes **OpenShift Kubernetes Engine**, **OpenShift Container Platform**, or **OpenShift Platform Plus** are allowed.

## Requirements

- **Kubernetes 1.28+** (VAP in beta) or **OpenShift 4.14+**
- **Cluster-admin** to create `ValidatingAdmissionPolicy` and `ValidatingAdmissionPolicyBinding` resources

## CSV annotation format

Operators may set the following annotation on their ClusterServiceVersion to declare which subscription types they support:

```yaml
metadata:
  annotations:
    operators.openshift.io/valid-subscription: '["OpenShift Kubernetes Engine", "OpenShift Container Platform", "OpenShift Platform Plus"]'
```

- **If the annotation is missing**, the operator is allowed to be installed.
- **If the annotation is present**, its value must be a **JSON array of strings** and at least one of:
  - `OpenShift Kubernetes Engine`
  - `OpenShift Container Platform`
  - `OpenShift Platform Plus`
  must appear in the array.

## Feature summary (OKE vs OCP vs OPP)

Abbreviated from [Red Hat OKE about](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/overview/oke-about). Use this to decide which operators are valid for OKE vs OCP vs OPP.

### Included in OKE and OCP

- OLM, Administrator web console, OpenShift Virtualization
- Cluster Monitoring (Prometheus), Cost Management
- Compliance Operator, File Integrity Operator, PTP, SR-IOV, VPA, Local Storage, Node Feature Discovery, OADP
- Log forwarding (OKE has log forwarding; full Platform Logging is OCP-only)
- MetalLB, HAProxy Ingress, Multus, Network Policies, etc.

### OCP-only (not included in OKE)

| Feature / Operator | Note |
|--------------------|------|
| User Workload Monitoring | OCP only |
| Platform Logging (Fluentd/Kibana-style) | OCP only |
| Developer Web Console, Developer Application Catalog | OCP only |
| Source to Image, Tekton builders, OpenShift Pipelines | OCP only |
| OpenShift Service Mesh, Kiali, Distributed Tracing | OCP only |
| OpenShift Serverless (Knative), Kourier | OCP only |
| Red Hat OpenShift GitOps | OCP only |
| Red Hat OpenShift Dev Spaces, Web Terminal, odo | OCP only |
| Migration Toolkit for Containers, Quay Bridge, JWS, etc. | OCP only |
| OpenShift sandboxed containers | OCP/OKE: not included; separate entitlement |

### Separate or optional subscriptions (not included in base OCP/OKE/OPP)

- Red Hat Advanced Cluster Management, Advanced Cluster Security
- Red Hat Quay, OpenShift Data Foundation
- Red Hat Integration (3Scale, AMQ, Camel K, Fuse, etc.), JBoss EAP, Ansible Automation Platform, etc.

### OPP (OpenShift Platform Plus)

OPP builds on OCP and typically bundles:

- Red Hat Advanced Cluster Management for Kubernetes
- Red Hat Advanced Cluster Security for Kubernetes
- Red Hat Quay
- Red Hat OpenShift Data Foundation Essentials

Any operator that is valid for OCP is valid for OPP from a subscription perspective; OPP adds more capabilities.

## Test cases

See [tests/README.md](tests/README.md) for the full matrix. Tests run in **three suites** (cluster subscription OKE, OCP, OPP); each suite applies the matching ConfigMap and asserts which fixtures pass or fail.

Run against a live cluster (1.28+ or OpenShift 4.14+):

```bash
./tests/run-tests.sh my-namespace
```

## Project layout

```
├── README.md
├── policies/
│   ├── operator-valid-subscription.yaml
│   └── operator-subscription-matches-cluster.yaml
├── bindings/
│   ├── operator-valid-subscription-binding.yaml
│   └── operator-subscription-matches-cluster-binding.yaml
├── config/
│   ├── cluster-subscription-oke.yaml
│   ├── cluster-subscription-ocp.yaml
│   └── cluster-subscription-opp.yaml
├── tests/
│   ├── README.md
│   ├── run-tests.sh
│   └── fixtures/
│       ├── csv-valid-*.yaml
│       └── csv-invalid-*.yaml
└── clusterServiceVersion-example.yml   # example CSV with valid-subscription
```

## License

See [LICENSE](LICENSE).
