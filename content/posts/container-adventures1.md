---
title: "Container Adventures 1"
date: 2022-11-22T22:44:11+31:00
lastmod: 2023-01-27T16:11:54+02:00
draft: false
description: | 
  Exploring podman's codebase.. and trying something as stupid as modifying the
  version string when doing `podman version`.. see if it compiles and
  see what happens next
tags: 
 - container_adventures
 - golang
---

Since this is the first post.. I may start by saying that this will be 
a series documenting my learning process for containers/golang.  
I'm finding out about myself, that I tend to implement the head-first 
approach when I have no clear ideas about what I'm doing..
That would mean that I'll definitely (when not bothering the community.. or the 
community not answering me) be drawing conclusions and answering the conclusions 
that I drew myself.. 

So everything read on this ~~posts~~ blog.. shouldn't be taken too seriously. 

Actually.. since I'm just exploring the life on the internet and have no idea
if people actually use mails..  
If you've found something dumb that I wrote, or something
questionable, or something that you share excitement for... or just wanna say hi :)..
please send me a mail [===> here <===](mailto:x7uplime@gmail.com) :)
## container adventures
Everyone seems to be so much into the containers/kübernetes thing now..

I heard about good reasons to adopt containers 
and I heard about good reasons to not adopt containers.. it mostly depends on the workflow  
I also heard from coworkers, really bad decisions for kübernetes adoptions in workflows that really
didn't need that overhead, taken by the upper management just to follow a trend.

I once met this fellow sysadmin, he was from the bsd world while I was primarily operating on linux boxes..  
I was caught by the container fuzz at my workplace, and already knew something about it; so when a conversation
about containers was issued.. I was more prone to advocating.  
But this guy already had his workflow in mind.. it was tested, working, and based
on years of experience.  
So he was telling me how little resources he needed in order to 
run services in bsd jails.. and how efficiently and fault-tolerantly he was able to manage
its stuff.. so he didn't see any use for containers.  
He presented its arguments in a very conscious way; he knew what he was doing.  
I couldn't argue with that.

The (now-referred-to-as)"legacy" way of making stuff has nothing less exciting about its inner workings than 
container-world's stuff inner workings.  
Some elderly colleagues told me the most
fuck'd up technology stories I heard, and they were all about "legacy" tech.

Containers is just the new-world-order style of making stuff. It's intriguing.  
It's just something else.. there are just more things going on around it right now.

### prior knowledge..

Having said that.. 
I learned about containers, used them at work, people were happy...  
But do I really know what's going on?  
Of course not.

At my workplace, people were very agitated around containers.  
There were a couple personalities, which were involved in kübernetes 
workflows and were advocating for "the new world order", 
and they were doing it greatly, with those very interesting stories.

We were mainly involved on the "new-wave" of containers, so they gave due credit to docker for being 
the pioneering project for the container world (for its mass adoption), and sold me podman as 
the new way of making things.

They told me those interesting stories, like they created podman years after docker, they were making it better
and they were making it 1:1 compatible with docker so that experienced docker users could switch to podman
by doing something as `alias docker=podman`, interesting I thought...

They were telling me that podman was so superior, that by design it allowed running container 
by not being root, as docker required.. also that podman didn't even required a running service to 
interact with.. Interesting I thought...

Is it really that superior? I have no idea.. I liked the stories.  
There are a lot of interesting articles coming out periodically about containers;  
In particular I started carrying this interest about container, after reading 
[this psychedelic series of posts](https://github.com/saschagrunert/demystifying-containers) about
how containers work internally; really good stuff :)

- a container is just a linux process, with a bunch of things added (all the process dependencies, a filesystem, whatever...); 
- all the uppermentioned stuff is contained in container images.. the ones we're pulling from remote container registries (like dockerHub)
- containers are for container images, what processes are for programs(instructions)
- container Runtimes are the ones that actually run containers (crun/runc/...),
  those are generally hidden to the user.
- Container Engines (docker/podman/..) are the ones that the user
  directly interacts with.. like some kind of "frontend"?

> It took me a quick tour on the "demistifying containers" series to 
> separate containerEngines from containerRuntimes, in that containerThing-idea/intersection
> between the two, that I had before.

Then I thought: "since I was already looking to learn some programming language.."  
why not learn go while learning containers.. everything container-related seems to 
be written in go...

### crun --version

