#!/bin/bash

docker run -d \
    --name pihole \
    -p 53:53/tcp -p 53:53/udp \
    -p 80:80 \
    -e TZ="Europe/Amsterdam" \
    -v "/home/victor/docker_data/pihole/etc-pihole:/etc/pihole" \
    -v "/home/victor/docker_data/pihole/etc-dnsmasq.d:/etc/dnsmasq.d" \
    --dns=127.0.0.1 --dns=1.1.1.1 \
    --restart=unless-stopped \
    --hostname pihole \
    -e VIRTUAL_HOST="pi.hole" \
    -e PROXY_LOCATION="pi.hole" \
    -e FTLCONF_LOCAL_IPV4="127.0.0.1" \
    pihole/pihole:latest

# change password
docker exec -it pihole pihole -a -p

docker run -d \
    --name portainer \
    -p 8000:8000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/victor/docker_data/portainer:/data \
    --restart=no \
    portainer/portainer-ce:2.21.5

docker run -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
