# The docker image to generate Golang code from Protol Buffer.
FROM golang:1.17.5-alpine3.14 as builder
LABEL intermediate=true
MAINTAINER DL NGP-App-Infra-API <ngp-app-infra-api@infoblox.com>

ARG AAT_VERSION=master
ARG PGG_VERSION=main

# Set up mandatory Go environmental variables.
ENV CGO_ENABLED=0

RUN apk update \
    && apk add --no-cache --purge git upx dep

# Use go modules to download application code and dependencies
WORKDIR ${GOPATH}/src/github.com/infobloxopen/atlas-gentool
COPY go.mod .
COPY go.sum .
COPY tools.go .
RUN go mod vendor

# Copy to /go/src so the protos will be available
RUN cp -r vendor/* ${GOPATH}/src/

# Build protoc tools
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
RUN go install github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema
RUN go install github.com/envoyproxy/protoc-gen-validate
RUN go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc
RUN go install github.com/infobloxopen/protoc-gen-preprocess
RUN cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-query-validate && dep ensure && GO111MODULE=off go install .
RUN go install github.com/infobloxopen/protoc-gen-atlas-validate

# TODO: this should be installed the same way once it is compatible with updated protobuf
RUN go install  \
      -ldflags "-X github.com/infobloxopen/protoc-gen-gorm/plugin.ProtocGenGormVersion=$PGG_VERSION -X github.com/infobloxopen/protoc-gen-gorm/plugin.AtlasAppToolkitVersion=$AAT_VERSION" \
      github.com/infobloxopen/protoc-gen-gorm@$PGG_VERSION

# Download any projects that have proto-only packages, since go mod ignores those
RUN cd ${GOPATH}/src/github.com/infobloxopen && rm -rf protoc-gen-gorm && \
    git clone https://github.com/infobloxopen/protoc-gen-gorm && cd protoc-gen-gorm && git checkout $PGG_VERSION
RUN cd ${GOPATH}/src/github.com && mkdir -p googleapis/googleapis && cd googleapis/googleapis && \
    git init && git remote add origin https://github.com/googleapis/googleapis && git fetch && \
    git checkout origin/master -- *.proto

RUN mkdir -p /out/usr/bin

RUN rm -rf vendor/* ${GOPATH}/pkg/* \
    && install -c ${GOPATH}/bin/protoc-gen* /out/usr/bin/

# Build protoc-gen-grpc-gateway and protoc-gen-openapiv2 from infobloxopen/grpc-gateway where it is kept consistent
# with infoblox products (protoc-gen-openapiv2 atlas_patch, etc.).
RUN cd ${GOPATH}/src/github.com/infobloxopen && git clone --single-branch --branch v2.0.2 https://github.com/infobloxopen/grpc-gateway.git && \
    cd ${GOPATH}/src/github.com/infobloxopen/grpc-gateway/protoc-gen-grpc-gateway && go build -o /out/usr/bin/protoc-gen-grpc-gateway main.go && \
    cd ${GOPATH}/src/github.com/infobloxopen/grpc-gateway/protoc-gen-openapiv2 && go build -o /out/usr/bin/protoc-gen-openapiv2 main.go

RUN mkdir -p /out/protos && \
    find ${GOPATH}/src -name "*.proto" -exec cp --parents {} /out/protos \;

RUN upx --lzma \
        /out/usr/bin/protoc-gen-*

FROM alpine:3.14.2
RUN apk add --no-cache libstdc++ protobuf-dev
COPY --from=builder /out/usr /usr
COPY --from=builder /out/protos /

WORKDIR /go/src

# protoc as an entry point for all plugins with import paths set
ENTRYPOINT ["protoc", "-I.", \
    # required import paths for protoc-gen-openapiv2 plugin
    "-Igithub.com/infobloxopen/grpc-gateway", \
    "-Igithub.com/infobloxopen/grpc-gateway/protoc-gen-openapiv2/options", \
    # required import paths for protoc-gen-validate plugin
    "-Igithub.com/envoyproxy/protoc-gen-validate/validate", \
    # required import paths for go-proto-validators plugin
    "-Igithub.com/mwitkow/go-proto-validators", \
    # googleapis proto files
    "-Igithub.com/googleapis/googleapis", \
    # required import paths for protoc-gen-gorm plugin, Should add /proto path once updated
    "-Igithub.com/infobloxopen/protoc-gen-gorm", \
    # required import paths for protoc-gen-atlas-query-validate plugin
    "-Igithub.com/infobloxopen/protoc-gen-atlas-query-validate", \
    # required import paths for protoc-gen-preprocess plugin
    "-Igithub.com/infobloxopen/protoc-gen-preprocess", \
    # required import paths for protoc-gen-atlas-validate plugin
    "-Igithub.com/infobloxopen/protoc-gen-atlas-validate" \
]
