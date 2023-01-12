#!/bin/bash

CNAME="andrewdomain-blog"

isittherealready=$(podman ps | grep ${CNAME} | awk '{print $1}')  #:)
if [ ! -z "$isittherealready" ]
then
	echo
	echo "[!] braising already running '$CNAME' container"
	echo
	podman rm -f $isittherealready 1>/dev/null
fi

buildah bud -t andrewdomain/blog . && podman run --name $CNAME -d -p 80:80 andrewdomain/blog:latest
