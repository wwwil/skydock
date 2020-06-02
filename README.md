# Skydock

[![Build Status](https://travis-ci.com/lumastar/skydock.svg?branch=master)](https://travis-ci.com/lumastar/skydock)

*Skydock* is a tool to customise Raspberry Pi OS images using Docker.

It's designed to enable automated creation of customised Raspberry Pi OS images
for easy packaging and deployment of software.

## Features

- Run custom scripts inside the Raspberry Pi OS for configuration, software
  installation, and adding files.
- Expand the root file system for additional capacity.
- Add a `FAT32` format data partition to the end of the image.

## Supported OSes

This tool should work with any Raspbian or RasPi OS image, it is currently
tested with Raspbian Stretch Lite and RasPiOS Buster arm64. In general it should
work with any Debian based OS targeting `arm` or `arm64` architecture. However
there are known networking issues with Ubuntu 20.04, and no other OSes have been
tested.

More OSes for a wider range of devices may be added in future.

## Usage

Pull the latest Skydock Docker image from the
[Quay.io repository](https://quay.io/repository/lumastar/skydock)
with:

```
$ docker pull quay.io/lumastar/skydock:v0.3.0
```

A version tag should be given explicitly. Notes for each release can be found on
the [GitHub releases](https://github.com/lumastar/skydock/releases) page.

Run Skydock like so:

```
$ docker run --privileged \
    -e SOURCE_IMAGE=/resources/raspbian-lite.img \
    -e MOUNT=/resources/customisations \
    -e SCRIPT=/customisations/customise.sh \
    --mount type=bind,source=$(pwd)/resources,destination=/resources \
    lumastar/skydock:v0.3.0
```

- `SOURCE_IMAGE` is the Raspberry Pi OS image to customise.
- `MOUNT` is a directory to mount inside the image for scripts and other files.
- `SCRIPT` is the script to run inside the image. This must be inside the
  `MOUNT` directory.

These resources must also be mounted into the Skydock Docker container. The
`--privileged` option is required to allow Skydock to create loop devices.

### Data Partition

A `FAT32` format data partition can be added to the end of the `.img` if
`ADD_DATA_PART` is set to `true`. The partition will be `64Mib` in size,
labelled `DATA`, and mounted at `/data`. The `/etc/fstab` and `/boot/config.txt`
files will be updated with correct `PARTUUID`s.

```
$ docker run --privileged \
    ...
    -e ADD_DATA_PART=true \
    ...
    lumastar/skydock:v0.3.0
```

This partition can be helpful when writing the `.img` to an SD card in macOS
and Windows as data files can be placed there.

### Expanding Main Partition

The main Raspbian partition can be expanded using the `EXPAND` environment
variable. This will add the specified number of `Mib` to the end of the second
partition before the data partition is added. For example,
the main partition can be expanded by `200Mib` like so:

```
$ docker run --privileged \
    ...
    -e EXPAND=200 \
    ...
    lumastar/skydock:v0.3.0
```

This can be helpful to add more space when installing large applications.

## CI/CD

Travis is used to automatically build the Docker image and run tests.
For tagged builds it also pushes the image to the registry on Quay.io.

GitLab CI is also used to build and test the image. This is because the two
CI/CD systems seemed to handle loop devices differently. As Skydock is used by
projects in both environments it is important that both are functional.
