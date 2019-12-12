#!/bin/bash

set -e

IMAGE='pure/nvidia-device-plugin'

for d in $(find . -mindepth 1 -maxdepth 1 -type d); do
    TAG=$(basename "$d")
    docker build -t ${IMAGE}:${TAG} $d && \
    docker push ${IMAGE}:${TAG}
done

# get latest tags
source latest.tags

# tag latest images for Tesla
docker tag  ${IMAGE}:${TESLA} ${IMAGE}:tesla
docker push ${IMAGE}:tesla
