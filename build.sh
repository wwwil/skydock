#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o xtrace

if [ ! -z "$TRAVIS_BRANCH" ]; then
	# For tag builds `TRAVIS_BRANCH` is set to the tag name.
	BRANCH=$TRAVIS_BRANCH
	# For PR builds branch is the target branch.
	if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
		# Change the branch name for PR builds so we don't create a tag.
		BRANCH="${BRANCH}-${TRAVIS_PULL_REQUEST}"
	fi
	# Only Travis should push images, so we only need to use the tag with
    # Travis.
	TAG=$TRAVIS_TAG
elif [ ! -z "$CI_COMMIT_REF_NAME" ]; then
	# This is also run in GitLab CI, for build and test only.
	BRANCH="$CI_COMMIT_REF_NAME"
elif [ ! -z "$LOCAL" ]; then
    BRANCH="local-test"
else
	exit 1
fi

# Default `TAG` to `false` if unset.
TAG="${TAG:-false}"
# Delay setting `nounset` until all used variables are set.
set -o nounset

echo "BUILD - Will now build Docker container"
docker build -t wwwil/skydock:$BRANCH .

echo "TEST - Will now test built Docker container"

function test {
    IMAGE_LINK=$1
    echo $IMAGE_LINK
    IMAGE_ZIP=$(basename $IMAGE_LINK)
    cd test/
    if [ ! -f "$IMAGE_ZIP" ]; then
       wget -nv $IMAGE_LINK
    fi
    unzip -o $IMAGE_ZIP
    cd ..
    docker run --privileged --rm \
      -e MOUNT=/test \
      -e SOURCE_IMAGE=/test/${IMAGE_ZIP%.zip}.img \
      -e SCRIPT=/test/test.sh \
      -e ADD_DATA_PART=true \
      -e EXPAND=100 \
      --mount type=bind,source="$(pwd)"/test,destination=/test \
      wwwil/skydock:$BRANCH
}

echo "TEST - Testing with Raspbian Stretch Lite 2018-10-11"
IMAGE_LINK=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-10-11/2018-10-09-raspbian-stretch-lite.zip
test $IMAGE_LINK

echo "TEST - Testing with RasPi OS Buster arm64 2020-05-28"
IMAGE_LINK=https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2020-05-28/2020-05-27-raspios-buster-arm64.zip
test $IMAGE_LINK

if [ "$TAG" != "false" ]; then
	# Only push an image if `TAG` is not false.
	echo "DEPLOY - Will now push Docker image to Quay.io repository as $TAG"
	echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin quay.io
	docker tag wwwil/skydock:$BRANCH quay.io/wwwil/skydock:$TAG
	docker push quay.io/wwwil/skydock:$TAG
fi
