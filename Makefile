# Utility docker image to generate Go files from .proto definition.
# https://github.com/infobloxopen/atlas-gentool
IMAGE_NAME := infoblox/atlas-gentool

GO_PATH              	:= /go
SRCROOT_ON_HOST      	:= $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
SRCROOT_IN_CONTAINER  := $(GO_PATH)/src/github.com/infobloxopen/atlas-gentool
IMAGE_VERSION	        ?= $(shell git tag --points-at HEAD | sort -n -r | head -1)

get_version = sed -n 's/^$(1)=//p' plugin.version

AATVersion   ?= $(shell $(call get_version,atlas-app-toolkit))
PGGVersion   ?= $(shell $(call get_version,protoc-gen-gorm))
PGAQVVersion ?= $(shell $(call get_version,protoc-gen-atlas-query-validate))
PGAVVersion  ?= $(shell $(call get_version,protoc-gen-atlas-validate))
PGPVersion   ?= $(shell $(call get_version,protoc-gen-preprocess))

.PHONY: all
all: latest

# Create the Docker image with the latest tag.
.PHONY: latest
latest:
	docker build -f Dockerfile -t $(IMAGE_NAME):latest .

.PHONY: versioned
versioned:
	docker build -f Dockerfile \
	 --build-arg AAT_VERSION=$(AATVersion) \
	 --build-arg PGG_VERSION=$(PGGVersion) \
	 --build-arg PGAQV_VERSION=$(PGAQVVersion) \
	 --build-arg PGAV_VERSION=$(PGAVVersion) \
	 --build-arg PGP_VERSION=$(PGPVersion) \
	 -t $(IMAGE_NAME):$(IMAGE_VERSION) .

.PHONY: clean
clean:
	docker rmi -f $(IMAGE_NAME)
	docker rmi `docker images --filter "label=intermediate=true" -q`

.PHONY: test test-gen test-check test-clean
test: test-gen test-check test-clean

test-gen:
	docker run --rm -v $(SRCROOT_ON_HOST):$(SRCROOT_IN_CONTAINER) \
	 infoblox/atlas-gentool:latest \
	--go_out=plugins=grpc:. \
	--grpc-gateway_out=logtostderr=true:. \
	--validate_out="lang=go:." \
	--gorm_out=. \
	--atlas-query-validate_out=. \
	--atlas-validate_out=. \
	--preprocess_out=. \
	--swagger_out=:. github.com/infobloxopen/atlas-gentool/testdata/test.proto

test-check:
	test -e testdata/test.pb.go
	test -e testdata/test.pb.gw.go
	test -e testdata/test.pb.gorm.go
	test -e testdata/test.pb.atlas.query.validate.go
	test -e testdata/test.pb.atlas.validate.go
	test -e testdata/test.pb.validate.go
	test -e testdata/test.pb.preprocess.go
	test -e testdata/test.swagger.json

test-clean:
	rm -f testdata/*.go
	rm -f testdata/*.json

.PHONY: push-latest push-versioned

push-latest:
	docker push $(IMAGE_NAME):latest

push-versioned:
	docker push $(IMAGE_NAME):$(IMAGE_VERSION)

.PHONY: version
version:
	@echo $(IMAGE_VERSION)
