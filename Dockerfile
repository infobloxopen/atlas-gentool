# The docker image to generate Golang code from Protol Buffer.
FROM golang:1.16.6-alpine as builder
LABEL intermediate=true
MAINTAINER DL NGP-App-Infra-API <ngp-app-infra-api@infoblox.com>

ARG AAT_VERSION=master
ARG PGG_VERSION=main
ARG PGAQV_VERSION=master
ARG PGAV_VERSION=master
ARG PGP_VERSION=master

# Set up mandatory Go environmental variables.
ENV CGO_ENABLED=0
ENV GO111MODULE=off

RUN apk update \
    && apk add --no-cache --purge git upx

# Use go modules to download application code and dependencies

WORKDIR ${GOPATH}/src/github.com/infobloxopen/atlas-gentool
COPY go.mod .
COPY go.sum .
COPY tools.go .
RUN GO111MODULE=on go mod vendor
RUN cp -r vendor/* ${GOPATH}/src/

# Build protoc tools
WORKDIR ${GOPATH}/src
RUN go install github.com/golang/protobuf/protoc-gen-go
RUN go install github.com/gogo/protobuf/protoc-gen-combo
RUN go install github.com/gogo/protobuf/protoc-gen-gofast
RUN go install github.com/gogo/protobuf/protoc-gen-gogo
RUN go install github.com/gogo/protobuf/protoc-gen-gogofast
RUN go install github.com/gogo/protobuf/protoc-gen-gogofaster
RUN go install github.com/gogo/protobuf/protoc-gen-gogoslick
RUN go install github.com/gogo/protobuf/protoc-gen-gogotypes
RUN go install github.com/gogo/protobuf/protoc-gen-gostring
RUN go install github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema
RUN go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway
RUN go install github.com/envoyproxy/protoc-gen-validate
RUN go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/...
RUN go install github.com/infobloxopen/protoc-gen-preprocess
RUN go install github.com/infobloxopen/protoc-gen-atlas-query-validate
RUN go install github.com/infobloxopen/protoc-gen-atlas-validate

# TODO: this should be installed the same way once it is compatible with updated protobuf
RUN GO111MODULE=on go install  \
      -ldflags "-X github.com/infobloxopen/protoc-gen-gorm/plugin.ProtocGenGormVersion=$PGG_VERSION -X github.com/infobloxopen/protoc-gen-gorm/plugin.AtlasAppToolkitVersion=$AAT_VERSION" \
      github.com/infobloxopen/protoc-gen-gorm@$PGG_VERSION

# Download any projects that have proto-only packages, since go mod ignores those
RUN cd ${GOPATH}/src/github.com/infobloxopen && rm -rf protoc-gen-gorm && git clone https://github.com/infobloxopen/protoc-gen-gorm && cd protoc-gen-gorm && git checkout $PGG_VERSION
RUN cd ${GOPATH}/src/github.com && mkdir googleapis && cd googleapis && git clone https://github.com/googleapis/googleapis

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

FROM alpine:3.14.0
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
    "-Igithub.com/envoyproxy/protoc-gen-validate/validate", \
    # required import paths for go-proto-validators plugin
    "-Igithub.com/mwitkow/go-proto-validators", \
    # googleapis proto files
    "-Igithub.com/googleapis/googleapis", \
    # required import paths for protoc-gen-gorm plugin
    "-Igithub.com/infobloxopen/protoc-gen-gorm", \ # Should add /proto path once updated
    # required import paths for protoc-gen-atlas-query-validate plugin
    "-Igithub.com/infobloxopen/protoc-gen-atlas-query-validate", \
    # required import paths for protoc-gen-preprocess plugin
    "-Igithub.com/infobloxopen/protoc-gen-preprocess", \
    # required import paths for protoc-gen-atlas-validate plugin
    "-Igithub.com/infobloxopen/protoc-gen-atlas-validate" \
]
