FROM ubuntu:20.04 as build
ARG APP_VERSION=2021.03.22
RUN apt update && apt install -y wget build-essential libssl-dev && rm -rf /var/lib/apt/lists/*

# TODO "set -o pipefail "
RUN mkdir -p /opt && \
	cd /opt && \
	wget -O - http://www.live555.com/liveMedia/public/live.$APP_VERSION.tar.gz | tar -xzf - && \
	cd live && \
	./genMakefiles linux && \
	cd liveMedia && \
	# dirty workaround for "The remote endpoint is using a buggy implementation of RTP/RTCP-over-TCP" error
	sed -i 's/maxRTCPPacketSize = 1438/maxRTCPPacketSize = (512 * 1024)/' RTCP.cpp && \
	make && \
	cd ../groupsock && \
	make && \
	cd ../BasicUsageEnvironment && \
	make && \
	cd ../UsageEnvironment && \
	make && \
	cd ../proxyServer && \
	# lose the /proxyStream path
	sed -i 's/"proxyStream"/""/' live555ProxyServer.cpp && \
	sed -i 's/OutPacketBuffer::maxSize = 100000;/OutPacketBuffer::maxSize = (1024 * 1024);/' live555ProxyServer.cpp && \
	sed -i 's/(rtspServer->setUpTunnelingOverHTTP(80) || rtspServer->setUpTunnelingOverHTTP(8000) || rtspServer->setUpTunnelingOverHTTP(8080))/(rtspServer->setUpTunnelingOverHTTP(8080))/' live555ProxyServer.cpp && \
	make && \
	make install && \
	cd / && \
	rm -rf /opt/live


FROM ubuntu:20.04

RUN apt update && \
	apt install -y openssl && \
	rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin/live555ProxyServer /usr/local/bin/

USER 1000

EXPOSE 8080
EXPOSE 8554

ENTRYPOINT ["/usr/local/bin/live555ProxyServer", "-p", "8554"]

# use arguments to give original stream address:
# -t rtsp://192.168.1.10:8554