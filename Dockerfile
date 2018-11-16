FROM debian:stable

RUN apt-get -y update && \
	apt-get -y install \
	wget unzip kpartx qemu qemu-user-static binfmt-support

WORKDIR /build/

COPY build.sh /build/
