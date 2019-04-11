# raspbian-customiser

[![Build Status](https://travis-ci.com/lumastar/raspbian-customiser.svg?branch=master)](https://travis-ci.com/lumastar/raspbian-customiser)

Tool to customise a Raspbian image by mounting it as a loop device and running commands in it with *chroot* and *qemu*. This enables automated creation of the customised Rasbian images, and is designed to use in CI/CD pipelines to package software into a pre-configured image which can easily be deployed to a Raspberry Pi.

*raspbian-customiser* is packaged as a Docker image. The latest stable version can be pulled from the repo with:

```
docker pull edwardotme/raspbian-customiser:latest
```

To use it, group any scripts and asset files in a directory. Then mount this directory as a Docker volume when running the container.

To mount the directory in the Raspbian environment specify it's path with the `MOUNT` environment variable.

To specify a script to run in the Raspbian environment use the `SCRIPT` environment variable. This should point to your main script in the mounted volume which can apply whatever modifications you require and copy any asset files from the volume to their desired location.

The source image file can also be specified with `SOURCE_IMAGE`. This should be the path to an `.img` file, also found in your mounted volume.

A FAT32 format data partition can be added to the end of the image if `ADD_DATA_PART` is set to `true`. This partiton can be helpful when writing the image to an SD card in macOS and Windows as data files can be placed there. The partition will be `64MiB`, labeled `DATA`, and mounted at `/data`. The `/etc/fstab` and `/boot/config.txt` files will be updated with correct `PARTUUID`s.

```
docker run --privileged \
-e MOUNT=/customisations \
-e SOURCE_IMAGE=/customisations/raspbian-lite.img \
-e SCRIPT=/customisations/customise.sh \
-e ADD_DATA_PART=true \
--mount source=customisations,destination=/customisations \
edwardotme/raspbian-customiser:latest
```
