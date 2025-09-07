---
title: "Loki_install En"
date: 2025-09-07T16:41:28+03:00
draft: false
description: |
  Simplest setup for a Loki service,
  deployed as a podman-systemd.unit (a.k.a. quadlet)
tags:
 - sys
---

The more sources you have generating logs that you need to collect, 
visualize, and manage and so on, the more it becomes a necessity to have a central
location where all logs converge, so that then it becomes much easier
to perform operations from visualization to backup.

If you don't see the value of doing so in your home lab, you can do that
just for the sake of learning, because it is a real-world scenario need.

I'm using Loki because, as the project itself states, it is much cheaper than other alternatives.
And from my direct experience, it is quite so.

Loki by itself is not a complete log management solution, but you can build one based on it.  
At its core, Loki is only responsible for ingesting, storing and processing queries on logs. 
Then you will need other components such as Grafana to be able to (e.g.) add visualization to your log aggregation platform.

## Assumptions
 + A *containers.blog.jacket.lime* machine at 192.168.126.12
 + there is no local firewall active on the *containers* machine
 + cloud-user on the *containers* machine
 
Please note also that I assume that **this setup is used only inside a closed lab environment**, 
as the cofiguration could be polished more to make the services more maintainable and secure.

## Ingredients
**dnf install podman**

Also make sure that you have the one of the directories in the **podman rootless unit search path** in place:  
```bash
$ mkdir -pv ~/.config/containers/systemd/
```

Whenever there's something that you don't know or you want to learn more about, 
your first point of reference should be: `man 5 podman-systemd.unit`

Also it would be useful to add a **~/.config/containers/systemd/blogposts.network** file
with the following content:  
```
[Network]
NetworkName=blogposts-network
```

This way, after a `systemctl --user daemon-reload`, you'll have a blogposts network that you can 
share between your quadlets, so that they can see each other and resolve each other's names.  
You can see the network in the output of `podman network list`.

## Tutorial
We're gonna deploy a Loki service inside a podman container, that 
is defined as a podman-systemd.unit and managed as a user service unit.

### ### Install a Loki podman-systemd.unit
You'll need to decide which **version of the software** you want. If you don't know use the latest available version
by sticking to a specific (biggest) version tag, avoiding the tag latest:  
If latest points to 3.5.4, then your command line is:  
**podman pull docker.io/grafana/loki:3.5.4**

Also if you do this by hand, then podman-systemd will already have the image in the local registry, 
so you save some time during the first run of the service.

```
# ~/.config/containers/systemd/blogposts__loki.container

[Unit]
Description=blog.jacket.lime's Loki quadlet

[Container]
ContainerName=blogposts__loki

Image=docker.io/grafana/loki:3.5.4

PublishPort=0.0.0.0:3100:3100

Network=blogposts.network

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
```

Now to inform systemd that we've added a user unit and start it:  
**systemctl --user daemon-reload**
**systemctl --user enable --now blogposts__loki**

### Check if it works
The following is to ensure that you have something listening on port 3100:  
**nc- vz -w 1 localhost 3100**

This curl sends a log message to loki
```bash

curl -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [{
      "stream": { "job": "demo" },
      "values": [[ "'$(date +%s%N)'", "hello loki" ]]
    }]
  }'

```

This curl tries to get back the "demo" job, if there is one in loki, the grep will highlight it to you.  
```bash
curl -G --data-urlencode 'query={job="demo"}'   "http://localhost:3100/loki/api/v1/query_range" | grep -i "hello loki"
```

### What to do from here
As you already saw above, there is a specif data structure that loki expects from its log messages, 
and not all the applications log the loki format.
It may be required to put something in the middle. Something like a **Grafana Alloy**.

The same way, Loki is quite useless as a log analyzer, without something to visualize stuff.
This role is played by Grafana.

Both Alloy and Grafana are separate projects with broader use cases. 
It makes sense to keep this post short and cover each of those in separate posts.
