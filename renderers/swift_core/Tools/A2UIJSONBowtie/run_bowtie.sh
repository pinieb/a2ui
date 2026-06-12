#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../../../../" && pwd )"

echo "=== 1. Starting Podman Machine ==="
# Start the Podman machine if it is not already running
podman machine start || echo "Podman machine already running or starting failed. Proceeding..."

# Set DOCKER_HOST so Bowtie CLI can communicate with Podman
echo "=== 2. Setting up Podman connection for Bowtie ==="
# Give the VM a moment to make the socket available
sleep 2

PODMAN_JSON=$(podman machine inspect 2>/dev/null || true)
if [ -n "$PODMAN_JSON" ]; then
    PODMAN_SOCKET=$(python3 -c "import json, sys; data = json.load(sys.stdin); print(data[0]['ConnectionInfo']['PodmanSocket']['Path'])" <<< "$PODMAN_JSON")
    if [ -n "$PODMAN_SOCKET" ]; then
        export DOCKER_HOST="unix://$PODMAN_SOCKET"
        echo "DOCKER_HOST is set to: $DOCKER_HOST"
    fi
fi

if [ -z "$DOCKER_HOST" ]; then
    # Fallback to podman info
    PODMAN_URI=$(podman info --format '{{.Host.ServiceURI}}' 2>/dev/null || true)
    if [ -n "$PODMAN_URI" ]; then
        export DOCKER_HOST="$PODMAN_URI"
        echo "DOCKER_HOST is set to (fallback): $DOCKER_HOST"
    fi
fi

if [ -z "$DOCKER_HOST" ]; then
    echo "ERROR: Could not retrieve Podman socket path. Bowtie will fail."
    exit 1
fi

echo "=== 3. Building Native Swift Linux Container ==="
# We must run the build from the repository root because the Dockerfile copies the entire package
cd "$REPO_ROOT"
podman build -f renderers/swift_core/Tools/A2UIJSONBowtie/Dockerfile.linux -t localhost/a2ui-json-bowtie-swift-harness .

echo "=== 4. Running Bowtie Draft 7 Suite ==="
# Locate bowtie executable
BOWTIE_BIN="bowtie"
if [ -f "$REPO_ROOT/renderers/swift_core/.venv/bin/bowtie" ]; then
    BOWTIE_BIN="$REPO_ROOT/renderers/swift_core/.venv/bin/bowtie"
    echo "Using local Bowtie binary: $BOWTIE_BIN"
fi

# Run Bowtie against our native Linux image, saving the raw report
$BOWTIE_BIN suite -i localhost/a2ui-json-bowtie-swift-harness draft7 > "$SCRIPT_DIR/report.jsonl"

# Generate and print a beautiful markdown summary table
$BOWTIE_BIN summary --format markdown "$SCRIPT_DIR/report.jsonl"

echo "=== Bowtie Run Completed! ==="
