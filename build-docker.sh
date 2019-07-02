#!/usr/bin/env bash

set -o errexit
# set -o nounset
set -o pipefail
set -o xtrace

if [ ! -z "$TRAVIS_BRANCH" ]; then
	# For tag builds TRAVIS_BRANCH is set to the tag name
	BRANCH=$TRAVIS_BRANCH
	# For PR builds branch is the target branch
	if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
		# Change the branch name for PR builds so we don't create a tag
		BRANCH="${BRANCH}-${TRAVIS_PULL_REQUEST}"
	fi
	# Only Travis should push images, so we only need to use the tag with Travis
	TAG=$TRAVIS_TAG
	# For the master branch use the "latest" tag
	if [ $BRANCH == "master" ]; then
		TAG="latest"
	fi
elif [ ! -z "$CI_COMMIT_REF_NAME" ]; then
	# This is also run in GitLab CI, for build and test only. 
	BRANCH="$CI_COMMIT_REF_NAME"
else
	exit 1
fi

echo "BUILD - Will now build Docker container"
docker build -t edwardotme/raspbian-customiser:$BRANCH .

echo "TEST - Will now test built Docker container"
IMAGE_LINK=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-10-11/2018-10-09-raspbian-stretch-lite.zip
cd test/
wget -nv $IMAGE_LINK
IMAGE_ZIP=$(basename $IMAGE_LINK)
unzip -o $IMAGE_ZIP
rm $IMAGE_ZIP
cd ..
docker run --privileged --rm \
  -e MOUNT=/test \
  -e SOURCE_IMAGE=/test/${IMAGE_ZIP%.zip}.img \
  -e SCRIPT=/test/test.sh \
  -e ADD_DATA_PART=true \
  --mount type=bind,source="$(pwd)"/test,destination=/test \
  edwardotme/raspbian-customiser:$BRANCH

if [ ! -z "$TAG" ]; then
	# Only push image if TAG is set
	echo "DEPLOY - Will now push Docker image to Docker Hub as $TAG"
	echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
	docker tag edwardotme/raspbian-customiser:$BRANCH edwardotme/raspbian-customiser:$TAG
	docker push edwardotme/raspbian-customiser:$TAG
fi
