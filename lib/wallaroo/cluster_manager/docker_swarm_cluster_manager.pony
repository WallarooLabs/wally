use "collections"
use "json"
use "net/http"
use "random"
use "time"
use "sendence/fix_generator_utils"

actor DockerSwarmClusterManager
  """
  DockerSwarmClusterManager

  Provides a way to dynamically create a new Wallaroo worker given a running
  Docker Swarm manager's address and the control port for the worker's in that
  Docker Swarm cluster.

  TODO:
  The HTTP client and it's handlers will need to be replaced/restructured when
  the new HTTP package is pulled in from latest ponyc.
  """
  let _cluster_manager_address: String
  let _auth: AmbientAuth
  let _client: Client
  let _control_port: String
  let _number_generator: RandomNumberGenerator = RandomNumberGenerator()
  let _service_list_response_handler: DockerSwarmServicesResponseHandler val
  let _worker_response_handler: DockerSwarmWorkerResponseHandler val

  new create(auth: AmbientAuth, cluster_manager_address: String,
    control_port: String)
  =>
    _cluster_manager_address = cluster_manager_address
    _auth = auth
    _control_port = control_port
    _client = Client(_auth)
    _service_list_response_handler = DockerSwarmServicesResponseHandler(this)
    _worker_response_handler = DockerSwarmWorkerResponseHandler(this)

  be request_new_worker() =>
    """
    Sends off get request to our Docker Swarm cluster manager and our
    DockerSwarmServicesResponseHandler is used to call
    generate_new_worker_request() if a service response is provided.
    """
    try
      let url =
        DockerSwarmAPIURLBuilder.service_list_url(_cluster_manager_address)
      let req = Payload.request("GET", url, _service_list_response_handler)
      _client(consume req)
    else
      @printf[I32](("Unable to request a new worker").cstring())
    end

  fun ref _worker_name_generator(): String =>
    """
    Generates a worker name with a random 6 character alhpanumeric suffix
    in order to avoid naming collisions when creating a new worker across
    different workers.

    TODO: Revisit when we begin to use more than 20 workers to provide a
    more robust solution. (GUID?)
    """
    "worker-" + _number_generator.rand_alphanumeric(6)

  be generate_new_worker_request(
    json_builder': DockerSwarmServiceRequestJsonBuilder iso)
  =>
    """
    Uses DockerSwarmServiceRequestJsonBuilder to build a properly formed
    services/create JSON string to build a POST request for a new worker.
    TODO:
    Currently only prints out that the request failed, should there be other
    options for a user to bring up a new worker if this is the case?
    """
    try
      let json_builder: DockerSwarmServiceRequestJsonBuilder ref =
        consume json_builder'
      let worker_name: String = _worker_name_generator()

      let json_data: String = json_builder.add_control_port(_control_port)
        .add_worker_name(worker_name)
        .build()
      try
        let url: URL =
          DockerSwarmAPIURLBuilder.worker_request_url(_cluster_manager_address)
        let payload: Payload = Payload.request("POST", url,
          _worker_response_handler)
        payload.add_chunk(json_data)
        payload.update("Content-Type", "application/json")
        _client(consume payload)
      else
        @printf[I32](("Failed generating valid URL").cstring())
      end
    end

class val DockerSwarmServicesResponseHandler
  """
  DockerSwarmServicesResponseHandler

  Provides a response handler for our Payload which is then used to notify
  our DockerSwarmClusterManager to generate_new_worker_request() if a proper
    service response is received from our services GET request.

  TODO: This will need to be replaced when new HTTP package is pulled in from
  latest ponyc.
  """
  let _cluster_manager: DockerSwarmClusterManager

  new val create(cluster_manager: DockerSwarmClusterManager) =>
    _cluster_manager = cluster_manager

  fun apply(request: Payload val, response: Payload val) =>
    match response.status
    | 200 =>
      try
        let doc: JsonDoc = JsonDoc
        let chunk = response.body()(0)
        let string_resp: String val = String.from_array(chunk as Array[U8] val)
        doc.parse(string_resp)
        let service_list: JsonArray = doc.data as JsonArray
        let service_list_size: USize = service_list.data.size()
        if service_list_size > 0 then
          let service_obj: JsonObject = service_list.data(0) as JsonObject
          let service_name: String =
            DockerSwarmAPIServiceParser.parse_service_name(service_obj)
          let network_name: String =
            DockerSwarmAPIServiceParser.parse_network_name(service_obj)
          let image_name: String =
            DockerSwarmAPIServiceParser.parse_image_name(service_obj)
          let json_builder = recover iso
              DockerSwarmServiceRequestJsonBuilder
                .add_service_name(service_name)
                .add_network_name(network_name)
                .add_app_image_name(image_name)
            end
          _cluster_manager.generate_new_worker_request(consume json_builder)
        else
          @printf[I32]("Unable to find services with provided label\n"
            .cstring())
        end
      else
        @printf[I32](("Error: unable to extract relevant info for " +
          "Docker Swarm new worker request\n").cstring())
      end
    else
      @printf[I32](("Docker Swarm Request Failed: " +
        response.status.string() + " Error\n").cstring())
    end

class val DockerSwarmWorkerResponseHandler
  let _cluster_manager: DockerSwarmClusterManager

  new val create(cluster_manager: DockerSwarmClusterManager) =>
    _cluster_manager = cluster_manager

  fun apply(request: Payload val, response: Payload val) =>
    match response.status
    | 201 =>
      @printf[I32]("Docker Swarm Worker Request Suceeded".cstring())
    else
      @printf[I32](("Docker Swarm Request Failed: " +
        response.status.string() + " Error\n").cstring())
    end

primitive _SwarmServiceRequestBuilderInitialized
primitive _SwarmServiceRequestBuilderError
primitive _SwarmServiceRequestBuilderReady

type _DockerSwarmServiceRequestState is
  ( _SwarmServiceRequestBuilderInitialized
  | _SwarmServiceRequestBuilderError
  | _SwarmServiceRequestBuilderReady
  )

class DockerSwarmServiceRequestJsonBuilder
  """
  DockerSwarmServiceRequestJsonBuilder

  A builder for generating a properly formed string representation of the
  JSON object required starting a new service.

  TODO: Remove this chaining when latest ponyc is pulled in as new syntax
  has been provided to support this functionality.
  """
  var worker_name: String = ""
  var service_name: String = ""
  var network_name: String = ""
  var app_image_name: String = ""
  var control_port: String = ""
  var _state: _DockerSwarmServiceRequestState

  new create() =>
    _state = _SwarmServiceRequestBuilderInitialized

  fun ref add_worker_name(worker_name': String):
    DockerSwarmServiceRequestJsonBuilder
  =>
    worker_name = worker_name'
    _validate_fields()
    this

  fun ref add_service_name(service_name': String):
    DockerSwarmServiceRequestJsonBuilder
  =>
    service_name = service_name'
    _validate_fields()
    this

  fun ref add_network_name(network_name': String):
    DockerSwarmServiceRequestJsonBuilder
  =>
    network_name = network_name'
    _validate_fields()
    this

  fun ref add_app_image_name(app_image_name': String):
    DockerSwarmServiceRequestJsonBuilder
  =>
    app_image_name = app_image_name'
    _validate_fields()
    this

  fun ref add_control_port(control_port': String):
    DockerSwarmServiceRequestJsonBuilder
  =>
    control_port = control_port'
    _validate_fields()
    this

  fun ref build(): String ? =>
    if _state is _SwarmServiceRequestBuilderReady then
      DockerSwarmServiceRequestJsonString(this)
    else
      @printf[I32](("Not all required fields were set when calling build on " +
        "DockerSwarmServiceRequestJsonBuilder\n").cstring())
      error
    end

  fun ref _has_valid_fields(): Bool =>
    ((worker_name != "")  and
     (service_name != "") and
     (network_name != "") and
     (app_image_name != "") and
     (control_port != "")
    )

  fun ref _validate_fields() =>
    _state = if _has_valid_fields() then
      _SwarmServiceRequestBuilderReady
    else
      _SwarmServiceRequestBuilderError
    end


primitive DockerSwarmServiceRequestJsonString
  """
  DockerSwarmServiceRequestJsonString

  Given a DockerSwarmServiceRequestJsonBuilder, builds out a Docker Swarm
  Service Request JSON string
  """
  fun apply(request_builder: DockerSwarmServiceRequestJsonBuilder):
    String
  =>
    let app_address = request_builder.service_name + ":" +
      request_builder.control_port
    let args_array: JsonArray = JsonArray
    args_array.data.push("-j")
    args_array.data.push(app_address)
    args_array.data.push("-n")
    args_array.data.push(request_builder.worker_name)

    let container_spec_data: JsonObject = JsonObject
    container_spec_data.data.update("Image",
      request_builder.app_image_name)
    container_spec_data.data.update("Args", args_array)

    let task_template_data: JsonObject = JsonObject
    task_template_data.data.update("ContainerSpec", container_spec_data)

    let network_data: JsonObject = JsonObject
    network_data.data.update("Target", request_builder.network_name)

    let replica_count: I64 = 1
    let replica_data: JsonObject = JsonObject
    replica_data.data.update("Replicas", replica_count)

    let mode_data: JsonObject = JsonObject
    mode_data.data.update("Replicated", replica_data)

    let network_array: JsonArray = JsonArray
    network_array.data.push(network_data)

    let new_service_name = request_builder.service_name + "_" +
      request_builder.worker_name

    let j: JsonObject = JsonObject
    j.data.update("Name", new_service_name)
    j.data.update("TaskTemplate", task_template_data)
    j.data.update("Mode", mode_data)
    j.data.update("Networks", network_array)
    j.string(where pretty_print=false)

primitive DockerSwarmAPIURLBuilder
  """
  Builds URL objects needed to make Docker Swarm API requests.

  TODO:
  replace GET request with "/v1.26/services" +
  "?filters='{\"label\":[\"wallaroo-worker\"]}'" once new HTTP
  package is pulled in from latest ponyc for proper encoding which
  allows us to provide a label to further limit the services returned
  from the Docker Swarm API services GET request.
  Current label: "wallaroo-worker"
  """
  fun service_list_url(cluster_manager_address: String): URL ? =>
    URL.build(cluster_manager_address +
       "/v1.26/services")

  fun worker_request_url(cluster_manager_address: String): URL ? =>
    URL.build(cluster_manager_address + "/v1.26/services/create")

primitive DockerSwarmAPIServiceParser
  """
  DockerSwarmAPIServiceParser

  Parses a JsonObject representation of returned service from the
  Docker Swarm API services GET request.

  Extracts relevant information needed to form a service create POST
  request.
  """
  fun parse_service_name(service_obj: JsonObject): String ? =>
    let spec_obj: JsonObject = service_obj.data("Spec") as JsonObject
    let service_name: String = spec_obj.data("Name") as String
    service_name

  fun parse_image_name(service_obj: JsonObject): String ? =>
    let spec_obj: JsonObject = service_obj.data("Spec") as JsonObject
    let task_template_obj = spec_obj.data("TaskTemplate") as JsonObject
    let container_spec_obj = task_template_obj.data("ContainerSpec") as
      JsonObject
    let image_name = container_spec_obj.data("Image") as String
    image_name

  fun parse_network_name(service_obj: JsonObject): String ? =>
    let spec_obj: JsonObject = service_obj.data("Spec") as JsonObject
    let networks_array: JsonArray = spec_obj.data("Networks") as JsonArray
    if networks_array.data.size() >= 1 then
      let network_obj: JsonObject = networks_array.data(0) as JsonObject
      let network_name: String = network_obj.data("Target") as String
      return network_obj.data("Target") as String
    else
      @printf[I32](
        "Error: Service is not connected to a Docker Swarm Network".cstring())
      error
    end
