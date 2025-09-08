---
title: "Alloy_install En"
date: 2025-09-08T09:26:09+03:00
draft: false
description: |
  Simplest setup for a Grafana Alloy service,
  deployed as a podman-systemd.unit (a.k.a. quadlet)
tags:
 - sys
---

There are cases in which you want to hook an application instance, platform,
hardware or whatever, into your collector of whatever.

It may happen that your collector of whatever needs clients to speak a certain protocol,
that they may not know. So in that case the only way is to put something in between to translate.

Grafana Alloy is a distribution of something called OpenTelemetry Collector, which in turn 
enables you to create pipelines that can ingest, transform and forward metrics, logs, traces, ... into
stuff like our Loki or our Prometheus that we set up in previous articles.

## Tutorial
We're gonna deploy an Alloy service inside a podman container, that 
is defined as a podman-systemd.unit and managed as a user service unit.

### Assumptions
 + A *containers.blog.jacket.lime* machine at 192.168.126.12
 + there is no local firewall active on the *containers* machine
 + cloud-user on the *containers* machine
 + there is a working Loki instance on the same host
 + the Loki instance is already hooked to Grafana
 
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

### Install an Alloy podman-systemd.unit
You'll need to decide which **version of the software** you want. If you don't know use the latest available version
by sticking to a specific (biggest) version tag, avoiding the tag latest:  
If latest points to v1.10.2, then your command line is:  
**podman pull docker.io/grafana/alloy:v1.10.2**

Also if you do this by hand, then podman-systemd will already have the image in the local registry, 
so you save some time during the first run of the service.

Alloy also needs a configuration file, in order to create the pipeline that will receive
your logs over http, transform them by giving them labels, and send them to Loki.

Once again I sacrificed tidiness by putting
the file in the same directory as the rootles podman/systemd units, for the sake of simplicity

Mind that **loki.source.api**, **loki.process** and **loki.write** are *"components"* in Grafana Alloy,
that you are borrowing and configuring with those blocks that you are defining between curly braces
(similar to how Terraform does things 🤮🤢)

```
# ~/.config/containers/systemd/etc-alloy/alloy.yml

logging {
  level = "info"
  format = "logfmt"
}

loki.write "to_loki" {
  endpoint {
    url = "http://blogposts__loki:3100/loki/api/v1/push"
  }
}

loki.process "labels" {
  stage.json {
    expressions = {"extracted_service" = "app"}
  }

  stage.labels {
    values = {
      "job" = "extracted_service",
      "service_name" = "extracted_service",
    }
  }
  
  forward_to = [loki.write.to_loki.receiver]
}

loki.source.api "http_logs" {
  http {
    listen_address = "0.0.0.0"
    listen_port = 12346
  }

  forward_to = [loki.process.labels.receiver]
}
```

It basically works like this:  
  + By default Alloy exposes port 12345 for its own metrics and health and other stuff.  
  + You can define an arbitrary number of endpoint to bind to, just like we do with **loki.source.api "http_logs"**  
  + You can pipe the input of those to processors such as **loki.process "labels"** that in turn gives your data labels and stuff.  
  + You can pipe the result to a service such as (in this case for logs) Loki, via the **loki.write "to_loki"** component  

The end podman-systemd.unit file looks like the following:  
```
# ~/.config/containers/systemd/blogposts__alloy.container

[Unit]
Description=blog.jacket.lime's Alloy quadlet

[Container]
ContainerName=blogposts__alloy

Image=docker.io/grafana/alloy:v1.10.2

Volume=./etc-alloy/alloy.yml:/etc/alloy/config.alloy:ro,z

PublishPort=0.0.0.0:12345:12345
PublishPort=0.0.0.0:12346:12346

Network=blogposts.network

Exec=run --server.http.listen-addr=0.0.0.0:12345 --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
```

Here we've mounted the config file for Alloy in a path inside the container, that we are
then referencing with in the *Exec* directive, that defines the command line for the app inside the container.

We're putting Alloy inside the blogposts network, 
as we need other containerized service on the same host to see it.

We're exposing port 12345 as it shows metrics and the Alloy web app, 
and port 12346 as it is the endpoint that receives logs, that we can then test with curls.

...

Now after a bunch of calls to systemctl:  
```bash
systemctl --user daemon-reload
systemctl --user enable --now blogposts__alloy
```

We should have an Alloy service ready on http://localhost:12345 
and ready to ingest logs on http://localhost:12346:  
**curl -v http://localhost:12346/ready && echo**

### Verify log ingestion
Testing if we're able to send logs to alloy is easy: instead of the classical *logger* cli, 
we're sending a curl to the **/loki/api/v1/raw** endpoint with some arbitrary data, like so:

```bash
curl -X POST localhost:12346/loki/api/v1/raw -d '{"app": "myapp", "level": "info", "message": "hello from curl"}'
curl -X POST localhost:12346/loki/api/v1/raw -d '{"app": "myapp", "level": "info", "warn": "something is happening"}'
curl -X POST localhost:12346/loki/api/v1/raw -d '{"app": "myapp", "level": "info", "crit": "something bad has happened"}'
```

The response should be silent. Append a -v to curl should show a status code of 204 (No content).

Assuming that you already made the connection from Loki to Grafana, as described in an earlier post,
you have just sent raw logs to Alloy, that in turn has sent them to Loki, that in turn is queried from Grafana.
So at this point you should be able to see it in the grafana web app at **Home > Drilldown > Logs**

![drilldown alloy logs](/posts/images/alloy_grafana_drilldown.png "drilldown alloy logs")

### Helpful troubleshooting commands
**journalctl --user -e -o json** - checks all the fields of a log record in the journal  
**journalctl --user _SYSTEMD_USER_UNIT=blogposts__alloy.service** - check logs only for that specific user unit  
**nc -vz -w 1 localhost 12345** - check if port 12345 is open  
**curl -v http://localhost:12345/metrics**  - if you see metrics here, it means we're online  
**curl -v http://localhost:12346/ready && echo**  - if you see "ready", it means it can receive logs
