# PROF testing with Kurtosis
The Setup script checks that the kurtosis version, the ethereum-package version, the relay branch, the bundle merger branch and the sequencer branch are correct.
Successively, it spins up the enclave with the network_params.yaml.


```
./setup.sh
```

Alternatively,
```
make init
```
copy go-bundle-merger/.env.sample to go-bundle-merger/.env and add your (classic) Github personal access token.
```
make build-all-containers
make run
make stop
```

Kurtosis, and especially the ethereum-package, are fairly volatile, so deviation from the setup script can lead to unexpected behavior.

# Makefile targets
This project uses a Makefile as a frontend. To use make, first install. E.g. via apt on a Debian system:
```
sudo apt install -y make
```

- init: initialize the repo
- buildContainers: build all container images for the project
- run: start the kurtosis package
- runScript: execute the scripted version of this package and the preparation
- stop: stop the kurtosis package

## The Ethereum Package
The ethereum-package is adapted from commit hash `beb764fb9a18fcb09cb7d3d9ee48e4826595512d`, and further expanded to include the Prof Relay, Bundle Merger and Sequencer.
The reason to use a specific commit hash is to have a more stable environment, whereas later versions do not support a stable MEV value chain.

## Running the enclave & specific parameters
To run the kurtosis enclave with the network_params.yaml, run the following command:

```bash
kurtosis run --enclave <NAME> ./ --args-file network_params.yaml
```

The following extra_args is needed to run the Prof Relay in the mev_relay_launcher.star:

```
"--bundle-merger-url",
builder_uri,
```

The following network_params.yaml is executing correctly for a plain MEV setup with the ethereum-package:

(The main difference is the seconds_per_slot, which is set to 2 instead of 12, and the mev_flood_seconds_per_bundle which is set to 1 instead of 15 in the original network_params.yaml + grafane is removed)

```yaml
participants:
  - el_client_type: geth
    el_client_image: ethereum/client-go:latest
    el_client_log_level: ""
    el_extra_params: []
    el_extra_labels: {}
    el_tolerations: []
    cl_client_type: lighthouse
    cl_client_image: sigp/lighthouse:latest
    cl_client_log_level: ""
    cl_tolerations: []
    validator_tolerations: []
    tolerations: []
    node_selectors: {}
    beacon_extra_params: []
    beacon_extra_labels: {}
    validator_extra_params: []
    validator_extra_labels: {}
    builder_network_params: null
    validator_count: null
    snooper_enabled: false
    ethereum_metrics_exporter_enabled: false
    xatu_sentry_enabled: false
    el_min_cpu: 0
    el_max_cpu: 0
    el_min_mem: 0
    el_max_mem: 0
    bn_min_cpu: 0
    bn_max_cpu: 0
    bn_min_mem: 0
    bn_max_mem: 0
    v_min_cpu: 0
    v_max_cpu: 0
    v_min_mem: 0
    v_max_mem: 0
    count: 2
    # prometheus_config:
    #   scrape_interval: 15s
    #   labels: {}
    blobber_enabled: false
    blobber_extra_params: []
network_params:
  network_id: "3151908"
  deposit_contract_address: "0x4242424242424242424242424242424242424242"
  seconds_per_slot: 2
  num_validator_keys_per_node: 64
  preregistered_validator_keys_mnemonic:
    "giant issue aisle success illegal bike spike
    question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy
    very lucky have athlete"
  preregistered_validator_count: 0
  genesis_delay: 20
  max_churn: 8
  ejection_balance: 16000000000
  capella_fork_epoch: 0
  deneb_fork_epoch: 4
  electra_fork_epoch: null
  network: kurtosis
  min_validator_withdrawability_delay: 256
  shard_committee_period: 256

additional_services:
  - tx_spammer
  - blob_spammer
  - el_forkmon
  # - beacon_metrics_gazer
  - dora
  # - prometheus_grafana
wait_for_finalization: false
global_client_log_level: info
snooper_enabled: false
ethereum_metrics_exporter_enabled: false
parallel_keystore_generation: false
mev_type: full
mev_params:
  mev_relay_image: flashbots/mev-boost-relay
  mev_relay_api_extra_args: []
  mev_relay_housekeeper_extra_args: []
  mev_relay_website_extra_args: []
  mev_builder_extra_args: []
  # mev_builder_prometheus_config:
  #   scrape_interval: 15s
  #   labels: {}
  mev_flood_image: flashbots/mev-flood
  mev_flood_extra_args: []
  mev_flood_seconds_per_bundle: 1
  mev_boost_image: flashbots/mev-boost
  mev_boost_args: ["mev-boost", "--relay-check"]
grafana_additional_dashboards: []
persistent: false
xatu_sentry_enabled: false
global_tolerations: []
global_node_selectors: {}
```

# debugging
To follow errors on a specific service, for example the builder, execute:
```
kurtosis service logs -f prof-test-flood el-3-geth-builder-lighthouse --match=error
```
