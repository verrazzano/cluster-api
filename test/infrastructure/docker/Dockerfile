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

ARG golang_image

# Build the manager binary
# Run this with docker build --build-arg builder_image=<golang:x.y.z>
ARG builder_image

# Build architecture
ARG ARCH

FROM ${golang_image} as custom_golang_image

# Ignore Hadolint rule "Always tag the version of an image explicitly."
# It's an invalid finding since the image is explicitly set in the Makefile.
# https://github.com/hadolint/hadolint/wiki/DL3006
# hadolint ignore=DL3006
FROM ${builder_image} as builder

# Run this with docker build --build-arg goproxy=$(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

COPY --from=custom_golang_image /usr/lib/golang/ /usr/lib/golang/
RUN ln -s /usr/lib/golang/bin/go /usr/bin/go

RUN dnf install -y oracle-olcne-release-el8 oraclelinux-developer-release-el8 && \
    dnf config-manager --enable ol8_olcne16 ol8_developer && \
    dnf update -y && \
    dnf install -y openssl-devel delve gcc && \
    go version

# Gets additional CAPD dependencies
WORKDIR /tmp

WORKDIR /workspace
COPY go.mod go.mod
COPY go.sum go.sum

# Essentially, change directories into the test go module
WORKDIR /workspace/test
# Copy the Go Modules manifests
COPY test/go.mod go.mod
COPY test/go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# This needs to build with the entire Cluster API context
WORKDIR /workspace
# Copy in cluster-api (which includes the test/infrastructure/docker subdirectory)
COPY . .

# Essentially, change directories into CAPD
WORKDIR /workspace/test/infrastructure/docker

# Build
ARG ARCH

# Build the CAPD manager using the compiler cache folder
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} go build -trimpath -a -o /workspace/manager main.go

# NOTE: CAPD can't use non-root because docker requires access to the docker socket

# Ignore Hadolint rule "Using latest is prone to errors if the image will ever update. Pin the version explicitly to a release tag."
# https://github.com/hadolint/hadolint/wiki/DL3007
# hadolint ignore=DL3007
FROM ghcr.io/oracle/oraclelinux:8-slim
RUN microdnf update \
    && microdnf clean all
WORKDIR /
COPY --from=builder /workspace/manager .

ENTRYPOINT ["/manager"]
