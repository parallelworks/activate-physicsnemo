#!/bin/bash
# clean.sh - Clean up stale artifacts from previous runs
set -x

echo "Cleaning up stale PhysicsNemo artifacts..."

# Kill any stale Docker containers
for cid in $(docker ps -q --filter "name=physicsnemo" 2>/dev/null || sudo docker ps -q --filter "name=physicsnemo" 2>/dev/null); do
    echo "Stopping container: $cid"
    docker rm -f "$cid" 2>/dev/null || sudo docker rm -f "$cid" 2>/dev/null || true
done

# Clean up runtime files
rm -f job.started job.ended HOSTNAME jobid cancel.sh .run.env
rm -rf logs/

echo "Cleanup complete"
