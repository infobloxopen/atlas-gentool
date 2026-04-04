# The docker image to generate Golang code from Protocol Buffers.
FROM golang:1.21-alpine3.19 AS builder
LABEL intermediate=true

ENV CGO_ENABLED=0
ENV GOPATH=/go

RUN apk update \
    && apk add --no-cache --purge git curl upx

# Clone all dependencies into GOPATH/src (replicating the old glide layout)
# This ensures proto files end up in the right place for protoc -I paths.
WORKDIR ${GOPATH}/src

# Standard proto / gogo
RUN git clone --depth 1 --branch v1.3.1  https://github.com/golang/protobuf.git           github.com/golang/protobuf && \
    git clone --depth 1 --branch v1.0.0  https://github.com/gogo/protobuf.git              github.com/gogo/protobuf && \
    git clone --depth 1                   https://github.com/google/protobuf.git             github.com/google/protobuf

# grpc-gateway (upstream for protoc-gen-grpc-gateway)
RUN git clone --depth 1 --branch v1.14.8 https://github.com/grpc-ecosystem/grpc-gateway.git github.com/grpc-ecosystem/grpc-gateway

# googleapis
RUN git clone --depth 1 --branch master  https://github.com/googleapis/googleapis.git       github.com/googleapis/googleapis

# Validators
RUN git clone --depth 1 --branch v0.1.0  https://github.com/envoyproxy/protoc-gen-validate.git github.com/envoyproxy/protoc-gen-validate && \
    git clone --depth 1                   https://github.com/mwitkow/go-proto-validators.git    github.com/mwitkow/go-proto-validators

# Documentation generator
RUN git clone --depth 1 --branch v1.0.0  https://github.com/pseudomuto/protoc-gen-doc.git  github.com/pseudomuto/protoc-gen-doc

# JSON schema generator
RUN git clone --depth 1                   https://github.com/chrusty/protoc-gen-jsonschema.git github.com/chrusty/protoc-gen-jsonschema

# Infoblox plugins
RUN git clone --depth 1 --branch v0.20.3 https://github.com/infobloxopen/protoc-gen-gorm.git                    github.com/infobloxopen/protoc-gen-gorm && \
    git clone --depth 1 --branch v0.19.6 https://github.com/infobloxopen/atlas-app-toolkit.git                  github.com/infobloxopen/atlas-app-toolkit && \
    git clone --depth 1 --branch v0.5.1  https://github.com/infobloxopen/protoc-gen-atlas-query-validate.git     github.com/infobloxopen/protoc-gen-atlas-query-validate && \
    git clone --depth 1 --branch v0.4.1  https://github.com/infobloxopen/protoc-gen-atlas-validate.git           github.com/infobloxopen/protoc-gen-atlas-validate && \
    git clone --depth 1 --branch v0.3.3  https://github.com/infobloxopen/protoc-gen-preprocess.git               github.com/infobloxopen/protoc-gen-preprocess

# gorm / inflection (runtime deps for protoc-gen-gorm)
RUN git clone --depth 1 --branch v1.9.1  https://github.com/jinzhu/gorm.git      github.com/jinzhu/gorm && \
    git clone --depth 1                   https://github.com/jinzhu/inflection.git github.com/jinzhu/inflection

# Misc deps needed by the above
RUN git clone --depth 1 https://github.com/ghodss/yaml.git         github.com/ghodss/yaml && \
    git clone --depth 1 https://github.com/go-openapi/spec.git     github.com/go-openapi/spec && \
    git clone --depth 1 https://github.com/golang/glog.git         github.com/golang/glog

# Build all protoc plugins in GOPATH mode
ENV GO111MODULE=off

RUN go install github.com/golang/protobuf/protoc-gen-go && \
    go install github.com/gogo/protobuf/protoc-gen-combo && \
    go install github.com/gogo/protobuf/protoc-gen-gofast && \
    go install github.com/gogo/protobuf/protoc-gen-gogo && \
    go install github.com/gogo/protobuf/protoc-gen-gogofast && \
    go install github.com/gogo/protobuf/protoc-gen-gogofaster && \
    go install github.com/gogo/protobuf/protoc-gen-gogoslick && \
    go install github.com/gogo/protobuf/protoc-gen-gogotypes && \
    go install github.com/gogo/protobuf/protoc-gen-gostring && \
    go install github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema && \
    go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && \
    go install github.com/envoyproxy/protoc-gen-validate && \
    go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators && \
    go install github.com/pseudomuto/protoc-gen-doc/cmd/... && \
    go install github.com/infobloxopen/protoc-gen-preprocess && \
    go install github.com/infobloxopen/protoc-gen-gorm

# These two use dep for their own deps
RUN cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-query-validate && \
    go install . && \
    cd ${GOPATH}/src/github.com/infobloxopen/protoc-gen-atlas-validate && \
    go install .

# Build protoc-gen-swagger with atlas_patch fork
RUN rm -rf ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway && \
    git clone --single-branch -b atlas-patch https://github.com/infobloxopen/grpc-gateway.git \
      ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway && \
    cd ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger && \
    go build -o ${GOPATH}/bin/protoc-gen-swagger .

RUN mkdir -p /out/usr/bin && \
    install -c ${GOPATH}/bin/protoc-gen* /out/usr/bin/

# Collect proto files
RUN mkdir -p /out/go/src && \
    find ${GOPATH}/src -name "*.proto" -exec cp --parents {} /out/ \;

RUN upx --lzma /out/usr/bin/protoc-gen-*

FROM alpine:3.19
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
