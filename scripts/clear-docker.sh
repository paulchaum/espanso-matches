#!/bin/bash

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <container_name_or_id> [container_name_or_id...]"
    exit 1
fi

# Iterate over all arguments passed to the script
for container in "$@"; do
    echo "------------------------------------------------"
    echo "Processing container: $container"

    # 1. Inspect resources before deletion
    IMAGE=$(docker inspect --format='{{.Image}}' "$container" 2>/dev/null)
    VOLUMES=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "$container" 2>/dev/null)
    NETWORKS=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' "$container" 2>/dev/null)

    # 2. Stop and Remove Container
    docker stop "$container" 2>/dev/null
    docker rm -v "$container"

    # 3. Remove Named Volumes
    if [ -n "$VOLUMES" ]; then
        for vol in $VOLUMES; do
            echo "Attempting to remove volume: $vol"
            docker volume rm "$vol" || echo "-> Volume in use, kept."
        done
    fi

    # 4. Attempt to Remove Image
    if [ -n "$IMAGE" ]; then
        echo "Attempting to remove image: $IMAGE"
        docker rmi "$IMAGE" || echo "-> Image in use, kept."
    fi

    # 5. Attempt to Remove Networks
    if [ -n "$NETWORKS" ]; then
        for net in $NETWORKS; do
            echo "Attempting to remove network: $net"
            docker network rm "$net" || echo "-> Network in use or default, kept."
        done
    fi
done