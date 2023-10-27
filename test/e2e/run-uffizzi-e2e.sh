#!/bin/bash

# Copyright 2019 The Kubernetes Authors.
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

set -o errexit
set -o nounset
set -o pipefail

cleanup() {
  uffizzi cluster delete "${UFFIZZI_CLUSTER_NAME}"
}

DEBUG=${DEBUG:=false}

if [ "${DEBUG}" = "true" ]; then
  set -x
else
  trap cleanup EXIT
fi

IS_CHROOT="${IS_CHROOT:-false}"
ENABLE_VALIDATIONS="${ENABLE_VALIDATIONS:-false}"
export UFFIZZI_CLUSTER_NAME=${UFFIZZI_CLUSTER_NAME:-ingress-nginx-dev}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Use 1.0.0-dev to make sure we use the latest configuration in the helm template
export TAG=1.0.0-dev #TODO: more unique
export ARCH=${ARCH:-amd64}
export REGISTRY=registry.uffizzi.com
NGINX_BASE_IMAGE=$(cat "$DIR"/../../NGINX_BASE)
export NGINX_BASE_IMAGE=$NGINX_BASE_IMAGE
export E2E_TEST_IMAGE="${E2E_TEST_IMAGE:-registry.uffizzi.com/nginx-ingress-controller:e2e}"
export DOCKER_CLI_EXPERIMENTAL=enabled
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/uffizzi-config-$UFFIZZI_CLUSTER_NAME}"
SKIP_INGRESS_IMAGE_CREATION="${SKIP_INGRESS_IMAGE_CREATION:-false}"
SKIP_E2E_IMAGE_CREATION="${SKIP_E2E_IMAGE_CREATION:=false}"
SKIP_CLUSTER_CREATION="${SKIP_CLUSTER_CREATION:-false}"

if ! command -v uffizzi version &> /dev/null; then
  echo "uffizzi CLI is not installed. Visit the official site https://docs.uffizzi.com/install/"
  exit 1
fi

echo "Running e2e with nginx base image ${NGINX_BASE_IMAGE}"

if [ "${SKIP_CLUSTER_CREATION}" = "false" ]; then
  echo "[dev-env] creating Kubernetes cluster with Uffizzi"

  export K8S_VERSION=${K8S_VERSION:-v1.26.3@sha256:61b92f38dff6ccc29969e7aa154d34e38b89443af1a2c14e6cfbd2df6419c66f}

  # delete the cluster if it exists
  if uffizzi cluster list | grep "${UFFIZZI_CLUSTER_NAME}"; then
    uffizzi cluster delete "${UFFIZZI_CLUSTER_NAME}"
  fi

  uffizzi cluster create \
    --name "${UFFIZZI_CLUSTER_NAME}" \
    --kubeconfig="${KUBECONFIG}" \
    --update-current-context

  echo "Kubernetes cluster:"
  kubectl get nodes -o wide
fi

if [ "${SKIP_INGRESS_IMAGE_CREATION}" = "false" ]; then
  echo "[dev-env] building image"
  if [ "${IS_CHROOT}" = "true" ]; then
    make -C "${DIR}"/../../ clean-image build image-chroot
    docker tag ${REGISTRY}/controller-chroot:${TAG} ${REGISTRY}/controller:${TAG}
  else
    make -C "${DIR}"/../../ clean-image build image
  fi

  docker push ${REGISTRY}/controller:${TAG}
  echo "[dev-env] .. done building controller images"
fi

if [ "${SKIP_E2E_IMAGE_CREATION}" = "false" ]; then
  if ! command -v ginkgo &> /dev/null; then
    go install github.com/onsi/ginkgo/v2/ginkgo@v2.9.5
  fi

  echo "[dev-env] .. done building controller images"
  echo "[dev-env] now building e2e-image.."
  make -C "${DIR}"/../e2e-image image
  echo "[dev-env] ..done building e2e-image"

  #docker tag nginx-ingress-controller:e2e "${E2E_TEST_IMAGE}"
  docker push "${E2E_TEST_IMAGE}"
fi

# Preload images used in e2e tests
echo "[dev-env] copying docker images to registry..."

#docker push "${REGISTRY}"/controller:"${TAG}"
echo "[dev-env] running e2e tests..."
make -C "${DIR}"/../../ e2e-test
