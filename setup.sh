#!/bin/bash

# Exit on any error
set -e

KURTOSIS_VERSION="0.87.2"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Setting up environment..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git is not installed. Please install git first.${NC}"
    exit 1
fi

# Kurtosis installation
echo -e "${YELLOW}Checking Kurtosis version...${NC}"

# Check current Kurtosis version if installed
if command -v kurtosis &> /dev/null; then
    current_version=$(kurtosis version | grep "CLI Version:" | awk '{print $3}' | tr -d ']')
    if [ "$current_version" = "$KURTOSIS_VERSION" ]; then
        echo -e "${GREEN}Correct Kurtosis version ($KURTOSIS_VERSION) already installed${NC}"
    else
        echo -e "${YELLOW}Wrong Kurtosis version detected (got: $current_version, want: $KURTOSIS_VERSION)${NC}"
        echo "Removing existing Kurtosis installation..."
        sudo apt remove -y kurtosis-cli
        needs_install=true
    fi
else
    echo "Kurtosis not found"
    needs_install=true
fi

# Install Kurtosis if needed
if [ "${needs_install}" = true ]; then
    # Set up Kurtosis repository
    echo "Setting up Kurtosis repository..."
    echo "deb [trusted=yes] https://apt.fury.io/kurtosis-tech/ /" | sudo tee /etc/apt/sources.list.d/kurtosis.list

    # Update package list
    echo "Updating package list..."
    sudo apt update

    # Install specific version of Kurtosis
    echo "Installing Kurtosis version $KURTOSIS_VERSION..."
    sudo apt install -y kurtosis-cli=$KURTOSIS_VERSION -V

    # Verify installation
    installed_version=$(kurtosis version | grep "CLI Version:" | awk '{print $3}' | tr -d ']')
    if [ "$installed_version" != "$KURTOSIS_VERSION" ]; then
        echo -e "${RED}Failed to install correct Kurtosis version!${NC}"
        echo -e "Wanted: $KURTOSIS_VERSION"
        echo -e "Got: $installed_version"
        exit 1
    fi
fi

echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "Kurtosis version: ${GREEN}$KURTOSIS_VERSION${NC}"

# Build the relay Docker image
echo -e "${YELLOW}Building relay Docker image...${NC}"
if [ -d "go-prof-relay" ]; then
    cd go-prof-relay
    
    echo "Building prof-project/prof-relay without cache..."
    make docker-image
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Relay image built successfully${NC}"
    else
        echo -e "${RED}Relay image build failed${NC}"
        exit 1
    fi
    cd ..
else
    echo -e "${RED}Relay directory not found!${NC}"
    exit 1
fi

# Build the bundle-merger
echo "Building bundle-merger..."
cd go-bundle-merger
make docker-build    # Changed from make docker-image to match Makefile
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Bundle-merger image built successfully${NC}"
else
    echo -e "${RED}Bundle-merger image build failed${NC}"
    exit 1
fi
cd ..

# Check and switch to correct sequencer branch
cd go-prof-sequencer
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$SEQUENCER_BRANCH" ]; then
    echo -e "${YELLOW}Wrong branch detected${NC}"
    echo -e "Current: $current_branch"
    echo -e "Wanted:  $SEQUENCER_BRANCH"
    echo "Checking out sequencer branch ${SEQUENCER_BRANCH}..."
    git fetch
    git checkout $SEQUENCER_BRANCH
else
    echo -e "${GREEN}Correct sequencer branch already checked out${NC}"
fi

# Build the sequencer
echo "Building sequencer..."
make init
make docker-build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Sequencer image built successfully${NC}"
else
    echo -e "${RED}Sequencer image build failed${NC}"
    exit 1
fi
cd ..

# Build prof-flood
echo -e "${YELLOW}Building prof-flood...${NC}"
if [ -d "prof-flood" ]; then
    cd prof-flood
 
    echo "Building prof-project/mev-flood without cache..."
    docker build --no-cache -t prof-project/mev-flood .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Prof-flood image built successfully${NC}"
    else
        echo -e "${RED}Prof-flood image build failed${NC}"
        exit 1
    fi
    cd ..
else
    echo -e "${RED}Prof-flood directory not found!${NC}"
    exit 1
fi

# Build the builder
cd go-prof-builder
echo "Building builder..."
make docker-image
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Builder image built successfully${NC}"
else
    echo -e "${RED}Builder image build failed${NC}"
    exit 1
fi
cd ..

# Run the Project with Kurtosis
echo -e "${YELLOW}Starting up services using Kurtosis...${NC}"
cd prof-ethereum-package
kurtosis run --enclave prof-test-flood ./ --args-file network_params.yaml

# Check Logs (Optional)
echo "To check the logs for prof mev-relay-api, run:"
echo "kurtosis service logs prof-test mev-relay-api"

# Cleanup Option
echo "To stop and clean up the enclave, run:"
echo "kurtosis enclave rm -f prof-test-flood"

echo "Setup completed successfully."


