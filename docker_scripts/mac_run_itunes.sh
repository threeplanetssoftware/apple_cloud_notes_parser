
#IMAGE_NAME="apple_cloud_notes_parser"
IMAGE_NAME="ghcr.io/threeplanetssoftware/apple_cloud_notes_parser"
CONTAINER_NAME="apple_cloud_notes_parser"
COMMAND="--itunes /data"
ITUNES="/Users/$(whoami)/Library/Application Support/MobileSync/Backup"

echo "Using Docker to run ruby notes_cloud_parser.rb $COMMAND"
echo "NOTE: Because there may be multiple backups, this will NOT use the '--one-output-folder' option."

for itunes_backup in "$ITUNES"/*/; do
  echo "Working on $itunes_backup folder"
  docker run --rm \
    --name $CONTAINER_NAME \
    --volume "$itunes_backup:/data:ro" \
    --volume "$(pwd)/output:/app/output" \
    $IMAGE_NAME \
    $COMMAND
done
