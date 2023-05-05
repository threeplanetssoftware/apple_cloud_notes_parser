
#IMAGE_NAME="apple_cloud_notes_parser"
IMAGE_NAME="ghcr.io/threeplanetssoftware/apple_cloud_notes_parser"
CONTAINER_NAME="apple_cloud_notes_parser"
COMMAND="--itunes /data"
ITUNES="/Users/$(whoami)/Library/Application Support/MobileSync/Backup"
TMP_FOLDER="$(pwd)/.tmp_notes_input"

echo "Using Docker to run ruby notes_cloud_parser.rb $COMMAND"
echo "NOTE: Because there may be multiple backups, this will NOT use the '--one-output-folder' option."

echo "Creating temporary storage: $TMP_FOLDER"
mkdir -p "$TMP_FOLDER"
for itunes_backup in "$ITUNES"/*/; do
  echo "Copying $itunes_backup to temporary storage: $TMP_FOLDER"
  cp -r "$itunes_backup"/* "$TMP_FOLDER"
  docker run --rm \
    --name $CONTAINER_NAME \
    --volume "$TMP_FOLDER:/data:ro" \
    --volume "$(pwd)/output:/app/output" \
    $IMAGE_NAME \
    $COMMAND
  rm -rf "$TMP_FOLDER"/*
done

rm -rf "$TMP_FOLDER"
