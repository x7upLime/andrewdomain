---
title: "Prometheus_install En"
date: 2025-09-07T01:32:58+03:00
draft: false
description: |
  Simplest setup for a Prometheus and node-exporter services,
  deployed as podman-systemd.units (a.k.a. quadlets)
tags:
 - sys
---

Say you want to keep under observation things like a platform, operating system,
how many times do you go to the bathroom during office hours, ...
for all those needs and many more, there are specific types of data that are better
suited to represent, store and process this kind of information.

Prometheus defines **counters**, **gauges** and **histograms** as native metric types, 
that respectively represent values that increase, that can go up/down, and samples of observations.

From those very simple types you can model many things such as the latencies in your pings
to a node on a network, memory consumption, times you do something, ...

## What is Prometheus
Prometheus is not one atomic thing, there are different components.

### TSDB
Depending on the type of data, there are better ways to store it.

 + SQL databases work well for relational data
 + NoSQL works for non-relational data
 + Key-value stores for fast retrieval of simple data models
 
There are many other examples, and the metric data types proposed above make no exceptions, 
hence a very important piece of the Prometheus platform is the TSDB that it packs.

TSDB stands for **Time-Series Database** and it is a kind of database
that is optimized for timestamped metric data.

### Query Language
PromQL, which stands for Prometheus Query Language is used to retrieve and manipulate the timeseries 
data stored in the TSDB, just like you use the Structured Query Language for your SQL-compatible database.

## Tutorial
We're gonna deploy a Prometheus service inside a podman container, that 
is defined as a podman-systemd.unit and managed as a user service unit.

### Assumptions
 + A *containers.blog.jacket.lime* machine at 192.168.126.12
 + there is no local firewall active on the *containers* machine
 + cloud-user on the *containers* machine
 
Please note also that I assume that **this setup is used only inside a closed lab environment**, 
as the cofiguration could be polished more to make the services more maintainable and secure.

### Ingredients
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

### Install a Prometheus podman-systemd.unit
The requirements for having a Prometheus service locally are quite small compared to other services.

You'll need to decide which **version of the software** you want. If you don't know use the latest available version
by sticking to a specific (biggest) version tag, avoiding the tag latest:  
If latest points to v3.5.0, then your command line is:  
**podman pull docker.io/prom/prometheus:v3.5.0**

Also if you do this by hand, then podman-systemd will already have the image in the local registry, 
so you save some time during the first run of the service.

Then you need to decide if you want to save the metrics that Prometheus collects or not,
and this is done by attaching or not a volume (named volume in my case) to the */prometheus* path inside the container.

Another useful thing to do is to mount the configuration file, instead of baking it in the image.
This way the time to add a change is much smaller, compared to rebuilding the image every time.  
I opted for a slightly dirty approach of putting an *./etc-prometheus/* folder inside the podman rootless unit search path, 
with a prometheus.yml config file inside, for the benefit of having everything in the same place.  
For now it only contains itself as a scraping target.  
```
# ~/.config/containers/systemd/etc-prometheus/prometheus.yml

global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'myprometheus'
    static_configs:
      - targets: ['localhost:9090']

```

The podman-systemd.unit file looks like the following:  
```
# ~/.config/containers/systemd/blogposts__prometheus.container

[Unit]
Description=blog.jacket.lime's Prometheus quadlet

[Container]
ContainerName=blogposts__prometheus

Image=docker.io/prom/prometheus:v3.5.0

Environment=TZ=Europe/Bucharest

Volume=blogposts__prometheus.volume:/prometheus
Volume=./etc-prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:z,ro

PublishPort=0.0.0.0:9090:9090

Network=blogposts.network

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
```

Here we're both using the blogposts-network container network, because later we will add another component
that needs to be visible to Prometheus, and exposing Prometheus on port 9090 on all interfaces, because in the future
other services will need to contact Prometheus on this machine's IP.

Now after a bunch of calls to systemctl:  
```bash
systemctl --user daemon-reload
systemctl --user enable --now blogposts__prometheus
```

You should see something coming up on this machine's ip on port 9090.  
You can either point a browser to it or just send curl and check that you have something coming back.

### Adds os monitoring via node-exporter
So far our Prometheus instance only monitors itself, as you can see from 
**Status > Target Health**.

It is worth mentioning again that at its core Prometheus packs a TSDB, then it has a query language,
some very minimal features for visualizing and alerting and so on... 
The metric export capabilities should come from elsewhere.

There is another project called **node-exporter** that does exactly that: it is installed as a container
on an operating system, it mounts relevant paths and generates metrics that are exposed on an endpoint that
Prometheus can query.

The container image can be found on public registries such as Docker Hub. Again, try to point to the latest but not "latest" tag:  
**podman pull docker.io/prom/node-exporter**

Its podman-systemd.unit definition looks like the following:  
```
# ~/.config/containers/systemd/blogposts__node-exporter.container
[Unit]
Description=node-exporter on the containers machine

[Container]
ContainerName=blogposts__exporter

Image=docker.io/prom/node-exporter:v1.9.1

PublishPort=127.0.0.1:9100:9100

Network=blogposts.network

Volume=/proc:/host/proc:ro
Volume=/sys:/host/sys:ro
Volume=/:/rootfs:ro

Exec=--path.procfs=/host/proc
Exec=--path.sysfs=/host/sys
Exec=--path.rootfs=/rootfs

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
```

Here we're exposing the metrics on port 9100 of localhost. 
This still needs to be placed in a network that the Prometheus container has access to (*blogposts-network*),
as localhost in the container world does not look the same as in the "normal" world.

Other than that, in order to see meaningful details about the operating system around the node-exporter container,
you need to mount the /proc, /sys, and / paths into the container, and indicate the mount point via flags to the node-exporter process.

At this points you can add this scrape to the Prometheus config, that now
should look like the following:
```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'myprometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'myexporter'
    static_configs:
      - targets: ['blogposts__exporter:9100']
```

start the node-exporter container:  
```bash
systemctl --user daemon-reload
systemctl --user start blogposts__node-exporter.service
```

and restart Prometheus:  
```bash
$ systemctl --user restart blogposts__prometheus
```

At this point, navigating to Prometheus's web gui, you should be able to go to **Status > Target health**
and see something like the following:

![Prometheus scraping targets](/posts/images/prom_scrape_targets_tutorial.png "Prometheus scraping targets")

### Helpful troubleshooting commands
**journalctl --user -e -o json** - checks all the fields of a log record in the journal  
**journalctl --user _SYSTEMD_USER_UNIT=blogposts__prometheus.service** - check logs only for that specific user unit  
**podman exec -it blogposts__prometheus sh** - opens a shell inside the Prometheus container. It has netcat inside  
**nc -vz -w 1 blogposts__exporter 9100** - check if port 9100 on host blogposts__exporter is open  
