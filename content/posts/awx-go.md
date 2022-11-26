---
title: "when work meets interests"
description: "first steps inside the programming world.."
date: 2022-10-07T21:23:17+02:00
draft: false
slug: awx-go
tags:
 - golang

## let's see if I can do anything with those..
local-go-version: "go1.19.1 linux/amd64"
upstream-proj-scm: git
upstream-proj-url: "https://github.com/Colstuwjx/awx-go"
upstream-proj-commit: "18b6677c43983e3b96cca561ab29a756a82df7c5"
---

### Let's look at the problem..

It all started when I was put on the infrastructure patching for the linux machines,
in an awx/git infrastructure;   
I had to patch a number of services, with an almost equal number of related ansible playbooks on git,
and a much lower number of equivalent awx projects...

The previous management suggested me to do the update work by hand,  
creating for each missing ansible project on awx:  
 + a project
 + an inventory
 + an inventory source (+sync call)
 + a job template
 + credentials
 +  whatever...

No way.

### Finding a solution..
Well.. awx servers have apis...

I started by 4 keywords: "awx api client golang" --> Search!  
No particular reason for the last one,  
since nobody I know programs for a hobby or work..
I just wanted to pick one language and learn it for good.  
It just happened that I was more charmed by Go than c or python at that moment,
so I followed a couple more projects written in Go.   
Golang just fell on my desk.. it seemed promising,
interesting and with a bunch of nice tutorials and blog posts.

