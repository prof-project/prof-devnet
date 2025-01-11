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
	$(MAKE) -C go-prof-sequencer/ docker-build-noauth

build-prof-flood:
	$(MAKE) -C prof-flood/ docker-build

build-prof-spamoor:
	$(MAKE) -C prof-spamoor/ docker-build

# Target to build all containers
build-all-containers: stop build-go-bundle-merger build-go-prof-builder build-go-prof-relay build-go-prof-sequencer build-prof-flood build-prof-spamoor
	@echo "All containers have been built."

setup: init
	./setup.sh

create-logs-dir:
	mkdir -p logs/run-$(shell date +%Y%m%d-%H%M%S)

# New target that waits for Kurtosis and then attaches loggers
attach-loggers:
	@./scripts/attach-loggers.sh prof-test-flood-$(USER)-2

# Modified run target that starts logging after Kurtosis
clean-kurtosis:
	# First stop the engine if it's running
	-kurtosis engine stop 2>/dev/null || true
	# sleep 2
	# Remove any leftover containers
	# -docker rm -f kurtosis-engine kurtosis-github-auth-storage-creator kurtosis-reverse-proxy 2>/dev/null || true
	# # Start engine and wait for it
	# -kurtosis engine start 2>/dev/null || true
	# sleep 5
	# # Now remove the enclave
	-kurtosis enclave rm -f prof-test-flood-$(USER)-2 2>/dev/null || true
	# # Final cleanup
	-kurtosis clean -a 2>/dev/null || true
	-kurtosis engine stop 2>/dev/null || true
	# sleep 2

run: create-logs-dir
	cd prof-ethereum-package && kurtosis run \
		--enclave prof-test-flood-$(USER)-2 \
		./ \
		--args-file network_params.yaml \
		2>&1 | tee ../logs/run-$(shell date +%Y%m%d-%H%M%S)/kurtosis.log & \
	sleep 2 && $(MAKE) -C . attach-loggers

stop: clean-kurtosis
