FROM debian:stretch

RUN apt-get -y update && \
	apt-get -y install \
	wget \
	unzip \
	kpartx \
	qemu \
	qemu-user-static \
	binfmt-support \
	parted \
	dosfstools \
	xxd

WORKDIR /raspbian-customiser/

COPY customise.sh /raspbian-customiser/
COPY add-partition.sh /raspbian-customiser/
COPY mount.sh /raspbian-customiser/
COPY expand.sh /raspbian-customiser/

ENTRYPOINT /raspbian-customiser/customise.sh