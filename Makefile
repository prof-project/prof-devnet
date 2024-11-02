all:
	@echo "This is a dummy to prevent running make without explicit target!"

init:
	git submodule update --init --recursive

git-fetchall:
	git fetch --recurse-submodules

build-go-bundle-merger:
	cd go-bundle-merger && make docker-build

build-go-prof-builder:
	cd go-prof-builder && make docker-image

build-go-prof-relay:
	cd go-prof-relay && make docker-image

build-go-prof-sequencer:
	cd go-prof-sequencer && make docker-build

build-prof-flood:
	cd prof-flood && docker build --no-cache -t prof-project/mev-flood .

# Target to build all containers
build-all-containers: stop build-go-bundle-merger build-go-prof-builder build-go-prof-relay build-go-prof-sequencer build-prof-flood
	@echo "All containers have been built."

setup: init
	./setup.sh

run:
	cd prof-ethereum-package; kurtosis run --enclave prof-test-flood ./ --args-file network_params.yaml

stop:
	-kurtosis enclave rm -f prof-test-flood 2>/dev/null || true
	kurtosis engine stop
