Introduction
===
This repository contains examples for using [Kueue](https://kueue.sigs.k8s.io/) and [Kube Ray](https://docs.ray.io/en/latest/cluster/kubernetes/index.html) on OpenShift AI.

Prerequisite
---
Ensure there is at least 1 worker node that has a GPU. On AWS, this can be a p3.8xlarge instance, otherwise you can run the makefile target to add a `machineset` for a single replica of p3.8xlarge.

```
$ make add-gpu-machineset
```

Taint the GPU node
```bash
oc adm taint nodes <gpu-node> nvidia.com/gpu=Exists:NoSchedule
```

Setup
---
Install OpenShift AI using the OpenShift AI Operator. This install the latest version from the fast channel.

```
make openshift-ai-install
```

Examples
---

1. [Preemption using priority with quota](yaml/preemption/)



