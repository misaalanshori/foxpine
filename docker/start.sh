#!/bin/bash
set -e

# Fix permissions for the mounted volumes
# We use 'sudo' because the script runs as 'builder',
# but we configured passwordless sudo in the Dockerfile.
echo "Checking and fixing permissions for /work and /external..."
sudo chown -R builder:builder /work
sudo chown -R builder:builder /external
sudo chown -R builder:builder /home/builder/.ssh

# Execute the command passed to the container (default is bash)
exec "$@"
