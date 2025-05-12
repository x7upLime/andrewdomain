---
title: "artisanal Object Storage"
date: 2025-05-10T17:31:12+02:00
draft: false
description: |
  How to create an object storage without raising the cloud bill
tags:
 - sys
 - linux
 - containers
---

To add the qrcode generation feature for an app that I'm building, I would need to store the images somewhere, so
that the user can retrieve them without computing them every time. To do that, I would need an **object-storage**.

Different cloud providers bill it in different ways. Most of my stuff I deploy it on Linode, 
that charges $5/month for some GBs of object storage and then an extra $0.002 for extra GB.
Then Oracle Cloud offer it for free, but I wasn't able to understand their UI to find the 
object storage. Then Vercel offer it for free on the developer tier, but then you have to install some sdk to access it? Nuts 🤷

So I figured.. how much space do I have on the local filesystem of my tiny nanode?  

```
[cloud-user@garage01-andrewdomain ~]$ df -h | grep -v tmpfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda         25G  2.3G   21G  10% /
```

Nice.

## How to set up limits
We don't want to have our little nanode full of qrcode images.. so it would be wise to set up a limit
around the "disk" that we're gonna give our new object-storage server.

When you build an ISO file, like the one that you burn on a USB device
to install your Linux distro, you usually allocate some disk space to a file and create a loop device that you then
use as a mount point to fill it with content.  
We're gonna use the same principle.

```
$ touch ./nasty 
$ sudo dd if=/dev/zero of=./nasty bs=1KiB count=3000000
```

Now, to use our newly created file as a loop device, we can spawn a block device whose name is like /dev/loopX,
provided that it is not occupied yet.

To check for any loop device in use (empty output is definitely possible):
```
$ losetup --list
```

To use our newly created file as a loop device, we could use  
`$ sudo losetup -f ./nasty`, where *-f* means "find first available" 
or we can choose a name (provided that it is not occupied) with the following command line.
```
$ sudo losetup /dev/loop0 ./nasty
```

Our /dev/loop0 will show up in the output of `lsblk`, and will be usable
as any other block device on the system.

## Mounting it persistently
Now that we have a device of a specific size, we can make a filesystem on it and mount it.

First we create the filesystem on the loop device, and we place the definition of the mount on /etc/fstab.
```
$ sudo mkfs.xfs /dev/loop0
$ echo "" | sudo tee -a /etc/fstab
$ echo "# Artisanal Object Storage" | sudo tee -a /etc/fstab
$ echo "UUID=$(lsblk --output=UUID /dev/loop0 | tail -n 1) /mnt/objs-artisanal xfs defaults 0 0" | sudo tee -a /etc/fstab
$ sudo systemctl daemon-reload
```

Now we can verify that the mounts in the fstab file work correctly, and if they do, we move forward...
```
$ sudo mount -a
$ df -h | grep loop0
```

## The container image for the object storage server logic
I chose minio as the object-storage server. For no particular reason.

To run the minio container available at *docker.io/minio/minio*, one could either 
```
$ podman run -it -p 9000:9000 --rm -v /mnt/objs-artisanal/:/data:z docker.io/minio/minio server /data
```

**or even better**, manage it as a systemd service using the podman systemd units (**man 5 podman-systemd.unit**)

So we should first think of credentials for this service and save them somewhere.  
Then we could create a podman secret like so:
```
$ podman secret create minio-pwd ./miniopwd
```

That secret will be mounted inside the container, as an env variable, 
one that the app inside the container knows and watches.

The path for podman systemd units is: **~/.config/containers/systemd/**  
and we want to put the following content inside of the file **minio.container**
```
# ~/.config/containers/systemd/minio.container

[Container]
Image=docker.io/minio/minio:RELEASE.2025-04-22T22-12-26Z

Secret=minio-usr,type=env,target=MINIO_ROOT_USER
Secret=minio-pwd,type=env,target=MINIO_ROOT_PASSWORD

Network=short.network
Volume=/mnt/objs-artisanal:/data:z
PublishPort=9000:9000

Exec=server /data

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
```

Then we must inform systemd of the change in available user units:
```
$ systemd --user daemon-reload
```

Then if we configured everything correctly, we should have a working container:
```
$ systemctl --user start minio
$ journalctl -e    # shows system logs
$ ss -tlpn         # shows listening tcp sockets
```

Now.. provided that minio does not change the location of [this document](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart),
you could read it to understand how to acquire the `mc` command line tool (a.k.a. minio client).

Then you could do something like this (if you have your password in the env var *$secretmini*)
```
$ mc alias set artisanal http://127.0.0.1:9000 <username> $secretmini
```

Now you could test if everything works with
```
$ mc admin info artisanal
```

Notice how until now.. you never needed root privileges to spawn the minio service.

## Write to it
For somebody that does not know much about an object storage...

First we create a bucket
```
$ mc mb artisanal/trashcan
```

then create some content
```
$ touch ./trash
$ dd if=/dev/urandom of=./trash bs=1MB count=100
```

and upload it
```
$ mc cp ./trash artisanal/trashcan
```

*Green as Success!*
![Green as Success](/posts/images/trashcan_upload.png "green as success")

Then you can always take it out!
```
$ mc ls artisanal/trashcan
$ mc cp artisanal/trashcan/trash ./more-trash
```

# Finale
One would not want to use this solution for something that needs be reliable..  
On this kind of setup, backup/restore and disaster recovery (a.k.a. DR) procedures are not considered.

When you use a cloud provider's object storage service, 
they take care of the backup/restore and DR procedures for you.
Plus they make the service highly available to you and fast to access on the selected regions,
all things of the infra world that are complex and cost money.

Am I gonna use this dirtyness for a project?  
*Yes, definitely.*

Well.. let's say a project and not a product.

# BONUS
SQL databases are no file servers. They are not optimized to serve byte-objects.  
Of course technically you could use the `bytea` object in (e.g.) Postgres, but it smells and looks bad.

So you either keep it in your filesystem (looks bad, backup plans look worse, you don't scale), or you do it the
modern-world way and put it in a specialized place that exposes and endpoint that you can talk to, to share objects (a.k.a. blobs),
i.e. an object storage server, that exposes a REST API endpoint and is responsible for all the sharing/archiving logic, so
you don't have to.
