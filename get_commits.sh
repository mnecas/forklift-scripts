#!/bin/bash

set -e

NAMESPACE=openshift-mtv
echo "Get API and UI plugin pods"
API_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-api/{print $1}')
UI_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-ui-plugin/{print $1}')

echo "Get images from pods"
API_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $API_POD)
UI_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $UI_POD)

IFS='@' read _ API_IMG_HASH <<< $API_IMG
IFS='@' read _ UI_IMG_HASH <<< $UI_IMG


echo "Get commit from images"
URL_FORKLIFT=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-api-rhel9@$API_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_PLUGIN=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-console-plugin-rhel9@$UI_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)

echo "----------"
echo "$URL_FORKLIFT$API_COMMIT"
echo "$URL_FORKLIFT_PLUGIN$UI_COMMIT"

