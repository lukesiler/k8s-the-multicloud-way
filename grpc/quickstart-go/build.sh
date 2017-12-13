#!/bin/bash
go get -u google.golang.org/grpc
go get -u github.com/golang/protobuf/protoc-gen-go
../../protoc/bin/protoc -I helloworld/ helloworld/helloworld.proto --go_out=plugins=grpc:helloworld
