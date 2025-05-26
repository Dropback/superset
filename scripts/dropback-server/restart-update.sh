#!/bin/bash

# Parse command line arguments
FORCE_RESTART=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--force) FORCE_RESTART=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ "$PWD" != "$HOME/superset" ]; then
  cd "$HOME/superset"
fi

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
IMAGE_NAME="dropbackhq/superset-dropback-amd64"
IMAGE_TAG="latest"

# Function to restart containers
restart_containers() {
    echo "Pulling latest image and restarting containers..."
    docker compose pull
    docker compose down
    docker compose up -d
    echo "Container restarted"
}

if [ "$FORCE_RESTART" = true ]; then
    echo "Force restart requested..."
    restart_containers
else
    # Function to get image SHA
    get_image_sha() {
        docker manifest inspect "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null | jq -r '.config.digest'
    }

    # Get remote SHA
    REMOTE_SHA=$(get_image_sha)

    # If we couldn't get remote SHA, exit
    if [ -z "$REMOTE_SHA" ]; then
        echo "Could not get remote image SHA. Image might not exist in registry."
        exit 1
    fi

    # Get local SHA
    LOCAL_SHA=$(docker inspect --format='{{.Id}}' "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null)

    # If images are different or local image doesn't exist
    if [ "$REMOTE_SHA" != "$LOCAL_SHA" ]; then
        echo "New image available. Pulling and restarting..."
        restart_containers
    else
        echo "Local image is up to date. No restart needed."
    fi
fi