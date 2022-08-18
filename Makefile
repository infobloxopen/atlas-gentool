# Utility docker image to generate Go files from .proto definition.
# https://github.com/infobloxopen/atlas-gentool
IMAGE_NAME := infoblox/atlas-gentool

GO_PATH                 := /go
SRCROOT_ON_HOST         := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
SRCROOT_IN_CONTAINER    := $(GO_PATH)/src/github.com/infobloxopen/atlas-gentool
IMAGE_VERSION           ?= $(shell git describe --tags)

.PHONY: all
all: docker-build

# Create the Docker image locally
.PHONY: docker-build
docker-build:
	docker build -f Dockerfile \
	 -t $(IMAGE_NAME):$(IMAGE_VERSION) .
	docker tag $(IMAGE_NAME):$(IMAGE_VERSION) $(IMAGE_NAME):latest

.PHONY: clean
clean:
	docker rmi -f $(IMAGE_NAME)
	docker rmi `docker images --filter "label=intermediate=true" -q`

.PHONY: test test-gen test-check test-clean
test: test-gen test-check test-clean

test-gen:
	docker run --rm -v $(SRCROOT_ON_HOST):$(SRCROOT_IN_CONTAINER) \
	 infoblox/atlas-gentool:latest \
	--go_out=. \
	--go-grpc_out=. \
	--grpc-gateway_out=logtostderr=true:. \
	--validate_out="lang=go:." \
	--gorm_out=. \
	--atlas-query-validate_out=. \
	--atlas-validate_out=. \
	--preprocess_out=. \
	--doc_out=. --doc_opt=markdown,test.md,source_relative \
	--openapiv2_out=. github.com/infobloxopen/atlas-gentool/testdata/test.proto

test-check:
	test -e testdata/test.pb.go
	test -e testdata/test_grpc.pb.go
	test -e testdata/test.pb.gw.go
	test -e testdata/test.pb.gorm.go
	test -e testdata/test.pb.atlas.query.validate.go
	test -e testdata/test.pb.atlas.validate.go
	test -e testdata/test.pb.validate.go
	test -e testdata/test.pb.preprocess.go
	test -e testdata/test.swagger.json
	test -e testdata/test.md
	go mod vendor && go test ./testdata

test-clean:
	rm -f testdata/*.go
	rm -f testdata/*.json
	rm -f testdata/*.md

# push with multi-arch builds
.PHONY: push-latest push-versioned
PLATFORMS ?= linux/amd64,linux/arm64,linux/arm/v7

push-latest:
	docker buildx build -f Dockerfile --push \
	 --platform $(PLATFORMS) \
	 -t $(IMAGE_NAME):latest .

push-versioned:
	docker buildx build -f Dockerfile --push \
	 --platform $(PLATFORMS) \
	 -t $(IMAGE_NAME):$(IMAGE_VERSION) .

.PHONY: version
version:
	@echo $(IMAGE_VERSION)
