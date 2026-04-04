# The docker image to generate Golang code from Protocol Buffers.
FROM golang:1.25-alpine3.21 AS builder
LABEL intermediate=true

ENV CGO_ENABLED=0

RUN apk update \
    && apk add --no-cache --purge git curl upx protobuf-dev

WORKDIR /build

# Create a throwaway module for installing pinned tools
RUN go mod init tools

# Install protoc plugins
RUN GONOSUMCHECK='*' go install github.com/golang/protobuf/protoc-gen-go@v1.3.1
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-combo@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gofast@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gogo@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gogofast@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gogofaster@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gogoslick@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gogotypes@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/gogo/protobuf/protoc-gen-gostring@v1.0.0
# tag 1.3.5 (no v prefix, so use commit hash)
RUN GONOSUMCHECK='*' go install github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema@f5fcc609186685c113253757aa83eda7ec11dd90
RUN GONOSUMCHECK='*' go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@v1.14.8
RUN GONOSUMCHECK='*' go install github.com/envoyproxy/protoc-gen-validate@v0.1.0
RUN GONOSUMCHECK='*' go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators@v0.3.2
RUN GONOSUMCHECK='*' go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@v1.0.0
RUN GONOSUMCHECK='*' go install github.com/infobloxopen/protoc-gen-preprocess@v0.3.3
RUN GONOSUMCHECK='*' go install github.com/infobloxopen/protoc-gen-gorm@v0.20.3
RUN GONOSUMCHECK='*' go install github.com/infobloxopen/protoc-gen-atlas-query-validate@v0.5.1
RUN GONOSUMCHECK='*' go install github.com/infobloxopen/protoc-gen-atlas-validate@v0.4.2

# Build protoc-gen-swagger from atlas-patch fork
RUN git clone --depth 1 --single-branch -b atlas-patch \
      https://github.com/infobloxopen/grpc-gateway.git /tmp/grpc-gateway && \
    cd /tmp/grpc-gateway/protoc-gen-swagger && \
    go build -o /go/bin/protoc-gen-swagger .

RUN mkdir -p /out/usr/bin && \
    install -c ${GOPATH}/bin/protoc-gen* /out/usr/bin/

# Download modules that contain .proto files needed at runtime
RUN GONOSUMCHECK='*' go mod download \
      github.com/infobloxopen/atlas-app-toolkit@v0.19.6 \
      github.com/infobloxopen/protoc-gen-gorm@v0.20.3 \
      github.com/infobloxopen/protoc-gen-atlas-query-validate@v0.5.1 \
      github.com/infobloxopen/protoc-gen-atlas-validate@v0.4.2 \
      github.com/infobloxopen/protoc-gen-preprocess@v0.3.3 \
      github.com/grpc-ecosystem/grpc-gateway@v1.14.8 \
      github.com/envoyproxy/protoc-gen-validate@v0.1.0 \
      github.com/mwitkow/go-proto-validators@v0.3.2 \
      github.com/gogo/protobuf@v1.0.0 \
      github.com/golang/protobuf@v1.3.1 \
      google.golang.org/genproto@v0.0.0-20200526211855-cb27e3aa2013 2>/dev/null; true

# googleapis (not a Go module — clone directly)
RUN git clone --depth 1 https://github.com/googleapis/googleapis.git \
      /tmp/googleapis

# Copy .proto files from specific module versions into /go/src layout for protoc -I paths
# We copy from exact versioned paths to avoid newer transitive deps overwriting older protos
RUN mkdir -p /out/go/src && MOD=${GOPATH}/pkg/mod && \
    copy_mod_protos() { \
      src="$1"; target="$2"; \
      find "$src" -name "*.proto" | while read f; do \
        rel="${f#$src/}"; \
        mkdir -p "/out/go/src/${target}/$(dirname "$rel")"; \
        cp "$f" "/out/go/src/${target}/$rel"; \
      done; \
    } && \
    copy_mod_protos "$MOD/github.com/infobloxopen/atlas-app-toolkit@v0.19.6" "github.com/infobloxopen/atlas-app-toolkit" && \
    copy_mod_protos "$MOD/github.com/infobloxopen/protoc-gen-gorm@v0.20.3" "github.com/infobloxopen/protoc-gen-gorm" && \
    copy_mod_protos "$MOD/github.com/infobloxopen/protoc-gen-atlas-query-validate@v0.5.1" "github.com/infobloxopen/protoc-gen-atlas-query-validate" && \
    copy_mod_protos "$MOD/github.com/infobloxopen/protoc-gen-atlas-validate@v0.4.2" "github.com/infobloxopen/protoc-gen-atlas-validate" && \
    copy_mod_protos "$MOD/github.com/infobloxopen/protoc-gen-preprocess@v0.3.3" "github.com/infobloxopen/protoc-gen-preprocess" && \
    copy_mod_protos "$MOD/github.com/grpc-ecosystem/grpc-gateway@v1.14.8" "github.com/grpc-ecosystem/grpc-gateway" && \
    copy_mod_protos "$MOD/github.com/envoyproxy/protoc-gen-validate@v0.1.0" "github.com/envoyproxy/protoc-gen-validate" && \
    copy_mod_protos "$MOD/github.com/mwitkow/go-proto-validators@v0.3.2" "github.com/mwitkow/go-proto-validators" && \
    copy_mod_protos "$MOD/github.com/gogo/protobuf@v1.0.0" "github.com/gogo/protobuf" && \
    copy_mod_protos "$MOD/github.com/golang/protobuf@v1.3.1" "github.com/golang/protobuf" && \
    copy_mod_protos "$MOD/google.golang.org/genproto@v0.0.0-20200526211855-cb27e3aa2013" "google.golang.org/genproto" && \
    # Copy protos from the swagger fork (overrides grpc-gateway protos with atlas-patch version)
    copy_mod_protos "/tmp/grpc-gateway" "github.com/grpc-ecosystem/grpc-gateway" && \
    # Copy googleapis protos
    copy_mod_protos "/tmp/googleapis" "github.com/googleapis/googleapis"

RUN upx --lzma /out/usr/bin/protoc-gen-*

FROM alpine:3.21
RUN apk add --no-cache libstdc++ protobuf-dev
COPY --from=builder /out/usr /usr
COPY --from=builder /out/go/src /go/src

WORKDIR /go/src

ENTRYPOINT ["protoc", "-I.", \
    "-Igithub.com/grpc-ecosystem/grpc-gateway/third_party/googleapis", \
    "-Igithub.com/grpc-ecosystem/grpc-gateway", "-Igithub.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options", \
    "-Igithub.com/envoyproxy/protoc-gen-validate/validate", \
    "-Igithub.com/mwitkow/go-proto-validators", \
    "-Igithub.com/googleapis/googleapis", \
    "-Igithub.com/infobloxopen/protoc-gen-gorm", \
    "-Igithub.com/infobloxopen/protoc-gen-atlas-query-validate", \
    "-Igithub.com/infobloxopen/protoc-gen-preprocess", \
    "-Igithub.com/infobloxopen/protoc-gen-atlas-validate" \
]
