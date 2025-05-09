---
title: "Object Storage on vps (a.k.a. Virtual Private Server)"
date: 2024-01-07T21:33:38+02:00
draft: true
description: |
  How to create a tiny object storage without raising the bill
tags:
 - sys
 - linux
 - containers
---

Different cloud providers bill it in different ways. Most of my stuff I deploy it on Linode, who charges $5/month for some GBs
and then an extra $0.002 for extra GB. Then Oracle Cloud offer it for free, but I wasn't able to understand their UI to find the 
object storage. Then Vercel offer it for free on the developer tier, but then you have to install some sdk to access it? Nuts 🤷

So I figured.. how much space do I have on the local filesystem of my tiny nanode?  
> Of course in this scenario any backup/restore and DR strategy goes to the trash

```
[cloud-user@garage01-andrewdomain ~]$ df -h | grep -v tmpfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda         25G  2.3G   21G  10% /
```

Nice.

## How to set up limits
We don't want to have our little nanode full of (in my case) qrcode images.. so it would be wise to set up a limit
around the "disk" that we're gonna give our storage server.

To craft an ISO file, the same way as people do it to make the ISO archives that you burn on a USB device
to install your Linux distro, you just need a handful of commands.

```
$ Don't remember...
```

## Mounting it persistently

## The container image for the object storage server logic

# Finale
Then I saw that Vercel actually gives you the endpoints. So I could've basically interact with their storage via http... Oh, well.

# BONUS
SQL databases are no file servers. They are not optimized to serve byte-objects.  
Of course technically you could use the `bytea` object in (e.g.) Postgres, but it smells and looks bad.

So you either keep it in your filesystem (looks bad, backup plans look worse, you don't scale), or you do it the
modern-world way and put it in a specialized place that exposes and endpoint that you can talk to, to share objects (a.k.a. blobs),
i.e. an object storage server, that exposes a REST API endpoint and is responsible for all the sharing/archiving logic, so
you don't have to.
