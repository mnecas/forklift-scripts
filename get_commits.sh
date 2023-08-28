#!/bin/bash

set -e

USE_BRANCH=${1:-false}
NAMESPACE=${2:-"openshift-mtv"}
BRANCH=${3:-"refs/heads/release-$(git ls-remote -h https://github.com/kubev2v/forklift.git | cut -f 2 | cut -d "-" -f 2 | grep v | tail -n 1)"}
TAG_UI=${4:-$(git ls-remote -t https://github.com/kubev2v/forklift-console-plugin.git | tail -n 1 | cut -f 2)}
TAG_CONTROLLER=${5:-$(git ls-remote -t https://github.com/kubev2v/forklift.git | tail -n 1 | cut -f 2)}

if [ "$USE_BRANCH" = true ]; then
	echo "Using latest branch from upstream"
	echo Branch: $BRANCH
	FORKLIFT_GIT_HASH=$(git ls-remote -h https://github.com/kubev2v/forklift.git | grep $BRANCH | cut -f 1)
	CONSOLE_GIT_HASH=$(git ls-remote -h https://github.com/kubev2v/forklift-console-plugin.git | grep $BRANCH | cut -f 1)
	MUST_GATHER_API_GIT_HASH=$(git ls-remote -h https://github.com/kubev2v/forklift-must-gather-api.git | grep $BRANCH | cut -f 1)
	MUST_GATHER_GIT_HASH=$(git ls-remote -h https://github.com/kubev2v/forklift-must-gather.git | grep $BRANCH | cut -f 1)
else
	echo "Using latest branch and tags from upstream"
	echo UI tag: $TAG_UI
	echo General tag: $TAG_CONTROLLER
	echo Branch: $BRANCH
	FORKLIFT_GIT_HASH=$(git ls-remote -t https://github.com/kubev2v/forklift.git | grep $TAG_CONTROLLER | cut -f 1)
	CONSOLE_GIT_HASH=$(git ls-remote -t https://github.com/kubev2v/forklift-console-plugin.git | grep $TAG_UI | cut -f 1)
	MUST_GATHER_API_GIT_HASH=$(git ls-remote -h https://github.com/kubev2v/forklift-must-gather-api.git | grep $BRANCH | cut -f 1)
	MUST_GATHER_GIT_HASH=$(git ls-remote -h https://github.com/kubev2v/forklift-must-gather.git | grep $BRANCH | cut -f 1)
fi

echo Namespace: $NAMESPACE

echo "Get forklift pods"
API_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-api/{print $1}')
UI_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-ui-plugin/{print $1}')
CONTROLLER_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-controller/{print $1}')
POPULATOR_CONTROLLER_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-volume-populator-controller/{print $1}')
MUST_GATHER_API_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-must-gather-api/{print $1}')
VALIDATION_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-validation/{print $1}')
OPERATOR_POD=$(oc get pods -n $NAMESPACE --no-headers=true | awk '/forklift-operator/{print $1}')

echo "Get images from pods"
API_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $API_POD)
UI_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $UI_POD)
CONTROLLER_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[0].image}" $CONTROLLER_POD)
POP_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $POPULATOR_CONTROLLER_POD)
MUST_API_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $MUST_GATHER_API_POD)
VALIDATION_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $VALIDATION_POD)
OPERATOR_IMG=$(oc get pods -n $NAMESPACE -o jsonpath="{.spec.containers[*].image}" $OPERATOR_POD)
V2V_IMGS=$(oc get pod -n $NAMESPACE -o json $CONTROLLER_POD | grep v2v | awk '{print $2}' | cut -d "\"" -f 2)
V2V_EL9_IMG=$(echo $V2V_IMGS | cut -d "|" -f 1)
V2V_EL8_IMG=$(echo $V2V_IMGS | cut -d "|" -f 2)
MUST_GATHER_IMG=$(oc get pod -n $NAMESPACE -o json $MUST_GATHER_API_POD | grep mtv-must-gather-rhel8 | awk '{print $2}' | cut -d "\"" -f 2)
OVIRT_POP_IMG=$(oc get pod -n $NAMESPACE -o json $POPULATOR_CONTROLLER_POD | grep mtv-rhv-populator-rhel8 | awk '{print $2}' | cut -d "\"" -f 2)
OPENSTACK_POP_IMG=$(oc get pod -n $NAMESPACE -o json $POPULATOR_CONTROLLER_POD | grep mtv-openstack-populator-rhel9 | awk '{print $2}' | cut -d "\"" -f 2)
OVA_SERVER_IMG=$(oc get pod -n $NAMESPACE -o json $OPERATOR_POD | grep mtv-ova-provider-server | awk '{print $2}' | cut -d "\"" -f 2)

IFS='@' read _ API_IMG_HASH <<< $API_IMG
IFS='@' read _ UI_IMG_HASH <<< $UI_IMG
IFS='@' read _ CONTROLLER_IMG_HASH <<< $CONTROLLER_IMG
IFS='@' read _ POP_IMG_HASH <<< $POP_IMG
IFS='@' read _ MUST_API_IMG_HASH <<< $MUST_API_IMG
IFS='@' read _ VALIDATION_IMG_HASH <<< $VALIDATION_IMG
IFS='@' read _ OPERATOR_IMG_HASH <<< $OPERATOR_IMG
IFS='@' read _ V2V_EL9_IMG_HASH <<< $V2V_EL9_IMG
IFS='@' read _ V2V_EL8_IMG_HASH <<< $V2V_EL8_IMG
IFS='@' read _ MUST_GATHER_IMG_HASH <<< $MUST_GATHER_IMG
IFS='@' read _ OVIRT_POP_IMG_HASH <<< $OVIRT_POP_IMG
IFS='@' read _ OPENSTACK_POP_IMG_HASH <<< $OPENSTACK_POP_IMG
IFS='@' read _ OVA_SERVER_IMG_HASH <<< $OVA_SERVER_IMG

echo "Get commit from images"
URL_FORKLIFT_API=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-api-rhel9@$API_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_PLUGIN=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-console-plugin-rhel9@$UI_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_CONTROLLER=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-controller-rhel9@$CONTROLLER_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_POPULATOR=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-populator-controller-rhel9@$POP_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_MUST_API=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-must-gather-api-rhel8@$MUST_API_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_VALIDATION=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-validation-rhel9@$VALIDATION_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_OPERATOR=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-rhel8-operator@$OPERATOR_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_V2V_EL9=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-virt-v2v-rhel9@$V2V_EL9_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_V2V_EL8=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-virt-v2v-warm-rhel8@$V2V_EL8_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_MUST_GATHER=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-must-gather-rhel8@$MUST_GATHER_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_OVIRT_POP=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-rhv-populator-rhel8@$OVIRT_POP_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_OSP_POP=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-openstack-populator-rhel9@$OPENSTACK_POP_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)
URL_FORKLIFT_OVA_SERVER=$(skopeo inspect "docker://registry-proxy.engineering.redhat.com/rh-osbs/migration-toolkit-virtualization-mtv-ova-provider-server-rhel9@$OVA_SERVER_IMG_HASH" -n | jq '.Labels."io.openshift.build.commit.url"' -r)

echo "----------"
echo "forklift-api: $URL_FORKLIFT_API"
echo "forklift-console-plugin: $URL_FORKLIFT_PLUGIN"
echo "forklift-controller: $URL_FORKLIFT_CONTROLLER"
echo "forklift-populator-controller: $URL_FORKLIFT_POPULATOR"
echo "forklift-must-gather-api: $URL_FORKLIFT_MUST_API"
echo "forklift-validation: $URL_FORKLIFT_VALIDATION"
echo "forklift-operator: $URL_FORKLIFT_OPERATOR"
echo "forklift-v2v-el9: $URL_FORKLIFT_V2V_EL9"
echo "forklift-v2v-el8: $URL_FORKLIFT_V2V_EL8"
echo "forklift-must-gather: $URL_FORKLIFT_MUST_GATHER"
echo "forklift-ovirt-populator: $URL_FORKLIFT_OVIRT_POP"
echo "forklift-openstack-populator: $URL_FORKLIFT_OSP_POP"
echo "forklift-ova-server: $URL_FORKLIFT_OVA_SERVER"

OK=true
if [ $(echo $URL_FORKLIFT_API | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
	echo "Wrong forklift-API commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_PLUGIN | cut -d "/" -f 7) != $CONSOLE_GIT_HASH ]; then
	echo "Wrong forklift-ui-Console commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_CONTROLLER | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-controller commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_POPULATOR | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-populator-controller commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_MUST_API | cut -d "/" -f 7) != $MUST_GATHER_API_GIT_HASH ]; then
        echo "Wrong forklift-must-gather-api commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_VALIDATION | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-validation commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_OPERATOR | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-operator commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_V2V_EL9 | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-v2v-el9 commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_V2V_EL8 | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-v2v-warm-el8 commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_MUST_GATHER | cut -d "/" -f 7) != $MUST_GATHER_GIT_HASH ]; then
        echo "Wrong forklift-must-gather commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_OVIRT_POP | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-ovirt-populator commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_OSP_POP | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-openstack-populator commit"
	OK=false
fi
if [ $(echo $URL_FORKLIFT_OVA_SERVER | cut -d "/" -f 7) != $FORKLIFT_GIT_HASH ]; then
        echo "Wrong forklift-ova-provider-server commit"
	OK=false
fi
if [ ! $OK ]; then
	echo "There is at least one wrong image"
	exit 1
fi
echo "The deployement is OK! Image check passed!"

