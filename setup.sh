#!/bin/bash

# Checkout specific commits for each submodule
cd ethereum-package
git checkout 5787bc9677d03fa469a2fa4a99c72f5afe9eb6f7
cd ../prof-relay
git checkout b76cc18727b8049f62871d9c4d7f9f273e5a7941
cd ../builder
git checkout 21ceda269c9d9da8ec39faea0f63efa29d8d3ebe
cd ../prof-sequencer
git checkout 13ad0a12c69cba61b29fabe97582fecc2ae8e35f
cd ..

echo "Submodules are initialized to specified versions."

# Build Docker Images
echo "Building Docker images for prof bundle merger and sequencer..."

cd builder
docker build . -t prof-project/builder-prof-merger
cd ../prof-sequencer
docker build . -t prof-project/prof-sequencer
cd ..

# Run the Project with Kurtosis
echo "Starting up services using Kurtosis..."
cd ethereum-package
kurtosis run --enclave prof-test ./ --args-file network_params.yaml

# Check Logs (Optional)
echo "To check the logs for prof mev-relay-api, run:"
echo "kurtosis service logs prof mev-relay-api"

# Cleanup Option
echo "To stop and clean up the enclave, run:"
echo "kurtosis enclave rm -f prof"

echo "Setup completed successfully."