So I found a couple of libraries for the awx apis,  
one had last commit 5 years ago,  
one was throwing errors even following the tutorial  
one had some pretty
gopher image in it.. so I chose [this..](https://github.com/Colstuwjx/awx-go)

---

#### new codebase

Familiarizing with the library was almost immediate:
Let's start from the readme exmple..
```go
// README.md
import (
    "log"
    awxGo "github.com/Colstuwjx/awx-go"
)

func main() {
    awx := awxGo.NewAWX("http://awx.domain", "awx_usr", "awxpwd", nil)
    result, err := awx.PingService.Ping()
    if err != nil {
        log.Fatalf("Ping awx err: %s", err)
    }

    log.Println("Ping awx: ", result)
}
```

You get a client, you call methods from it, you check for err.. and that's about it. Easy.

I started using the library to write a little piece of code.. and It worked!
```golang
func (mt *mytype) createprj(/*someparameters..*/) int { // you get the idea..
	nprj, err := mt.ProjectService.CreateProject(map[string]interface{}{
		"name": name,
		"description": descr,
		"organization": org,
		"scm_type": "git",
		"scm_url": giturl,
		"scm_branch": gitbranch,
	}, nil)
	if err != nil {
		log.Println("Error during prj creation:")
		log.Println(err)
		os.Exit(-1)
	}

	
	log.Println(nprj.Created)
	log.Println("Project successfully created")
	log.Println(nprj.Name, " || ", nprj.ID)

	return nprj.ID
}
```

For how to call the CreateProject() function, I had a hint from the tests:  
Noticed the *Service pattern (the ProjectService above, the PingService in the example,...),  
I saw how those referred to some awx api 'group' of related calls (the group being awx-go specific
..there is no Ping section
[here](https://docs.ansible.com/ansible-tower/latest/html/towerapi/api_ref.html)) 
and how those groups had each 1 file in the awx-go repo:

```
  -rw-r--r-- 1 andrew andrew  4413 Sep 28 21:32 inventories.go
  -rw-r--r-- 1 andrew andrew 24146 Sep 28 19:50 inventories_test.go
  -rw-r--r-- 1 andrew andrew   637 Sep 24 06:23 inventory_update.go
  -rw-r--r-- 1 andrew andrew  4043 Sep 24 06:23 inventory_update_test.go
  -rw-r--r-- 1 andrew andrew  3306 Sep 24 06:23 job.go
  -rw-r--r-- 1 andrew andrew 14635 Sep 24 06:23 job_test.go
  -rw-r--r-- 1 andrew andrew  4018 Oct  1 18:34 job_template.go
  -rw-r--r-- 1 andrew andrew 22056 Sep 24 06:23 job_template_test.go
  -rw-r--r-- 1 andrew andrew   437 Sep 24 06:23 ping.go
  -rw-r--r-- 1 andrew andrew   809 Sep 24 06:23 ping_test.go
  -rw-r--r-- 1 andrew andrew  2470 Sep 24 20:49 projects.go
  -rw-r--r-- 1 andrew andrew  8992 Sep 24 06:23 projects_test.go
  -rw-r--r-- 1 andrew andrew   973 Sep 24 06:23 project_updates.go
  -rw-r--r-- 1 andrew andrew  5831 Sep 24 06:23 project_updates_test.go
```

each group also has a related _test.go file, and that of  projects.go has a test for
the CreateProject() function I was looking for...

```golang
// projects_test.go

func TestCreateProject(t *testing.T) {
	var (
		expectCreateProjectResponse = &Project{
					    // ..some big struct
		}
	)

	awx := NewAWX(testAwxHost, testAwxUserName, testAwxPasswd, nil)
	result, err := awx.ProjectService.CreateProject(map[string]interface{}{
		"name":         "TestProject",
		"description":  "Test project",
		"organization": 1,
		"scm_type":     "git",
	}, map[string]string{})

	if err != nil {
		t.Fatalf("CreateProject err: %s", err)
	} else {
		checkAPICallResult(t, expectCreateProjectResponse, result)
		t.Log("CreateProject passed!")
	}
}
```

hmm.. so CreateProject() is called like this.  
No check on the api call parameters nor anything, just plain strings..  
May have ups and downs. (..TODO)

### The issue
My strategy was: "Test all calls first, put'em in the correct order.. add logic.. add cli"  
and the project creation part was covered. The inventory part was not that different,
but I wasn't able to find the inventory source api call... cause there was none.  
It shouldn't be too difficult to add one..

All exported functions for api calls have this form:
```golang
// ping.go
func (p *PingService) Ping() (*Ping, error) {
	result := new(Ping)
	endpoint := "/api/v2/ping/"
	resp, err := p.client.Requester.GetJSON(endpoint, result, map[string]string{})
	if err != nil {
		return nil, err
	}

	if err := CheckResponse(resp); err != nil { // it ..well ..check for response
		return nil, err
	}

	return result, nil
}
```
Which essentially little logic around that GetJson(), which is itself nothing more that
a couple of headers on top of a Do() method:

```golang
// request.go
func (r *Requester) GetJSON(endpoint string, responseStruct interface{}, query map[string]string) (*http.Response, error) {
	ar := NewAPIRequest("GET", endpoint, nil)
	ar.SetHeader("Content-Type", "application/json")
	ar.Suffix = ""
	return r.Do(ar, &responseStruct, query)
}

// request.go
func (r *Requester) Do(ar *APIRequest, responseStruct interface{}, options ...interface{}) (*http.Response, error) {
   	// ...

	// parsing url
	URL, err := url.Parse(r.Base + ar.Endpoint + ar.Suffix)
	if err != nil {
		return nil, err
	}

  	// ...

	// creates a std http request
	var req *http.Request
	req, err = http.NewRequest(ar.Method, URL.String(), ar.Payload)
	if err != nil {
		return nil, err
	}

	// ...

	// make a std request
	response, err := r.Client.Do(req)
	if err != nil {
		return nil, err
	}

	// return unpacked json response.. based on what struct was originally passed
	// by the (in this case) Ping() call
	switch responseStruct.(type) {
	case *string:
		return r.ReadRawResponse(response, responseStruct)
	default:
		return r.ReadJSONResponse(response, responseStruct)
	}
}

// request.go
func (r *Requester) ReadJSONResponse(response *http.Response, responseStruct interface{}) (*http.Response, error) {
	defer response.Body.Close()

	json.NewDecoder(response.Body).Decode(responseStruct)
	return response, nil
}
```

Then GetJSON() surely has PostJSON()/PatchJSON()/... counterparts and so on..
And I don't expect that NewAPIRequest() inside GetJSON() to be that complex
```golang
// request.go
func NewAPIRequest(method string, endpoint string, payload io.Reader) *APIRequest {
	var headers = http.Header{}
	var suffix string
	ar := &APIRequest{method, endpoint, payload, headers, suffix}
	return ar
}

// request.go
type APIRequest struct {
	Method   string
	Endpoint string
	Payload  io.Reader
	Headers  http.Header
	Suffix   string
}
```

Essentially is just putting a method for the api endpoint, with payload and sprinkles
under the same roof.

Knowing what foundations are we building on top of..
Let's explore some other high level fuctions, maybe we find something similar to
what we're tring to write.

### Adding a couple of lines
Of course first there's
+ git clone repo
+ git checkout -b newBranch (I was already aiming at my first pull request..)

Because I noticed that.. once familiarizing with git.. working on branches is tidier

We're trying to make a POST call  
So let's copy from something like this:
```golang
// inventories.go
func (i *InventoriesService) CreateInventory(data map[string]interface{}, params map[string]string) (*Inventory, error) {
	mandatoryFields = []string{"name", "organization"}
	validate, status := ValidateParams(data, mandatoryFields)

	if !status {
		err := fmt.Errorf("Mandatory input arguments are absent: %s", validate)
		return nil, err
	}

	result := new(Inventory)
	endpoint := "/api/v2/inventories/"
	payload, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}

	// Add check if inventory exists and return proper error

	resp, err := i.client.Requester.PostJSON(endpoint, bytes.NewReader(payload), result, params)
	if err != nil {
		return nil, err
	}

	if err := CheckResponse(resp); err != nil {
		return nil, err
	}

	return result, nil
}
```

for how the library's exported calls are structured.. it doesn't really need much rework,  
just change the endpoint, mandatory arguments..  
and we're pretty much good to go:
```golang
func (i *InventoriesService) CreateInventorySource(id int, data map[string]interface{}, params map[string]string) (*InventorySource, error) {
	mandatoryFields = []string{"name"}  // checked api docs..
	validate, status := ValidateParams(data, mandatoryFields)

	if !status {
		err := fmt.Errorf("Mandatory input arguments are absent: %s", validate)
		return nil, err
	}

	result := new(InventorySource)
	endpoint := fmt.Sprintf("/api/v2/inventories/%d/inventory_sources/", id)
	payload, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}

	// Add check if inventory_source exists and return proper error
	// (I even kept the todos :) 

	resp, err := i.client.Requester.PostJSON(endpoint, bytes.NewReader(payload), result, params)
	if err != nil {
		return nil, err
	}

	if err := CheckResponse(resp); err != nil {
		return nil, err
	}

	return result, nil
}
```

It works.. it provides the same level of control on the api call..  
think we're ok.

#### types

Oh yeah..  
One major change was the type we're expecting from the awx server:  
that InventorySource was not there before

Turns out each high level call (which is an api request) initializes his own type that
is then passed down the stack, till is used to parse the json received from server,
then returns (the type is indeed the api response).

A couple examples...
> Inventory
```golang
// inventories.go
func (i *InventoriesService) UpdateInventory(id int, data map[string]interface{}, params map[string]string) (*Inventory, error) {
	result := new(Inventory) // same as CreateInventory/GetInventory/...
	// ...
	
// types.go
type Inventory struct {
	ID                           int         `json:"id"`
	Name                         string      `json:"name"`
	Description                  string      `json:"description"`
	// other stuff as well..
}
```
> ListInventoriesresponse
```golang
// inventories.go
func (i *InventoriesService) ListInventories(params map[string]string) ([]*Inventory, *ListInventoriesResponse, error) {
	result := new(ListInventoriesResponse)
	// ...
	
// types.go
type ListInventoriesResponse struct {
	Pagination
	Results []*Inventory `json:"results"`
}

```
> Project
```golang
// projects.go
func (p *ProjectService) CreateProject(data map[string]interface{}, params map[string]string) (*Project, error) {
        // ...
	result := new(Project)
	// ...
	
// types.go
type Project struct {
	ID                    int       `json:"id"`
	Name                  string    `json:"name"`
	Description           string    `json:"description"`
	// other stuff as well...
}
```

and so on...

In order to build our own type, one could copy/paste the
[json from the docs](https://docs.ansible.com/ansible-tower/latest/html/towerapi/api_ref.html#/Inventory_Sources/Inventory_Sources_inventory_sources_create) in the Responses section:
```json
{
  "created": "2018-02-01T08:00:00.000000Z",
  "credential": 1,
  "custom_virtualenv": null,
  "description": "",
  "enabled_value": "",
  "enabled_var": "",
  "host_filter": "",
  "id": 2,
  "inventory": 1,
 /// It's larger than that..
}
```

or even better.. to clone&[run the awx repo](https://github.com/ansible/awx/blob/devel/tools/docker-compose/README.md)
and make a curl to the latest version
(there is no info about which version we're using.. as far as I can tell..),
because ..well, it's open.

( [!] first u need to create the relative project and inventory.. either via gui or api call)   
Here's the curl..  
```bash
$ curl -u user:'complex-pwd' \
       -k https://localhost:8043/api/v2/inventory_sources/ \
       -X POST -H 'Content-Type: application/json' \
       -d '{"name":"testinvrsc2","source":"scm","source_path":"somepath","inventory":5,"update_on_launch":"true","source_project":18}' \
       | jq
```

> [!] Don'1 forget the '/' at the end of the uri (https://localhost:8043/api/v2/inventory_sources/) !!   
> For how the lib is implemented right now.. it could be the missing '/', it could be a parameter typo,
> it could be that the project/inventory/... already exists.. you're still getting a 400. (TODO)
> 
> You may or may not choose to use a real password for your project..  
> so you could pass the secrets to the curl via an env var
> ```bash
> $ MYSECRET=secretpwd
> $ curl -u user:$MYSECRET # and so on..
> ```
> or just
> ```bash
> $ export HISTCONTROL=ignorespace
> ```
> and then C-k/C-y your command :)

with jq the output is prettier and you can do stuff with it..
like displaying only certain k/v pairs of json for a list of entities in the out...   

Either way one choses.. the json is getting copypasted inside (maybe..) a
[go struct generator..](https://mholt.github.io/json-to-go/)  
to obtain the new InventorySource type:

```golang
// --> types.go
type InventorySource struct {
	Created              time.Time   `json:"created"`
	Credential           interface{} `json:"credential"`
	CustomVirtualenv     interface{} `json:"custom_virtualenv"`
	Description          string      `json:"description"`
	EnabledValue         string      `json:"enabled_value"`
	EnabledVar           string      `json:"enabled_var"`
	HostFilter           string      `json:"host_filter"`
	ID                   int         `json:"id"`
	Inventory            int         `json:"inventory"`
	/// and so on...
}
```

et voila!

#### the *Service

Since we're putting all this inside the InventoriesService type, we don't need to create another
*Service entity.. which is this thing at the top of the inventories.go file:
```golang
// inventories.go
// InventoriesService implements awx inventories apis.
type InventoriesService struct {
	client *Client
}
```

which becomes part of the greater entity AWX, here:

```golang
// awx.go
type AWX struct {
	client *Client

	PingService             *PingService
	InventoriesService      *InventoriesService // <---  here
	InventoryUpdatesService *InventoryUpdatesService
	JobService              *JobService
	JobTemplateService      *JobTemplateService
	ProjectService          *ProjectService
	ProjectUpdatesService   *ProjectUpdatesService
	UserService             *UserService
	GroupService            *GroupService
	HostService             *HostService
}

```

and get's initialized here:

```golang
// awx.go
func NewAWX(baseURL, userName, passwd string, client *http.Client) *AWX {
	r := &Requester{Base: baseURL, BasicAuth: &BasicAuth{Username: userName, Password: passwd}, Client: client}
	if r.Client == nil {
		r.Client = http.DefaultClient
	}

	awxClient := &Client{
		BaseURL:   baseURL,
		Requester: r,
	}

	return &AWX{
		client: awxClient,

		PingService: &PingService{
			client: awxClient,
		},
		InventoriesService: &InventoriesService{ //  <--- here
			client: awxClient,
		},
		InventoryUpdatesService: &InventoryUpdatesService{
			client: awxClient,
		},
		JobService: &JobService{
			client: awxClient,
		},
		JobTemplateService: &JobTemplateService{
			client: awxClient,
		},
		ProjectService: &ProjectService{
			client: awxClient,
		},
		ProjectUpdatesService: &ProjectUpdatesService{
			client: awxClient,
		},
		UserService: &UserService{
			client: awxClient,
		},
		GroupService: &GroupService{
			client: awxClient,
		},
		HostService: &HostService{
			client: awxClient,
		},
	}
}
```


> I figured one starts to codes piece-wise,  
> programming languages allow you to develop logic in a straight line of "makes-senseness"  
> (sorry, not my main language...)  
> at some point you have a number of lines that need to converge in the same point,  
> that is where you glue your code together..  
> and while its almost always possible to glue different parts together..  
> it is there that your code makes less sense/looks weird...
> 
> If every repo has one such point,  
> for awx-go.. that point was that above

So we can say that, in order to add a new awx-go service, there are a couple places where you
need to modify stuff:
 + The "service".go file
   + Add the file itself..
   + Add the *service type
   + Add the *service type methods
 + The types.go file
   + Add the api-call-response-go-type-structs for the *service type methods
 + The awx.go file
   + Add *service pointer to the AWX struct if the *service is new
   + Add *service struct initialization to the NewAWX() function

should be enough..

### Testing

I found this part to be quite teachful..  
As previously stated, each service.go has(or should have) a service_test.go equivalent,
let's look at the CreateInventory() test inside the inventories_test.go file.

```golang
func TestCreateInventory(t *testing.T) {
	var (
		expectCreateInventoryResponse = &Inventory{
			ID:   6,
			Type: "inventory",
			URL:  "/api/v2/inventories/6/",
			Related: &Related{
				NamedURL:               "/api/v2/inventories/TestInventory++Default/",
				CreatedBy:              "/api/v2/users/1/",
				ModifiedBy:             "/api/v2/users/1/",
				JobTemplates:           "/api/v2/inventories/6/job_templates/",
				VariableData:           "/api/v2/inventories/6/variable_data/",
				RootGroups:             "/api/v2/inventories/6/root_groups/",
				ObjectRoles:            "/api/v2/inventories/6/object_roles/",
				AdHocCommands:          "/api/v2/inventories/6/ad_hoc_commands/",
				Script:                 "/api/v2/inventories/6/script/",
				Tree:                   "/api/v2/inventories/6/tree/",
				AccessList:             "/api/v2/inventories/6/access_list/",
				ActivityStream:         "/api/v2/inventories/6/activity_stream/",
				InstanceGroups:         "/api/v2/inventories/6/instance_groups/",
				Hosts:                  "/api/v2/inventories/6/hosts/",
				Groups:                 "/api/v2/inventories/6/groups/",
				Copy:                   "/api/v2/inventories/6/copy/",
				UpdateInventorySources: "/api/v2/inventories/6/update_inventory_sources/",
				InventorySources:       "/api/v2/inventories/6/inventory_sources/",
				Organization:           "/api/v2/organizations/1/",
			},
			SummaryFields: &Summary{
				Organization: &OrgnizationSummary{
					ID:          1,
					Name:        "Default",
					Description: "",
				},

				CreatedBy: &ByUserSummary{
					ID:        1,
					Username:  "admin",
					FirstName: "",
					LastName:  "",
				},

				ModifiedBy: &ByUserSummary{
					ID:        1,
					Username:  "admin",
					FirstName: "",
					LastName:  "",
				},

				ObjectRoles: &ObjectRoles{
					UseRole: &ApplyRole{
						ID:          80,
						Description: "Can use the inventory in a job template",
						Name:        "Use",
					},

					AdminRole: &ApplyRole{
						ID:          78,
						Description: "Can manage all aspects of the inventory",
						Name:        "Admin",
					},

					AdhocRole: &ApplyRole{
						ID:          77,
						Description: "May run ad hoc commands on an inventory",
						Name:        "Ad Hoc",
					},

					UpdateRole: &ApplyRole{
						ID:          81,
						Description: "May update project or inventory or group using the configured source update system",
						Name:        "Update",
					},

					ReadRole: &ApplyRole{
						ID:          79,
						Description: "May view settings for the inventory",
						Name:        "Read",
					},
				},

				UserCapabilities: &UserCapabilities{
					Edit:   true,
					Copy:   true,
					Adhoc:  true,
					Delete: true,
				},
			},

			Created: func() time.Time {
				t, _ := time.Parse(time.RFC3339, "2018-08-13T01:59:47.160127Z")
				return t
			}(),

			Modified: func() time.Time {
				t, _ := time.Parse(time.RFC3339, "2018-08-13T01:59:47.160140Z")
				return t
			}(),

			Name:                         "TestInventory",
			Description:                  "for testing CreateInventory api",
			Organization:                 1,
			Kind:                         "",
			HostFilter:                   nil,
			Variables:                    "",
			HasActiveFailures:            false,
			TotalHosts:                   0,
			HostsWithActiveFailures:      0,
			TotalGroups:                  0,
			GroupsWithActiveFailures:     0,
			HasInventorySources:          false,
			TotalInventorySources:        0,
			InventorySourcesWithFailures: 0,
			InsightsCredential:           nil,
			PendingDeletion:              false,
		}
	)

	awx := NewAWX(testAwxHost, testAwxUserName, testAwxPasswd, nil)
	result, err := awx.InventoriesService.CreateInventory(map[string]interface{}{
		"name":         "TestInventory",
		"description":  "for testing CreateInventory api",
		"organization": 1,
		"kind":         "",
		"host_filter":  "",
		"variables":    "",
	}, map[string]string{})

	if err != nil {
		t.Fatalf("CreateInventory err: %s", err)
	} else {
		checkAPICallResult(t, expectCreateInventoryResponse, result)
		t.Log("CreateInventory passed!")
	}
}
```

That is huuge...  
and the first like 100 lines of code is not even logic.. it is the initialization of a struct.
In fact, it is the initialization of the struct we're expecting the CreateInventory() call to return.  
The rest is just:
 + init client
 + make call
 + check for error
 + [!!] Check if the result is what we're expecting (checkAPICallResult())

---

Interesting.. but where's that response coming from?  
we don't have an actual awx server listening and returning json..
> well, we could..  
> but then it's dependencies within repos.. extra test logic... extra complications..

The server returning stuff to our calls is a mock server..  
here:
```golang
// awxtesting/mockserver/mockserver.go
type mockServer struct {
	// ...
	server http.Server  // the basic go-stdlib http server
}

// ...

func (s *mockServer) InventoriesHandler(rw http.ResponseWriter, req *http.Request) {
	switch {
	case req.RequestURI == "/api/v2/inventories/1/" && req.Method == "GET":
		result := mockdata.MockedGetInventoryResponse
		rw.Write(result)
		return
	case req.Method == "POST":
		result := mockdata.MockedCreateInventoryResponse
		rw.Write(result)
		return

	// ...
	default:
		result := mockdata.MockedListInventoriesResponse
		rw.Write(result)
	}
}
```

And that result we're rw.Writing looks like this:
```golang
// awxtesting/mockserver/mockdata/inventories.go
MockedCreateInventoryResponse = []byte(`
{
    "id": 6,
    "type": "inventory",
    "url": "/api/v2/inventories/6/",
    "related": {
        "named_url": "/api/v2/inventories/TestInventory++Default/",
        "created_by": "/api/v2/users/1/",
        "modified_by": "/api/v2/users/1/",
        "job_templates": "/api/v2/inventories/6/job_templates/",
        "variable_data": "/api/v2/inventories/6/variable_data/",
        "root_groups": "/api/v2/inventories/6/root_groups/",
        "object_roles": "/api/v2/inventories/6/object_roles/",
        "ad_hoc_commands": "/api/v2/inventories/6/ad_hoc_commands/",
        "script": "/api/v2/inventories/6/script/",
        "tree": "/api/v2/inventories/6/tree/",
        "access_list": "/api/v2/inventories/6/access_list/",
        "activity_stream": "/api/v2/inventories/6/activity_stream/",
        "instance_groups": "/api/v2/inventories/6/instance_groups/",
        "hosts": "/api/v2/inventories/6/hosts/",
        "groups": "/api/v2/inventories/6/groups/",
        "copy": "/api/v2/inventories/6/copy/",
        "update_inventory_sources": "/api/v2/inventories/6/update_inventory_sources/",
        "inventory_sources": "/api/v2/inventories/6/inventory_sources/",
        "organization": "/api/v2/organizations/1/"
    },
    "summary_fields": {
        "organization": {
            "id": 1,
            "name": "Default",
            "description": ""
        },
        "created_by": {
            "id": 1,
            "username": "admin",
            "first_name": "",
            "last_name": ""
        },
        "modified_by": {
            "id": 1,
            "username": "admin",
            "first_name": "",
            "last_name": ""
        },
        "object_roles": {
            "use_role": {
                "id": 80,
                "description": "Can use the inventory in a job template",
                "name": "Use"
            },
            "admin_role": {
                "id": 78,
                "description": "Can manage all aspects of the inventory",
                "name": "Admin"
            },
            "adhoc_role": {
                "id": 77,
                "description": "May run ad hoc commands on an inventory",
                "name": "Ad Hoc"
            },
            "update_role": {
                "id": 81,
                "description": "May update project or inventory or group using the configured source update system",
                "name": "Update"
            },
            "read_role": {
                "id": 79,
                "description": "May view settings for the inventory",
                "name": "Read"
            }
        },
        "user_capabilities": {
            "edit": true,
            "copy": true,
            "adhoc": true,
            "delete": true
        }
    },
    "created": "2018-08-13T01:59:47.160127Z",
    "modified": "2018-08-13T01:59:47.160140Z",
    "name": "TestInventory",
    "description": "for testing CreateInventory api",
    "organization": 1,
    "kind": "",
    "host_filter": null,
    "variables": "",
    "has_active_failures": false,
    "total_hosts": 0,
    "hosts_with_active_failures": 0,
    "total_groups": 0,
    "groups_with_active_failures": 0,
    "has_inventory_sources": false,
    "total_inventory_sources": 0,
    "inventory_sources_with_failures": 0,
    "insights_credential": null,
    "pending_deletion": false
}`)
```

Which is plain json.  
And each high level api call exported by awx-go needs to have a test that is implemented
using a mockserver.. that mocks an awx api json response.. which in this case is that above.

> #### __How does that work?__  
> one could be interesting to know how the mockserver thing works...  
> the rest of the mockserver implementation works like a normal go-stdlib http server  
> but it's still quite interesting and it can be found [here](https://github.com/colstuwjx/awx-go/blob/master/awxtesting/mockserver/mockserver.go)  
> The question "how this mockserver even spawns under my ass when I press "go test"
> can find an answer [here](https://stackoverflow.com/questions/23729790/how-can-i-do-test-setup-using-the-testing-package-in-go), knowing that when we're gotesting we're also gotesting awx_test.go:
> 
> ```golang
> // awx_test.go
> package awx
> 
> import (
> 	"log"
> 	"os"
> 	"testing"
> 	"time"
> 
> 	"github.com/Colstuwjx/awx-go/awxtesting/mockserver"
> )
> 
> var (
> 	testAwxHost     = "http://127.0.0.1:8080"
> 	testAwxUserName = "admin"
> 	testAwxPasswd   = "password"
> )
> 
> func TestMain(m *testing.M) {
> 	setup()
> 	code := m.Run()
> 
> 	os.Exit(code)
> }
> 
> func setup() {
> 	go func() {
> 		if err := mockserver.Run(); err != nil {
> 			log.Fatal(err)
> 		}
> 	}()
> 
> 	// wait for mock server to run
> 	time.Sleep(time.Millisecond * 10)
> }
> 
> func teardown() {
> 	mockserver.Close()
> }
> ```

So when we're testing our calls..  
we're initializing a go struct for the awx api response we're expecting  
we're writing the mock plain json to pass to our high level function when calls  
So we're expecting to receive the same data we're passing?  
seems like an easy win...

That one made no sense to me..  

I spent a lot of time even trying to formulate a phrase that could even resemble a question
for the gopher community.. had no idea about what purpose those tests may have, nor how to write tests.   

![v1.0 question for the community](/posts/images/v1.0.png "first version")

I tried to reformulate the question several times, and it was getting waay too long,   
it also contained self-answers.. the kind that have the effect to leave your question unanswered...
depending on the community..   
I tried to write a test that would be equivalent to the ones proposed in the project.. 
after some time, something clicked!

![v1.1 question for the community](/posts/images/v1.1.png "second version")

at that point that question was not a question anymore.. It was a blog post :)

As anticipated in my v1.1 question...   
We are not testing the high level api function itself..  
we're testing the functions from which our function is built upon(which is quite te same thing..).. 
so that when we change a piece of innocent code somewhere, everything keeps its intended behaviour.

So for me those tests mean:
"We want the tests to assure that under optimal network conditions and server access, the tested
function will be able to parse each and every field of a complete json response returned
from the awx server" nothing more..   
So there is no coverage (yet) for network unreliability/server_authentication issues
(a note in the code suggested me that)/strange status codes/server errors/.... 
Because how do we even want the library to behave under network unreliability or server failure? (TODO)  
Perhaps I'm thinking towards an improvement here.. and I learned that if you've something
to propose in an open source project you better propose it in code.. in readable code actually..  
and I can't think in golang yet...

### mocking api responses

So I already spent way too much time in initializing this expected api response struct:
```golang
var (
		expectCreateInventorySourceResponse = &InventorySource{
			Source: "somesource",
			LastUpdated : func() time.Time {
							t, _ := time.Parse(time.RFC3339, "2018-08-13T01:59:47.160127Z")
							return t
						}(),
			Status: "somestatus",
			Created: func() time.Time {
							t, _ := time.Parse(time.RFC3339, "2018-08-13T01:59:47.160127Z")
							return t
						}(),
			Credential: "totallylegitaccess",
			CustomVirtualenv: "null",
			Description: "somedescription",
			EnabledValue: "A",
			EnabledVar: "A",
			ExecutionEnvironment: "A",
			HostFilter: "A",
			ID: 1,
			Inventory: 1,
			LastJobFailed: false,
			LastJobRun: "yesterday..",
			LastUpdateFailed: false,
			Modified: func() time.Time {
							t, _ := time.Parse(time.RFC3339, "2018-08-13T01:59:47.160127Z")
							return t
						}() ,
			Name: "an inventory source",
			NextJobRun: true,
			Overwrite: true,
			OverwriteVars: true,
			Related: &Related{
				NamedURL:               "/api/v2/inventories/TestInventory++Default/",
				CreatedBy:              "/api/v2/users/1/",
				ModifiedBy:             "/api/v2/users/1/",
				JobTemplates:           "/api/v2/inventories/6/job_templates/",
				VariableData:           "/api/v2/inventories/6/variable_data/",
				RootGroups:             "/api/v2/inventories/6/root_groups/",
				ObjectRoles:            "/api/v2/inventories/6/object_roles/",
				AdHocCommands:          "/api/v2/inventories/6/ad_hoc_commands/",
				Script:                 "/api/v2/inventories/6/script/",
				Tree:                   "/api/v2/inventories/6/tree/",
				AccessList:             "/api/v2/inventories/6/access_list/",
				ActivityStream:         "/api/v2/inventories/6/activity_stream/",
				InstanceGroups:         "/api/v2/inventories/6/instance_groups/",
				Hosts:                  "/api/v2/inventories/6/hosts/",
				Groups:                 "/api/v2/inventories/6/groups/",
				Copy:                   "/api/v2/inventories/6/copy/",
				UpdateInventorySources: "/api/v2/inventories/6/update_inventory_sources/",
				InventorySources:       "/api/v2/inventories/6/inventory_sources/",
				Organization:           "/api/v2/organizations/1/",
			},
			SourcePath: "somesourcepath",
			SourceProject: 1,
			SourceVars: "somesourcevars",
			SummaryFields: &Summary{
				Organization: &OrgnizationSummary{
					ID:          1,
					Name:        "default",
					Description: "",
				},
				CreatedBy: &ByUserSummary{
					ID:        1,
					Username:  "admin",
					FirstName: "",
					LastName:  "",
				},
				ModifiedBy: &ByUserSummary{
					ID:        1,
					Username:  "admin",
					FirstName: "",
					LastName:  "",
				},
			},
			Timeout: 1,
			Type: "a",
			UpdateCacheTimeout: 1,
			UpdateOnLaunch: true,
			UpdateOnProjectUpdate: true,
			URL: "someurl",
			Verbosity: 1,
		}
	)
```

(from json to go) yes, I did it by hand.. with the help of the previous json-to-go tool, and an editor macro...   
And only then I figured that I had to do the same thing in reverse; from go struct to json,
to create the mocked api response
and there was no macro I could think about to help me out.    

Who knows if golang provides some kind of utility..? ...that maybe can help me generate json from
go structs within the repos without disturbing main...? ..but then it should be module-aware, like 
a test.. naah. (TODO: is that a thing?)

I already employed a [workspace](https://go.dev/doc/tutorial/workspaces)
(really.. all the documentation I needed was contained in the linked article) to develop 
my forked version of the library while I was using it in the actual client project; 
it was sufficient to add a module to the workspace that would use the awx-go lib
 (otherwise I would've had to copy all the types within the api resposne type struct..), 
copy paste the initialized expected api response struct, and then marshal it...

```golang
package main

import (
	"encoding/json"
	"time"

	awxgo "github.com/Colstuwjx/awx-go"
	"fmt"
)

var (
		expectCreateInventorySourceResponse = &awxgo.InventorySource{
			Source: "somesource",
			LastUpdated : func() time.Time {
							t, _ := time.Parse(time.RFC3339, "2018-08-13T01:59:47.160127Z")
							return t
						}(),
			Status: "somestatus",
			/// all that stuff...
			// ...
		}
	)

func main() {
	str, err := json.Marshal(expectCreateInventorySourceResponse)
	if err != nil {
		fmt.Println("Error marshaling!")
		return
	}

	fmt.Println(string(str))
}
```

Go run the module.. and I had the json that the mock server was ought to pass.

So the [pull request](https://github.com/Colstuwjx/awx-go/pull/38/files) is now ready.   
not afraid of github diffs anymore..
