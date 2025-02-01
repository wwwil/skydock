FROM debian:bullseye

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

WORKDIR /skydock/

COPY customise.sh /skydock/
COPY add-partition.sh /skydock/
COPY mount.sh /skydock/
COPY expand.sh /skydock/

ENTRYPOINT /skydock/customise.sh