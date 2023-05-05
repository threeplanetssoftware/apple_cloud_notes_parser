
IMAGE_NAME="ghcr.io/threeplanetssoftware/apple_cloud_notes_parser"
CONTAINER_NAME="apple_cloud_notes_parser"
COMMAND="--mac /data"
COMMAND="$COMMAND --one-output-folder"
NOTES="/Users/$(whoami)/Library/Group Containers/group.com.apple.notes"
TMP_FOLDER="$(pwd)/.tmp_notes_input"

echo "Using Docker to run ruby notes_cloud_parser.rb $COMMAND"

echo "Creating temporary storage: $TMP_FOLDER"
mkdir -p "$TMP_FOLDER"
cp -r "$NOTES"/* "$TMP_FOLDER"
docker run --rm \
  --name $CONTAINER_NAME \
  --volume "$TMP_FOLDER:/data:ro" \
  --volume "$(pwd)/output:/app/output" \
  $IMAGE_NAME \
  $COMMAND

echo "Removing temporary storage: $TMP_FOLDER"
rm -rf "$TMP_FOLDER"
