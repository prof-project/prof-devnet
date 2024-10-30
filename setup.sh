#!/bin/bash

# Exit on any error
set -e

ETHEREUM_PACKAGE_VERSION="9a6a7834a112c8507af1bc436df8283a98f6ac35"
KURTOSIS_VERSION="0.87.2"
RELAY_BRANCH="1-grpc-bundle-merger"
BUNDLE_MERGER_BRANCH="5-simulateBundleJsonRPC"
SEQUENCER_BRANCH="1-implement-first-draft-of-sequencer-in-go"
PROF_FLOOD_BRANCH="1-adapt-for-prof-sequencer"

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
    git submodule add https://github.com/prof-project/ethereum-package.git 2>/dev/null || true
    git submodule update --init
fi

# Update remote if it's pointing to kurtosis-tech
cd ethereum-package
current_remote=$(git remote get-url origin)
if [[ "$current_remote" == *"kurtosis-tech"* ]]; then
    echo "Updating remote to prof-project repository..."
    git remote remove origin
    git remote add origin https://github.com/prof-project/ethereum-package.git
    git fetch origin
fi

# Checkout specific branch
git fetch origin prof-devnet
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "prof-devnet" ]; then
    echo -e "${YELLOW}Wrong branch detected${NC}"
    echo -e "Current: $current_branch"
    echo -e "Wanted:  prof-devnet"
    echo "Checking out prof-devnet branch..."
    git checkout prof-devnet
else
    echo -e "${GREEN}Correct branch already checked out${NC}"
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

# Initialize and check bundle-merger
echo -e "${YELLOW}Checking bundle-merger...${NC}"
if [ ! -d "go-bundle-merger" ] || [ ! -f "go-bundle-merger/.git" ]; then
    echo "Initializing bundle-merger submodule..."
    git submodule add https://github.com/prof-project/go-bundle-merger.git 2>/dev/null || true
    git submodule update --init
fi

# Check and switch to correct bundle-merger branch
cd go-bundle-merger
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$BUNDLE_MERGER_BRANCH" ]; then
    echo -e "${YELLOW}Wrong branch detected${NC}"
    echo -e "Current: $current_branch"
    echo -e "Wanted:  $BUNDLE_MERGER_BRANCH"
    echo "Checking out bundle-merger branch ${BUNDLE_MERGER_BRANCH}..."
    git fetch
    git checkout $BUNDLE_MERGER_BRANCH
else
    echo -e "${GREEN}Correct bundle-merger branch already checked out${NC}"
fi

# Build the bundle-merger
echo "Building bundle-merger..."
make docker-build    # Changed from make docker-image to match Makefile
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Bundle-merger image built successfully${NC}"
else
    echo -e "${RED}Bundle-merger image build failed${NC}"
    exit 1
fi
cd ..

# Initialize and check sequencer
echo -e "${YELLOW}Checking sequencer...${NC}"
if [ ! -d "go-prof-sequencer" ] || [ ! -f "go-prof-sequencer/.git" ]; then
    echo "Initializing sequencer submodule..."
    git submodule add https://github.com/prof-project/go-prof-sequencer.git 2>/dev/null || true
    git submodule update --init
fi

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
    
    # Check and switch to correct branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$PROF_FLOOD_BRANCH" ]; then
        echo -e "${YELLOW}Wrong branch detected${NC}"
        echo -e "Current: $current_branch"
        echo -e "Wanted:  $PROF_FLOOD_BRANCH"
        echo "Checking out prof-flood branch ${PROF_FLOOD_BRANCH}..."
        git fetch
        git checkout $PROF_FLOOD_BRANCH
    else
        echo -e "${GREEN}Correct prof-flood branch already checked out${NC}"
    fi
    
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

# Run the Project with Kurtosis
echo -e "${YELLOW}Starting up services using Kurtosis...${NC}"
cd ethereum-package
kurtosis run --enclave prof-test-flood ./ --args-file network_params.yaml

# Check Logs (Optional)
echo "To check the logs for prof mev-relay-api, run:"
echo "kurtosis service logs prof-test mev-relay-api"

# Cleanup Option
echo "To stop and clean up the enclave, run:"
echo "kurtosis enclave rm -f prof-test-flood"

echo "Setup completed successfully."


