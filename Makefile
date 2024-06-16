BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL:= /bin/bash
WORK_DIR=$(shell mktemp -d)

#include .env
#export

.PHONY: deploy-oai clean

install-openshift-ai:
	add-gpu-operator
	deploy-oai

add-gpu-machineset:
	$(BASE)/scripts/add-gpu.sh $(WORK_DIR)
	@rm -rf "$(WORK_DIR)"

add-gpu-operator:
	oc apply -f $(BASE)/yaml/operators/nfd.yaml

	@until oc get crd nodefeaturediscoveries.nfd.openshift.io >/dev/null 2>&1; do \
    	echo "Wait until CRD nodefeaturediscoveries.nfd.openshift.io is ready..."; \
	done

	oc apply -f $(BASE)/yaml/operators/nfd-cr.yaml
	oc apply -f $(BASE)/yaml/operators/nvidia.yaml

	@until oc get crd clusterpolicies.nvidia.com>/dev/null 2>&1; do \
    	echo "Wait until CRD clusterpolicies.nvidia.com is ready..."; \
	done

	oc apply -f $(BASE)/yaml/operators/nvidia-cluster-policy.yaml

deploy-oai:
	oc apply -f $(BASE)/yaml/operators/serverless.yaml
	oc apply -f $(BASE)/yaml/operators/servicemesh.yaml
	oc apply -f $(BASE)/yaml/operators/oai.yaml
	
setup-kueue-premption:
	oc create -f $(BASE)/yaml/preemption/team-a-ns.yaml -f $(BASE)/yaml/preemption/team-b-ns.yaml
	oc create -f $(BASE)/yaml/preemption/team-a-rb.yaml -f $(BASE)/yaml/preemption/team-b-rb.yaml
	oc create -f $(BASE)/yaml/preemption/default-flavor.yaml -f $(BASE)/yaml/preemption/gpu-flavor.yaml
	oc create -f $(BASE)/yaml/preemption/team-a-cq.yaml -f $(BASE)/yaml/preemption/team-b-cq.yaml -f $(BASE)/yaml/preemption/shared-cq.yaml
	oc create -f $(BASE)/yaml/preemption/team-a-local-queue.yaml -f $(BASE)/yaml/preemption/team-b-local-queue.yaml
	