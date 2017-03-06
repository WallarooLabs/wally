use "ponytest"
use "json"

actor TestDockerSwarmClusterManager is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestJsonRequestBuilder)
    test(_TestAPIServiceParser)
    test(_TestDockerSwarmAPIURLBuilder)

class iso _TestJsonRequestBuilder is UnitTest
  """
  Test that we build a properly formed Docker Swarm Worker Request JSON
  string if all required arguments are supplied.
  Errors if all arguments are not supplied and build() is called.
  """
  fun name(): String =>
    "docker_swarm_cluster_manager/DockerSwarmServiceRequestJsonBuilder"

  fun apply(h: TestHelper) =>
    h.assert_error({()? =>
     DockerSwarmServiceRequestJsonBuilder.build() })
    try
      let json_request = DockerSwarmServiceRequestJsonBuilder
        .add_worker_name("worker1")
        .add_service_name("complex")
        .add_network_name("wallaroo")
        .add_app_image_name("complex:latest")
        .add_control_port("6000")
        .build()
      let stub = DockerSwarmAPIStubs.worker_request()
      h.assert_eq[String](json_request, stub)
    else
      h.fail("Failed to build DockerSwarmServiceRequestJsonBuilder given" +
        " proper parameters")
    end

class iso _TestAPIServiceParser is UnitTest
  """
  Test that we properly parse a returned service object from our
  services GET request so that we can extract that relevant information
  needed for building a services/create POST request.
  """
  fun name(): String =>
    "docker_swarm_cluster_manager/DockerSwarmAPIServiceParser"

  fun apply(h: TestHelper) =>
    try
      let doc: JsonDoc = JsonDoc
      doc.parse(DockerSwarmAPIStubs.service_response())
      let service_list: JsonArray = doc.data as JsonArray
      let service_list_size: USize = service_list.data.size()
      h.assert_eq[USize](1, service_list_size)

      let service_obj: JsonObject = service_list.data(0) as JsonObject
      try
        let service_name =
          DockerSwarmAPIServiceParser.parse_service_name(service_obj)
        h.assert_eq[String]("complex", service_name)
      else
        h.fail("Failed to parse service object name")
      end
      try
        let image_name =
          DockerSwarmAPIServiceParser.parse_image_name(service_obj)
        h.assert_eq[String]("complex:latest", image_name)
      else
        h.fail("Failed to parse service app image name")
      end
      try
        let network_name =
          DockerSwarmAPIServiceParser.parse_network_name(service_obj)
        h.assert_eq[String]("wallaroo", network_name)
      else
        h.fail("Failed to parse service network name")
      end
    else
      h.fail("Failed to properly create Service JSON object from " +
        "DockerSwarmAPIStubs.service_response()")
    end

class iso _TestDockerSwarmAPIURLBuilder is UnitTest
  """
  Test that we build the expected URLs for a services GET request
  and a services/create POST request.
  """
  fun name(): String =>
    "docker_swarm_cluster_manager/DockerSwarmAPIURLBuilder"

  fun apply(h: TestHelper) =>
    let cluster_address = "http://localhost"
    try
      let sl_url =
        DockerSwarmAPIURLBuilder.service_list_url(cluster_address)
      h.assert_true(sl_url.is_valid())
      h.assert_eq[String]("http://localhost/v1.26/services",
        sl_url.string())
    else
      h.fail("Failed to build Service List URL")
    end
    try
      let wr_url =
        DockerSwarmAPIURLBuilder.worker_request_url(cluster_address)
      h.assert_true(wr_url.is_valid())
      h.assert_eq[String]("http://localhost/v1.26/services/create",
        wr_url.string())
    else
      h.fail("Failed to build Service Request URL")
    end

primitive DockerSwarmAPIStubs
  fun worker_request(): String =>
    """{"Networks":[{"Target":"wallaroo"}],"Name":"complex_worker1",""" +
    """"TaskTemplate":{"ContainerSpec":{"Image":"complex:latest",""" +
    """"Args":["-j","complex:6000","-n","worker1"]}},""" +
    """"Mode":{"Replicated":{"Replicas":1}}}"""

  fun service_response(): String =>
    """
    [{"ID":"xrh4yu8po05ivi2r1drfe9jzr","Version":{"Index":326178},""" +
    """"CreatedAt":"2017-03-02T22:54:06.441843495Z","UpdatedAt":""" +
    """"2017-03-06T14:16:11.085962249Z","Spec":{"Name":"complex","Labels":""" +
    """{"wallaroo-worker":"initializer"},"TaskTemplate":{"ContainerSpec":""" +
    """{"Image":"complex:latest","Args":["-i","0.0.0.0:7010","-o",""" +
    """"192.168.1.105:7002","-m","192.168.1.105:5001","-c","0.0.0.0:6000",""" +
    """"-d","0.0.0.0:6001","-n","worker-name"],"DNSConfig":{}},""" +
    """"Resources":{"Limits":{},"Reservations":{}},"RestartPolicy":""" +
    """{"Condition":"any","MaxAttempts":0},"Placement":{},"Networks":""" +
    """[{"Target":"i9ez4a7do49b2m2wad4zyqb6g"}],"ForceUpdate":0},"Mode":""" +
    """{"Replicated":{"Replicas":1}},"UpdateConfig":{"Parallelism":1,""" +
    """"FailureAction":"pause","MaxFailureRatio":0},"Networks":[""" +
    """{"Target":"wallaroo"}],"EndpointSpec":{"Mode":"vip"}},"Endpoint":""" +
    """{"Spec":{"Mode":"vip"},"VirtualIPs":[{"NetworkID":""" +
    """"i9ez4a7do49b2m2wad4zyqb6g","Addr":"10.0.0.2/24"}]},"UpdateStatus":""" +
    """{"StartedAt":"0001-01-01T00:00:00Z","CompletedAt":""" +
    """"0001-01-01T00:00:00Z"}}]
    """
