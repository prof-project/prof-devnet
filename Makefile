all:
	@echo "This is a dummy to prevent running make without explicit target!"

init:
	git submodule update --init --recursive

git-fetchall:
	git fetch --recurse-submodules

build-go-bundle-merger:
	$(MAKE) -C go-bundle-merger/ docker-build

build-go-prof-builder:
	$(MAKE) -C go-prof-builder/ docker-image

build-go-prof-relay:
	$(MAKE) -C go-prof-relay/ docker-image

build-go-prof-sequencer:
	$(MAKE) -C go-prof-sequencer/ docker-build

build-prof-flood:
	$(MAKE) -C prof-flood/ docker-build

# Target to build all containers
build-all-containers: stop build-go-bundle-merger build-go-prof-builder build-go-prof-relay build-go-prof-sequencer build-prof-flood
	@echo "All containers have been built."

setup: init
	./setup.sh

run:
	cd prof-ethereum-package; kurtosis run --enclave prof-test-flood-$(USER) ./ --args-file network_params.yaml

stop:
	-kurtosis enclave rm -f prof-test-flood-$(USER) 2>/dev/null || true
	kurtosis engine stop
