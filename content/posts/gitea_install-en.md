---
title: "Gitea_install En"
date: 2025-09-08T18:50:04+03:00
draft: false
description: |
  Simplest setup for a Gitea service,
  deployed as a podman-systemd.unit (a.k.a. quadlet)
tags:
 - sys
---

Every infrastructure has a brain.

Sometimes it's an inventory platform that somebody wrote many years ago,
if you're unlucky it's one of those old CMDBs that works awfully, if you're 
lucky, today a good candidate is a git server.

The git server is one of the most versatile pieces of software that you can find around.
It has a small and simple core idea, but it does it so well and is so elegant, that it can be used as a lot of things.

The main purpose of a git server is to store a codebase for something, or a collection of scripts,
or a collection of notes, or automation workflows and IaaC stuff, or it could be used to 
store an installer and its dependencies, or to become the backend of some sort of cache.

Its ability to keep track of changes makes it an invaluable tool for a lot of use cases.

## Which git server?
There are many implementations around. There are ones with enterprise support and ones without,
ones that you can install on-prem or use as a SaaS, and you can even make your artisanal
git server fairly easily.

My pick is a project named Gitea, because it's lightweight and easy to deploy containerized,
it has a lot of interesting features and also for fact that I know a little the language in which it's written.

## Tutorial
We're gonna deploy a Gitea service inside a podman container, that 
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

### Install a Gitea podman-systemd.unit
The requirements for having a Gitea service locally are quite small compared to other services.

You'll need to decide which **version of the software** you want. If you don't know use the latest available version
by sticking to a specific (biggest) version tag, avoiding the tag latest:  
If latest points to 1.24, then your command line is:  
**podman pull docker.io/gitea/gitea:1.24**

Also if you do this by hand, then podman-systemd will already have the image in the local registry, 
so you save some time during the first run of the service.

The podman-systemd.unit files look like the following:  

```
# ~/.config/containers/systemd/blogposts__gitea.volume

[Volume]
VolumeName=blogposts__gitea
```

We need a named volume to attach on the **/data** path inside Gitea's container, if we want persistence.

```
# ~/.config/containers/systemd/blogposts__gitea.container

[Container]
Image=docker.io/gitea/gitea:1.24

ContainerName=blogposts__gitea

Environment=GITEA__security__INSTALL_LOCK=true

Environment=USER_UID=1000
Environment=USER_GID=1000
Environment="GITEA____APP_NAME=blog.jacket.lime's git server"

Environment=GITEA__server__DOMAIN=0.0.0.0
Environment=GITEA__server__HTTP_ADDR=0.0.0.0
Environment=GITEA__server__HTTP_PORT=3000

PublishPort=3333:3000
PublishPort=2222:22

Volume=blogposts__gitea.volume:/data
Volume=/etc/localtime:/etc/localtime:ro,z

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
```

We're exposing the following ports:  
  + **3333** - where the web app is exposed  
  + **2222** - where an ssh endpoint is exposed for an user to interact with its repos.  


Now after a bunch of calls to systemctl:  
```bash
systemctl --user daemon-reload
systemctl --user enable --now blogposts__gitea
```

You should see the web app coming up on this machine's ip on port 3333.  
You can either point a browser to it or just send curl and check that you have something coming back.

### Create the first user
**podman exec -it -u 1000 blogposts__gitea gitea admin user create --username andrew --password secret --email andrew@blog.jacket.lime --admin**

Then if you want you can also disable user registration, if you don't plan your gitea instance to be public.
**podman exec -it blogposts__gitea sed -i 's/DISABLE_REGISTRATION = false/DISABLE_REGISTRATION = true/' /data/gitea/conf/app.ini**


### Helpful troubleshooting commands
**journalctl --user -e -o json** - checks all the fields of a log record in the journal  
**journalctl --user _SYSTEMD_USER_UNIT=blogposts__gitea.service** - check logs only for that specific user unit  
**podman exec -it blogposts__gitea bash** - opens a shell inside the Gitea container. It has a lot of stuff inside.  
