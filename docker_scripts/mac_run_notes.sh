
#IMAGE_NAME="apple_cloud_notes_parser"
IMAGE_NAME="ghcr.io/threeplanetssoftware/apple_cloud_notes_parser"
CONTAINER_NAME="apple_cloud_notes_parser"
COMMAND="--mac /data"
COMMAND="$COMMAND --one-output-folder"

echo "Using Docker to run ruby notes_cloud_parser.rb $COMMAND"

docker run --rm \
  --name $CONTAINER_NAME \
  --volume "/Users/$(whoami)/Library/Group Containers/group.com.apple.notes:/data:ro" \
  --volume "$(pwd)/output:/app/output" \
  $IMAGE_NAME \
  $COMMAND
