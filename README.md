# Docker image to generate Go source code from Protocol Buffer schemes

This repository provides the Docker image used to generate the Go source code from Protocol Buffer schemes.

## Build

Build of the Docker image requires [docker](https://docs.docker.com/engine/installation/)
engine and ```make``` utility as pre-requisites. As the requirements are satisfied, use the
following command to compile the ```latest``` version of the Docker image:
```sh
make latest
```

## Usage

To generate the Go source code using the provided tool, you could start with the following command,
where

- `project` variable defines the Go project
- `plugin` variable defines protoc plugin (go, grpc-gateway, validate, swagger, etc.)
- `plugin_args` variable defines arguments to be passed to the specified plugin
- `{schema}` variable defines your Protocol Buffer schema

**NOTE** It is supposed that your proto schema has proper `option go_package` set.
E.g: `option go_package = "github.com/{your_repo}/{your_app}"`


```sh
docker run --rm -v $(pwd):/go/src/${project} \
    infoblox/atlas-gentool:latest --{plugin}_out={plugin_args} ${project}/{schema}.proto
```

## Plugins

- protoc-gen-go
- protoc-gen-combo
- protoc-gen-gofast
- protoc-gen-gogo
- protoc-gen-gogofast
- protoc-gen-gogofaster
- protoc-gen-gogoslick
- protoc-gen-gogotypes
- protoc-gen-gostring
- protoc-gen-swagger (**atlas-patch**)
- protoc-gen-grpc-gateway
- protoc-gen-validate
- protoc-gen-govalidators
- protoc-gen-doc
- protoc-gen-gorm (**Infoblox Open**)
- protoc-gen-atlas-query-perm (**Infoblox Open**)
- protoc-gen-atlas-validate (**Infoblox Open**)

## protoc-gen-swagger patch

atlas-patch is build on top of original protoc-gen-swagger and is intended to
conform [atlas-app-toolkit REST API Sepcification](https://github.com/infobloxopen/atlas-app-toolkit#rest-api-syntax-specification).
A full list of modifications can be found [here](https://github.com/infobloxopen/grpc-gateway/tree/atlas-patch/protoc-gen-swagger)
