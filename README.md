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
- `plugin` variable defines protoc plugin (go, grpc-gateway, protoc-gen-openapiv2, validate, etc.)
- `plugin_opt` variable defines options to be passed to the specified plugin
- `{schema}` variable defines your Protocol Buffer schema

**NOTE** It is supposed that your proto schema has proper `option go_package` set.
E.g: `option go_package = "github.com/{your_repo}/{your_app}"`


```sh
docker run --rm -v $(pwd):/go/src/${project} \
    infoblox/atlas-gentool:latest --{plugin}_out={plugin_opt} ${project}/{schema}.proto
```

## Plugins

- protoc-gen-go
- protoc-gen-go-grpc
- protoc-gen-combo
- protoc-gen-gofast
- protoc-gen-gogo
- protoc-gen-gogofast
- protoc-gen-gogofaster
- protoc-gen-gogoslick
- protoc-gen-gogotypes
- protoc-gen-gostring
- protoc-gen-openapiv2 (**Infoblox Open with atlas-patch**)
- protoc-gen-grpc-gateway (**Infoblox Open**)
- protoc-gen-doc
- protoc-gen-validate
- protoc-gen-govalidators
- protoc-gen-gorm (**Infoblox Open**)
- protoc-gen-atlas-query-validate (**Infoblox Open**)
- protoc-gen-atlas-validate (**Infoblox Open**)
- protoc-gen-preprocess (**Infoblox Open**)
- protoc-gen-jsonschema

## protoc-gen-openapiv2 patch

atlas-patch is build on top of original protoc-gen-openapiv2 and is intended to
conform [atlas-app-toolkit REST API Sepcification](https://github.com/infobloxopen/atlas-app-toolkit#rest-api-syntax-specification).
A full list of modifications can be found [here](https://github.com/infobloxopen/grpc-gateway/tree/v2/protoc-gen-openapiv2).

Note that `infobloxopen/grpc-gateway` has restrictions in using it as a self-standing go module. It inherits go module path from the original [grpc-ecosystem/grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) repository. Use either git tools or NOT module-aware (GOPATH based) go mode to fetch it as a dependency.
