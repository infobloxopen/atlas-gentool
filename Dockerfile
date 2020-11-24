# The docker image to generate Golang code from Protol Buffer.
FROM golang:1.15.5-alpine as builder
LABEL intermediate=true
MAINTAINER DL NGP-App-Infra-API <ngp-app-infra-api@infoblox.com>

ARG AAT_VERSION=master
ARG PGG_VERSION=master
ARG PGAQV_VERSION=master
ARG PGAV_VERSION=master
ARG PGP_VERSION=master

# Set up mandatory Go environmental variables.
ENV CGO_ENABLED=0

RUN apk update \
    && apk add --no-cache --purge git curl upx

# Download and install dep.
ENV INSTALL_DIRECTORY /usr/local/bin
RUN curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

# glide is unable to resolve correctly these deps requiring
# to import all the dependencies in ghodss/yaml
RUN go get github.com/ghodss/yaml

# Compile binaries for the protocol buffer plugins. We need specific
# versions of these tools, this is why we at first step install glide,
# download required versions and then installing them.
RUN sed -e "s/@AATVersion/$AAT_VERSION/" \
        -e "s/@PGGVersion/$PGG_VERSION/" \
        -e "s/@PGAQVVersion/$PGAQV_VERSION/" \
        -e "s/@PGAVVersion/$PGAV_VERSION/" \
        -e "s/@PGPVersion/$PGP_VERSION/" \
        glide.yaml.tmpl > glide.yaml
RUN glide up --skip-test
RUN cp -r vendor/* ${GOPATH}/src/

RUN go install github.com/golang/protobuf/protoc-gen-go
RUN go install github.com/gogo/protobuf/protoc-gen-combo
RUN go install github.com/gogo/protobuf/protoc-gen-gofast
RUN go install github.com/gogo/protobuf/protoc-gen-gogo
RUN go install github.com/gogo/protobuf/protoc-gen-gogofast
RUN go install github.com/gogo/protobuf/protoc-gen-gogofaster
RUN go install github.com/gogo/protobuf/protoc-gen-gogoslick
RUN go install github.com/gogo/protobuf/protoc-gen-gogotypes
RUN go install github.com/gogo/protobuf/protoc-gen-gostring
RUN go get github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema
RUN go install github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema
RUN go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
RUN go install github.com/lyft/protoc-gen-validate
RUN go get github.com/envoyproxy/protoc-gen-validate
RUN go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/...
RUN go install github.com/infobloxopen/protoc-gen-preprocess
RUN go install  \
      -ldflags "-X github.com/infobloxopen/protoc-gen-gorm/plugin.ProtocGenGormVersion=$PGG_VERSION -X github.com/infobloxopen/protoc-gen-gorm/plugin.AtlasAppToolkitVersion=$AAT_VERSION" \
      github.com/infobloxopen/protoc-gen-gorm
# Download all dependencies of protoc-gen-atlas-query-validate
RUN cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-query-validate && dep ensure -vendor-only
RUN go install github.com/infobloxopen/protoc-gen-atlas-query-validate

# Download all dependencies of protoc-gen-atlas-validate
RUN cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-validate && dep ensure -vendor-only
RUN go install github.com/infobloxopen/protoc-gen-atlas-validate

RUN mkdir -p /out/usr/bin

RUN rm -rf vendor/* ${GOPATH}/pkg/* \
    && install -c ${GOPATH}/bin/protoc-gen* /out/usr/bin/

# build protoc-gen-swagger separately with atlas_patch
RUN go get github.com/go-openapi/spec && \
	rm -rf ${GOPATH}/src/github.com/grpc-ecosystem/ \
	&& mkdir -p ${GOPATH}/src/github.com/grpc-ecosystem/ && \
	cd ${GOPATH}/src/github.com/grpc-ecosystem && \
	git clone --single-branch -b atlas-patch https://github.com/infobloxopen/grpc-gateway.git && \
	cd grpc-gateway/protoc-gen-swagger && go build -o /out/usr/bin/protoc-gen-swagger main.go

RUN mkdir -p /out/protos && \
    find ${GOPATH}/src -name "*.proto" -exec cp --parents {} /out/protos \;

RUN upx --lzma \
        /out/usr/bin/protoc-gen-*

FROM alpine:3.12.1
RUN apk add --no-cache libstdc++ protobuf-dev
COPY --from=builder /out/usr /usr
COPY --from=builder /out/protos /

WORKDIR /go/src

# protoc as an entry point for all plugins with import paths set
ENTRYPOINT ["protoc", "-I.", \
    # required import paths for protoc-gen-grpc-gateway plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway/third_party/googleapis", \
    # required import paths for protoc-gen-swagger plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway", "-Igithub.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options", \
    # required import paths for protoc-gen-validate plugin
    "-Igithub.com/lyft/protoc-gen-validate/validate", \
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