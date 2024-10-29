all:
	@echo "This is a dummy to prevent running make without explicit target!"

init:
	sudo apt install -y make

buildContainers:
	cd go-prof-relay; make docker-image
	cd go-bundle-merger; make docker-build
	cd go-prof-sequencer; make init; make docker-build

run:
	cd ethereum-package; kurtosis run --enclave prof-test-enhanced ./ --args-file network_params.yaml

runScript:
	./setup.sh
