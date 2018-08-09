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

## protoc-gen-swagger patch

protoc-gen-swagger patch includes following changes:

 * Fixed method comments extraction

 * Rendering of messages that have a primitive type (STRING, INT, BOOLEAN)
   does not occur if message is used only as a field (not an rpc Request or Response),
   hence recursive message definitions and complex-structured messages can be presented
   as plain string query parameters.

 * Introduced new `atlas_patch` flag. If this flag is enabled `--swagger_out="atlas_patch=true:."`
   following changes are made to a swagger spec:

   * All responses are wrapped with `success` field and assigned to an appropriate response code:
     GET - 200/OK, POST - 201/CREATED, PUT - 202/UPDATED, DELETE - 203/DELETED.

   * Recursive references are broken up. Such references occur while using protoc-gen-gorm plugin
     with many-to-many/one-to-many relations.

   * Collection operators from atlas-app-toolkit are provided with documentation and correct
     names.

   * atlas.rpc.identifier in path is treated correctly and not distributed among path and
     query parameters, also id.payload_id is replaced with id in path.

   * Unused references elimination.
