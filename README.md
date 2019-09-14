# raspbian-customiser

[![Build Status](https://travis-ci.com/lumastar/raspbian-customiser.svg?branch=master)](https://travis-ci.com/lumastar/raspbian-customiser)

*raspbian-customiser* is a tool to customise a Raspbian image.
It works by taking an existing Raspbian `.img` image,
mounting it as a loop device,
and running commands in the Raspbian environment using *chroot* and *qemu*.

This enables automated creation of the customised Rasbian images,
and is designed to be used in CI/CD pipelines to package software
into a pre-configured image which can easily be deployed to a Raspberry Pi.

It can also append a FAT32 format data partition to the `.img`,
and add this to Raspbian's `/etc/fstab` for automatic mounting.
This is to provide an easy place to drop data files when writing the `.img`
to SD cards that its compatible with all operating systems.

## Usage

### Image

*raspbian-customiser* is packaged as a Docker image.
The latest stable version can be pulled from the
[Quay.io repository](https://quay.io/repository/lumastar/raspbian-customiser)
with:

```
docker pull quay.io/lumastar/raspbian-customiser:v0.2.3
```

A version tag should be given explicitly.
Released versions with notes can be found in the releases page on GitHub.

### Running

To use *raspbian-customiser* first group required resources in a directory.
This must include the source `.img`,
and a script to run inside the Raspbian environment.
It can also include other assets such as sub scripts
and data files to be copied over.

This directory must be mounted as a Docker volume when running the container.

The source `.img` is specified with `SOURCE_IMAGE`.
This is the Raspbian environment that the scripts will run in.

The directory containing resources to use inside the Raspbian environment
must be specified using the `MOUNT` environment variable.
It will be mounted at the root of the Raspbian environment.

The script to run can be specified using the `SCRIPT` environment variable.
This script must be inside the `MOUNT` directory.

```
$ docker run --privileged \
    -e SOURCE_IMAGE=/resources/raspbian-lite.img \
    -e MOUNT=/resources/customisations \
    -e SCRIPT=/customisations/customise.sh \
    --mount type=bind,source=$(pwd)/resources,destination=/resources \
    lumastar/raspbian-customiser:v0.2.3
```

### Data Partition

A FAT32 format data partition can be added to the end of the `.img`
if `ADD_DATA_PART` is set to `true`.
The partition will be `64MiB`, labelled `DATA`, and mounted at `/data`.
The `/etc/fstab` and `/boot/config.txt` files will be updated
with correct `PARTUUID`s.

```
$ docker run --privileged \
    ...
    -e ADD_DATA_PART=true \
    ...
    lumastar/raspbian-customiser:v0.2.3
```

This partition can be helpful when writing the `.img` to an SD card in macOS
and Windows as data files can be placed there.

### Expanding Main Partition

The main Raspbian partition can be expanded
using the `EXPAND` environment variable.
This will add the specified number of megabytes (Mib)
to the end of the second partition before the data partition is added.
For example,
the main partition can be expanded by 200Mib like so:

```
$ docker run --privileged \
    ...
    -e EXPAND=200 \
    ...
    lumastar/raspbian-customiser:v0.2.3
```

This can be helpful to make more space in Raspbian for installing applications.

## CI/CD

Travis is used to automatically build the Docker image and run tests.
For tagged builds it also pushes the image to the
[Quay.io repository](https://quay.io/repository/lumastar/raspbian-customiser).

GitLab CI is also used to build and test the image.
This is because the two CI/CD systems seem to handle loop devices differently.
As the raspbian-customiser is used by projects in both environments
it is important that both are functional.
