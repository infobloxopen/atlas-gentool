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
	_ "github.com/golang/protobuf/protoc-gen-go"
	_ "github.com/golang/protobuf/protoc-gen-go/generator"
	_ "github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger"
	_ "github.com/grpc-ecosystem/grpc-gateway/runtime"
	_ "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway"
	_ "github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	_ "github.com/infobloxopen/atlas-app-toolkit/query"
	_ "github.com/infobloxopen/atlas-app-toolkit/rpc/errdetails"
	_ "github.com/infobloxopen/atlas-app-toolkit/rpc/errfields"
	_ "github.com/infobloxopen/atlas-app-toolkit/rpc/resource"
	_ "github.com/infobloxopen/protoc-gen-atlas-query-validate"
	_ "github.com/infobloxopen/protoc-gen-atlas-validate"
	_ "github.com/infobloxopen/protoc-gen-gorm"
	_ "github.com/infobloxopen/protoc-gen-preprocess"
	_ "github.com/mwitkow/go-proto-validators"
	_ "github.com/mwitkow/go-proto-validators/protoc-gen-govalidators"
)
