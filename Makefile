BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL=/bin/sh
WORK_DIR=/tmp/openshift-ai-ray
JOB_NAME=git-clone-job
NAMESPACE=distributed

.PHONY: install-openshift-ai add-gpu-machineset setup-kueue-premption clean

install-openshift-ai:
	add-gpu-operator
	deploy-oai

add-gpu-machineset:
	@mkdir -p $(WORK_DIR)
	@$(BASE)/scripts/add-gpu.sh $(WORK_DIR)	

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
	@$(BASE)/scripts/clean-kueue.sh
	
	oc create -f $(BASE)/yaml/preemption/team-a-ns.yaml -f $(BASE)/yaml/preemption/team-b-ns.yaml
	oc create -f $(BASE)/yaml/preemption/team-a-rb.yaml -f $(BASE)/yaml/preemption/team-b-rb.yaml
	oc create -f $(BASE)/yaml/preemption/default-flavor.yaml -f $(BASE)/yaml/preemption/gpu-flavor.yaml
	oc create -f $(BASE)/yaml/preemption/team-a-cq.yaml -f $(BASE)/yaml/preemption/team-b-cq.yaml -f $(BASE)/yaml/preemption/shared-cq.yaml
	oc create -f $(BASE)/yaml/preemption/team-a-local-queue.yaml -f $(BASE)/yaml/preemption/team-b-local-queue.yaml

setup-ray-distributed-training: 	
	@$(BASE)/scripts/clean-kueue.sh

	-oc delete -f $(BASE)/yaml/distributed/git-clone.yaml
	-oc delete -f $(BASE)/yaml/distributed/workbench.yaml
	-oc delete -f $(BASE)/yaml/distributed/cephfs-pvc.yaml
	-oc delete -f $(BASE)/yaml/distributed/ns.yaml

	oc create -f $(BASE)/yaml/distributed/ns.yaml
	oc create -f $(BASE)/yaml/distributed/rolebinding.yaml
	oc create -f $(BASE)/yaml/distributed/default-flavor.yaml -f $(BASE)/yaml/distributed/gpu-flavor.yaml
	oc create -f $(BASE)/yaml/distributed/cluster-queue.yaml
	oc create -f $(BASE)/yaml/distributed/local-queue.yaml
	oc create -f $(BASE)/yaml/distributed/cephfs-pvc.yaml
	
	oc create -f $(BASE)/yaml/distributed/git-clone.yaml
	@echo "Waiting for job $(JOB_NAME) to complete..."
    
	@until oc get job $(JOB_NAME) -n $(NAMESPACE) -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; do \
        if oc get job $(JOB_NAME) -n $(NAMESPACE) -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q "True"; then \
            echo "Job $(JOB_NAME) failed."; \
            exit 1; \
        fi; \
        echo "Job $(JOB_NAME) is still running..."; \
        sleep 10; \
    done	
	
	oc delete -f $(BASE)/yaml/distributed/git-clone.yaml

	oc create -f $(BASE)/yaml/distributed/workbench.yaml
	