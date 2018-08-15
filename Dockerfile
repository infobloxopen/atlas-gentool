# The docker image to generate Golang code from Protol Buffer.
FROM golang:1.9.2-alpine as builder
LABEL intermediate=true
MAINTAINER DL NGP-App-Infra-API <ngp-app-infra-api@infoblox.com>
ARG PGG_VERSION=master
ARG AAT_VERSION=master

# Set up mandatory Go environmental variables.
ENV CGO_ENABLED=0

# Install zip tool to unpack the protoc compiler.
RUN apk update \
    && apk add --no-cache --purge unzip curl git build-base automake autoconf libtool ucl-dev zlib-dev

# The versions for the protocol buffers compiler and grpc.
ENV PROTOC_VERSION 3.5.1
ENV GRPC_VERSION=1.8.3

# Download and build of the protobuffer compiler and grpc
# This and compression behavior adapted from github.com/znly/docker-protobuf
RUN mkdir -p /protobuf && \
    curl -L https://github.com/google/protobuf/archive/v${PROTOC_VERSION}.tar.gz | tar xvz --strip-components=1 -C /protobuf
RUN git clone --depth 1 --recursive -b v${GRPC_VERSION} https://github.com/grpc/grpc.git /grpc && \
    rm -rf grpc/third_party/protobuf && \
    ln -s /protobuf /grpc/third_party/protobuf
RUN cd /protobuf && \
    autoreconf -f -i -Wall,no-obsolete && \
    ./configure --prefix=/usr --enable-static=no && \
    make -j2 && make install
RUN cd /grpc && \
    make -j2 plugins
RUN cd /protobuf && \
    make install DESTDIR=/out
RUN cd /grpc && \
    make install-plugins prefix=/out/usr
RUN find /out -name "*.a" -delete -or -name "*.la" -delete


# The version and the binaries checksum for the glide package manager.
ENV GLIDE_VERSION 0.12.3
ENV GLIDE_DOWNLOAD_URL https://github.com/Masterminds/glide/releases/download/v${GLIDE_VERSION}/glide-v${GLIDE_VERSION}-linux-amd64.tar.gz
ENV GLIDE_DOWNLOAD_SHA256 0e2be5e863464610ebc420443ccfab15cdfdf1c4ab63b5eb25d1216900a75109

# Download and install the glide package manager.
RUN curl -fsSL ${GLIDE_DOWNLOAD_URL} -o glide.tar.gz \
    && echo "${GLIDE_DOWNLOAD_SHA256}  glide.tar.gz" | sha256sum -c - \
    && tar -xzf glide.tar.gz --strip-components=1 -C /usr/local/bin \
    && rm -rf glide.tar.gz

# Install as the protoc plugins as build-time dependecies.
COPY glide.yaml.tmpl .

# glide is unable to resolve correctly these deps requiring
# to import all the dependencies in ghodss/yaml
RUN go get github.com/ghodss/yaml

# Compile binaries for the protocol buffer plugins. We need specific
# versions of these tools, this is why we at first step install glide,
# download required versions and then installing them.
RUN sed -e "s/@PGGVersion/$PGG_VERSION/" -e "s/@AATVersion/$AATVersion/" glide.yaml.tmpl > glide.yaml; \
    glide up --skip-test \
    && cp -r vendor/* ${GOPATH}/src/ \
    && go install github.com/golang/protobuf/protoc-gen-go \
    && go install github.com/gogo/protobuf/protoc-gen-combo \
    && go install github.com/gogo/protobuf/protoc-gen-gofast \
    && go install github.com/gogo/protobuf/protoc-gen-gogo \
    && go install github.com/gogo/protobuf/protoc-gen-gogofast \
    && go install github.com/gogo/protobuf/protoc-gen-gogofaster \
    && go install github.com/gogo/protobuf/protoc-gen-gogoslick \
    && go install github.com/gogo/protobuf/protoc-gen-gogotypes \
    && go install github.com/gogo/protobuf/protoc-gen-gostring \
    && go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway \
    && go install github.com/lyft/protoc-gen-validate \
    && go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators \
    && go install github.com/pseudomuto/protoc-gen-doc/cmd/... \
    && go install  \
      -ldflags "-X github.com/infobloxopen/protoc-gen-gorm/plugin.ProtocGenGormVersion=$PGG_VERSION -X github.com/infobloxopen/protoc-gen-gorm/plugin.AtlasAppToolkitVersion=$AAT_VERSION" \
      github.com/infobloxopen/protoc-gen-gorm \
    && go install github.com/infobloxopen/protoc-gen-perm \
    && rm -rf vendor/* ${GOPATH}/pkg/* \
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

RUN git clone --depth 1 --recursive https://github.com/upx/upx.git /upx
RUN cd /upx/src && \
    make -j2 upx.out CHECK_WHITESPACE=
RUN /upx/src/upx.out --lzma -o /usr/bin/upx /upx/src/upx.out

RUN upx --lzma \
        /out/usr/bin/protoc \
        /out/usr/bin/grpc_* \
        /out/usr/bin/protoc-gen-*


FROM alpine:3.6
RUN apk add --no-cache libstdc++
COPY --from=builder /out/usr /usr
COPY --from=builder /out/protos /

WORKDIR /go/src

RUN mkdir -p google/protobuf && \
  for f in any duration empty struct timestamp wrappers; do \
    cp /go/src/github.com/golang/protobuf/ptypes/${f}/${f}.proto /go/src/google/protobuf; \
  done; \
  cp /go/src/github.com/google/protobuf/src/google/protobuf/field_mask.proto /go/src/google/protobuf;

# protoc as an entry point for all plugins with import paths set
ENTRYPOINT ["protoc", "-I.", \
    # required import paths for protoc-gen-grpc-gateway plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway/third_party/googleapis", \
    # required import paths for protoc-gen-swagger plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway", "-Igithub.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options", \
    # required import paths for extensions of protoc-gen-gogo
    "-Igithub.com/gogo/protobuf/protobuf", \
    # required import paths for protoc-gen-validate plugin
    "-Igithub.com/lyft/protoc-gen-validate/validate", \
    # required import paths for go-proto-validators plugin
    "-Igithub.com/mwitkow/go-proto-validators", \
    # googleapis proto files
    "-Igithub.com/googleapis/googleapis", \
    # required import paths for protoc-gen-gorm plugin
    "-Igithub.com/infobloxopen/protoc-gen-gorm", \
    # required import paths for protoc-gen-perm plugin
    "-Igithub.com/infobloxopen/protoc-gen-perm" \
]
