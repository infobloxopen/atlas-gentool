//go:build tools
// +build tools

package main

import (
	_ "github.com/chrusty/protoc-gen-jsonschema/cmd/protoc-gen-jsonschema"
	_ "github.com/envoyproxy/protoc-gen-validate"
	_ "github.com/ghodss/yaml"
	_ "github.com/go-openapi/spec"
	_ "github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	_ "github.com/mwitkow/go-proto-validators"
	_ "github.com/mwitkow/go-proto-validators/protoc-gen-govalidators"
	_ "github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc"
	_ "google.golang.org/grpc/cmd/protoc-gen-go-grpc"
	_ "google.golang.org/protobuf/cmd/protoc-gen-go"
	_ "google.golang.org/protobuf/types/known/emptypb"
	_ "google.golang.org/protobuf/types/known/structpb"

	_ "github.com/infobloxopen/atlas-app-toolkit/v2/gorm"
	_ "github.com/infobloxopen/atlas-app-toolkit/v2/query"
	_ "github.com/infobloxopen/atlas-app-toolkit/v2/rpc/errdetails"
	_ "github.com/infobloxopen/atlas-app-toolkit/v2/rpc/errfields"
	_ "github.com/infobloxopen/atlas-app-toolkit/v2/rpc/resource"
	_ "github.com/infobloxopen/protoc-gen-atlas-query-validate"
	_ "github.com/infobloxopen/protoc-gen-atlas-validate"
	_ "github.com/infobloxopen/protoc-gen-atlas-validate/runtime"
	_ "github.com/infobloxopen/protoc-gen-gorm"
	_ "github.com/infobloxopen/protoc-gen-gorm/auth"
	_ "github.com/infobloxopen/protoc-gen-gorm/errors"
	_ "github.com/infobloxopen/protoc-gen-gorm/types"
	_ "github.com/infobloxopen/protoc-gen-preprocess"
)
