all:
	@echo "This is a dummy to prevent running make without explicit target!"

init:
	sudo apt install -y make
	git submodule update --init --recursive

buildContainers:
	cd go-bundle-merger; make docker-build
	cd go-prof-builder; make docker-image
	cd go-prof-relay; make docker-image
	cd go-prof-sequencer; make init; make docker-build
	cd prof-flood; docker build --no-cache -t prof-project/mev-flood .

run:
	cd prof-ethereum-package; kurtosis run --enclave prof-test-flood ./ --args-file network_params.yaml

runScript: init
	./setup.sh

stop:
	kurtosis enclave rm -f prof-test-flood
	kurtosis engine stop
