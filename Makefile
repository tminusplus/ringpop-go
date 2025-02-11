.PHONY: clean clean-common clean-mocks coveralls testpop lint mocks out setup test test-integration test-unit test-race

SHELL = /bin/bash

export GO15VENDOREXPERIMENT=1
NOVENDOR = $(shell GO15VENDOREXPERIMENT=1 glide novendor)

export PATH := $(shell pwd)/scripts/travis/thrift-release/linux-x86_64:$(PATH)
export PATH := $(shell pwd)/scripts/travis/thrift-gen-release/linux-x86_64:$(PATH)
export PATH := $(GOPATH)/bin:$(PATH)

export ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
export GOPKG=$(shell go list)


# Automatically gather packages
PKGS = $(shell find . -maxdepth 3 -type d \
	! -path '*/.git*' \
	! -path '*/_*' \
	! -path '*/vendor*' \
	! -path '*/test*' \
	! -path '*/gen-go*' \
)

out:	test

clean:
	rm -f testpop

clean-common:
	rm -rf test/ringpop-common

clean-mocks:
	rm -f test/mocks/*.go forward/mock_*.go
	rm -rf test/thrift/pingpong/

coveralls:
	test/update-coveralls

lint:
	@:>lint.log

	@-golint ./... | grep -Ev '(^vendor|test|gen-go)/' | tee -a lint.log

	@for pkg in $(PKGS); do \
		scripts/lint/run-vet "$$pkg" | tee -a lint.log; \
	done;

	@[ ! -s lint.log ]
	@rm -f lint.log

mocks:
	test/gen-testfiles

dev_deps:
	command -v pip >/dev/null 2>&1 || { echo >&2 "'pip' required but not found. Please install. Aborting."; exit 1; }

	pip install cram
	command -v cram >/dev/null 2>&1 || { echo >&2 "'cram' required but not found. Please install. Aborting."; exit 1; }

	pip install virtualenv
	command -v virtualenv >/dev/null 2>&1 || { echo >&2 "'virtualenv' required but not found. Please install. Aborting."; exit 1; }

	pip install npm
	command -v npm >/dev/null 2>&1 || { echo >&2 "'npm' required but not found. Please install. Aborting."; exit 1; }

	npm install -g tcurl@4.22.0
	command -v tcurl >/dev/null 2>&1 || { echo >&2 "'tcurl' installed but not found on path.  Aborting."; exit 1; }

	go get -u github.com/uber/tchannel-go/thrift/thrift-gen
	command -v thrift-gen >/dev/null 2>&1 || { echo >&2 "'thrift-gen' installed but not found on path.  Aborting."; exit 1; }

	go get -u golang.org/x/lint/golint...

	# Thrift commit matches glide version
	go get -u github.com/apache/thrift/lib/go/thrift@5bc8b5a3a5da507b6f87436ca629be664496a69f
	command -v thrift >/dev/null 2>&1 || { echo >&2 "'thrift' installed but not found on path. Aborting."; exit 1; }

	./scripts/go-get-version.sh github.com/vektra/mockery/.../@130a05e
	command -v mockery >/dev/null 2>&1 || { echo >&2 "'mockery' installed but not found on path. Aborting."; exit 1; }


setup: dev_deps
	@if ! which thrift | grep -q /; then \
		echo "thrift not in PATH. (brew install thrift?)" >&2; \
 		exit 1; \
	fi

	ln -sf ../../scripts/pre-commit .git/hooks/pre-commit

# lint should happen after test-unit and test-examples as it relies on objects
# being created during these phases
test: test-unit test-race test-examples lint test-integration

test-integration: vendor
	test/run-integration-tests

test-unit:
	go generate $(NOVENDOR)
	test/go-test-prettify $(NOVENDOR)

test-examples: vendor _venv/bin/cram
	. _venv/bin/activate && ./test/run-example-tests

test-race: vendor
	go generate $(NOVENDOR)
	test/go-test-prettify -race $(NOVENDOR)

vendor:
	$(error run 'make setup' first)

_venv/bin/cram:
	./scripts/travis/get-cram.sh

testpop:	clean
	go build ./scripts/testpop/
