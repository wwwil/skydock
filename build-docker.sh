#!/bin/bash

docker build -t rasp-mod .
docker run --rm --privileged rasp-mod \
	bash -e -o pipefail -c \
	"chmod +x build.sh && ./build.sh"
