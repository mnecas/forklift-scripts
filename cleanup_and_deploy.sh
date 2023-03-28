#!/bin/bash

set -e

cleanup() {
echo "Deleting ForkliftController"
oc delete ForkliftController -n openshift-mtv forklift-controller

echo "Deleting catalog"
oc delete catalogsource -n openshift-marketplace redhat-mtv

echo "Delete CSV"
oc delete clusterserviceversion -n openshift-mtv mtv-operator.v2.4.0

echo "Deleting subscription"
oc delete subscription -n openshift-mtv mtv-operator
}

setup(){
echo "Adding catalog"
cat << EOF | kubectl apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-mtv
  namespace: openshift-marketplace
spec:
  displayName: Martin Necas $VERSION
  publisher: Red Hat
  sourceType: grpc
  image: registry-proxy.engineering.redhat.com/rh-osbs/iib:$VERSION
  updateStrategy:
    registryPoll:
      interval: 10m0s
EOF

cat << EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: mtv-operator
  namespace: openshift-mtv
spec:
  channel: release-v2.4
  installPlanApproval: Automatic
  name: mtv-operator
  source: redhat-mtv
  sourceNamespace: openshift-marketplace
  startingCSV: mtv-operator.v2.4.0
EOF

cat << EOF | kubectl apply -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: ForkliftController
metadata:
  name: forklift-controller
  namespace: openshift-mtv
spec:
  feature_must_gather_api: 'true'
  feature_ui: 'false'
  feature_ui_plugin: 'true'
  feature_validation: 'true'
  feature_volume_populator: 'true'
EOF

}

if [ $# -eq 0 ]
  then
    echo "Please specify the version of index."
    exit
fi
VERSION=$1
cleanup
setup

