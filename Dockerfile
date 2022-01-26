# The docker image to generate Golang code from Protol Buffer.
FROM golang:1.17-alpine as builder
LABEL intermediate=true
MAINTAINER DL NGP-App-Infra-API <ngp-app-infra-api@infoblox.com>

ARG AAT_VERSION=master
ARG PGG_VERSION=main
ARG PGAQV_VERSION=master
ARG PGAV_VERSION=master
ARG PGP_VERSION=master

# Set up mandatory Go environmental variables.
ENV CGO_ENABLED=0

# Use go modules to download application code and dependencies
WORKDIR ${GOPATH}/src/github.com/infobloxopen/atlas-gentool
COPY go.mod .
COPY go.sum .
COPY tools.go .
COPY . ${GOPATH}/src/github.com/infobloxopen/atlas-gentool/

# Copy to /go/src so the protos will be available
RUN cp -r ${GOPATH}/src/github.com/infobloxopen/atlas-gentool/vendor/* ${GOPATH}/src/

RUN apk update \
    && apk add --no-cache --purge git curl upx

# The version and the binaries checksum for the glide package manager.
ENV GLIDE_VERSION 0.12.3
ENV GLIDE_DOWNLOAD_URL https://github.com/Masterminds/glide/releases/download/v${GLIDE_VERSION}/glide-v${GLIDE_VERSION}-linux-amd64.tar.gz
ENV GLIDE_DOWNLOAD_SHA256 0e2be5e863464610ebc420443ccfab15cdfdf1c4ab63b5eb25d1216900a75109

# Download and install the glide package manager.
RUN curl -fsSL ${GLIDE_DOWNLOAD_URL} -o glide.tar.gz \
    && echo "${GLIDE_DOWNLOAD_SHA256}  glide.tar.gz" | sha256sum -c - \
    && tar -xzf glide.tar.gz --strip-components=1 -C /usr/local/bin \
    && rm -rf glide.tar.gz

# Download and install dep.
ENV INSTALL_DIRECTORY /usr/local/bin
RUN curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

# Install as the protoc plugins as build-time dependecies.
COPY glide.yaml.tmpl .

# glide is unable to resolve correctly these deps requiring
# to import all the dependencies in ghodss/yaml
RUN go get github.com/ghodss/yaml

# updated to use go.mod vendoring instead of glide (consistent with later releases in atlas-gentool)
#
# Compile binaries for the protocol buffer plugins. We need specific
# versions of these tools, this is why we at first step install glide,
# download required versions and then installing them.
#RUN sed -e "s/@AATVersion/$AAT_VERSION/" \
#        -e "s/@PGGVersion/$PGG_VERSION/" \
#        -e "s/@PGAQVVersion/$PGAQV_VERSION/" \
#        -e "s/@PGAVVersion/$PGAV_VERSION/" \
#        -e "s/@PGPVersion/$PGP_VERSION/" \
#        glide.yaml.tmpl > glide.yaml
# RUN glide up --skip-test
# RUN cp -r vendor/* ${GOPATH}/src/

RUN go install github.com/golang/protobuf/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
RUN go install github.com/gogo/protobuf/protoc-gen-combo@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gofast@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gogo@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gogofast@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gogofaster@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gogoslick@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gogotypes@latest
RUN go install github.com/gogo/protobuf/protoc-gen-gostring@latest
RUN go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@latest
RUN go install github.com/envoyproxy/protoc-gen-validate@latest
RUN go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators@latest
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/...@latest
RUN go install github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema

# infoblox plugins
RUN go install github.com/infobloxopen/protoc-gen-preprocess@${PGP_VERSION}

RUN go install  \
      -ldflags "-X github.com/infobloxopen/protoc-gen-gorm/plugin.ProtocGenGormVersion=$PGG_VERSION -X github.com/infobloxopen/protoc-gen-gorm/plugin.AtlasAppToolkitVersion=$AAT_VERSION" \
      github.com/infobloxopen/protoc-gen-gorm@${PGG_VERSION}
# Download all dependencies of protoc-gen-atlas-query-validate
# RUN cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-query-validate && dep ensure -vendor-only
RUN go install github.com/infobloxopen/protoc-gen-atlas-query-validate@${PGAQV_VERSION}

# Download all dependencies of protoc-gen-atlas-validate
# RUN cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-validate && dep ensure -vendor-only
RUN go install github.com/infobloxopen/protoc-gen-atlas-validate@${PGAV_VERSION}

RUN mkdir -p /out/usr/bin

RUN rm -rf vendor/* ${GOPATH}/pkg/* \
    && install -c ${GOPATH}/bin/protoc-gen* /out/usr/bin/

# build protoc-gen-swagger separately with atlas_patch
RUN go get github.com/go-openapi/spec && \
	rm -rf ${GOPATH}/src/github.com/grpc-ecosystem/ && \
    mkdir -p ${GOPATH}/src/github.com/grpc-ecosystem/ && \
	cd ${GOPATH}/src/github.com/grpc-ecosystem && \
	    git clone --single-branch -b atlas-patch https://github.com/infobloxopen/grpc-gateway.git && \
    cd grpc-gateway/protoc-gen-grpc-gateway && \
        go build -o /out/usr/bin/protoc-gen-grpc-gateway main.go && \
	cd ../protoc-gen-swagger && \
        go build -o /out/usr/bin/protoc-gen-swagger main.go

# Download any projects that have proto-only packages, since go mod ignores those
RUN cd ${GOPATH}/src/github.com/infobloxopen && \
        rm -rf protoc-gen-gorm && \
        git clone https://github.com/infobloxopen/protoc-gen-gorm && \
        cd protoc-gen-gorm && \
        git checkout $PGG_VERSION

RUN cd ${GOPATH}/src/github.com && \
    mkdir -p googleapis/googleapis && \
    cd googleapis/googleapis && \
    git init && \
    git remote add origin https://github.com/googleapis/googleapis && \
    git fetch && \
    git checkout origin/master -- *.proto

RUN mkdir -p /out/protos && \
    find ${GOPATH}/src -name "*.proto" -exec cp --parents {} /out/protos \;

RUN find /out/protos -type f

RUN upx --lzma \
        /out/usr/bin/protoc-gen-*

FROM alpine:3.8
RUN apk add --no-cache \
        libstdc++ \
        protobuf-dev \
        bash
COPY --from=builder /out/usr /usr
COPY --from=builder /out/protos /

WORKDIR /go/src

# protoc as an entry point for all plugins with import paths set
ENTRYPOINT ["protoc", "-I.", \
    # required import paths for protoc-gen-grpc-gateway plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway/third_party/googleapis", \
    # required import paths for protoc-gen-swagger plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway", \
    "-Igithub.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options", \
    # required import paths for protoc-gen-validate plugin
    "-Igithub.com/envoyproxy/protoc-gen-validate", \
    # required import paths for go-proto-validators plugin
    "-Igithub.com/mwitkow/go-proto-validators", \
    # googleapis proto files
    "-Igithub.com/googleapis/googleapis", \
    # required import paths for protoc-gen-gorm plugin
    "-Igithub.com/infobloxopen/protoc-gen-gorm", \
    # required import paths for protoc-gen-atlas-query-validate plugin
    "-Igithub.com/infobloxopen/protoc-gen-atlas-query-validate", \
    # required import paths for protoc-gen-preprocess plugin
    "-Igithub.com/infobloxopen/protoc-gen-preprocess", \
    # required import paths for protoc-gen-atlas-validate plugin
    "-Igithub.com/infobloxopen/protoc-gen-atlas-validate" \
]