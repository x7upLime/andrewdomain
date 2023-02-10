---
title: "notes on `Rootless`"
date: 2023-02-06T11:44:12+02:00
lastmod: 2023-02-10T17:23:42+02:00
draft: false
description: | 
  mainly taking notes about different rootless-mechanism 
  implementations in buildah, podman and rootlesskit.
  The level is: what's rootless/how does it even work.
tags: 
 - containers
 - golang
 - rootless
 - exploration
---

Rootless is one big deal in the container-new-world-order; was one of podman's
most captivating features.. then everyone seem to have moved to(supported) rootless.  
Community efforts were made to demistify the rootless mechanism,
then everyone was adding support to rootless...
But how does it work? Does it work only for containers?

Of course it doesn't work only for containers.. the whole rootless-thingy relies on the namespaces
mechanism, which is something that lives in the linux kernel(maybe other kernels as well.. I don't know.),
so as long as your kernel supports it.. you can be rootless while doing whatever you want.

The people that made the most efforts to explain/adopt rootless were the container-people, so most 
documentation come from that world, and if you decide you don't have nothing to do with containers,
you might just lose that train.

In regard of "how does it work"..  
that's easy: you fork a generic child process, and while you do that, you tell your kernel that you want that process
to lose some resources it shares with its parent process(effectively creating a new namespace), so that that child process
is(to the degree you desire) isolated to the other processes in terms of access to resources.  
It has been decided that, in that **unshared**('cause you know.. when forking, child shares parent's resources..) context, it is
safe to let a process think it has root capabilities, 
i.e. Giving him actual root capabilities to play with the toys it's got (not many if isolated).

A simple and very teachful example is give by Liz Rice in this fantastic talk: 
[Rootless Containers from Scratch](https://www.youtube.com/watch?v=jeTKgAEyhsA), and in tandem with her other 
work on containers from scratch in this [github repo](https://github.com/lizrice/containers-from-scratch/blob/master/main.go),
you pretty much got everything you need to quickstart your adventure inside the container world.

Of course you've noticed that the structure of those go exmaples on how to work with rootless container,
is rather mazy.. that's why everybody says that rootles setup requires some more complex logic...

The obstacle is the way in which namespace-attach occurs.  
The kernel offers a bunch of syscalls for userland to use, to interact with the namespaces-api:  
- **clone**
- **fork** [(perhaps only under glibc..?)](https://www.schutzwerk.com/en/blog/linux-container-namespaces01-intro/)
- **setns**
- **unshare**
- **ioctl**

If wondering about "how do I know..", check [this](https://man7.org/linux/man-pages/man7/namespaces.7.html) out..
it also comprehends this valuable information for our rootless-thingy:
```
       Creation of new namespaces using clone(2) and unshare(2) in most
       cases requires the CAP_SYS_ADMIN capability, since, in the new
       namespace, the creator will have the power to change global
       resources that are visible to other processes that are
       subsequently created in, or join the namespace.  User namespaces
       are the exception: since Linux 3.8, no privilege is required to
       create a user namespace.
```

This tells us two things:  
1. changing one namespace does not guarantee isolation, and requires root permissions (only a slice of those
actually: CAP_SYS_ADMIN... see manpages for capabilities(7)); although we're using those for containers,
they're not at the root of the rootless mechanism.

2. the process of creating a namespace (clone(2) and unshare(2)), makes the process that gets spawned inside 
the new namespace, to have full capabilities (be root).

3.  The usernamespace is **THEExeption**; that one is the root of rootless.

Actually three things..  
Plus I also kept this reference to the [kernel doc about namespaces design](https://docs.kernel.org/userspace-api/unshare.html),
which I probably read 'till 3)..

..ah yeah.. in case you were wondering..  
That's a full list of avail namespaces:
- **CLONE_NEWNS**
- **CLONE_NEWUTS**
- **CLONE_NEWIPC**
- **CLONE_NEWPID**
- **CLONE_NEWBET**
- **CLONE_NEWUSER**
- **CLONE_NEWCGROUP**

But who cares..

## the workflow

The idea I'm making is the following:  
I have a little cli project in mind, where one command should build container images.. then we'll see..  
I wouldn't use **setns** here, because it implies the existence of the namespace we want to jump into, and I wouldn't do that
for my hypothetical cli project.. who cares about having **THAT** namespace: we want to build a container image, and we want to do that
in a single command run...   
I think that a generic user namespace where 
our proc has root capabilities is enough...

In order to accomplish isolation, we must first create a new user namespace, then (if necessary, but no really..) 
create other namespaces to isolate other resources.  
We can do that either with **clone**/**fork**, or with **unshare**. **ioctl** is only used to `ls` namespaces/features.

I'm thinking that the **clone**/**fork** approach differs from the **unshare** approach in its application:  
For the **clone**/**fork** to work, we must have a process to call.  
For the **unshare** call, we can just do that at the top of our main and that's it..

For a **clone**/**fork** approach on a hyphotetical [cobra](https://github.com/spf13/cobra)-built cli application,
we could implement the various commands, so that they could be called in a way like `$ myApp command -flag`,
and do that from the rootcmd, flagging the necessary new namespaces....

I'm not sure.. I'd have to try it out...

...

Let's have a look at a couple of projects implementing this mechanism,  
just to have a better idea on how people think this should work...

### rootlesskit implementation
Rootlesskit is a github project put together with the efforts of some recurring names
of the container world.. some of those are also responsible for [rootless containers](https://rootlesscontaine.rs/).  
It was also mentioned by Liz Rice on one of her containers-from-scratch works I think...

We're looking at [this repo](https://github.com/rootless-containers/rootlesskit) to be precise;  
as the readme states, this kit is used across a bunch of major container projects, including podman/moby,
even tho podman(at least) only uses rootlesskit to setup some port-forwarding mechanism.. and I'm mainly interested
in the actual namespace jump.

k3s uses rootlesskit that way.. also the rootlesskit repo itself makes an example available in cmd/rootlesskit/.  
We might be able to learn something about the namespace jump, cross-checking between the two repos.

We can see from main.go that cmd/rootlesskit doesn't use the cobra lib for the cli(makes sense..). 
That shouldn't be a problem..

Having a quick look at the packages in this module.. I can see a child pkg, which I can
connect to the idea of our process creating a child in a new namespace... Let's have a look:
```bash
$ go doc github.com/rootless-containers/rootlesskit/pkg/child
package child // import "github.com/rootless-containers/rootlesskit/pkg/child"

func Child(opt Opt) error
type Opt struct{ ... }
```

```bash
$ go doc github.com/rootless-containers/rootlesskit/pkg/child.Opt
package child // import "github.com/rootless-containers/rootlesskit/pkg/child"

type Opt struct {
	PipeFDEnvKey    string              // needs to be set
	TargetCmd       []string            // needs to be set
	NetworkDriver   network.ChildDriver // nil for HostNetwork
	CopyUpDriver    copyup.ChildDriver  // cannot be nil if len(CopyUpDirs) != 0
	CopyUpDirs      []string
	PortDriver      port.ChildDriver
	MountProcfs     bool   // needs to be set if (and only if) parent.Opt.CreatePIDNS is set
	Propagation     string // mount propagation type
	Reaper          bool
	EvacuateCgroup2 bool // needs to correspond to parent.Opt.EvacuateCgroup2 is set
}


```

..Well that shorten's our research.

```golang
// pkg/child/child.go
func Child(opt Opt) error {
	if opt.PipeFDEnvKey == "" {
		return errors.New("pipe FD env key is not set")
	}
	pipeFDStr := os.Getenv(opt.PipeFDEnvKey)
	if pipeFDStr == "" {
		return fmt.Errorf("%s is not set", opt.PipeFDEnvKey)
	}
	pipeFD, err := strconv.Atoi(pipeFDStr)
	if err != nil {
		return fmt.Errorf("unexpected fd value: %s: %w", pipeFDStr, err)
	}
	// then a bunch of setups..
	// a createCmd() call using what was passed inside opt arg..
	// and ultimately a command exec.. possibly inside a new namespace
```

What's that PipeFD anyway?  
If we don't have it we error out of the function.. it must be important..  
It looks like an env var.. and the os.Getenv() line confirms it.

Inside the cmd/rootlesskit/ for the rootlesskit executable, we can see that there is a const 
reference for that:  
```golang
// cmd/rootlesskit/main.go
	const (
		pipeFDEnvKey     = "_ROOTLESSKIT_PIPEFD_UNDOCUMENTED"
		stateDirEnvKey   = "ROOTLESSKIT_STATE_DIR"   // documented
		parentEUIDEnvKey = "ROOTLESSKIT_PARENT_EUID" // documented
		parentEGIDEnvKey = "ROOTLESSKIT_PARENT_EGID" // documented
	)
```

Those are env vars.. the one that's so important is also quite clearly left undocumented.. very interesting...

I'd try to compile that, exec it, and see if we can get through...  
one `make` and `make install` after:
```bash
andrew@leather-jacket:~/go/src/wspace-rootless/rootlesskit$ rootlesskit /bin/bash
root@leather-jacket:~/go/src/wspace-rootless/rootlesskit# ...
```
it works... How?!  
Do we have that thing set?
```
# echo $_ROOTLESSKIT_PIPEFD_UNDOCUMENTED

```
we don't...

```
# echo $ROOTLESSKIT_STATE_DIR
/tmp/rootlesskit3719646074
```

but we have something else set... What is going on..?

If we're able to obtain that root shell, something must be setting that envvar somewhere.  
Let's peek at the code for cmd/rootlesskit/

I can see that the logic has place inside those `app.Action`, `app.Before` funcs..  
What about adding a couple of printfs to see what's going on..
```golang
// cmd/rootlesskit/main.go
func main()
	// immediately after const definitions:
	fmt.Printf("at start..\n_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to %s\n\n", os.Getenv(pipeFDEnvKey))
	// ...
	app.Before = func(context *cli.Context) error {

		fmt.Printf("inside app.Before..\n")
		fmt.Printf("_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to %s\n\n", os.Getenv(pipeFDEnvKey))

		if debug {
			logrus.SetLevel(logrus.DebugLevel)
		}
		return nil
	}
	app.Action = func(clicontext *cli.Context) error {

		fmt.Printf("inside app.Action..\n")
		fmt.Printf("_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to %s\n\n", os.Getenv(pipeFDEnvKey))

		if clicontext.NArg() < 1 {
			return errors.New("no command specified")
		}
		if iAmChild {

			fmt.Printf("I am already child:")
			fmt.Printf("_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to %s\n\n", os.Getenv(pipeFDEnvKey))

			childOpt, err := createChildOpt(clicontext, pipeFDEnvKey, clicontext.Args().Slice())
			if err != nil {
				return err
			}
			return child.Child(childOpt)
		}
		parentOpt, err := createParentOpt(clicontext, pipeFDEnvKey, stateDirEnvKey,
			parentEUIDEnvKey, parentEGIDEnvKey)
		if err != nil {
			return err
		}
		return parent.Parent(parentOpt)
	}
```

Recompiled again and run.. this time I got some fatal errors:
```bash
WARN[0000] Running RootlessKit as the root user is unsupported. 
[rootlesskit:parent] error: failed to setup UID/GID map: failed to compute uid/gid map: No subuid ranges found for user 0 ("root")
```
Luckily they were pretty talkative: I've run rootlesskit inside the root shell from the namespace 
created in the previous run of rootlesskit...  
The actual result of a healthy run is:
```bash
andrew@leather-jacket:~/go/src/wspace-rootless/rootlesskit$ rootlesskit /bin/bash
at start..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 

inside app.Before..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 

inside app.Action..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 

at start..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

inside app.Before..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

inside app.Action..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

I am already child:_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

at start..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

inside app.Before..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

inside app.Action..
_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3

I am already child:_ROOTLESSKIT_PIPEFD_UNDOCUMENTED is set to 3
```

I'm not sure what's going on...  
But this reminds me of the logic from Liz Rice's [containers-from-scratch](https://github.com/lizrice/containers-from-scratch).

One thing is for sure: We didn't have that env var before; something's setting it inside the application.

Now.. I didn't read the code for `app.Action` that carefully. I could've skipped this trial step,
by taking into consideration that there was another pkg, other than child that was called.. and that was parent.

The have the same(more or less..) Opt structure on which the only exported function
(Child for child, and Parent for parent) depends.. they do complementary things;  
The code in app.Action calls parent before child:
```golang
// cmd/rootlesskit/main.go
func main()
	// if that infamous env var is set.. it means we're already child!
	iAmChild := os.Getenv(pipeFDEnvKey) != ""
	
	/// later on..
	
	// if we're already child, we do childish calls and return
	if iAmChild {
		childOpt, err := createChildOpt(clicontext, pipeFDEnvKey, clicontext.Args().Slice())
			if err != nil {
				return err
			}
			return child.Child(childOpt)
		}
		
	// if we're not child yet, we do parent stuff and return
	parentOpt, err := createParentOpt(clicontext, pipeFDEnvKey, stateDirEnvKey,	parentEUIDEnvKey, parentEGIDEnvKey)
		if err != nil {
			return err
		}
		return parent.Parent(parentOpt)
```

Feel like we're getting closer.
Let's peek at parent's code:

```golang
// pkg/parent/parent.go
func Parent(opt Opt) error {
	// we call something that checks that there is an actual
	// env key to look for, then...
	cmd.Env = append(os.Environ(), opt.PipeFDEnvKey+"=3")
```
3!?  
perhaps the immediately free after stdin/out/err? that surpasses me..

Let's have a look on how this mechanism is orchestrated inside k3s.

Just check the output of `git grep -in "rootless"` to see that this localpkg/externalpkg/string/whatever
is contained in a bunch of places.. from there, a little lsp code navigation enables us to come to
```golang
// pkg/rootless/rootless.go @ k3s
func Rootless(stateDir string, enableIPv6 bool) error {
	// ...
	hasFD := os.Getenv(pipeFD) != ""
```

same infamous pipeFD.. I'm sure this time it'll be handled in a more understandable way:
```golang
var (
	pipeFD             = "_K3S_ROOTLESS_FD"
	childEnv           = "_K3S_ROOTLESS_SOCK"
	evacuateCgroup2Env = "_K3S_ROOTLESS_EVACUATE_CGROUP2" // boolean
```

oh.. Much better.

This time there are more things going on.. but in the end they're the same calls to:
```golang
// pkg/rootless/rootless.go @ k3s
	parentOpt, err := createParentOpt(driver, rootlessDir, enableIPv6)
	// ...
	if err := parent.Parent(*parentOpt); err != nil {
	
// and

	// Identical to the one in cmd/rootlesskit
	if hasFD {
		logrus.Debug("Running rootless child")
		childOpt, err := createChildOpt(driver)
		if err != nil {
			logrus.Fatal(err)
		}
		if err := child.Child(*childOpt); err != nil {
			logrus.Fatalf("child died: %v", err)
		}
	}
```

Is it really that simple.. just let the child/parent couple handle the quantic jump?  
We should be able to implement our own rootless command:
```golang
// just open a main.go in a new go.mod 
package main

import (
	"fmt"
	"log"
	"os"

	"github.com/rootless-containers/rootlesskit/pkg/child"
	"github.com/rootless-containers/rootlesskit/pkg/parent"
)

const (
	pipeFDEnvKey     = "SOMEGENERICNOTPRETENTIOUSPROGRAMNAME_PIPEFD"
	stateDirEnvKey   = "SOMEGENERICNOTPRETENTIOUSPROGRAMNAME_STATE_DIR"
	parentEUIDEnvKey = "SOMEGENERICNOTPRETENTIOUSPROGRAMNAME_PARENT_EUID"
	parentEGIDEnvKey = "SOMEGENERICNOTPRETENTIOUSPROGRAMNAME_PARENT_EGID"

	// child
	propagation      = ""
	mountprocfs      = true
	evatuatecgroupv2 = true

	// parent
	createpidns       = true
	createcgroupns    = true
	createutsns       = true
	createipcns       = true
	evacutatecgroupv2 = ""
	subidsource       = ""
)

func main() {
	err := JumpNamespace()
	die(err, "while making the jump")
}

func JumpNamespace() error {
	weChild := os.Getenv(pipeFDEnvKey) != ""
	if weChild {
		copts, err := calibrateChild()
		die(err, "while generating child opts: %v")
		return child.Child(*copts)
	}

	popts, err := calibrateParent()
	die(err, "while generating parent opts: %v")

	return parent.Parent(*popts)
}
func calibrateChild() (*child.Opt, error) {
	o := &child.Opt{}
	o.TargetCmd = []string{"/bin/bash"}
	o.PipeFDEnvKey = pipeFDEnvKey
	o.MountProcfs = mountprocfs
	o.Propagation = propagation
	o.EvacuateCgroup2 = evatuatecgroupv2

	return o, nil
}

func calibrateParent() (*parent.Opt, error) {
	o := &parent.Opt{}
	o.PipeFDEnvKey = pipeFDEnvKey
	o.Propagation = propagation
	o.StateDirEnvKey = stateDirEnvKey
	o.ParentEGIDEnvKey = parentEGIDEnvKey
	o.ParentEUIDEnvKey = parentEUIDEnvKey
	o.Propagation = propagation
	o.EvacuateCgroup2 = evacutatecgroupv2
	o.SubidSource = subidsource
	o.Propagation = propagation

	if o.StateDir == "" {
		var err error
		o.StateDir, err = os.MkdirTemp("", "rootlesskit")
		if err != nil {
			return o, fmt.Errorf("creating a state directory: %w", err)
		}
	}

	return o, nil
}

func die(err error, msg string) {
	if err != nil {
		log.Fatalf(msg, err)
	}
}
```
This piece of code should be anough.. but I'm getting errors:
```sh
while making the jump%!(EXTRA *fmt.wrapError=failed to mount cgroup2 on /sys/fs/cgroup: operation not permitted)
```

> I know that the code highlight is wrong...  
> still better than the alternative (dark gray :/)

Clear.. I've passed parameters I didn't know how to handle.  
What should I pass instead?
```golang
// cmd/rootlesskit/main.go @ rootlesskit
func createParentOpt(clicontext *cli.Context, pipeFDEnvKey, stateDirEnvKey, parentEUIDEnvKey, parentEGIDEnvKey string) (parent.Opt, error) {
	var err error
	opt := parent.Opt{
		PipeFDEnvKey:     pipeFDEnvKey,
		StateDirEnvKey:   stateDirEnvKey,
		CreatePIDNS:      clicontext.Bool("pidns"),
		CreateCgroupNS:   clicontext.Bool("cgroupns"),
		CreateUTSNS:      clicontext.Bool("utsns"),
		CreateIPCNS:      clicontext.Bool("ipcns"),
		ParentEUIDEnvKey: parentEUIDEnvKey,
		ParentEGIDEnvKey: parentEGIDEnvKey,
		Propagation:      clicontext.String("propagation"),
		EvacuateCgroup2:  clicontext.String("evacuate-cgroup2"),
		SubidSource:      parent.SubidSource(clicontext.String("subid-source")),
	}

	fmt.Printf("[*] parent.Opt:")
	fmt.Printf("\t- %s:\t%v\n", "opt.PipeFDEnvKey", opt.PipeFDEnvKey)
	fmt.Printf("\t- %s:\t%v\n", "opt.StateDirEnvKey", opt.StateDirEnvKey)
	fmt.Printf("\t- %s:\t%v\n", "opt.CreatePIDNS", opt.CreatePIDNS)
	fmt.Printf("\t- %s:\t%v\n", "opt.CreateCgroupNS", opt.CreateCgroupNS)
	fmt.Printf("\t- %s:\t%v\n", "opt.CreateUTSNS", opt.CreateUTSNS)
	fmt.Printf("\t- %s:\t%v\n", "opt.CreateIPCNS", opt.CreateIPCNS)
	fmt.Printf("\t- %s:\t%v\n", "opt.ParentEUIDEnvKey", opt.ParentEUIDEnvKey)
	fmt.Printf("\t- %s:\t%v\n", "opt.ParentEGIDEnvKey", opt.ParentEGIDEnvKey)
	fmt.Printf("\t- %s:\t%v\n", "opt.EvacuateCgroup2", opt.EvacuateCgroup2)
	fmt.Printf("\t- %s:\t%v\n", "opt.SubidSource", opt.SubidSource)
	fmt.Printf("\t- %s:\t%v\n", "opt.Propagation", opt.Propagation)
	
// cmd/rootlesskit/main.go @ rootlesskit
func createChildOpt(clicontext *cli.Context, pipeFDEnvKey string, targetCmd []string) (child.Opt, error) {
	pidns := clicontext.Bool("pidns")
	opt := child.Opt{
		PipeFDEnvKey:    pipeFDEnvKey,
		TargetCmd:       targetCmd,
		MountProcfs:     pidns,
		Propagation:     clicontext.String("propagation"),
		EvacuateCgroup2: clicontext.String("evacuate-cgroup2") != "",
	}

	fmt.Printf("[*] child.Opt:\n")
	fmt.Printf("\t- %s:\t%v\n", "opt.PipeFDEnvKey", opt.PipeFDEnvKey)
	fmt.Printf("\t- %s:\t%v\n", "opt.TargetCmd", opt.TargetCmd)
	fmt.Printf("\t- %s:\t%v\n", "opt.MountProcfs", opt.MountProcfs)
	fmt.Printf("\t- %s:\t%v\n", "opt.Propagation", opt.Propagation)
	fmt.Printf("\t- %s:\t%v\n", "opt.EvacuateCgroup2", opt.EvacuateCgroup2)

```

```bash
$ rootlesskit /bin/bash

[*] parent.Opt:	- opt.PipeFDEnvKey:	_ROOTLESSKIT_PIPEFD_UNDOCUMENTED
	- opt.StateDirEnvKey:     ROOTLESSKIT_STATE_DIR
	- opt.CreatePIDNS:        false
	- opt.CreateCgroupNS:     false
	- opt.CreateUTSNS:        false
	- opt.CreateIPCNS:        false
	- opt.ParentEUIDEnvKey:   ROOTLESSKIT_PARENT_EUID
	- opt.ParentEGIDEnvKey:   ROOTLESSKIT_PARENT_EGID
	- opt.EvacuateCgroup2:	
	- opt.SubidSource:        auto
	- opt.Propagation:        rprivate


[*] child.Opt:
    - opt.PipeFDEnvKey:       _ROOTLESSKIT_PIPEFD_UNDOCUMENTED
    - opt.TargetCmd:          [/bin/bash]
    - opt.MountProcfs:        false
    - opt.Propagation:        rprivate
    - opt.EvacuateCgroup2:    false

```
There we go..

So now I should only modify my constants accordingly and....
```bash
andrew@leather-jacket:~/go/src/wspace-rootless/test-rootless$ go run main.go 
root@leather-jacket:~/go/src/wspace-rootless/test-rootless# 
```

yep.

The "/bin/bash" reference for the child process is hardcoded, 
but we'd need to add only some command parsing logic,
to be able to have something working.. real-world-like.

...

WTF is that PID-thing anyway!?

### podman implementation
Here's wtf it is: 
```golang 
// pkg/domain/infra/abi/system.go @ podman
func (ic *ContainerEngine) SetupRootless(_ context.Context, noMoveProcess bool) error {
	pausePidPath, err := util.GetRootlessPauseProcessPidPathGivenDir(tmpDir)
	
// pkg/util/utils_supported.go
// GetRootlessPauseProcessPidPathGivenDir returns the path to the file that
// holds the PID of the pause process, given the location of Libpod's temporary
// files.
func GetRootlessPauseProcessPidPathGivenDir(libpodTmpDir string) (string, error) {
	if libpodTmpDir == "" {
		return "", errors.New("must provide non-empty temporary directory")
	}
	return filepath.Join(libpodTmpDir, "pause.pid"), nil
}

```

It must be him!

It then later tries to join that pid's namespace:
```golang
// pkg/domain/infra/abi/system.go
func (ic *ContainerEngine) SetupRootless(_ context.Context, noMoveProcess bool) error {
	became, ret, err := rootless.TryJoinPauseProcess(pausePidPath)
	
// pkg/rootless/rootless.go
// TryJoinPauseProcess attempts to join the namespaces of the pause PID via
// TryJoinFromFilePaths.  If joining fails, it attempts to delete the specified
// file.
func TryJoinPauseProcess(pausePidPath string) (bool, int, error) {
	became, ret, err := TryJoinFromFilePaths("", false, []string{pausePidPath})
```

:) now more pieces of the puzzle are coming together!  
Luckily those mechanisms are documented in podman:
```golang
// pkg/rootless/rootless_linux.go 
// TryJoinFromFilePaths attempts to join the namespaces of the pid files in paths.
// This is useful when there are already running containers and we
// don't have a pause process yet.  We can use the paths to the conmon
// processes to attempt joining their namespaces.
// If needNewNamespace is set, the file is read from a temporary user
// namespace, this is useful for containers that are running with a
// different uidmap and the unprivileged user has no way to read the
// file owned by the root in the container.
func TryJoinFromFilePaths(pausePidPath string, needNewNamespace bool, paths []string) (bool, int, error) {

// + tries to become root in the new userNamespace

// pkg/rootless/rootless_linux.go
// joinUserAndMountNS re-exec podman in a new userNS and join the user and mount
// namespace of the specified PID without looking up its parent.  Useful to join directly
// the conmon process.
func joinUserAndMountNS(pid uint, pausePid string) (bool, int, error) {
```

> #### thought process
> 
> Ok.. let me clarify what happened here:  
> I was convinced that the rootlesskit pipefd was a mechanism similar to that described by the podman code above...  
> It's not!
> > :) now more pieces of the puzzle are coming together!
>
> I felt like everything was starting to make sense..
> 
> In my mind I was thinking: "something to keep track of the unshared process, across different calls".  
> Now for podman, the code above could describe something like that,  
> but our rootlesskit it was something entirely different.
> 
> Inside rootlesskit, that pipefd is a mechanism of parent/child communication, without exchanging
> data in weird ways across function calls(possibly.. dunno what the actual limit is..).  
> This example should clarify:
> ```golang
> // cmd/rootlesskit/main.go @ rootlesskit
> func main() {
> 	const (
> 		pipeFDEnvKey     = "_ROOTLESSKIT_PIPEFD_UNDOCUMENTED"
> 		stateDirEnvKey   = "ROOTLESSKIT_STATE_DIR"   // documented
> 		parentEUIDEnvKey = "ROOTLESSKIT_PARENT_EUID" // documented
> 		parentEGIDEnvKey = "ROOTLESSKIT_PARENT_EGID" // documented
> 	)
> 
> // Add this line here:
> +	fmt.Printf("Starting rootlesskit - _ROOTLESSKIT_PIPEFD_UNDOCUMENTED ==  %s\n", os.Getenv(pipeFDEnvKey))
> 
> 
> // follow the pipe-Rabbit:
> // we start by checking if the envKey is defined,
> // then open that file descriptor and read from it...
> // It then becomes a message
> // pkg/child/child.go
> func Child(opt Opt) error {
> 	if opt.PipeFDEnvKey == "" {
> 		return errors.New("pipe FD env key is not set")
> 	}
> 	pipeFDStr := os.Getenv(opt.PipeFDEnvKey)
> 	if pipeFDStr == "" {
> 		return fmt.Errorf("%s is not set", opt.PipeFDEnvKey)
> 	}
> 	pipeFD, err := strconv.Atoi(pipeFDStr)
> 	if err != nil {
> 		return fmt.Errorf("unexpected fd value: %s: %w", pipeFDStr, err)
> 	}
> 	pipeR := os.NewFile(uintptr(pipeFD), "")
> 	var msg common.Message
> 	if _, err := msgutil.UnmarshalFromReader(pipeR, &msg); err != nil {
> 		return fmt.Errorf("parsing message from fd %d: %w", pipeFD, err)
> 	}
> // Here change from logrus.Debugf to logrus.Printf	
> -	logrus.Debugf("child: got msg from parent: %+v", msg)
> +	logrus.Printf("child: got msg from parent: %+v", msg)
> // ...
> // Or just set verbosity for logrus at the beginning of main and then grep for it... whatever
> 
> 	if msg.Stage == 0 {
> 		// the parent has configured the child's uid_map and gid_map, but the child doesn't have caps here.
> 		// so we exec the child again to obtain caps.
> 		// PID should be kept.
> 		if err = syscall.Exec("/proc/self/exe", os.Args, os.Environ()); err != nil {
> 			return err
> 		}
> 		panic("should not reach here")
> 	}
> 	if msg.Stage != 1 {
> 		return fmt.Errorf("expected stage 1, got stage %d", msg.Stage)
> 	}
> 	
> ///// And the parent.Parent() call, opens a pipe,
> ///// that gets that 3 fd in the child process somehow...
> ```
> That comment near that `if msg.Stage == 0 {` line, is describing what we'ge gonna see after compile/run:
> ```
> Starting rootlesskit - _ROOTLESSKIT_PIPEFD_UNDOCUMENTED ==  
> Starting rootlesskit - _ROOTLESSKIT_PIPEFD_UNDOCUMENTED ==  3
> INFO[0000] child: got msg from parent: {Stage:0 Message0:{} Message1:{StateDir: Network:{Dev: IP: Netmask:0 Gateway: DNS: MTU:0 Opaque:map[]} Port:{Opaque:map[]}}} 
> Starting rootlesskit - _ROOTLESSKIT_PIPEFD_UNDOCUMENTED ==  3
> INFO[0000] child: got msg from parent: {Stage:1 Message0:{} Message1:{StateDir:/tmp/rootlesskit1346310653 Network:{Dev: IP: Netmask:0 Gateway: DNS: MTU:0 Opaque:map[]} Port:{Opaque:map[]}}} 
> ```
> [WhatHappened] The program started, and realized that it wasn't already child, so it executed parent.Parent():
> ```golang
> // cmd/rootlesskit/main.go
> 	iAmChild := os.Getenv(pipeFDEnvKey) != ""
> 	// ...
> 		if iAmChild {
>			// we didn't enter here
> 		}
> 		parentOpt, err := createParentOpt(clicontext, pipeFDEnvKey, stateDirEnvKey,
> 			parentEUIDEnvKey, parentEGIDEnvKey)
> 		if err != nil {
> 			return err
> 		}
> 		return parent.Parent(parentOpt)
> ```
> 
> Then parent.Parent() did its setup magic, and reexeced the program..
> ```golang
> // pkg/parent/parent.go
> 	if err := cmd.Start(); err != nil {
> 		return fmt.Errorf("failed to start the child: %w", err)
> 	}
> ```
> This time it realized it was already child, and took a different path:
>
>```golang 	
> // cmd/rootlesskit/main.go
> 	iAmChild := os.Getenv(pipeFDEnvKey) != ""  // set by parent.Parent to '3'
> 	// ...
> 		if iAmChild {
> 			childOpt, err := createChildOpt(clicontext, pipeFDEnvKey, clicontext.Args().Slice())
> 			if err != nil {
> 				return err
> 			}
> 			return child.Child(childOpt)
> 		}
> ```
> 
> It then received some message that told it to reexec, to use the uid_map/gid_map the parent configured for it..  
> That's why we see a main() start 3 times:
> ```golang
> // pkg/child/child.go
> 	pipeR := os.NewFile(uintptr(pipeFD), "")
> 	var msg common.Message
> 	if _, err := msgutil.UnmarshalFromReader(pipeR, &msg); err != nil {
> 		return fmt.Errorf("parsing message from fd %d: %w", pipeFD, err)
> 	}
> 	logrus.Printf("child: got msg from parent: %+v", msg)
> 	if msg.Stage == 0 {
> 		// the parent has configured the child's uid_map and gid_map, but the child doesn't have caps here.
> 		// so we exec the child again to obtain caps.
> 		// PID should be kept.
> 		if err = syscall.Exec("/proc/self/exe", os.Args, os.Environ()); err != nil {
> 			return err
> 		}
> 		panic("should not reach here")
> 	}
> ```
> Now back to me trippin about that podman joinNamespace mechanism..
> 

And the lowlevel implementation of this relies on
```golang
// pkg/rootless/rootless_linux.go

/*
#cgo remote CFLAGS: -Wall -Werror -DDISABLE_JOIN_SHORTCUT
#include <stdlib.h>
#include <sys/types.h>
extern uid_t rootless_uid();
extern uid_t rootless_gid();
extern int reexec_in_user_namespace(int ready, char *pause_pid_file_path, char *file_to_read, int fd);
extern int reexec_in_user_namespace_wait(int pid, int options);
extern int reexec_userns_join(int pid, char *pause_pid_file_path);
extern int is_fd_inherited(int fd);
*/
import "C"

```

Seems something more articulated than the usecase I had in mind..  
from the description here:
```golang
// ...
// If needNewNamespace is set, the file is read from a temporary user
// namespace, this is useful for containers that are running with a
// different uidmap and the unprivileged user has no way to read the
// file owned by the root in the container.
func TryJoinFromFilePaths(pausePidPath string, needNewNamespace bool, paths []string) (bool, int, error) {
```
It seems like this kind of logic could be (possibly?)related to the issues described
[here](https://opensource.com/article/18/12/podman-and-user-namespaces) 
and [here](https://projectatomic.io/blog/2018/05/podman-userns/); 
so the usecase could roughly be described as one container image being shared by 
different containers(processes) spawned inside different user namespaces, so that the files in the
image's filesystem are lead to experience an identity crisis.
We keep track of the namespace we've created with our clone/fork/whatever/... so that when we 
reexec our process another time, we can jump into that userNamespace, instead of creating another one.  
Dunno... I could be wrong..

...

Anyway.. we're talking about a mechanism which concentrates the most on this namespace-join,
and has all the actual joinNamespace functions written in cgo..  
I don't know yet what are the usecases where I should need this kind of logic.  
Looking for something that could match the project I have in mind..

Skipping...

### buildah implementation
Say I want to
[include buildah in my build tool](https://github.com/containers/buildah/blob/v1.29.0/docs/tutorials/04-include-in-your-build-tool.md)...

The code inside that .md contains this little function call here:
```golang
// see the link above..
	unshare.MaybeReexecUsingUserNamespace(false)
```
It seems like our "makeRootless()".  
The .md states:  
`This code ensures that your application is re-executed in a user namespace where it has root privileges.`  
Sounds the simplest.. sounds like the thing I was looking for..  
It looks like this:
```golang
// This comes from the containers/storage lib.
// 
// pkg/unshare/unshare_linux.go @ storage
// MaybeReexecUsingUserNamespace re-exec the process in a new namespace
func MaybeReexecUsingUserNamespace(evenForRoot bool) {
+	// we're returning if we're already root and we've started as non root
	// If we've already been through this once, no need to try again.
	if os.Geteuid() == 0 && GetRootlessUID() > 0 {
		return
	}

	// Figure out who we are.
+	//parses this output
	me, err := user.Current()
+	// to populate those
	var uidNum, gidNum uint64

+	// Does some `/etc/subuid`/`/etc/subgid` mapping magic..
+	// ...
	
	// Unlike most uses of reexec or unshare, we're using a name that
	// _won't_ be recognized as a registered reexec handler, since we
	// _want_ to fall through reexec.Init() to the normal main().
	cmd := Command(append([]string{fmt.Sprintf("%s-in-a-user-namespace", os.Args[0])}, os.Args[1:]...)...)
+	// Need to figure out what that means..


+	// Preparing to spawn child process
	// Reuse our stdio.
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Set up a new user namespace with the ID mapping.
+ 	//that we've gathered earlier
	cmd.UnshareFlags = syscall.CLONE_NEWUSER | syscall.CLONE_NEWNS
	cmd.UseNewuidmap = uidNum != 0
	cmd.UidMappings = uidmap
	cmd.UseNewgidmap = uidNum != 0
	cmd.GidMappings = gidmap
	cmd.GidMappingsEnableSetgroups = true

	// Finish up.
	logrus.Debugf("Running %+v with environment %+v, UID map %+v, and GID map %+v", cmd.Cmd.Args, os.Environ(), cmd.UidMappings, cmd.GidMappings)

	// Forward SIGHUP, SIGINT, and SIGTERM to our child process.
	interrupted := make(chan os.Signal, 100)
	defer func() {
		signal.Stop(interrupted)
		close(interrupted)
	}()
	cmd.Hook = func(int) error {
		go func() {
			for receivedSignal := range interrupted {
				cmd.Cmd.Process.Signal(receivedSignal)
			}
		}()
		return nil
	}
	signal.Notify(interrupted, syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM)

	// Make sure our child process gets SIGKILLed if we exit, for whatever
	// reason, before it does.
	if cmd.Cmd.SysProcAttr == nil {
		cmd.Cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.Cmd.SysProcAttr.Pdeathsig = syscall.SIGKILL

	ExecRunnable(cmd, nil)
}
```

## the usecase
So.. let's say I want to build a cli command that builds container images; ideally in one run.  
For something like that, being able to tell which namespace we're running on, 
and possibly join other open namespaces, sounds like overkill:  
As long as we can be root inside a generic userNamespace, I think we should be fine..

Plus I can see no need in unsharing other parent resources,  
I think we can rely on /etc/subuid and /etc/subgid to set our uid/gid inside the user namespace,
to be the same in multiple runs...  
Dunno.. now I'm probably just talking nonsense..

I really want to try to build something with this, to have a better idea about what's going on..  
Using the buildah lib solution(`unshare.MaybeReexecUsingUserNamespace(false)`) would be boring..  
also it contains hardcoded references to buildah itself.. 

But I'll keep this for another post..  
this one has grown too long too fast.
