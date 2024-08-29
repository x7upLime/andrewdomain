---
title: "Container Adventures 2"
date: 2023-01-23T15:17:23+02:00
lastmod: 2023-01-26T22:51:42+02:00
description: |
  My personal learning experience, started by trying to make sense of a minikube error;
  it later took me to the "how the 'Driver'-thing works in minikube", 
  and thorought the process of creation of the container image....
draft: false
minikube_master: 46bccc7defca8fce9c90f760cdf14026855d957a
tags:
 - container_adventures
 - golang
---

This whole thing happened after a couple of more trials in the container world 
and gave birth to those foolish junior prs/issues on [kubernetes/minikube](https://github.com/kubernetes/minikube)  
 [#15678](https://github.com/kubernetes/minikube/pull/15678) ca3  
 [#15696](https://github.com/kubernetes/minikube/pull/15696) ca3  
 [#15677](https://github.com/kubernetes/minikube/issues/15677) ca3 - the issue.. but the discussion is on slack  
 [#15491](https://github.com/kubernetes/minikube/pull/15491) ca3 -- not able to rebase + change in workflow  
 [#15697](https://github.com/kubernetes/minikube/issues/15697) the create-volume bug  
 [#15699](https://github.com/kubernetes/minikube/pull/15699) the create-volume proposed solution


## Solving container creation issues for the podman driver -- minikube
We were able to merge the newly proposed [cache-invalidation mechanism](https://github.com/kubernetes/minikube/pull/15678#issuecomment-1404612732)
(not yet actually.. it's still under discussion [here](https://github.com/kubernetes/minikube/issues/15677), but mainly on slack), based on
contentDigest.. so now the kicBase's cache interactions should be something more generic.

Thanks to this, we were able to define a new entity called kicDriver, which is something 
more generic than docker or podman.. its a mechanism that takes the common aspects of both
(maybe in the future will also support something else.. who knows) and put them to 
work, all this packed in a generic interface.

Now.. even tho the cache phase of ```minikube start``` seems to work with the podman driver,
only the rootful podman makes it past the container creation phase..  
For the rootless podman we have the following:
```
😄  minikube v1.28.0 on whatever..
    ▪ MINIKUBE_ROOTLESS=true
✨  Using the podman driver based on user configuration
📌  Using rootless Podman driver
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image to minikube cache ...
💾  Downloading Kubernetes v1.25.3 preload ...
    > preloaded-images-k8s-v18-v1...:  406.99 MiB / 406.99 MiB  100.00% 56.74 M
    > gcr.io/k8s-minikube/kicbase...:  404.96 MiB / 404.96 MiB  100.00% 22.67 M
⌛  Loading KicDriver with base image ...
🔥  Creating podman container (CPUs=2, Memory=8000MB) ...
✋  Stopping node "minikube"  ...
🔥  Deleting "minikube" in podman ...
🤦  StartHost failed, but will try again: creating host: create: creating: create kic node: container name "minikube": log: 2023-01-23T15:07:03.883512000+02:00 + grep -qw cpu /sys/fs/cgroup/cgroup.controllers
2023-01-23T15:07:03.884604000+02:00 + echo 'ERROR: UserNS: cpu controller needs to be delegated'
2023-01-23T15:07:03.884740000+02:00 ERROR: UserNS: cpu controller needs to be delegated
2023-01-23T15:07:03.884872000+02:00 + exit 1: container exited unexpectedly
🔥  Creating podman container (CPUs=2, Memory=8000MB) ...
😿  Failed to start podman container. Running "minikube delete" may fix it: creating host: create: creating: setting up container node: creating volume for minikube container: podman volume create minikube --label name.minikube.sigs.k8s.io=minikube --label created_by.minikube.sigs.k8s.io=true: exit status 125
stdout:

stderr:
Error: volume with name minikube already exists: volume already exists


❌  Exiting due to GUEST_PROVISION: Failed to start host: creating host: create: creating: setting up container node: creating volume for minikube container: podman volume create minikube --label name.minikube.sigs.k8s.io=minikube --label created_by.minikube.sigs.k8s.io=true: exit status 125
stdout:

stderr:
Error: volume with name minikube already exists: volume already exists

```
the "rootless podman" being:
```bash
$ minikube config set driver podman
$ minikube config set container-runtime crio
$ minikube config set rootless true
```

There's something wrong with the container creation step with this driver config..
I've got no Idea how this mechanism is like.. I only worked with the kicBase cache so far.  
I'd start by looking at how the mechanism as a whole looks like;  
so where does the "Creating podman container..." come from?  
```bash
## from root of minikube..
$ git grep -n "Creating %s container" ## this produced no output
$ git grep -n "Creating" ## this obviously produced a whole lot of it..
```
I looked for a container reference inside the output.. but eventually stumbled upon this:
```
pkg/minikube/machine/start.go:399:		out.Step(style.StartingVM, "Creating {{.driver_name}} {{.machine_type}} (CPUs={{.number_of_cpus}}, Memory={{.memory_size}}MB) ...", out.V{"driver_name": cfg.Driver, "number_of_cpus": cfg.CPUs, "memory_size": cfg.Memory, "machine_type": machineType})
```

which is part of this:
```golang
// pkg/minikube/machine/start.go
func showHostInfo(h *host.Host, cfg config.ClusterConfig) {
//  ......
	if driver.IsKIC(cfg.Driver) { // TODO:medyagh add free disk space on docker machine
		register.Reg.SetStep(register.CreatingContainer)
		out.Step(style.StartingVM, "Creating {{.driver_name}} {{.machine_type}} (CPUs={{.number_of_cpus}}, Memory={{.memory_size}}MB) ...", out.V{"driver_name": cfg.Driver, "number_of_cpus": cfg.CPUs, "memory_size": cfg.Memory, "machine_type": machineType})
		return
	}
```

which in called by this:
```golang
// pkg/minikube/machine/start.go
func createHost(api libmachine.API, cfg *config.ClusterConfig, n *config.Node) (*host.Host, error) {
	klog.Infof("createHost starting for %q (driver=%q)", n.Name, cfg.Driver)
	// ...
	// config read and some other setup stuff...

	if err := timedCreateHost(h, api, cfg.StartHostTimeout); err != nil {
		return nil, errors.Wrap(err, "creating host")
	}
	klog.Infof("duration metric: libmachine.API.Create for %q took %s", cfg.Name, time.Since(cstart))
	if cfg.Driver == driver.SSH {
		showHostInfo(h, *cfg) // <-- where we come from..
	}

	if err := postStartSetup(h, *cfg); err != nil {
		return h, errors.Wrap(err, "post-start")
	}

```
Now I bet that we're finding the string with the crying cat 😿 of the minikube's problematic output inside postSartSetup().  

...  
and I was wrong.. it happens.  
Logs from ~/.minikube/logs/lastStart.txt(where all the klog.Whatever() goes..) show that we didn't even ever reached postSartSetup().  
we getting closer..

What if look backwards, starting from the error itself.. I know a package that has the cat for sure:  
pkg/minikube/style/style.go  
and the crying cat is...  
```golang
// pkg/minikube/style/style.go

// Config is a map of style name to style struct
// For consistency, ensure that emojis added render with the same width across platforms.
var Config = map[Enum]Options{
	// ...
	Embarrassed:      {Prefix: "🤦  ", LowPrefix: LowWarning},
	Sad:              {Prefix: "😿  "}, // this one
	Shrug:            {Prefix: "🤷  "},
	// ...
}
```

and [gopls](https://github.com/golang/tools/tree/master/gopls) shows me that it is used only in a bunch of places.. 

```
pkg/minikube/style/style_enum.go
79: 	Sad
cmd/minikube/cmd/config/profile.go
84: 			out.ErrT(style.Sad, `Error loading profile config: {{.error}}`, out.V{"error": err})
93: 					out.ErrT(style.Sad, `Error while setting kubectl current context :  {{.error}}`, out.V{"error": err})
cmd/minikube/cmd/delete.go
542: 			out.ErrT(style.Sad, deletionError.Error())
554: 	out.ErrT(style.Sad, "Multiple errors deleting profiles")
cmd/minikube/cmd/update-context.go
51: 			out.ErrT(style.Sad, `Error while setting kubectl current context:  {{.error}}`, out.V{"error": err})
pkg/minikube/node/start.go
713: 	out.ErrT(style.Sad, `Failed to start {{.driver}} {{.driver_type}}. Running "{{.cmd}}" may fix it: {{.error}}`, out.V{"driver": drv, "driver_type": driver.MachineType(drv), "cmd": mustload.ExampleCmd(cc.Name, "delete"), "error": err})
pkg/minikube/out/out.go
422: 	msg := Sprintf(style.Sad, "If the above advice does not help, please let us know:")
pkg/minikube/service/service.go
291: 		out.Styled(style.Sad, "service {{.namespace_name}}/{{.service_name}} has no node port", out.V{"namespace_name": namespace, "service_name": service})
pkg/minikube/style/style.go
100: 	Sad:              {Prefix: "😿  "},
```

It's pretty obvious we're looking at pkg/minikube/node/start.go's
```golang
// pkg/minikube/node/start.go
// startHostInternal starts a new minikube host using a VM or None
func startHostInternal(api libmachine.API, cc *config.ClusterConfig, n *config.Node, delOnFail bool) (*host.Host, bool, error) {
```

It's not exactly were we're coming from. Let me figure it:
```
   pkg/minikube/node/start.go -- Provision()
        |
        | The furthest it makes sense to go..
        | This is alredy familiar, it calls beginDownloadKicBaseImage()
        | which is basically the kicBase cache logic
        | we tinkered with last time.
        | 
        |
    pkg/minikube/node/start.go -- startMachine()
                     |
                     |
                     -----> pkg/minikube/node/start.go -- startHostInternal()
					 
```

The one for the createHost() we ended up before the cat search is only a couple of layers deeper.  
So we could draw this:

```

=   pkg/minikube/node/start.go -- Provision()
		 |
		 |
=   pkg/minikube/node/start.go -- startMachine()
		 |
		 |		 
=   pkg/minikube/node/start.go -- startHostInternal()
         |
         |
=        .		                            ===😿====the=cat=error===
         |                                                      ^
         |                                                      |
=   pkg/minikube/machine/start.go -- StartHost()                |
         |                                                      |
         |                                                      |
=   pkg/minikube/machine/start.go -- createHost()    ------------ error is here.
         |
         |
=   pkg/minikube/machine/start.go -- showHostInfo()
         |
         |
=   =====🔥==the=creation=message======
```

...I'm never drawing that again..  
It could have been much easier to stacktrace it inside a debugger and copypaste it.

We're seeing the flame 'cause the code for creaHost().. before doing anything, calls showHostInfo() 
for every driver except the ssh one.
```golang
// pkg/minikube/machine/start.go
func createHost(api libmachine.API, cfg *config.ClusterConfig, n *config.Node) (*host.Host, error) {

	// ... 
	
	if cfg.Driver != driver.SSH {
		showHostInfo(nil, *cfg)
	}
	
	// this was the part I previously marked
	// "config read and some other setup stuff..."
	def := registry.Driver(cfg.Driver) // cfg.Driver -> just a string
	if def.Empty() {
		return nil, fmt.Errorf("unsupported/missing driver: %s", cfg.Driver)
	}
	dd, err := def.Config(*cfg, *n)
	if err != nil {
		return nil, errors.Wrap(err, "config")
	}
	data, err := json.Marshal(dd)
	if err != nil {
		return nil, errors.Wrap(err, "marshal")
	}

	h, err := api.NewHost(cfg.Driver, data)
	if err != nil {
		return nil, errors.Wrap(err, "new host")
	}
	defer postStartValidations(h, cfg.Driver)
	
	// ...
```

That registry.Driver(cfg.Driver) seems interesting..  
and I already heard the term "registry" from a conversation on [kübernetes's slack](https://minikube.sigs.k8s.io/community/),
in regard of an issue..

### the"registry" 
That `def := registry.Driver(string)` function.. just takes a driver name and instantiates
the base of it; later, when def.Config() is called.. some specific configuration magic starts to happen:
```golang
/// pkg/minikube/registry/global.go
// Driver gets a named driver from the global registry
func Driver(name string) DriverDef {
	return globalRegistry.Driver(name)
}

// globalRegistry being a var: -- pkg/minikube/registry/global.go
var (
	// globalRegistry is a globally accessible driver registry
	globalRegistry = newRegistry()
)
// pkg/minikube/registry/registry.go
func newRegistry() *driverRegistry {
	return &driverRegistry{
		drivers:        make(map[string]DriverDef),
		driversByAlias: make(map[string]DriverDef),
	}
}


// and that globalRegistry.Driver(string):
// pkg/minikube/registry/registry.go
// Driver returns a driver given a name
func (r *driverRegistry) Driver(name string) DriverDef {
	r.lock.RLock()
	defer r.lock.RUnlock()

	def, ok := r.drivers[name]
	if ok {
		return def
	}

	// Check if we have driver def with name as alias
	return r.driversByAlias[name]
}
```
I think now we know that a driver "registry" is:
```golang
// pkg/minikube/registry/registry.go
type driverRegistry struct {
	drivers        map[string]DriverDef
	driversByAlias map[string]DriverDef
	lock           sync.RWMutex
}
```

Just a fancy struct that contains the [drivers](https://minikube.sigs.k8s.io/docs/drivers/) that minikube supports?  
Hyphotesis supported by the fact that DriverDef == ...
```golang
// pkg/minikube/registry/registry.go
// DriverDef defines how to initialize and load a machine driver
type DriverDef struct {
	// Name of the machine driver. It has to be unique.
	Name string
	// Alias contains a list of machine driver aliases. Each alias should also be unique.
	Alias []string
	// Config is a function that emits a configured driver struct
	Config Configurator
	// Init is a function that initializes a machine driver, if built-in to the minikube binary
	Init Loader
	// Status returns the installation status of the driver
	Status StatusChecker
	// Default is whether this driver is selected by default or not (opt-in).
	Default bool
	// Priority returns the prioritization for selecting a driver by default.
	Priority Priority
}
```

We even have a doc.go file for that package registry:
```golang
// pkg/minikube/registry/doc.go

/*
Copyright 2018 The Kubernetes Authors All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// This package contains the registry to enable a docker machine driver to be used
// in minikube.

package registry

```
Hmmmm... that's not much to work with.  
From this one.. it looks like an [image registry](https://docs.docker.com/registry/).. which doesn't seem the case.

Fortunately.. there is a drvs folder here, that could enlighten us;  
Let me show you a piece of tree:
```bash
# from pkg/minikube/registry
$ tree drvs/

drvs/
├── docker
│   ├── docker.go
│   └── docker_test.go
├── init.go
├── kvm2
│   ├── doc.go
│   └── kvm2.go
├── podman
│   └── podman.go
├── ssh
│   └── ssh.go
...
└── vmwarefusion
    ├── doc.go
    └── vmwarefusion.go
```

Nothing could be more enlightning  
The init.go is just a list of supported drivers:
```golang
// pkg/minikube/registry/drvs/init.go
package drvs
import (
	// Register all of the drvs we know of
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/docker"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/hyperkit"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/hyperv"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/kvm2"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/none"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/parallels"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/podman"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/qemu2"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/ssh"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/virtualbox"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/vmware"
	_ "k8s.io/minikube/pkg/minikube/registry/drvs/vmwarefusion"
)
```

And each driver (say docker..) has an init() call for its package, that initializes its content inside the "registry":
```golang
func init() {
	if err := registry.Register(registry.DriverDef{
		Name:     driver.Docker,
		Config:   configure,
		Init:     func() drivers.Driver { return kic.NewDriver(kic.Config{OCIBinary: oci.Docker}) },
		Status:   status,
		Default:  true,
		Priority: registry.HighlyPreferred,
	}); err != nil {
		panic(fmt.Sprintf("register failed: %v", err))
	}
}
```

cobraish..  
No point in showing Register() code.. it is clear that it just puts a DriverDef inside the globalRegistry.  
So that the picture is as follows:
+ pkg/minikube/registry contains the global "registry".. even tho we don't directly interact with it, 
it contains all the drivers.
+ the various pkg/minikube/registry/drvs are initialized by putting their driver inside the global
registry at runtime, using init() functions; as if they're already there.. and any new driver can hook 
to the global registry by just initing its pkg.

## back to our bug..
So we're back to pkg/minikube/machine/start.go - createHost()
```golang
// pkg/minikube/machine/start.go
func createHost(api libmachine.API, cfg *config.ClusterConfig, n *config.Node) (*host.Host, error) {

	// ... 
	
	def := registry.Driver(cfg.Driver) // DONE
	if def.Empty() {
		return nil, fmt.Errorf("unsupported/missing driver: %s", cfg.Driver)
	}
	dd, err := def.Config(*cfg, *n)  // << could be a source of issues..
		                            // keeping in mind and returning later
	if err != nil {
		return nil, errors.Wrap(err, "config")
	}
	data, err := json.Marshal(dd)
	if err != nil {
		return nil, errors.Wrap(err, "marshal")
	}

	h, err := api.NewHost(cfg.Driver, data)  // << HERE.
	if err != nil {
		return nil, errors.Wrap(err, "new host")
	}
	defer postStartValidations(h, cfg.Driver)
	
	// ...
```
Even tho we're failing on timedCreateHost() inside k8s.io/minikube/pkg/minikube/machine.createHost,
I'd still give api.NewHost() a look.. just to have a little more info about the process, 

...

Oh.. that's not minikube. That api.NewHost() comes from ["github.com/docker/machine/libmachine"](https://github.com/docker/machine).  
That's part of the "docker-centric" heritage of minikube :)

Looking at this and at the description for the docker machine repo...
```golang
// libmachine/libmachine.go @ https://github.com/docker/machine.git
func (api *Client) NewHost(driverName string, rawDriver []byte) (*host.Host, error) {
	driver, err := api.clientDriverFactory.NewRPCClientDriver(driverName, rawDriver)

	// ...
	
	return &host.Host{
		// config and filepaths
		// based on the provided driverName.. 
	}, nil
}
```
It could be that the bigger picture is as follows..  
+ We're instantiating/finding our "node", which could be any kind of thing depending on the driver we're choosing:
    + container image for the KiC(Kübernetes in Container) workflow
    + vm image for the qemu/virtualbox/whatever..
    + a generic host with an sshd installed
	+ our localhost that we aknowledged has everything in place to kick kübernetes
+ We're creating a "docker machine"(giving docker capabilities to the vm/remote-host) if needed
but this should require some discrimination based on the driver
+ We're operating our cluster by the means provided by the Driver interface

But its too soon for that..

We could be looking at another chunk we would have to undockerize from minikube.  
Just because of the fact that we're using podman driver, we would have no need for a docker machine in the first place.

...

My bad.. it's not actually https://github.com/docker/machine.git that has been archived..   
THis quite interesting reading [here](https://github.com/docker/machine/issues/4537) 
and a sum of it [here](https://github.com/docker/machine/issues/4894), that described what happened.  
And what happened is that now we're
```golang
// go.mod
replace(		
	github.com/docker/machine => github.com/machine-drivers/machine v0.7.1-0.20211105063445-78a84df85426
)
```
And in fact using https://github.com/machine-drivers/machine which seems still maintaned; maintaining its fork relationship.  

#### undockerize?
Back to our timedCreateHost(); we can see that it's only a timer around an api.Create() call.

```golang
// pkg/minikube/machine/start.go
func timedCreateHost(h *host.Host, api libmachine.API, t time.Duration) error {
	timeout := make(chan bool, 1)
	go func() {
		time.Sleep(t)
		timeout <- true
	}()

	createFinished := make(chan bool, 1)
	var err error
	go func() {
		err = api.Create(h)
		createFinished <- true
	}()

	select {
	case <-createFinished:
		if err != nil {
			// Wait for all the logs to reach the client
			time.Sleep(2 * time.Second)
			return errors.Wrap(err, "create")
		}
		return nil
	case <-timeout:
		return fmt.Errorf("create host timed out in %f seconds", t.Seconds())
	}
}
```
where the used driver is LocalClient ([dlv](https://github.com/go-delve/delve) told me..)  
That doesn't seem part of the docker machine..  
Even grepping the docker machine repo doensn't show anything... would it be possible that..?  
Yes.. grepping shows that minikube implements its own libmachine api interface.

Struct and Create() method look like this.  
```golang
// pkg/minikube/machine/client.go
// LocalClient is a non-RPC implementation
// of the libmachine API
type LocalClient struct {
	certsDir  string
	storePath string
	*persist.Filestore
	legacyClient libmachine.API
	flock        *fslock.Lock
}

// Create creates the host
func (api *LocalClient) Create(h *host.Host) error {
	klog.Infof("LocalClient.Create starting")
	start := time.Now()
	defer func() {
		klog.Infof("LocalClient.Create took %s", time.Since(start))
	}()

	def := registry.Driver(h.DriverName)
	if def.Empty() {
		return fmt.Errorf("driver %q does not exist", h.DriverName)
	}
	if def.Init == nil {
		// NOTE: This will call provision.DetectProvisioner
		return api.legacyClient.Create(h)
	}

	steps := []struct {
		name string
		f    func() error
	}{
		{
			"bootstrapping certificates",
			func() error {
				// Lock is needed to avoid race condition in parallel Docker-Env test because issue #10107.
				// CA cert and client cert should be generated atomically, otherwise might cause bad certificate error.
				lockErr := api.flock.LockWithTimeout(time.Second * 5)
				if lockErr != nil {
					return fmt.Errorf("failed to acquire bootstrap client lock: %v " + lockErr.Error())
				}
				defer func() {
					lockErr = api.flock.Unlock()
					if lockErr != nil {
						klog.Errorf("failed to release bootstrap cert client lock: %v", lockErr.Error())
					}
				}()
				certErr := cert.BootstrapCertificates(h.AuthOptions())
				return certErr
			},
		},
		{
			"precreate",
			h.Driver.PreCreateCheck,
		},
		{
			"saving",
			func() error {
				return api.Save(h)
			},
		},
		{
			"creating",
			h.Driver.Create,
		},
		{
			"waiting",
			func() error {
				if driver.BareMetal(h.Driver.DriverName()) {
					return nil
				}
				return mcnutils.WaitFor(drivers.MachineInState(h.Driver, state.Running))
			},
		},
		{
			"provisioning",
			func() error {
				// Skippable because we don't reconfigure Docker?
				if driver.BareMetal(h.Driver.DriverName()) {
					return nil
				}
				return provisionDockerMachine(h)
			},
		},
	}

	for _, step := range steps {
		if err := step.f(); err != nil {
			return errors.Wrap(err, step.name)
		}
	}

	return nil
}
```

My editor is having a hard time navigating the machine mod.. I'm cloning and using it inside the workspace.

Each of the *steps* in the prev function, gives a name and a function to call;

Some steps use anonymous minikube functions, some use docker-machine ones, some rely on the underlying driver[!]

This driver is a docker-machine interface that has a wide range of implementation to fulfill any kind of need;
in particular, here's only some of the implementations..
```
drivers/amazonec2/amazonec2.go
64: type Driver struct {
drivers/azure/azure.go
67: type Driver struct {
drivers/digitalocean/digitalocean.go
23: type Driver struct {
drivers/errdriver/error.go
11: type Driver struct {
drivers/exoscale/exoscale.go
26: type Driver struct {
drivers/fakedriver/fakedriver.go
11: type Driver struct {
drivers/google/google.go
17: type Driver struct {
drivers/hyperv/hyperv.go
19: type Driver struct {
drivers/openstack/openstack.go
21: type Driver struct {
drivers/rackspace/rackspace.go
13: type Driver struct {
drivers/virtualbox/virtualbox.go
46: type Driver struct {
drivers/vmwarevcloudair/vcloudair.go
24: type Driver struct {
drivers/vmwarevsphere/vsphere.go
47: type Driver struct {
/home/andrew/go/src/wspace-container/minikube/pkg/drivers/kic/kic.go
53: type Driver struct {
/home/andrew/go/src/wspace-container/minikube/pkg/drivers/kvm/kvm.go
38: type Driver struct {
/home/andrew/go/src/wspace-container/minikube/pkg/drivers/none/none.go
47: type Driver struct {
/home/andrew/go/src/wspace-container/minikube/pkg/drivers/qemu/qemu.go
53: type Driver struct {
/home/andrew/go/src/wspace-container/minikube/pkg/drivers/ssh/ssh.go
46: type Driver struct {
/home/andrew/go/src/wspace-container/minikube/pkg/minikube/tests/driver_mock.go
33: type MockDriver struct {
```

This project aimed at bringing docker *anywhere*..  
Minikube itself implements the driver in a number of chunks..  
by pkg/drivers subpackages to be precise (kvm, kic, ..)

There's really no need to show the struct of factory method.. the locations are above; let's keep going.

We don't seem to customize the precreate step function.. so we're defaulting to docker-machine's BaseDriver,
which is that simple:
```golang
// libmachine/drivers/base.go @ machine
// PreCreateCheck is called to enforce pre-creation steps
func (d *BaseDriver) PreCreateCheck() error {
	return nil
}
```

I'm interested particularly in the "create" step,
which we're failing with rootless podman.  
I would guess that the driver implementation that we're looking at is the "Kübernetes In Container"(a.k.a. KiC) driver..

We're looking at `pkg/drivers/kic/kic.go - func(d *Driver) Create() error`.   
That's already a start.. stepping into it to see exactly where it breaks.

#### one step forward(?)

Found it!  
A big chunk of minikube seems to be putting together this long sh command:

```bash
$ podman run -d -t --privileged --security-opt seccomp=unconfined --tmpfs /tmp --tmpfs /run -v /lib/modules:/lib/modules:ro --hostname minikube --name minikube --label created_by.minikube.sigs.k8s.io=true --label name.minikube.sigs.k8s.io=minikube --label role.minikube.sigs.k8s.io= --label mode.minikube.sigs.k8s.io=minikube --network minikube --ip 192.168.49.2 --volume minikube:/var:exec --memory=8000mb -e container=podman --expose 8443 --publish=127.0.0.1::8443 --publish=127.0.0.1::22 --publish=127.0.0.1::2376 --publish=127.0.0.1::5000 --publish=127.0.0.1::32443 gcr.io/k8s-minikube/kicbase-builds:v0.0.36-1673540226-15630
```
No joking.. it's actually a cli run(it could've been either this or witchcraft):

```golang
// pkg/drivers/kic/oci/oci.go
// CreateContainer creates a container with "docker/podman run"
func createContainer(ociBin string, image string, opts ...createOpt) error {
	// ...
	if rr, err := runCmd(exec.Command(ociBin, args...)); err != nil {
		// full error: docker: Error response from daemon: Range of CPUs is from 0.01 to 8.00, as there are only 8 CPUs available.
		if strings.Contains(rr.Output(), "Range of CPUs is from") && strings.Contains(rr.Output(), "CPUs available") { // CPUs available
			return ErrCPUCountLimit
		}
		// example: docker: Error response from daemon: Address already in use.
		if strings.Contains(rr.Output(), "Address already in use") {
			return ErrIPinUse
		}
		return err
	}
```

That.. if fired by hand.. returns:  
``` Error: unable to find network with name or ID minikube: network not found ```  
We're one step closer..

I remember this being a step prior to container creation:
```golang
// pkg/drivers/kic/kic.go
func (d *Driver) Create() error {
	// ...
	if gateway, err := oci.CreateNetwork(d.OCIBinary, networkName, d.NodeConfig.Subnet, staticIP); err != nil {
		msg := "Unable to create dedicated network, this might result in cluster IP change after restart: {{.error}}"
		args := out.V{"error": err}
		if staticIP != "" {
			exit.Message(reason.IfDedicatedNetwork, msg, args)
		}
		out.WarningT(msg, args)
		// ...
```
Stepping into it..  
Seeing that CreateNetwork() seems to flow perfectly.. There is one thing that don't convince me: the oci.TryCreatedockernetwork()
function.. which takes an ociBin as parameter, so it should be good.. but we're failing on finding a resource that this function
seems to be responsible for. I'm thinking about an error condition that is not checked for.

There we go..  
At the end of the flow for oci.TryCreatedockernetwork(), the thing that happens is the same for the createContainer() thing:  
an sh exec of the ociBin; This is what's happening when all is initialized during runtime.
```
| > k8s.io/minikube/pkg/drivers/kic/oci.tryCreateDockerNetwork() ./pkg/drivers/kic/oci/network_create.go:146 (PC: 0x145927a)
   141:				args = append(args, fmt.Sprintf("com.docker.network.driver.mtu=%d", mtu))
   142:			}
   143:		}
   144:		args = append(args, fmt.Sprintf("--label=%s=%s", CreatedByLabelKey, "true"), fmt.Sprintf("--label=%s=%s", ProfileLabelKey, name), name)
   145:	
=> 146:		rr, err := runCmd(exec.Command(ociBin, args...))
   147:		if err != nil {
   148:			klog.Errorf("failed to create %s network %s %s with gateway %s and mtu of %d: %v", ociBin, name, subnet.CIDR, subnet.Gateway, mtu, err)
   149:			// Pool overlaps with other one on this address space
   150:			if strings.Contains(rr.Output(), "Pool overlaps") {
   151:				return nil, ErrNetworkSubnetTaken
(dlv) p args
[]string len: 8, cap: 10, [
	"network",
	"create",
	"--driver=bridge",
	"--subnet=192.168.49.0/24",
	"--gateway=192.168.49.1",
	"--label=created_by.minikube.sigs.k8s.io=true",
	"--label=name.minikube.sigs.k8s.io=minikube",
	"minikube",
]

```

So we should be more than able to do the same thing by hand:
```bash
$ podman network create -driver=bridge --subnet=192.168.49.0/24 --gateway=192.168.49.1 --label=created_by.minikube.sigs.k8s.io=true --label=name.minikube.sigs.k8s.io=minikube minikube
```
Which fails with: `Error: unsupported driver river=bridge: invalid argument`  
But apparently minikube is not detecting it;  
the code:

```golang
// pkg/drivers/kic/oci/network_create.go
func tryCreateDockerNetwork(ociBin string, subnet *network.Parameters, mtu int, name string) (net.IP, error) {
	// ...
	rr, err := runCmd(exec.Command(ociBin, args...))
	if err != nil {
		klog.Errorf("failed to create %s network %s %s with gateway %s and mtu of %d: %v", ociBin, name, subnet.CIDR, subnet.Gateway, mtu, err)
		// Pool overlaps with other one on this address space
		if strings.Contains(rr.Output(), "Pool overlaps") {
			return nil, ErrNetworkSubnetTaken
		}
		if strings.Contains(rr.Output(), "failed to allocate gateway") && strings.Contains(rr.Output(), "Address already in use") {
			return nil, ErrNetworkGatewayTaken
		}
		if strings.Contains(rr.Output(), "is being used by a network interface") {
			return nil, ErrNetworkGatewayTaken
		}
		return nil, fmt.Errorf("create %s network %s %s with gateway %s and MTU of %d: %w", ociBin, name, subnet.CIDR, subnet.Gateway, mtu, err)
	}
	return gateway, nil
}
```
What happens is that, at the end of the runCmd(), err is nil; so we're returning as everything's ok.

...

Oh.. my bad.. I was missing a '-' in '-driver=bridge': it should've been '- -driver=bridge'.  
Hmmm.. it works..  
Network's there:
```bash
$ podman network ls
NETWORK ID    NAME        DRIVER
5086431107ca  minikube    bridge
2f259bab93aa  podman      bridge
```

Then also the createContainer() command works..

```bash
$ podman run -d -t --privileged --security-opt seccomp=unconfined --tmpfs /tmp --tmpfs /run -v /lib/modules:/lib/modules:ro --hostname minikube --name minikube --label created_by.minikube.sigs.k8s.io=true --label name.minikube.sigs.k8s.io=minikube --label role.minikube.sigs.k8s.io= --label mode.minikube.sigs.k8s.io=minikube --network minikube --ip 192.168.49.2 --volume minikube:/var:exec --memory=8000mb -e container=podman --expose 8443 --publish=127.0.0.1::8443 --publish=127.0.0.1::22 --publish=127.0.0.1::2376 --publish=127.0.0.1::5000 --publish=127.0.0.1::32443 gcr.io/k8s-minikube/kicbase-builds:v0.0.36-1673540226-15630
```
It returns 0  
Dear god...

...

Oh.. when I was running `$podman run ...` I was doing it before `$ podman network creat...`, hence the confusion.. 
The fact that I missed a '-' during my parsing of the args dumped by the debugger(I've done it by hand..) seemed to confirm a 
false trail.

#### one step forward(!)
We were not failing inside createContainerNode() (now I don't even know why we were getting there in the first place..);
actually we're failing inside oci.PrepareContainernode().. which does volume preparation.. which seems like our initial error  
```
❌  Exiting due to GUEST_PROVISION: Failed to start host: creating host: create: creating: setting up container node: creating volume for minikube container: podman volume create minikube --label name.minikube.sigs.k8s.io=minikube --label created_by.minikube.sigs.k8s.io=true: exit status 125`  
stdout:

stderr:
Error: volume with name minikube already exists: volume already exists
```
Which I didn't even read carefully I guess..

In my defense, if retrying to `$ minikube start` without `$ minikube delete --all` first.. the error message changes to:  
``` 
❌  Exiting due to GUEST_PROVISION: Failed to start host: driver start: start: podman start minikube: exit status 125

stdout:

stderr:
Error: no container with name or ID "minikube" found: no such container
```

So we're failing the oci.PrepareContainernode() step here:

```golang
// pkg/drivers/kic/kic.go
func (d *Driver) Create() error {
	// ...
	if err := oci.PrepareContainerNode(params); err != nil {
		return errors.Wrap(err, "setting up container node")
	}
	// ...
```

which fails the "create" steps here:

```golang
// pkg/minikube/machine/client.go
func (api *LocalClient) Create(h *host.Host) error 
	// ...
		{
			"creating",
			h.Driver.Create,
		},
		
	// ...
	for _, step := range steps {
		if err := step.f(); err != nil {
			return errors.Wrap(err, step.name)
		}
	}

	return nil
```

and so forth...

oci.PrepareContainerNode() calls another ociBin-run-like function, called createVolume()...  
This is the incriminated function:

```golang
// createVolume creates a volume to be attached to the container with correct labels and prefixes based on profile name
// Caution ! if volume already exists does NOT return an error and will not apply the minikube labels on it.
// TODO: this should be fixed as a part of https://github.com/kubernetes/minikube/issues/6530
func createVolume(ociBin string, profile string, nodeName string) error {
	if _, err := runCmd(exec.Command(ociBin, "volume", "create", nodeName, "--label", fmt.Sprintf("%s=%s", ProfileLabelKey, profile), "--label", fmt.Sprintf("%s=%s", CreatedByLabelKey, "true"))); err != nil {
		return err
	}
	return nil
}
```
Just a `$ podman volume create` with a bunch of labels.. which if I had to guess, are used by minikube to keep track of 
what minikube creates, rather than what the user creates for its purposes outside the minikube perspective.. thus to don't clean
out user created containers during clean phase.

Our error is that minikube volume already exists... The comment on that function is pretty talkative too.  
So what is [#6530](https://github.com/kubernetes/minikube/issues/6530) about?

It's marked "Closed" but I cannot see any reference to any merged pr.

`$ podman volume ls` shows a minikube volume... then `$ minikube delete --all` is issued; I'd expect to see no more minikube 
volume.. but instead.. it's still there.  
So it should be safe to assume that removing that volume would fix our "podman-rootless-minikube-not-starting" issue. Really hope so..

Let's try a clean run:
```bash
$ podman volume rm minikube
$ podman system prune --all
$ minikube delete --all

## aaaaand..
$ minikube start
```

Fuck.

It doensn't work.. same error:
```
✋  Stopping node "minikube"  ...
🔥  Deleting "minikube" in podman ...
🤦  StartHost failed, but will try again: creating host: create: creating: create kic node: container name "minikube": log: 2023-01-24T14:20:51.264852000+02:00 + grep -qw cpu /sys/fs/cgroup/cgroup.controllers
2023-01-24T14:20:51.265972000+02:00 + echo 'ERROR: UserNS: cpu controller needs to be delegated'
2023-01-24T14:20:51.266089000+02:00 ERROR: UserNS: cpu controller needs to be delegated
2023-01-24T14:20:51.266169000+02:00 + exit 1: container exited unexpectedly
🔥  Creating podman container (CPUs=2, Memory=8000MB) ...
😿  Failed to start podman container. Running "minikube delete" may fix it: creating host: create: creating: setting up container node: creating volume for minikube container: podman volume create minikube --label name.minikube.sigs.k8s.io=minikube --label created_by.minikube.sigs.k8s.io=true: exit status 125
stdout:

stderr:
Error: volume with name minikube already exists: volume already exists


❌  Exiting due to GUEST_PROVISION: Failed to start host: creating host: create: creating: setting up container node: creating volume for minikube container: podman volume create minikube --label name.minikube.sigs.k8s.io=minikube --label created_by.minikube.sigs.k8s.io=true: exit status 125
stdout:

stderr:
Error: volume with name minikube already exists: volume already exists
```

Ok.. getting a grip to it  
It's a container creation that fails for some "cpu controller" issue.. and the oci.preparecontainernode() is not safe to run
multiple times.. so this results is us retrying container creation, but in the end failing for an unrelated error.

> EDIT:
> Actually its not a container creation that fails.. The container creates fine..  
> The newly created container immediately exits.. logging this:
> + userns=  
> + grep -Eqv '0[[:space:]]+0[[:space:]]+4294967295' /proc/self/uid_map  
> + userns=1  
> + echo 'INFO: running in a user namespace (experimental)'  
> INFO: running in a user namespace (experimental)  
> + validate_userns  
> + [[ -z 1 ]]  
> + local nofile_hard  
> ++ ulimit -Hn  
> + nofile_hard=1048576  
> + local nofile_hard_expected=64000  
> + [[ 1048576 -lt 64000 ]]  
> + [[ -f /sys/fs/cgroup/cgroup.controllers ]]  
> + for f in cpu memory pids  
> + grep -qw cpu /sys/fs/cgroup/cgroup.controllers  
> + echo 'ERROR: UserNS: cpu controller needs to be delegated'  
> ERROR: UserNS: cpu controller needs to be delegated  
> + exit 1


We could easily fix at least the show-wrong-err-msg issue, by adding a check on the volume.

..AAAnd we could (at some point) include volume cleanings when `$ minikube delete --all` is issued; (TODO)
which seems tied to [#15222](https://github.com/kubernetes/minikube/issues/15222)

...

Or maybe not.. It seems just that I didn't know about the extra `--purge` flag to `$ minikube delete --all`, which seems to also remove 
volumes when we're using podman.. The issue is still relevant by the way, it doesn't remove docker volumes
> PS.  
> It's confusing.. yeah..  
> That last volume thing confused me as well.  

...

While I was writing this, I was running `$ minikube start` after `$ minikube delete --all --purge` with rootless podman, just to be sure.
And then something very strange happened.. It worked..

...

..But only because the `--purge` flag, as described by `$ minikube delete --help`, has the effect of
removing the .minikube folder in the home directory.. Effectively removing cache and minikube config.  
So I was running with docker driver instead of podman.

That's why it was working.. I'll spare you the logs and my theories on this false trail.. this article is getting long.

Plus the help msg for the `--purge` flag, doesn't mention volumes..  
Someone on slack stated that `minikube delete --all` is for volumes.. any claim I made above is to be tossed..  
I'm not sure what happened.

#### starting to fix stuff..

What am I doing now.. fix the previous while the memory is still fresh.. or go to the next one and see if workarounds
work first, so that to mark it as "yes, it could work" and apply fixes to the stack of errors.. 
hoping to not find other n errors in the way.

Writing down things helps.. I was about to go with the latter, but on a second thought...

##### The "volume already exists" error
This should be no big deal to solve.. We could just add a check for the volume presence first.  
Let's check it out on a new branch.. separating PRs..

I talked about it on slack and created [#15697](https://github.com/kubernetes/minikube/issues/15697).  
The original function
```golang
// pkg/drivers/kic/oci/volumes.go
// createVolume creates a volume to be attached to the container with correct labels and prefixes based on profile name
// Caution ! if volume already exists does NOT return an error and will not apply the minikube labels on it.
// TODO: this should be fixed as a part of https://github.com/kubernetes/minikube/issues/6530
func createVolume(ociBin string, profile string, nodeName string) error {
	if _, err := runCmd(exec.Command(ociBin, "volume", "create", nodeName, "--label", fmt.Sprintf("%s=%s", ProfileLabelKey, profile), "--label", fmt.Sprintf("%s=%s", CreatedByLabelKey, "true"))); err != nil {
		return err
	}
	return nil
}
```

The new version:
```golang
// createVolume creates a volume to be attached to the container with correct labels and prefixes based on profile name
// Caution ! if volume already exists does NOT return an error and will not apply the minikube labels on it.
func createVolume(ociBin string, profile string, nodeName string) error {
	rr, err := runCmd(exec.Command(ociBin, "volume", "ls"))
	if err == nil {
		if strings.Contains(rr.Output(), nodeName) {
			klog.Infof("Trying to create %s volume using %s: Volume already exists !", nodeName, ociBin)
			return nil
		}

		_, err = runCmd(exec.Command(ociBin, "volume", "create", nodeName, "--label", fmt.Sprintf("%s=%s", ProfileLabelKey, profile), "--label", fmt.Sprintf("%s=%s", CreatedByLabelKey, "true")))
	}
	return err
}
```

Commit message:
```
Adds check for volume existence in oci driver's createVolume()

As the function's description states:
It should not return err or change labels if volume already exists..

Info that we found a volume might be helpful tho..
As unlikely as it may sound.. user might create a minikube volume
and wonder why its actual minikube cluster is not starting.

We're deleteing TODO msg.
The issue was already closed.
```

Done...  
Next.


##### The "cpu controller" error
This time it won’t be that easy.. I think..
I think this time we’re off the minikube sources.. the error is inside the kicBase container itself:

Placing an os.Exit() here:

```golang
// pkg/drivers/kic/oci/oci.go
func CreateContainerNode(p CreateParams) error {
	// ...
	
	os.Exit(0) // HERE --
	if err := createContainer(p.OCIBinary, p.Image, withRunArgs(runArgs...), withMounts(p.Mounts), withPortMappings(p.PortMappings)); err != nil {
		return errors.Wrap(err, "create container")
	}

	if err := retry.Expo(checkRunning(p), 15*time.Millisecond, 25*time.Second); err != nil {
		excerpt := LogContainerDebug(p.OCIBinary, p.Name)
```

Will give minikube free quarter to instantiate all the resources we’d need in order to successfully launch the following:
```bash
$ podman run -d -t --privileged --security-opt seccomp=unconfined --tmpfs /tmp --tmpfs /run -v /lib/modules:/lib/modules:ro --hostname minikube --name minikube --label created_by.minikube.sigs.k8s.io=true --label name.minikube.sigs.k8s.io=minikube --label role.minikube.sigs.k8s.io= --label mode.minikube.sigs.k8s.io=minikube --network minikube --ip 192.168.49.2 --volume minikube:/var:exec --memory=8000mb -e container=podman --expose 8443 --publish=127.0.0.1::8443 --publish=127.0.0.1::22 --publish=127.0.0.1::2376 --publish=127.0.0.1::5000 --publish=127.0.0.1::32443 gcr.io/k8s-minikube/kicbase-builds:v0.0.36-1674164627-15541
```

Which launches.. But the resulting container immediately exists;
`$ podman logs someImageID` shows us some more output:

```
+ userns=
+ grep -Eqv '0[[:space:]]+0[[:space:]]+4294967295' /proc/self/uid_map
+ userns=1
+ echo 'INFO: running in a user namespace (experimental)'
INFO: running in a user namespace (experimental)
+ validate_userns
+ [[ -z 1 ]]
+ local nofile_hard
++ ulimit -Hn
+ nofile_hard=1048576
+ local nofile_hard_expected=64000
+ [[ 1048576 -lt 64000 ]]
+ [[ -f /sys/fs/cgroup/cgroup.controllers ]]
+ for f in cpu memory pids
+ grep -qw cpu /sys/fs/cgroup/cgroup.controllers
+ echo 'ERROR: UserNS: cpu controller needs to be delegated'
ERROR: UserNS: cpu controller needs to be delegated
+ exit 1
```
This err message at the end got me throught
[a more or less related](https://unix.stackexchange.com/questions/624428/cgroups-v2-cgroup-controllers-not-delegated-to-non-privileged-users-on-centos-s) 
answer on stackoverflow; “I want to run rootless containers with podman” seems like what I’m trying to accomplish.

And in fact, repeating all the setup procedure for podman, to run the uppermentioned container as root, produced a whole different result
```bash
$ sudo podman volume create minikube --label name.minikube.sigs.k8s.io=minikube --label created_by.minikube.sigs.k8s.io=true
$ sudo podman network create --driver=bridge --subnet=192.168.49.0/24 --gateway=192.168.49.1 --label=created_by.minikube.sigs.k8s.io=true --label=name.minikube.sigs.k8s.io=minikube minikube
$ sudo podman run -it --privileged --security-opt seccomp=unconfined --tmpfs /tmp --tmpfs /run -v /lib/modules:/lib/modules:ro --hostname minikube --label created_by.minikube.sigs.k8s.io=true --label name.minikube.sigs.k8s.io=minikube --label role.minikube.sigs.k8s.io= --label mode.minikube.sigs.k8s.io=minikube --network minikube --ip 192.168.49.2 --volume minikube:/var:exec --memory=8000mb -e container=podman --expose 8443 --publish=127.0.0.1::8443 --publish=127.0.0.1::22 --publish=127.0.0.1::2376 --publish=127.0.0.1::5000 --publish=127.0.0.1::32443 gcr.io/k8s-minikube/kicbase-builds:v0.0.36-1674164627-15541 -- /bin/sh
```

```
[  OK  ] Listening on D-Bus System Message Bus Socket.
         Starting Docker Socket for the API.
         Starting Podman API Socket.
[  OK  ] Listening on Docker Socket for the API.
[  OK  ] Listening on Podman API Socket.
[  OK  ] Reached target Sockets.
[  OK  ] Reached target Basic System.
         Starting containerd container runtime...
[  OK  ] Started D-Bus System Message Bus.
         Starting minikube automount...
         Starting OpenBSD Secure Shell server...
[  OK  ] Finished minikube automount.
[  OK  ] Started OpenBSD Secure Shell server.
[  OK  ] Started containerd container runtime.
         Starting Docker Application Container Engine...
[  OK  ] Started Docker Application Container Engine.
[  OK  ] Reached target Multi-User System.
[  OK  ] Reached target Graphical Interface.
         Starting Update UTMP about System Runlevel Changes...
[  OK  ] Finished Update UTMP about System Runlevel Changes.
```

It’s systemd! We’re inside the container(we can’t do much tho..).

If we’re executing with its entrypoint – /usr/local/bin/entrypoint($ minikube inspect imageID) instead of
going to bash, we obtain a working "node" container.
```
$ sudo podman ps 
CONTAINER ID  IMAGE                                                        COMMAND     CREATED             STATUS                 PORTS                                                                                                                                 NAMES
b215ff45b340  gcr.io/k8s-minikube/kicbase-builds:v0.0.36-1674164627-15541              About a minute ago  Up About a minute ago  127.0.0.1:39057->22/tcp, 127.0.0.1:46879->2376/tcp, 127.0.0.1:46527->5000/tcp, 127.0.0.1:35029->8443/tcp, 127.0.0.1:38423->32443/tcp  minikube
```
##### The kicBase image

Ok now where does the kicBase image even come from?

The minikube site has [this tutorial](https://minikube.sigs.k8s.io/docs/contrib/building/iso/)
that explains how to build the .iso; it’s not exactly what we’re looking for, but I can see that it’s a make command…
Could it be?

```bash
$ make help
Available targets for minikube v1.28.0
--------------------------------------
all                            Build all different minikube components
drivers                        Build Hyperkit and KVM2 drivers
cross                          Build minikube for all platform
exotic                         Build minikube for non-amd64 linux
retro                          Build minikube for legacy 32-bit linux
windows                        Build minikube for Windows 64bit
darwin                         Build minikube for Darwin 64bit
linux                          Build minikube for Linux 64bit
goimports                      Run goimports and list the files differs from goimport's
golint                         Run golint
gocyclo                        Run gocyclo (calculates cyclomatic complexities)
lint                           Run lint
lint-ci                        Run lint-ci
apt                            Generate apt package file
## Here it is...
local-kicbase                  Builds the kicbase image and tags it local/kicbase:latest and local/kicbase:$(KIC_VERSION)-$(COMMIT_SHORT)
local-kicbase-debug            Builds a local kicbase image and switches source code to point to it
build-kic-base-image           Build multi-arch local/kicbase:latest
push-kic-base-image            Push multi-arch local/kicbase:latest to all remote registries
upload-preloaded-images-tar    Upload the preloaded images for oldest supported, newest supported, and default kubernetes versions to GCS.
```

```Makefile
# Makefile
.PHONY: local-kicbase
local-kicbase: ## Builds the kicbase image and tags it local/kicbase:latest and local/kicbase:$(KIC_VERSION)-$(COMMIT_SHORT)
	docker build -f ./deploy/kicbase/Dockerfile -t local/kicbase:$(KIC_VERSION) --build-arg VERSION_JSON=$(VERSION_JSON) --build-arg COMMIT_SHA=${VERSION}-$(COMMIT_NOQUOTES) --cache-from $(KICBASE_IMAGE_GCR) .
	docker tag local/kicbase:$(KIC_VERSION) local/kicbase:latest
	docker tag local/kicbase:$(KIC_VERSION) local/kicbase:$(KIC_VERSION)-$(COMMIT_SHORT)
```

nobody is gonna read this article at this point…

Had to apply a couple of little fixes in order to make `make build-kic-base-image` work.. 
later a maintainer on slack told me to stick to `make local-kicbase` instead: 
the former was used to build the kicBase for multiple archs.. 
which I guess is not supported?   
`ERROR: docker exporter does not currently support exporting manifest lists`  
either local-kicbase.. or just comment out the extra archs from makefile.

But now we have an image:

```
$ docker images 
REPOSITORY      TAG                                  IMAGE ID       CREATED          SIZE
local/kicbase   latest                               e099056031d5   19 minutes ago   1.15GB
local/kicbase   v0.0.36-1674164627-15541             e099056031d5   19 minutes ago   1.15GB
local/kicbase   v0.0.36-1674164627-15541-1784105c6   e099056031d5   19 minutes ago   1.15GB
```
and since we’re trying to make it work on podman, a docker_save/podman_load after..

```
$ podman images 
REPOSITORY                TAG         IMAGE ID      CREATED         SIZE
<none>                    <none>      e099056031d5  20 minutes ago  1.16 GB
```

good old imageID.

First thing is to create the resources with the previous podman network/volume create commands..

Then again, running the container works, but it immediately stops with same logs == we’re on the same track.
`ERROR: UserNS: cpu controller needs to be delegated`
This cpu controller really needs to be delegated; where is docker picking its stuff in order to build the image?

As the Makefile points out.. there’s a Dockerfile inside ./deply/kicbase;
which is quite huge, so I’m not posting it.. only the relevant parts:

Number one:

```Dockerfile
# ./deploy/kicbase/Dockerfile
# ...
COPY --from=auto-pause /src/cmd/auto-pause/auto-pause-${TARGETARCH} /bin/auto-pause

# Install dependencies, first from apt, then from release tarballs.
# NOTE: we use one RUN to minimize layers.  <--- Here
#
```
hmm.. we could (possibly?) use some buildah/Containerfile build types..
Dunno what the actual state of the art for docker builds is..(TODO)

Number two:
```Dockerfile
#./deploy/kicbase/Dockerfile

# First we must ensure that our util scripts are executable.
#
# The base image already has: ssh, apt, snapd, but we need to install more packages.
# Packages installed are broken down into (each on a line):
# - packages needed to run services (systemd)
# - packages needed for kubernetes components
# - packages needed by the container runtime
# - misc packages kind uses itself
# - packages that provide semi-core kubernetes functionality
# After installing packages we cleanup by:
# - removing unwanted systemd services
# - disabling kmsg in journald (these log entries would be confusing)
#
# Next we ensure the /etc/kubernetes/manifests directory exists. Normally
# a kubeadm debian / rpm package would ensure that this exists but we install
# freshly built binaries directly when we build the node image.
#
# Finally we adjust tempfiles cleanup to be 1 minute after "boot" instead of 15m
# This is plenty after we've done initial setup for a node, but before we are
# likely to try to export logs etc.
```

The whole workflow is documented. Wonderful!
It’s exactly how it’s written.. a couple of RUNs for each piece so… Even if not configured to be used, all the pieces (docker/podman/containerd/crio/crun/…) are still inside the image.

Dumping some random RUNs:
```Dockerfile
# ./deploy/kicbase/Dockerfile

# install cri-o based on https://github.com/cri-o/cri-o/blob/release-1.24/README.md#installing-cri-o
RUN export ARCH=$(dpkg --print-architecture | sed 's/ppc64el/ppc64le/' | sed 's/armhf/arm-v7/') && \
    if [ "$ARCH" != "ppc64le" ] && [ "$ARCH" != "arm-v7" ]; then sh -c "echo 'deb https://downloadcontent.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${CRIO_VERSION}/xUbuntu_20.04/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:${CRIO_VERSION}.list" && \
    curl -LO https://downloadcontent.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${CRIO_VERSION}/xUbuntu_20.04/Release.key && \
    apt-key add - < Release.key && \
    clean-install cri-o cri-o-runc; fi
```

```Dockerfile
# ./deploy/kicbase/Dockerfile

# Install cri-dockerd from pre-compiled binaries stored in GCS, this is way faster than building from source in multi-arch
RUN echo "Installing cri-dockerd" && \
        curl -L "https://storage.googleapis.com/kicbase-artifacts/cri-dockerd/${CRI_DOCKERD_VERSION}/${TARGETARCH}/cri-dockerd" -o /usr/bin/cri-dockerd && chmod +x /usr/bin/cri-dockerd && \
        curl -L "https://storage.googleapis.com/kicbase-artifacts/cri-dockerd/${CRI_DOCKERD_VERSION}/cri-docker.socket" -o /usr/lib/systemd/system/cri-docker.socket && \
        curl -L "https://storage.googleapis.com/kicbase-artifacts/cri-dockerd/${CRI_DOCKERD_VERSION}/cri-docker.service" -o /usr/lib/systemd/system/cri-docker.service
```
##### make kicBase is slooooow…

What I’m doing now is to try to guess which thing is responsible for that `ERROR: UserNS: cpu controller needs to be delegated` error,
which I didn’t ever see inside a container before..
The thing is that making the whole kicbase is a time consuming process.. But do we need the full 1.16G image?
I guess not.. so we’re stripping it down.

What I want to reproduce is the same ERROR output from the official kicBase.  
Just by trying to get to a shell inside of it for now, then try to call the entrypoint.

With the full image, doing this
`$ podman run -it officialKIcBase /bin/sh` is enough to trigger the error…  
Just an sh?  
What could’ve possibly gone wrong?

> EDIT  
> Got rid of it removing ENTRYPOINT directive inside Dockerfile  
> I thought that appending
> the command at the end of podman run would override entrypoint..

I tried to strip everything excpet the systemd parts from the container, since it seems responsible for the error.
I ended up with:

```Dockerfile
FROM golang:1.19.5 as auto-pause
WORKDIR /src
COPY pkg/ ./pkg
COPY cmd/ ./cmd
COPY deploy/addons ./deploy/addons
COPY translations/ ./translations
COPY third_party/ ./third_party
COPY go.mod go.sum ./

ARG TARGETARCH
ENV GOARCH=${TARGETARCH}
ARG PREBUILT_AUTO_PAUSE
RUN if [ "$PREBUILT_AUTO_PAUSE" != "true" ]; then cd ./cmd/auto-pause/ && go build -o auto-pause-${TARGETARCH}; fi

FROM ubuntu:focal-20221019 as kicbase

ARG BUILDKIT_VERSION="v0.11.0"
ARG FUSE_OVERLAYFS_VERSION="v1.7.1"
ARG CONTAINERD_FUSE_OVERLAYFS_VERSION="1.0.3"
ARG CRIO_VERSION="1.24"
ARG CRI_DOCKERD_VERSION="0de30fc57b659cf23b1212d6516e0cceab9c91d1"
ARG TARGETARCH

COPY deploy/kicbase/10-network-security.conf /etc/sysctl.d/10-network-security.conf
COPY deploy/kicbase/11-tcp-mtu-probing.conf /etc/sysctl.d/11-tcp-mtu-probing.conf
COPY deploy/kicbase/02-crio.conf /etc/crio/crio.conf.d/02-crio.conf
COPY deploy/kicbase/containerd.toml /etc/containerd/config.toml
COPY deploy/kicbase/containerd_docker_io_hosts.toml /etc/containerd/certs.d/docker.io/hosts.toml
COPY deploy/kicbase/clean-install /usr/local/bin/clean-install
COPY deploy/kicbase/entrypoint /usr/local/bin/entrypoint
COPY deploy/kicbase/CHANGELOG ./CHANGELOG
COPY --from=auto-pause /src/cmd/auto-pause/auto-pause-${TARGETARCH} /bin/auto-pause

RUN echo "Ensuring scripts are executable ..." \
    && chmod +x /usr/local/bin/clean-install /usr/local/bin/entrypoint \
 && echo "Installing Packages ..." \
    && DEBIAN_FRONTEND=noninteractive clean-install \
      systemd \
      conntrack iptables iproute2 ethtool socat util-linux mount ebtables udev kmod \
      libseccomp2 pigz \
      bash ca-certificates curl rsync \
      nfs-common \
      iputils-ping netcat-openbsd vim-tiny \
    && find /lib/systemd/system/sysinit.target.wants/ -name "systemd-tmpfiles-setup.service" -delete \
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
    && rm -f /etc/systemd/system/*.wants/* \
    && rm -f /lib/systemd/system/local-fs.target.wants/* \
    && rm -f /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -f /lib/systemd/system/basic.target.wants/* \
    && echo "ReadKMsg=no" >> /etc/systemd/journald.conf \
    && ln -s "$(which systemd)" /sbin/init \
 && echo "Ensuring /etc/kubernetes/manifests" \
    && mkdir -p /etc/kubernetes/manifests \
 && echo "Adjusting systemd-tmpfiles timer" \
 && echo "Disabling udev" \
    && systemctl disable udev.service \
 && echo "Modifying /etc/nsswitch.conf to prefer hosts" \

ENV container docker
STOPSIGNAL SIGRTMIN+3

ARG COMMIT_SHA
USER root

ARG VERSION_JSON
RUN echo "${VERSION_JSON}" > /version.json

COPY deploy/kicbase/automount/minikube-automount /usr/sbin/minikube-automount
COPY deploy/kicbase/automount/minikube-automount.service /usr/lib/systemd/system/minikube-automount.service
RUN ln -fs /usr/lib/systemd/system/minikube-automount.service \
    /etc/systemd/system/multi-user.target.wants/minikube-automount.service

COPY deploy/kicbase/scheduled-stop/minikube-scheduled-stop /var/lib/minikube/scheduled-stop/minikube-scheduled-stop
COPY deploy/kicbase/scheduled-stop/minikube-scheduled-stop.service /usr/lib/systemd/system/minikube-scheduled-stop.service
RUN  chmod +x /var/lib/minikube/scheduled-stop/minikube-scheduled-stop

RUN rm -rf \
  /usr/share/doc/* \
  /usr/share/man/* \
  /usr/share/local/*
RUN echo "kic! Build: ${COMMIT_SHA} Time :$(date)" > "/kic.txt"

### then make local-kicbase builds it
### then docker_save/podman_load ....
```

Which doesn’t reproduce the error..
Which seems bogus, since everything else on that Dockerfile is just installing stuff..

I successfully got a shell inside the container.
Something as simple as `# systemctl list-units` wouldn’t work, cause

```
root@a26f881f092a:/# systemctl list-units
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
```

Allright.. so something must be invoking systemd in some way somewhere..

What about the previous entrypoint?

```Dockerfile
# original Dockerfile @ ./deploy/kicbase/Dockerfile

#...
COPY deploy/kicbase/entrypoint /usr/local/bin/entrypoint

# NOTE: this is *only* for documentation, the entrypoint is overridden later
ENTRYPOINT [ "/usr/local/bin/entrypoint", "/sbin/init" ]

## dunno where it's overridden.. whatever..

```

Well.. dunno why I wasn’t able to override the entrypoint with the podman run command, but let’s try it out:

```
# from inside the container

$ /usr/local/bin/entrypoint
...
ERROR: UserNS: cpu controller needs to be delegated
+ exit 1
```
yep.. Here it is.
Let’s look at what it’s doing..

At the top of the file there is already a set -x, which makes all the ‘+’/’++’ prefixed line of output appear..
We can start reading from there…

Those are the only lines that we need:

```bash
# deploy/kicbase/entrypoint

# If /proc/self/uid_map 4294967295 mappings, we are in the initial user namespace, i.e. the host.
# Otherwise we are in a non-initial user namespace.
# https://github.com/opencontainers/runc/blob/v1.0.0-rc92/libcontainer/system/linux.go#L109-L118
userns=""
if grep -Eqv "0[[:space:]]+0[[:space:]]+4294967295" /proc/self/uid_map; then
  userns="1"
  echo 'INFO: running in a user namespace (experimental)'
fi

# then a bunch of definitions..

validate_userns() {
  if [[ -z "${userns}" ]]; then
    return
  fi

  local nofile_hard
  nofile_hard="$(ulimit -Hn)"
  local nofile_hard_expected="64000"
  if [[ "${nofile_hard}" -lt "${nofile_hard_expected}" ]]; then
    echo "WARN: UserNS: expected RLIMIT_NOFILE to be at least ${nofile_hard_expected}, got ${nofile_hard}" >&2
  fi

  if [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
    for f in cpu memory pids; do
      if ! grep -qw $f /sys/fs/cgroup/cgroup.controllers; then
## [!] we're dying here:
        echo "ERROR: UserNS: $f controller needs to be delegated" >&2
        exit 1
      fi
    done
  fi
}

# then other bunch of definitions..
# ultimately validate_userns gets called

# validate state
validate_userns
```

I thought there was some bug inside the grep or something..
There’s nothing wrong.. it was the original willing of the author(git blame him :).
Also.. if running a bash on the same container from `sudo podman` or `docker`, we’re getting past that line.

I have no idea what this means.

##### fastforward...
Ok now I have..

I was about to ask directly the one responsible for that line of code(he was online), but as happens to me a lot of times..
while I was writing the question.. I investigated further.. 'till I got the answer..

What happens is the following:

1. [this article](https://medium.com/nttlabs/cgroup-v2-596d035be4d7) talks about the migration from cgroupsv1 to
to cgroupsv2 and its status (at that time).. it also talks about podman and rootless containers and explains how 
to solve our issue(search for `podman run --cpus`), as well as why it's an issue.

2. [why is that an issue..](https://systemd.io/CGROUP_DELEGATION/#some-donts) more in detail (plus the link in the article is broken).  
It actually was considered an issue with cgroupsv1.. but then with cgroupsv2 it became like running a less-rootless container..?  
Still figuring..

3. [the solution expanded](https://rootlesscontaine.rs/getting-started/common/cgroup2/#enabling-cpu-cpuset-and-io-delegation), even tho
at the end it says to reboot.. actually a ` sudo systemctl daemon-reload` is enough for the delegation to take effect  
Althought I admit that I rebooted to undelegate...  
[Also podman is proposing it](https://github.com/containers/podman/blob/main/troubleshooting.md#26-running-containers-with-resource-limits-fails-with-a-permissions-error)

4. [one level deeper explaination of what's happening](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#model-of-delegation)  
   I was wondering why this is a thing.. why setting my own resources should imply more privileges than my own..  
   This kinda explains it..  
   `"Because the resource control interface files in a given directory control the distribution of the parent’s resources, the delegatee shouldn’t be allowed to write to them"`  
   But I'm not sure if I got it right...(TODO)

5. [doesn't work under wsl as of august29/2022](https://github.com/kubernetes/minikube/issues/14869) dunno why I posted it.. stumbled upon it
and it just seemed interesting(Dunno its current state, but I can close this tab now..)


So it's not an issue at all.. it's just extra care.

IT IS actually part of the [minikube documentation](https://minikube.sigs.k8s.io/docs/drivers/podman/#rootless-podman),  
in that "See the [Rootless Docker](https://minikube.sigs.k8s.io/docs/drivers/docker/#rootless-docker)" link..  
dunno why I missed it(so many times).

..Luckily we have another issue:

##### The other issue...
Oh no, wait..  
There was none.

*The END.*
