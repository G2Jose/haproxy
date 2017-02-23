FROM haproxy:1.7
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
RUN groupadd haproxy && useradd -g haproxy haproxy
RUN mkdir -p /var/lib/haproxy/run/haproxy/