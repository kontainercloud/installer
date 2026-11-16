#!/bin/bash

# Copyright AppsCode Inc. and Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eou pipefail

for dir in charts/*/; do
    dir=${dir%*/}
    dir=${dir##*/}
    num_files=$(find charts/${dir}/templates -type f | wc -l)
    echo $dir
    if [ $num_files -le 1 ] ||
        [[ "$dir" = "kubevirt-infra-csi-driver" ]] ||
        [[ "$dir" = "kubevirt-tenant-csi-driver" ]]; then
        make ct CT_COMMAND=lint TEST_CHARTS=charts/$dir
    else
        ns=app-$(date +%s | head -c 6)
        kubectl create ns $ns
        # kubectl label ns $ns pod-security.kubernetes.io/enforce=restricted
        extra=""
        if [[ "$dir" = "loadbalancer-controller" ]]; then
            # The chart requires OpenStack credentials in every mode. Placeholders are
            # enough for the install test: the controller only authenticates when it
            # reconciles a load balancer, which never happens here.
            extra="--helm-extra-set-args='--set=openstackCreds.osAuthUrl=http://keystone.ci.invalid:5000/v3 --set=openstackCreds.osPassword=ci-placeholder --set=openstackCreds.osProjectId=ci-placeholder'"
        fi
        make ct TEST_CHARTS=charts/$dir KUBE_NAMESPACE=$ns CT_EXTRA_ARGS="$extra"
        kubectl delete ns $ns || true
    fi
done
