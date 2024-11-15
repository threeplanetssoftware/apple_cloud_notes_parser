for VERSION in "3.0" "3.1" "3.2" "3.3"
do
	IMAGE_NAME="apple_notes_cloud_parser:test-"$VERSION
	CONTAINER_NAME="apple_cloud_notes_parser-test"

	echo "\n\n###############################\nUsing Docker to test notes_cloud_parser.rb on Ruby "$VERSION"\n###############################\n\n"

	docker run --rm --name \
	  $CONTAINER_NAME \
	  --volume "$(pwd):/data:ro" \
	  --volume "$(pwd)/output:/app/output" \
	  $IMAGE_NAME
done
