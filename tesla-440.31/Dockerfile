FROM debian:stretch-slim

RUN set -e \
	&& apt-get update \
	&& apt-get install -y -q --no-install-recommends \
		systemd \
		pciutils \
		curl \
	&& apt-get -y clean \
	&& apt-get -y autoremove

COPY run.sh /run.sh
COPY files/* /nvidia-device-plugin/

CMD [ "/bin/bash", "/run.sh" ]
