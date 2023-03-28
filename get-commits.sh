#!/bin/sh

set -e

echo "Creating registries.conf for brew builds"
cat << \EOT > ~/.config/containers/registries.conf
[[registry]]
location="brew.registry.redhat.io"
EOT

NAMESPACE=openshift-mtv
echo "Get API and UI plugin pods"
API_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-api/{print $1}')
UI_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-ui-plugin/{print $1}')

echo "Get images from pods"
# The images have use registry.redhat.io address but they are linked inside ocp to brew.registry.redhat.io
# So we need to add the `brew.` prefix
API_IMG=brew.$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $API_POD)
UI_IMG=brew.$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $UI_POD)

echo "Get commit from images"
API_COMMIT=$(skopeo inspect "docker://$API_IMG" -n | jq '.Labels."io.openshift.build.commit.id"' -r)
UI_COMMIT=$(skopeo inspect "docker://$UI_IMG" -n | jq '.Labels."io.openshift.build.commit.id"' -r)

URL_FORKLIFT=https://github.com/kubev2v/forklift/commit/
URL_FORKLIFT_PLUGIN=https://github.com/kubev2v/forklift-console-plugin/commit/
echo "----------"
echo "$URL_FORKLIFT$API_COMMIT"
echo "$URL_FORKLIFT_PLUGIN$UI_COMMIT"

