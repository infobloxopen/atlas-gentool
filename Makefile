# Utility docker image to generate Go files from .proto definition.
# https://github.com/infobloxcto/atlas-gentool
IMAGE_NAME := infoblox/atlas-gentool:latest

.PHONY: all
all: latest

# Create the Docker image with the latest tag.
.PHONY: latest
latest:
	docker build -f Dockerfile -t $(IMAGE_NAME) .

.PHONY: clean
clean:
	docker rmi -f $(IMAGE_NAME)

