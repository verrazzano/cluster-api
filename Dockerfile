# Copyright 2018 The Kubernetes Authors.
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

# Build the manager binary
# Run this with docker build --build-arg builder_image=<golang:x.y.z>
ARG builder_image

# Build architecture
ARG ARCH

# Final production base image
ARG FINAL_IMAGE=ghcr.io/verrazzano/ol8-static:v0.0.1-20231102152128-e7afc807

# Ignore Hadolint rule "Always tag the version of an image explicitly."
# It's an invalid finding since the image is explicitly set in the Makefile.
# https://github.com/hadolint/hadolint/wiki/DL3006
# hadolint ignore=DL3006
FROM ${builder_image} as builder
WORKDIR /workspace

# Run this with docker build --build-arg goproxy=$(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
# Run this with docker build --build-arg package=./controlplane/kubeadm or --build-arg package=./bootstrap/kubeadm
ENV GOPROXY=$goproxy

RUN go env GOPATH
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the sources
COPY ./ ./

## Cache the go build into the Go’s compiler cache folder so we take benefits of compiler caching across docker build calls
RUN go build .

# Build
ARG package=.
ARG ARCH
ARG ldflags

# Do not force rebuild of up-to-date packages (do not use -a) and use the compiler cache folder
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} \
    go build -trimpath -ldflags "${ldflags} -extldflags '-static'" \
    -o manager ${package} \
    && groupadd -r ocne \
    && useradd --no-log-init -r -m -d /ocne -g ocne -u 1000 ocne \
    && mkdir -p /home/ocne \
    && chown -R 1000:ocne /workspace/manager /home/ocne \
    && chmod 500 /workspace/manager

# Production image

FROM $FINAL_IMAGE

# Copy users and groups
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

WORKDIR /

COPY --from=builder --chown=1000:ocne /workspace/manager .
COPY --from=builder --chown=1000:ocne /home/ocne /home/ocne
COPY --from=builder --chown=1000:ocne /ocne /ocne

# Use uid of nonroot user (65532) because kubernetes expects numeric user when applying pod security policies
COPY LICENSE README.md THIRD_PARTY_LICENSES.txt /license/
USER 1000
ENTRYPOINT ["/manager"]
