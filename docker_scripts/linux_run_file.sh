
COMMAND="-f /data/NoteStore.sqlite"
COMMAND="$COMMAND --one-output-folder"
CONTAINER_NAME="apple_cloud_notes_parser"
IMAGE_NAME="ghcr.io/threeplanetssoftware/apple_cloud_notes_parser"
#IMAGE_NAME="apple_cloud_notes_parser"

echo "Using Docker to run ruby notes_cloud_parser.rb $COMMAND"

docker run --rm \
	--name $CONTAINER_NAME \
	--volume "$(pwd):/data:ro" \
	--volume "$(pwd)/output:/app/output" \
	$IMAGE_NAME \
	$COMMAND
