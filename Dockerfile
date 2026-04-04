# Start from the original v21.8 image and only replace protoc-gen-gorm
FROM golang:1.17.0-alpine3.14 AS builder

ENV CGO_ENABLED=0
ENV GO111MODULE=off

RUN apk add --no-cache git

# Clone protoc-gen-gorm v0.20.4 and its deps, then build
RUN git clone --depth 1 --branch v0.20.4 https://github.com/infobloxopen/protoc-gen-gorm.git \
      /go/src/github.com/infobloxopen/protoc-gen-gorm && \
    git clone --depth 1 --branch v0.19.6 https://github.com/infobloxopen/atlas-app-toolkit.git \
      /go/src/github.com/infobloxopen/atlas-app-toolkit && \
    git clone --depth 1 --branch v1.0.0 https://github.com/gogo/protobuf.git \
      /go/src/github.com/gogo/protobuf && \
    git clone --depth 1 --branch v1.3.1 https://github.com/golang/protobuf.git \
      /go/src/github.com/golang/protobuf && \
    git clone --depth 1 --branch v1.9.1 https://github.com/jinzhu/gorm.git \
      /go/src/github.com/jinzhu/gorm && \
    git clone --depth 1 https://github.com/jinzhu/inflection.git \
      /go/src/github.com/jinzhu/inflection && \
    git clone --depth 1 https://github.com/lib/pq.git \
      /go/src/github.com/lib/pq && \
    git clone --depth 1 https://github.com/grpc-ecosystem/grpc-gateway.git \
      /go/src/github.com/grpc-ecosystem/grpc-gateway && \
    git clone --depth 1 https://github.com/golang/glog.git \
      /go/src/github.com/golang/glog && \
    git clone --depth 1 --branch v0.22.3 https://github.com/census-instrumentation/opencensus-go.git \
      /go/src/go.opencensus.io && \
    git clone --depth 1 https://github.com/golang/groupcache.git \
      /go/src/github.com/golang/groupcache && \
    git clone --depth 1 https://github.com/hashicorp/golang-lru.git \
      /go/src/github.com/hashicorp/golang-lru && \
    git clone --depth 1 --branch v0.15.0 https://github.com/golang/sys.git \
      /go/src/golang.org/x/sys && \
    git clone --depth 1 https://github.com/golang/net.git \
      /go/src/golang.org/x/net && \
    git clone --depth 1 https://github.com/golang/text.git \
      /go/src/golang.org/x/text && \
    git clone --depth 1 https://github.com/grpc/grpc-go.git \
      /go/src/google.golang.org/grpc && \
    git clone --depth 1 https://github.com/googleapis/go-genproto.git \
      /go/src/google.golang.org/genproto

RUN go install github.com/infobloxopen/protoc-gen-gorm

# Copy just the new binary into the original image
FROM infoblox/atlas-gentool:v21.8
COPY --from=builder /go/bin/protoc-gen-gorm /usr/bin/protoc-gen-gorm
