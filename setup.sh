#!/bin/bash

# Exit on any error
set -e

ETHEREUM_PACKAGE_VERSION="beb764fb9a18fcb09cb7d3d9ee48e4826595512d"
KURTOSIS_VERSION="0.87.2"
RELAY_BRANCH="1-grpc-bundle-merger"

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

# Initialize and update ethereum-package submodule if needed
echo -e "${YELLOW}Checking ethereum-package version...${NC}"
if [ ! -d "ethereum-package" ] || [ ! -f "ethereum-package/.git" ]; then
    echo "Initializing ethereum-package submodule..."
    git submodule add https://github.com/kurtosis-tech/ethereum-package.git 2>/dev/null || true
    git submodule update --init
fi

# Checkout specific version of ethereum-package
cd ethereum-package
current_hash=$(git rev-parse HEAD)
if [ "$current_hash" != "$ETHEREUM_PACKAGE_VERSION" ]; then
    echo -e "${YELLOW}Wrong ethereum-package version detected${NC}"
    echo -e "Current: $current_hash"
    echo -e "Wanted:  $ETHEREUM_PACKAGE_VERSION"
    echo "Checking out ethereum-package version ${ETHEREUM_PACKAGE_VERSION}..."
    git fetch
    git checkout $ETHEREUM_PACKAGE_VERSION
else
    echo -e "${GREEN}Correct ethereum-package version already checked out${NC}"
fi
cd ..

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
echo -e "Ethereum Package version: ${GREEN}$ETHEREUM_PACKAGE_VERSION${NC}"
echo -e "Kurtosis version: ${GREEN}$KURTOSIS_VERSION${NC}"


# Build the relay Docker image
echo -e "${YELLOW}Building relay Docker image...${NC}"
if [ -d "go-prof-relay" ]; then
    cd go-prof-relay
    
    # Check and switch to correct branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$RELAY_BRANCH" ]; then
        echo -e "${YELLOW}Wrong branch detected${NC}"
        echo -e "Current: $current_branch"
        echo -e "Wanted:  $RELAY_BRANCH"
        echo "Checking out relay branch ${RELAY_BRANCH}..."
        git fetch
        git checkout $RELAY_BRANCH
    else
        echo -e "${GREEN}Correct relay branch already checked out${NC}"
    fi
    
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

# Run the Project with Kurtosis
echo -e "${YELLOW}Starting up services using Kurtosis...${NC}"
cd ethereum-package
kurtosis run --enclave prof-test-enhanced ./ --args-file network_params.yaml

# Check Logs (Optional)
echo "To check the logs for prof mev-relay-api, run:"
echo "kurtosis service logs prof-test mev-relay-api"

# Cleanup Option
echo "To stop and clean up the enclave, run:"
echo "kurtosis enclave rm -f prof-test"

echo "Setup completed successfully."


