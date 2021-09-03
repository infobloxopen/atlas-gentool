// +build tools

package main

import (
	_ "github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema"
	_ "github.com/envoyproxy/protoc-gen-validate"
	_ "github.com/ghodss/yaml"
	_ "github.com/go-openapi/spec"
	_ "github.com/gogo/protobuf/protoc-gen-combo"
	_ "github.com/gogo/protobuf/protoc-gen-gofast"
	_ "github.com/gogo/protobuf/protoc-gen-gogo"
	_ "github.com/gogo/protobuf/protoc-gen-gogofast"
	_ "github.com/gogo/protobuf/protoc-gen-gogofaster"
	_ "github.com/gogo/protobuf/protoc-gen-gogoslick"
	_ "github.com/gogo/protobuf/protoc-gen-gogotypes"
	_ "github.com/gogo/protobuf/protoc-gen-gostring"
	_ "google.golang.org/grpc/cmd/protoc-gen-go-grpc"
	_ "google.golang.org/protobuf/cmd/protoc-gen-go"
	_ "github.com/mwitkow/go-proto-validators"
	_ "github.com/mwitkow/go-proto-validators/protoc-gen-govalidators"
	_ "github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc"

	_ "github.com/infobloxopen/atlas-app-toolkit/query"
	_ "github.com/infobloxopen/atlas-app-toolkit/rpc/errdetails"
	_ "github.com/infobloxopen/atlas-app-toolkit/rpc/errfields"
	_ "github.com/infobloxopen/atlas-app-toolkit/rpc/resource"
	_ "github.com/infobloxopen/protoc-gen-atlas-query-validate"
	_ "github.com/infobloxopen/protoc-gen-atlas-validate"
	_ "github.com/infobloxopen/protoc-gen-gorm"
	_ "github.com/infobloxopen/protoc-gen-preprocess"
)
