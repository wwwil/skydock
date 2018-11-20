#!/bin/bash

set -e

echo "BUILD - Will now build Docker container"
docker build -t edwardotme/raspbian-customiser:$TRAVIS_BRANCH .

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
  --mount type=bind,source="$(pwd)"/test,destination=/test \
  edwardotme/raspbian-customiser:$TRAVIS_BRANCH
if [ $? -ne 0 ]; then
  exit 1;
fi

if [ $TRAVIS_BRANCH == "master" ]; then
  # For tag builds TRAVIS_BRANCH is set to the tag name
  echo "DEPLOY - Will now push Docker image to Docker Hub as latest"
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  docker tag edwardotme/raspbian-customiser:$TRAVIS_BRANCH edwardotme/raspbian-customiser:latest
  docker push edwardotme/raspbian-customiser:latest
elif [ ! -z $TRAVIS_TAG ]; then
  echo "DEPLOY - Will now push Docker image to Docker Hub as $TRAVIS_TAG"
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  docker tag edwardotme/raspbian-customiser:$TRAVIS_BRANCH edwardotme/raspbian-customiser:$TRAVIS_TAG
  docker push edwardotme/raspbian-customiser:$TRAVIS_TAG
fi