I already took a peek once inside the [containers/](https://github.com/containers) organization, 
that podman is part of; It comprehends libraries for container storage, container images, ... as well as other
tools for building images, container engines, container runtimes,...  
I thought of it as a common roof for most of the things I looked for in the container world.

[The podman documentation](https://docs.podman.io/en/latest/index.html) states that podman is a cli
built around libpod, and that it relies on OCI compliant container runtimes to run containers..  
Like it doesn't do it on its own?

Prior to taking on this article, I already cloned a bunch of repos of container runtimes.
Not based on any specific criteria.. only based on hearsay; like "kübernetes dropped support for docker runtime to run container
on the node, to move towards cri-o"... Interesting I thought..  
also it was mentioned [here](https://www.suse.com/c/demystifying-containers-part-ii-container-runtimes/), so  
`git clone https://github.com/cri-o/cri-o.git`

Now.. The thing I wanted to start with, was to modify something like the version string;
so that when calling a binary on my system.. I'd know that it would be the one I'm tinkering with,
and not the one that come with some package from my distro.  
This way, if something I was trying to implement(big words..) on that project didn't work,
I could cross out one of the possible reasons.

Let's try it on crun.
Once cloned the repo I did `./autogen.sh`, then `./configure` and `bear -- make -j9` for code navigation..  
Grepping for main didn't help.. If I had to guess, from the root of the repo, I'd look inside the src/ folder.  
From then on, a file called as the project itself was the next hint.  
We found main, and from there on:
```c
// ./src/crun.c
int
main (int argc, char **argv)
{
  // ...
  argp_parse (&argp, argc, argv, ARGP_IN_ORDER, &first_argument, &arguments);

  command = get_command (argv[first_argument]);  /// THIS is interesting
  if (command == NULL)
    libcrun_fail_with_error (0, "unknown command %s", argv[first_argument]);
	
// ./src/crun.c
static struct commands_s *
get_command (const char *arg)
{
  struct commands_s *it;
  for (it = commands; it->value; it++)  // Those commands..?
    if (strcmp (it->name, arg) == 0)
      return it;
  return NULL;
}

// ./src/crun.c
struct commands_s commands[] = { { COMMAND_CREATE, "create", crun_command_create },
                                 { COMMAND_DELETE, "delete", crun_command_delete },
                                 { COMMAND_EXEC, "exec", crun_command_exec },
                                 { COMMAND_LIST, "list", crun_command_list },
                                 { COMMAND_KILL, "kill", crun_command_kill },
                                 { COMMAND_PS, "ps", crun_command_ps },
                                 { COMMAND_RUN, "run", crun_command_run },
                                 { COMMAND_SPEC, "spec", crun_command_spec },
                                 { COMMAND_START, "start", crun_command_start },
                                 { COMMAND_STATE, "state", crun_command_state },
                                 { COMMAND_UPDATE, "update", crun_command_update },
                                 { COMMAND_PAUSE, "pause", crun_command_pause },
                                 { COMMAND_UNPAUSE, "resume", crun_command_unpause },
#if HAVE_CRIU && HAVE_DLOPEN
                                 { COMMAND_CHECKPOINT, "checkpoint", crun_command_checkpoint },
                                 { COMMAND_RESTORE, "restore", crun_command_restore },
#endif
                                 {
                                     0,
                                 } };
```

no `version` command..  

But immediately under that `get_command` function there is something:

```c
// ./src/crun.c
enum
{
  OPTION_VERSION = 'v',   // <----
  OPTION_VERSION_CAP = 'V',
  OPTION_DEBUG = 1000,
  OPTION_SYSTEMD_CGROUP,
  OPTION_CGROUP_MANAGER,
  OPTION_LOG,
  OPTION_LOG_FORMAT,
  OPTION_ROOT,
  OPTION_ROOTLESS
};

// That is also used here..
// ./src/crun.c
static struct argp_option options[] = { { "debug", OPTION_DEBUG, 0, 0, "produce verbose output", 0 },
                                        { "cgroup-manager", OPTION_CGROUP_MANAGER, "MANAGER", 0, "cgroup manager", 0 },
                                        { "systemd-cgroup", OPTION_SYSTEMD_CGROUP, 0, 0, "use systemd cgroups", 0 },
                                        { "log", OPTION_LOG, "FILE", 0, NULL, 0 },
                                        { "log-format", OPTION_LOG_FORMAT, "FORMAT", 0, NULL, 0 },
                                        { "root", OPTION_ROOT, "DIR", 0, NULL, 0 },
                                        { "rootless", OPTION_ROOT, "VALUE", 0, NULL, 0 },
       /* HERE --------------->> */     { "version", OPTION_VERSION, 0, 0, NULL, 0 },
                                        // alias OPTION_VERSION_CAP with OPTION_VERSION
                                        { NULL, OPTION_VERSION_CAP, 0, OPTION_ALIAS, NULL, 0 },
                                        {
                                            0,
                                        } };
										
// And here...
// ./src/crun.c -- @ parse_opt()
    case OPTION_VERSION:
    case OPTION_VERSION_CAP:
      print_version (stdout, state);  // <----
      exit (EXIT_SUCCESS);


// There we go...
// ./src/crun.c
static void
print_version (FILE *stream, struct argp_state *state arg_unused)
{
  cleanup_free char *rundir = libcrun_get_state_directory (arguments.root, NULL);
  fprintf (stream, "%s version %s\n", PACKAGE_NAME, PACKAGE_VERSION);
  fprintf (stream, "commit: %s\n", GIT_VERSION);
  fprintf (stream, "rundir: %s\n", rundir);
  fprintf (stream, "spec: 1.0.0\n");
#ifdef HAVE_SYSTEMD
  fprintf (stream, "+SYSTEMD ");
#endif
  fprintf (stream, "+SELINUX ");
  fprintf (stream, "+APPARMOR ");
#ifdef HAVE_CAP
  fprintf (stream, "+CAP ");
#endif
#ifdef HAVE_SECCOMP
  fprintf (stream, "+SECCOMP ");
#endif
#ifdef HAVE_EBPF
  fprintf (stream, "+EBPF ");
#endif
#ifdef HAVE_CRIU
  fprintf (stream, "+CRIU ");
#endif

  libcrun_handler_manager_print_feature_tags (libcrun_get_handler_manager (), stream);

  fprintf (stream, "+YAJL\n");
}
```

So we can just add a little something to let our future selfs, that we're using the 
tinkered-with binary:

```c
// ./src/crun.c -- @ print_version()
  fprintf (stream, "%s version %s | :^)\n", PACKAGE_NAME, PACKAGE_VERSION);
```

compile/install again and...  
```bash
$ crun --version
crun version 1.7.2.0.0.0.80-940b | :^)
commit: 940bf973f144c81149cf05135f127ca6f0d19eb6
rundir: /run/user/1000/crun
spec: 1.0.0
+SYSTEMD +SELINUX +APPARMOR +CAP +SECCOMP +EBPF +YAJL
```
There we go

But now.. how is podman gonna use our crun?  
And how are we gonna know it is *our* crun?

## Is there a way to know more about the underlying container runtime we're using?

From `$ podman help` I can see there is a `--runtime` flag..  
we can use that tospecify our desired oci-compliant runtime.  
By the way, there is [this article](https://www.suse.com/c/demystifying-containers-part-ii-container-runtimes/)
which talks about container runtimes, and introduces oci.

We could start digging inside podman to see how that `--runtime` flag looks like in the sources,
just like we did for the version in crun.

### podman -\-runtime

from the root level of the podman repo, I can see something very familiar:  
There is a cmd/ folder in that repo.. Dunno if it's a thing or not
([it seems like so](https://github.com/golang-standards/project-layout#cmd))
but it looks like some kind of standard that everybody follows:  
If your code is gonna be executed, you're probably putting the code for what comes immediately
next inside the cmd/ folder (usually next is arg parsing, config, ...)

And in fact, there is our entrypoint.

Any programming language may or may not require you to provide some kind of entrypoint;  
[for golang](https://go.dev/ref/spec#Program_execution) that one is the main function in the main package.

I can immediately see another something that looks familiar...

```golang

// THe following doesn't seem like much

// ./cmd/podman/main.go
func main() {
	if reexec.Init() {
		// We were invoked with a different argv[0] indicating that we
		// had a specific job to do as a subprocess, and it's done.
		return
	}

	rootCmd = parseCommands()

	Execute()
	os.Exit(0)
}

// But the parseCommands() has a referents that hints about the project layout:

// ./cmd/podman/main.go
func parseCommands() *cobra.Command {
```

That `*cobra.Command` refers to [the cobra library](https://github.com/spf13/cobra), which is 
an assured trend in golang, for everything that has a cli.  
THe cobra lib provides logic to manipulate arg parsing, commands, flags,... and enforces a certain 
layout described in [the cobra user guide](https://github.com/spf13/cobra/blob/main/user_guide.md#user-guide).

After reading the first two paragraphs, we're starting to have an idea of where to look for things.

#### podman version
Let's say we'd like to modify the version string as we did for runc...

From the cli, we're calling `podman version`, but there is no cmd/podman/version.go file..  
perhaps somewhere deeper?

```bash
## from cmd/podman/
$ find ./ -name "version.go"
./images/version.go
./system/version.go
```

It was some shot in the dark, but sometimes it works..  
I'll bet for that system/version.go

```golang

// luckily there is some "func version" there...

// cmd/podman/system/version.go
func version(cmd *cobra.Command, args []string) error {
	versions, err := registry.ContainerEngine().Version(registry.Context())
	if err != nil {
		return err
	}

	// I think we could easily toss the rest
	// ...
	
	
// That ContainerEngine().Version() looks promising..
// let's see how it looks like:

// ./pkg/domain/entities/engine_container.go
type ContainerEngine interface { //nolint:interfacebloat
	AutoUpdate(ctx context.Context, options AutoUpdateOptions) ([]*AutoUpdateReport, []error)
	Config(ctx context.Context) (*config.Config, error)
	ContainerAttach(ctx context.Context, nameOrID string, options AttachOptions) error
	ContainerCheckpoint(ctx context.Context, namesOrIds []string, options CheckpointOptions) ([]*CheckpointReport, error)
	ContainerCleanup(ctx context.Context, namesOrIds []string, options ContainerCleanupOptions) ([]*ContainerCleanupReport, error)
	Diff(ctx context.Context, namesOrIds []string, options DiffOptions) (*DiffReport, error)
	Events(ctx context.Context, opts EventsOptions) error
	GenerateSystemd(ctx context.Context, nameOrID string, opts GenerateSystemdOptions) (*GenerateSystemdReport, error)
	GenerateKube(ctx context.Context, nameOrIDs []string, opts GenerateKubeOptions) (*GenerateKubeReport, error)
	SystemPrune(ctx context.Context, options SystemPruneOptions) (*SystemPruneReport, error)
	Info(ctx context.Context) (*define.Info, error)
	KubeApply(ctx context.Context, body io.Reader, opts ApplyOptions) error
	NetworkConnect(ctx context.Context, networkname string, options NetworkConnectOptions) error
	NetworkCreate(ctx context.Context, network types.Network, createOptions *types.NetworkCreateOptions) (*types.Network, error)
	PodCreate(ctx context.Context, specg PodSpec) (*PodCreateReport, error)
	PodClone(ctx context.Context, podClone PodCloneOptions) (*PodCloneReport, error)
	PodExists(ctx context.Context, nameOrID string) (*BoolReport, error)
	/// and whatever.. it already looks pretty clear.
}
```

We just look at the interface that podman implements:  
Just try to write `podman` in a shell, followed by any name for that function and to autocomplete.

I guess we only need to see where that Version() is implemented:

```
pkg/domain/infra/abi/system.go
426: func (ic ContainerEngine) Version(ctx context.Context) (*entities.SystemVersionReport, error) {
pkg/domain/infra/tunnel/system.go
34: func (ic ContainerEngine) Version(ctx context.Context) (*entities.SystemVersionReport, error) {
```

Two places.. abi and tunnel?  
abi as [Application Binary Interface](https://stackoverflow.com/questions/2171177/what-is-an-application-binary-interface-abi)?  
Let's look at both..

```golang

// From the one in the tunnel..
// pkg/domain/infra/tunnel/system.go
// 34: func (ic ContainerEngine) Version(ctx context.Context) (*entities.SystemVersionReport, error) {

func (ic ContainerEngine) Version(ctx context.Context) (*entities.SystemVersionReport, error) {
	return system.Version(ic.ClientCtx, nil)
}
```


> It relies on system.Version()  
> ..that "system" coming from this pkg: "github.com/containers/podman/v4/pkg/bindings/system"  
> and that call takes an ic.ClientCtx, which we can see from 
> the code in Version, and by the name actually..  
> that it is a Context.. which means there are lots of things that are going on 
> inside that call, that we "don't directly control"...  
> Take a peek at [this](https://go.dev/blog/context)

The actual Version from the tunnel is implemented as so..

```golang
// pkg/bindings/system/system.go
func Version(ctx context.Context, options *VersionOptions) (*entities.SystemVersionReport, error) {
	// doesn't matter...
	
	_ = options
	version, err := define.GetVersion() //what's this??
	if err != nil {
		return nil, err
	}
	report.Client = &version

	conn, err := bindings.GetClient(ctx)  // Hmm..
	if err != nil {
		return nil, err
	}
	// And this?
	// We're making an http request...??
	response, err := conn.DoRequest(ctx, nil, http.MethodGet, "/version", nil, nil)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()

	// response processing...

	// blah...

	/// blaaah..
}
```

Won't investigate further..  
it doesn't seem like what we're looking for..  
It seems like it's the other one:

```golang
// pkg/domain/infra/abi/system.go
// 426: func (ic ContainerEngine) Version(ctx context.Context) (*entities.SystemVersionReport, error) {
```
...


> EDIT:  
> Ok, I did investigate further..  
> When I reviewd the draft for this article...  
> which wasn't really explicative
> about the thought process, so many things I had to reinvestigate.
>
> Here I followed the path of that define.GetVersion() and saw what type 
> that report in report.Client was..
> 
> ```golang
> // pkg/domain/entities/system.go
> // SystemVersionReport describes version information about the running Podman service
> type SystemVersionReport struct {
> 	// Always populated
> 	Client *define.Version `json:",omitempty"`
> 	// May be populated, when in tunnel mode
> 	Server *define.Version `json:",omitempty"`
> }
> ```
> pretty talkative..
> we're looking at https://docs.podman.io/en/latest/markdown/podman-system-service.1.html  
> but the me from the past didn't know yet..  
> 
> Let's get back at the other one...

```golang
// pkg/domain/infra/abi/system.go

func (ic ContainerEngine) Version(ctx context.Context) (*entities.SystemVersionReport, error) {
	var report entities.SystemVersionReport
	v, err := define.GetVersion()
	if err != nil {
		return nil, err
	}
	report.Client = &v
	return &report, err
}

// seems like we're just calling define.GetVersion()

// libpod/define/version.go
// GetVersion returns a VersionOutput struct for API and podman
func GetVersion() (Version, error) {
	var err error
	var buildTime int64
	if buildInfo != "" {
		// Converts unix time from string to int64
		buildTime, err = strconv.ParseInt(buildInfo, 10, 64)

		if err != nil {
			return Version{}, err
		}
	}
	return Version{
		APIVersion: version.APIVersion[version.Libpod][version.CurrentAPI].String(),
		Version:    version.Version.String(),
		GoVersion:  runtime.Version(),
		GitCommit:  gitCommit,
		BuiltTime:  time.Unix(buildTime, 0).Format(time.ANSIC),
		Built:      buildTime,
		OsArch:     runtime.GOOS + "/" + runtime.GOARCH,
		Os:         runtime.GOOS,
	}, nil
}
```
Same as before...?
...

> EDIT:  
> Not quite...  
> before it was:
> ```golang
> 	// ...
>  	version, err := define.GetVersion()
> 	// ...
> 	report.Client = &version
> 	
> 	// ...
> 	response, err := conn.DoRequest(ctx, nil, http.MethodGet, "/version", nil, nil)
> 	// ... 
> 	if err = response.Process(&component); err != nil {
> 	// ...
> 	report.Server = &define.Version{
> 		APIVersion: component.APIVersion,
> 		Version:    component.Version.Version,
> 		GoVersion:  component.GoVersion,
> 		GitCommit:  component.GitCommit,
> 		BuiltTime:  time.Unix(b.Unix(), 0).Format(time.ANSIC),
> 		Built:      b.Unix(),
> 		OsArch:     fmt.Sprintf("%s/%s", component.Os, component.Arch),
> 		Os:         component.Os,
> 	// ...
> 	return &report, err
> 
> ```
> 
> Looks like we already learned something about the codebase.. wonderfule  

It seems more like abi...  
sometimes you have to try it to make a sense out of it...  

```golang
// libpod/define/version.go
func GetVersion() (Version, error) {
		Version:    fmt.Sprintf("%s | :^)", version.Version.String()),
```

```bash
$ podman version
Client:       Podman Engine
Version:      4.4.0-dev | :^)
API Version:  4.4.0-dev
Go Version:   go1.19.2
Git Commit:   4bbe2ee012aec2283247e06b7a9066906b2cc92e-dirty
Built:        Sat Jan 28 00:23:42 2023
OS/Arch:      linux/amd64

```
There we go.

### Now.. back to our runtime thing..

I can see no reference to either the path or the version of the runtime we're using..

> Figuring what I was trying to say at that time..  
> This came out a couple of months after its draft, at the start of this journey.
> 
> Reading this a second time..  
> I realized how clear the outpuf for `podman help` was..  
> I was certainly looking for the wrong thing... and that blinded me..  
> But enough of this.. there's the twist at the end of the article.

but maybe I've just looked in the wrong corner. 

I was only able to obtain a list of supoprted oci runtimes and relative search paths,
but no reference to the one we're actually using...

```golang
// This is not even podman..
// It's the common/ module of the containers/ organization

// pkg/config/default.go
	c.OCIRuntimes = map[string][]string{
		"crun": {
			"/usr/bin/crun",
			"/usr/sbin/crun",
			"/usr/local/bin/crun",
			"/usr/local/sbin/crun",
			"/sbin/crun",
			"/bin/crun",
			"/run/current-system/sw/bin/crun",
		},
		"crun-wasm": {
			"/usr/bin/crun-wasm",
			"/usr/sbin/crun-wasm",
			"/usr/local/bin/crun-wasm",
			"/usr/local/sbin/crun-wasm",
			"/sbin/crun-wasm",
			"/bin/crun-wasm",
			"/run/current-system/sw/bin/crun-wasm",
		},
		"runc": {
			"/usr/bin/runc",
			"/usr/sbin/runc",
			"/usr/local/bin/runc",
			"/usr/local/sbin/runc",
			"/sbin/runc",
			"/bin/runc",
			"/usr/lib/cri-o-runc/sbin/runc",
			"/run/current-system/sw/bin/runc",
		},
		"runj": {
			"/usr/local/bin/runj",
		},
		"kata": {
			"/usr/bin/kata-runtime",
			"/usr/sbin/kata-runtime",
			"/usr/local/bin/kata-runtime",
			"/usr/local/sbin/kata-runtime",
			"/sbin/kata-runtime",
			"/bin/kata-runtime",
			"/usr/bin/kata-qemu",
			"/usr/bin/kata-fc",
		},
		"runsc": {
			"/usr/bin/runsc",
			"/usr/sbin/runsc",
			"/usr/local/bin/runsc",
			"/usr/local/sbin/runsc",
			"/bin/runsc",
			"/sbin/runsc",
			"/run/current-system/sw/bin/runsc",
		},
		"youki": {
			"/usr/local/bin/youki",
			"/usr/bin/youki",
			"/bin/youki",
			"/run/current-system/sw/bin/youki",
		},
		"krun": {
			"/usr/bin/krun",
			"/usr/local/bin/krun",
		},
		"ocijail": {
			"/usr/local/bin/ocijail",
		},
	}
	
// Here's where we're coming from..

// FROM
// pkg/config/config.go
func (c *EngineConfig) findRuntime() string {
	// Search for crun first followed by runc, kata, runsc
	for _, name := range []string{"crun", "runc", "runj", "kata", "runsc", "ocijail"} {
	// checked where OCIRuntimes was used..
		for _, v := range c.OCIRuntimes[name] {

// FROM
// pkg/config/default.go
func defaultConfigFromMemory() (*EngineConfig, error) {
	// Needs to be called after populating c.OCIRuntimes.
	c.OCIRuntime = c.findRuntime()

// FROM
// pkg/config/config.go
	// OCIRuntime is the OCI runtime to use.
	OCIRuntime string `toml:"runtime,omitempty"`	
	
// FROM
// cmd/podman/root.go
func rootFlags(cmd *cobra.Command, podmanConfig *entities.PodmanConfig) {
	//...
		runtimeFlagName := "runtime"
		pFlags.StringVar(&podmanConfig.RuntimePath, runtimeFlagName, podmanConfig.ContainersConfDefaultsRO.Engine.OCIRuntime, "Path to the OCI-compatible binary used to run containers.")
		_ = cmd.RegisterFlagCompletionFunc(runtimeFlagName, completion.AutocompleteDefault)
```

## stumbled upon container creation..

ContainerEngine.ContainerCreate is an interesting function, 

> Trying to recreate the line of thought...  
> Think I lost the thread and retraced my steps..

it calls things like generate.MakeContainer and generate.ExecuteCreate, which put 
everything in place, to obtain a container object to do stuff with.. like running it

In other words: "containers need a big config", they're complex objects.  
The most important(I guess..) containers commands in ContainerEngine, like 
ContainerCreate, ContainerClone, ContainerRun,... all rely on that 
pkg/specgen/generate package.

From what I can see, there are those big structs that each container
rely on:

```golang
// pkg/specgen/specgen.go

// SpecGenerator creates an OCI spec and Libpod configuration options to create
// a container based on the given configuration.
type SpecGenerator struct {
	ContainerBasicConfig
	ContainerStorageConfig
	ContainerSecurityConfig
	ContainerCgroupConfig
	ContainerNetworkConfig
	ContainerResourceConfig
	ContainerHealthCheckConfig

	image             *libimage.Image `json:"-"`
	resolvedImageName string          `json:"-"`
}
```
This is the thing that ContainerCreate takes as a param,
I guess is the most complete struct for container configuration...  
It inherits several other structs that should be responsible for given 
container lifecycle configurations.

Oh wait.. specgen.MakeContainer, doesn't only parse/adjust config..
it also calls specgen.makeCommand, which is responsible for a very familiar
aspect of a container run:  
The command that is run by the container.

```golang
// pkg/specgen/generate/oci.go

// Produce the final command for the container.
func makeCommand(s *specgen.SpecGenerator, imageData *libimage.ImageData, rtc *config.Config) ([]string, error) {
	finalCommand := []string{}

	// This draws the entrypoint from a number of places:
	// * s.Entrypoint is retrieved during container creation command I think..
	// like $ podman container create --entrypoint
	// * imageData.Config.Entrypoint should be
	// the Dockerfile/Containerfile's ENTRYPOINT entry :)
	// .. 
	// what happens here is that the specified --entrypoint flag 
	// takes precedence over the Containerfile's ENTRYPOINT
	entrypoint := s.Entrypoint
	if entrypoint == nil && imageData != nil {
		entrypoint = imageData.Config.Entrypoint
	}

	// This takes care of multiple entrypoints
	// like:
	// ENTRYPOINT ["/bin/bash", "/bin/somethingelse"]
	// ..
	// if we have multiple entrypoints,
	// or we have a non-empty first entrypoint in general..
	// we add that to the final container command.

	// Don't append the entrypoint if it is [""]
	if len(entrypoint) != 1 || entrypoint[0] != "" {
		finalCommand = append(finalCommand, entrypoint...)
	}

	// Only use image command if the user did not manually set an
	// entrypoint.
	// 
	// Is that so? s.Command is user prefixed cmd at the end of podman run?
	// ...
	// I think so:
	// from: cmd/podman/containers/run.go
	// inside func run(cmd *cobra.Command, args []string) error
	// which is called by "podman run" or "podman container run"
	// 	report, err := registry.ContainerEngine().ContainerRun(registry.GetContext(), runOpts)
	// 
	//
	command := s.Command
	if len(command) == 0 && imageData != nil && len(s.Entrypoint) == 0 {
		command = imageData.Config.Cmd
	}

	// appends the command, to the entrypoint
	finalCommand = append(finalCommand, command...)

	// if there's still nothing:
	if len(finalCommand) == 0 {
		return nil, fmt.Errorf("no command or entrypoint provided, and no CMD or ENTRYPOINT from image")
	}

	// if the spec for the container tells us 
	// that we need an init:
	if s.Init {  // a bool in the container spec.. not sure where it come from
		initPath := s.InitPath
		if initPath == "" && rtc != nil {
			// is there such a thing as a containerENgine default
			// path for container PID1??
			//.. 
			// Apparently there is:
			// pkg/config/default.go @ container/common
			// 	// DefaultInitPath is the default path to the container-init binary.
			//	DefaultInitPath = "/usr/libexec/podman/catatonit"
			initPath = rtc.Engine.InitPath
		}
		if initPath == "" {
			return nil, fmt.Errorf("no path to init binary found but container requested an init")
		}
		finalCommand = append([]string{define.ContainerInitPath, "--"}, finalCommand...)
	}

	return finalCommand, nil
}

```

One possible call stack has this aspect:
```
 1 cmd/podman/containers/run.go - run() -- your "$ podman run"
 2 pkg/domain/infra/abi/containers.go - (*ContainerEngine),ContainerRun() -- if locally
 3 pkg/specgen/generate/container_create.go - generate.MakeContainer()
 4 pkg/specgen/generate/oci.go - makeCommand()
```

While finding out how s.Command gets instantiated:  
 *Incontrovertible proof that `$ podman run` and `$ podman container run` are synonyms:

```golang
// cmd/podman/containers/run.go

var (
	runDescription = "Runs a command in a new container from the given image"
	runCommand     = &cobra.Command{
		Args:              cobra.MinimumNArgs(1),
		Use:               "run [options] IMAGE [COMMAND [ARG...]]",
		Short:             "Run a command in a new container",
		Long:              runDescription,
		RunE:              run,
		ValidArgsFunction: common.AutocompleteCreateRun,
		Example: `podman run imageID ls -alF /etc
  podman run --network=host imageID dnf -y install java
  podman run --volume /var/hostdir:/var/ctrdir -i -t fedora /bin/bash`,
	}

	containerRunCommand = &cobra.Command{
		Args:              cobra.MinimumNArgs(1),
		Use:               runCommand.Use,
		Short:             runCommand.Short,
		Long:              runCommand.Long,
		RunE:              runCommand.RunE,
		ValidArgsFunction: runCommand.ValidArgsFunction,
		Example: `podman container run imageID ls -alF /etc
	podman container run --network=host imageID dnf -y install java
	podman container run --volume /var/hostdir:/var/ctrdir -i -t fedora /bin/bash`,
	}
)
```

Another something that is interesting from the makeCommand, 
is the imageData.. which is of type *libimage.ImageData, which comes
from the containers/common library.

Those libraries are used by clis such as (at least) podman, buildah, skopeo,... 
and are at the core of the image-interactions mechanism 
that the clis build on top of...  
podman/docker/whatever are the container engines..  
but in fact they're just upperlevel logic,
that is wrapped around some more basic/lowlevel/lib-provided logic.

Yeah, it is pretty obvious..  
but I used to think about podman/docker, like those 
mysterious boxes that magic came out of.. 
Didn't even thought about container libraries..

### Different engines?

We already saw this with the two implementations of ContainerEngine.Version(),
the infra/abi thing..  
Let's get back at that run() that gets called when we `podman run` something..

This line that calls the implementation-specific ContainerRun():
```golang
// from cmd/podman/containers/run.go
//  -- inside run()
	report, err := registry.ContainerEngine().ContainerRun(registry.GetContext(), runOpts) 
```

Calls ContainerEngine(), in order to instantiate the actual implementation of the 
ContainerEngine-thing...  
It returns an 'entities.ContainerEngine'-thing:

```golang
// cmd/podman/registry/registry.go
func ContainerEngine() entities.ContainerEngine {
	return containerEngine
}
```

That containerEngine it returns is
a global var defined @ `cmd/podman/registry/registry.go`,  
that global var was tinkered by
`registry.NewContainerEngine() @ pkg/domain/infra/runtime_abi.go`,  
which gets *podmanOptions as a parameter.. which in turn gets instantiated by the 
flags passed to the actual `podman run` and by relative defaults.

That NewContainerEngine looks like this:
```golang
// pkg/domain/infra/runtime_abi.go

// NewContainerEngine factory provides a libpod runtime for container-related operations
func NewContainerEngine(facts *entities.PodmanConfig) (entities.ContainerEngine, error) {
	switch facts.EngineMode {
	case entities.ABIMode:
		r, err := NewLibpodRuntime(facts.FlagSet, facts)
		return r, err
	case entities.TunnelMode:
		ctx, err := bindings.NewConnectionWithIdentity(context.Background(), facts.URI, facts.Identity, facts.MachineMode)
		return &tunnel.ContainerEngine{ClientCtx: ctx}, err
	}
	return nil, fmt.Errorf("runtime mode '%v' is not supported", facts.EngineMode)
}
```

So if we want abi, we create a new LibpodRuntime,  
if we want tunnel, we try to connect with something.

> EDIT:  
> yep.. seems right;  
> we were looking at podman's SmallThinDaemon

### Implementations
There are different implementations of the containerEngine/ImageEngine/SYstemEngine:  
They're here:
  + github.com/containers/podman/v4/pkg/domain/infra/abi --> ./pkg/domain/infra/abi/
  + github.com/containers/podman/v4/pkg/domain/infra/tunnel --> ./pkg/domain/infra/tunne/
  
In general.... 
github.com/containers/podman/v4/pkg/domain/infra is the package containing 
the actual implementations (..of "podman"?).

I'm thinking that tunnel is the implementation of the ContainerEngine interface,
that it's supposed to be called from the podman api.

THe functions inside the tunnel, call functions inside the ./pkg/bindings/containers package.
The functions inside the abi don't.
That bindings package is at the same level as those libpod functions we already saw..
instead of directly operating with specs/images/whatnot/.. it's really clear what they do  
One example:
```golang
// pkg/bindings/containers/create.go

func CreateWithSpec(ctx context.Context, s *specgen.SpecGenerator, options *CreateOptions) (entities.ContainerCreateResponse, error) {
	var ccr entities.ContainerCreateResponse
	if options == nil {
		options = new(CreateOptions)
	}
	_ = options
	conn, err := bindings.GetClient(ctx)
	if err != nil {
		return ccr, err
	}
	specgenString, err := jsoniter.MarshalToString(s)
	if err != nil {
		return ccr, err
	}
	stringReader := strings.NewReader(specgenString)
	response, err := conn.DoRequest(ctx, stringReader, http.MethodPost, "/containers/create", nil, nil)
	if err != nil {
		return ccr, err
	}
	defer response.Body.Close()

	return ccr, response.Process(&ccr)
}

```

The two(abi/tunnel) are the implementation of the same interface that
github.com/containers/podman/v4/pkg/domain/entities.ContainerEngine is;  
abi is "the podman" itself,  
tunnel is podman frontend that is meant to be used 
by some http client, against some backend (perhaps podman itself..).

the containerEngine of tunnel:
```go
// pkg/domain/infra/tunnel/runtime.go

// Container-related runtime using an ssh-tunnel to utilize Podman service
type ContainerEngine struct {
	ClientCtx context.Context
}
```

the containerEngine of abi:
```go
// pkg/domain/infra/abi/runtime.go

// Container-related runtime linked against libpod library
type ContainerEngine struct {
	Libpod *libpod.Runtime
}
```

so one is backed by a libpod runtime: some crun/runc/crio/crun-wasm/whatever  
the other one is backed only by a context, and its methods are
implemented on top of the github.com/containers/podman/v4/pkg/bindings 
package, which is a golang binding to podman's REST API.  
This data structure inside the bindings package tells us more on what it is:

```go
// pkg/bindings/connection.go

type Connection struct {
	URI    *url.URL
	Client *http.Client
}
```

Top-level methods of the bindings package, intitialize a client, which is to be called to make requests.  
This signature inside the connection.go of the bindings package tells us how its ment to be called:
```go
// NewConnectionWithIdentity takes a URI as a string and returns a context with the
// Connection embedded as a value.  This context needs to be passed to each
// endpoint to work correctly.
//
// A valid URI connection should be scheme://
// For example tcp://localhost:<port>
// or unix:///run/podman/podman.sock
// or ssh://<user>@<host>[:port]/run/podman/podman.sock?secure=True
func NewConnectionWithIdentity(ctx context.Context, uri string, identity string, machine bool) (context.Context, error) {/*...*/}
```


> From [this README](https://github.com/containers/podman/blob/main/pkg/bindings/README.md)(
> referenced bu the doc.go file inside the bindings pkg), 
> we can have the complete picture.  
> 
> That is theoretically we can use just the bindings pkg to interact with a
> podman service, via http,  
> from our go application...  
> without getting out to the shell..  
> even without relying on a podman installed on the system!

## Container hacking

Now that we have a clearer idea about how things are designed..  
We can start writing something that would at least make
sense(programmatically speaking), to see then how the implementation evolves from there..

We know how the ContainerEngine thing is implemented..  
But what about the container runtime?  
And I'm referring to the one that we're actually using, 
the one that's currently embedded in some struct,
not some default path.  
We're currently relying on specifying the runtime to podman,
but we have nothing from podman that tells us that it's actually THAT ONE.

### from the bottom to the top...

Added a method to the ContainerEngine interface here:
```go
// pkg/domain/entities/engine_container.go

GetRuntimeInfo(ctx context.Context) string
```

Added the implementation here:

```go
// pkg/domain/infra/abi/system.go

func (ic *ContainerEngine) GetRuntimeInfo(ctx context.Context) string {
	return ic.Libpod.GetOCIRuntimePath()
} // let's start by getting this...
```

and here:  
(otherwise it would not compile...)  

```go
// pkg/domain/infra/tunnel/system.go 

func (ic *ContainerEngine) GetRuntimeInfo(ctx context.Context) string {
	return "toobad\n"
}
```

Then glued all together here:

```go
// cmd/podman/system/whichruntime.go

package system

import (
	"fmt"
	"os"

	"github.com/containers/podman/v4/cmd/podman/registry"
	"github.com/containers/podman/v4/cmd/podman/validate"
	"github.com/spf13/cobra"
)

var (
	whichRuntimeCommand = &cobra.Command{
		Use:               "whichruntime",
		Args:              validate.NoArgs,
		Short:             "Display some runtime related informations....",
		RunE:              whichruntime,
	}
	
	displaySearchPaths bool
	displaySearchPathsUsage = "show all configured runtime search paths"
)

func init() {
	registry.Commands = append(registry.Commands, registry.CliCommand{
		Command: whichRuntimeCommand,
	})

	flags := whichRuntimeCommand.Flags()
	flags.BoolVarP(&displaySearchPaths, "display-search-paths", "d", false, displaySearchPathsUsage)
}

func whichruntime(cmd *cobra.Command, args []string) error {
	ctx := registry.GetContext() //getting context
	ce := registry.ContainerEngine() // getting engine

	if displaySearchPaths == true {
		ctengConf, err := ce.Config(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "During config retrieval from engine: %v\n", err)
		}
		fmt.Printf("Configured search paths:\n")
		for i, v := range ctengConf.Engine.OCIRuntimes {
			fmt.Printf("%s:\n", i)
			for _, path := range v {
				fmt.Printf("\t-- %s\n", path)
			}
		}
		
		return nil
	}

	fmt.Printf("In-use runtime:\n")
	fmt.Printf("%s\n", ce.GetRuntimeInfo(ctx))
	
	return nil
}
```

It's a shot in the dark, because the underlying `ic.Libpod.GetOCIRuntimePath()` I used
to implement the abi method, looks like this:

```golang
// libpod/runtime.go

// GetOCIRuntimePath retrieves the path of the default OCI runtime.
func (r *Runtime) GetOCIRuntimePath() string {
	return r.defaultOCIRuntime.Path()
}
```

I was puzzled by it from the start.. at least we'd see that all the pieces can
stick together.. the worst that can happen is that I have to replace that defaultThing
with something else..

At this point we should be getting the path for the default OCIRuntime(..?)  
How does that change if I set the runtime flag?

The end result...

```bash
$ podman --runtime crun whichruntime

In-use runtime:
/usr/bin/crun
# at least it works..

```

odd...  
because if I say `$ which crun`, I get a `/usr/local/bin/crun`...  
And the command fails if I call it with some runtimes I built myself:  
It tells me `Error: default OCI runtime "crio" not found: invalid argument`...  
How could that be? I know that they're on the system..  
Is podman really that strict?  
Does it pull out its own runtimes from its hat?

Perhaps..

```bash
$(podman --runtime $(which crun) whichruntime | tail -n 1) --version
crun version 1.7.0.0.0.26-52e3 | :^)
commit: 52e303d3251c63c1a55d79cd1d45563d38ffb070
rundir: /run/user/1000/crun
spec: 1.0.0
+SYSTEMD +SELINUX +APPARMOR +CAP +SECCOMP +EBPF +YAJL
```

Promising start..


### deeper
If there is to go deeper with the whichruntime implementation...  
Perhaps to achieve something more than the path of the underlying runtime..
We must end up here:  
libpod/runtime.go

This contains
```go
// libpod/runtime.go

type Runtime struct {/*...*/}
```
which is **LibPod**.  
Which should be how podman interacts with crun/runc/crun-wasm/crio/runj/youki/kata/krun/runsc/...

### +
By the way.. it is not called "__runtime__" inside podman code (an authoritative place),
it is called "__OCI runtime__"; because "__runtime__" refers to..
```go
// libpod/runtime.go

// Make a new runtime based on the given configuration
// Sets up containers/storage, state store, OCI runtime
func makeRuntime(runtime *Runtime) (retErr error)
```
a libpod run..?..maybe..?

## ...

At this point, to have that functionality that I needed from libpod,
I started building from libpod's getInfo, all the way up to cmd/podman...

Then I found out that there already existed exactly what I've tried to build:

```go
// libpod/info.go

// top-level "host" info
func (r *Runtime) hostInfo() (*define.HostInfo, error) 
```
hostinfo!? I saw it and didn't sound like what I was looking for..

one level up:
```go
// libpod/info.go

// Info returns the store and host information
func (r *Runtime) info() (*define.Info, error)
```

another level up:
```go
// libpod/runtime.go

// Info returns the store and host information
func (r *Runtime) Info() (*define.Info, error) {
	return r.info()
}
```
another level up..
```go
func (ic *ContainerEngine) Info(ctx context.Context) (*define.Info, error) {
// Wat?
```

```bash
$ podman --runtime $(which crun) info
# ... cut some output
  ociRuntime:
    name: /usr/local/bin/crun
    package: Unknown
    path: /usr/local/bin/crun
    version: |-
      crun version 1.7.0.0.0.26-52e3 | :^)
      commit: 52e303d3251c63c1a55d79cd1d45563d38ffb070
      rundir: /run/user/1000/crun
      spec: 1.0.0
      +SYSTEMD +SELINUX +APPARMOR +CAP +SECCOMP +EBPF +YAJL
# ...
```

fuck.

So it turned out that the thing I was trying to build,
was already part of podman... 

Strange how when I `podman info`ed, I just got a wall of text;  
and now I got the ociRuntime version...  
I must've touched something.

..Also the help msg for the **--runtime** flag, had a very clear explaination of
that feature I discovered...

### How it works.. in the end

That *(Runtime).hostInfo() puts a whole lot of info on the screen,
it must've slipped me..  
And I was too concentrated on finding things on the code,
to document myself or pay attention to help msgs.

Among the other things, hostInfo() called this:
```golang
// libpod/info.go
func (r *Runtime) hostInfo() (*define.HostInfo, error) {
	// ...
	conmonInfo, ociruntimeInfo, err := r.defaultOCIRuntime.RuntimeInfo()
```

common with a typo?  
And I thought that that defaultOCIRuntime field was only a reference to what
runtime podman defaults to, if there's nothing provided by the user..

```golang
// libpod/oci.go

// OCIRuntime is an implementation of an OCI runtime.
// The OCI runtime implementation is expected to be a fairly thin wrapper around
// the actual runtime, and is not expected to include things like state
// management logic - e.g., we do not expect it to determine on its own that
// calling 'UnpauseContainer()' on a container that is not paused is an error.
// The code calling the OCIRuntime will manage this.
// TODO: May want to move the conmon cleanup code here - it depends on
// Conmon being in use.
type OCIRuntime interface { //nolint:interfacebloat
	// Name returns the name of the runtime.
	Name() string
	// Path returns the path to the runtime executable.
	Path() string

	// CreateContainer creates the container in the OCI runtime.
	// The returned int64 contains the microseconds needed to restore
	// the given container if it is a restore and if restoreOptions.PrintStats
	// is true. In all other cases the returned int64 is 0.
	CreateContainer(ctr *Container, restoreOptions *ContainerCheckpointOptions) (int64, error)
	// UpdateContainerStatus updates the status of the given container.
	UpdateContainerStatus(ctr *Container) error
	// StartContainer starts the given container.
	StartContainer(ctr *Container) error

	// ...

	// RuntimeInfo returns verbose information about the runtime.
	RuntimeInfo() (*define.ConmonInfo, *define.OCIRuntimeInfo, error)

}
```

Then the implementation for RuntimeInfo() looks like this:

```golang
// libpod/oci_conmon_common.go

// RuntimeInfo provides information on the runtime.
func (r *ConmonOCIRuntime) RuntimeInfo() (*define.ConmonInfo, *define.OCIRuntimeInfo, error) {
	// ...
	runtimeVersion, err := r.getOCIRuntimeVersion() // !?
	if err != nil {
		return nil, nil, fmt.Errorf("getting version of OCI runtime %s: %w", r.name, err)
	}
	conmonVersion, err := r.getConmonVersion() // ?!?
	if err != nil {
		return nil, nil, fmt.Errorf("getting conmon version: %w", err)
	}

	conmon := define.ConmonInfo{
		Package: conmonPackage,
		Path:    r.conmonPath,
		Version: conmonVersion,
	}
	ocirt := define.OCIRuntimeInfo{
		Name:    r.name,
		Path:    r.path,
		Package: runtimePackage,
		Version: runtimeVersion,
	}
	return &conmon, &ocirt, nil
}
```

I'm puzzled..  
Why the OCIRuntimeVersion-thing is not called by the Runtime-thing?  
There's another layer in the middle.. and I'm starting to thing that conmon is not a typo...

Those implementations speak for themselves:
```go
// libpod/oci_conmon_common.go

// getOCIRuntimeVersion returns a string representation of the OCI runtime's
// version.
func (r *ConmonOCIRuntime) getOCIRuntimeVersion() (string, error) {
	output, err := utils.ExecCmd(r.path, "--version")
	if err != nil {
		return "", err
	}
	return strings.TrimSuffix(output, "\n"), nil
}

// getConmonVersion returns a string representation of the conmon version.
func (r *ConmonOCIRuntime) getConmonVersion() (string, error) {
	output, err := utils.ExecCmd(r.conmonPath, "--version")
	if err != nil {
		return "", err
	}
	return strings.TrimSuffix(strings.Replace(output, "\n", ", ", 1), "\n"), nil
}
```

So runtime's api is just cli? Interesting..  
This does mean that everything we can do with a podman, we can do by hand as well.
(reminds me a post of the "demistifying containers" series).

That ExecCmd comes from the podman's utils pkg, and
it looks like this:

```go
// utils/utils.go

// ExecCmd executes a command with args and returns its output as a string along
// with an error, if any.
func ExecCmd(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("`%v %v` failed: %v %v (%v)", name, strings.Join(args, " "), stderr.String(), stdout.String(), err)
	}

	return stdout.String(), nil
}
```

Just a wrapper around basic command executions facilities provided by golang stdlib.  
[Podman is not that complex..] -- q.e.d.

The lowest level that podman reaches is that "**Conmon OCI runtime**"-wrapper/thing.  
podman calls the system container runtime (crun/runc/..) using conmon, which is a container
monitor facility, that does all the work of calling the container runtime itself, 
doing stuff with the output and sending all back to podman.  
Podman is like a baby local orchestrator? like a baby kübernetes?

# Container Engine

```
Container Engine
   |
   | (like **podman**)
   |
   ------------------ Container Runtime Monitor
                            |
                            | (like **conmon**)
                            |
                      OCI Runtime (like **crun**)
                         |It may be that just __runtime__ would
                         |not be enough to describe what **crun** is..
                         |In the podman codebase, crun is referred to as an
                         |**OCI Runtime**;
                         |In the podman codebase, **runtime** refers to the..
                         |well.. time in which a container is.. run
                         | ...
                         |Or it may just be that they found it more
                         |convenient that way with the naming...
```

I could've skipped this whole experience and still get out with all
the information I needed, and more, only by watching the first 15mins of
[this](https://www.youtube.com/watch?v=kJnxeinEWyA&t=1422s).  
someone commented the slides are
[here](https://www.slideshare.net/SaimSafder/podman-overview-and-internalspdf)...
never used slides in my life I think..  

Having said so..  
the whole experience would've been much less thirst quenching.
