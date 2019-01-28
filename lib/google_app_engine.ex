defmodule Cluster.Strategy.GoogleAppEngine do
  @moduledoc """
  Clustering strategy for Google App Engine.

  This strategy checks for the list of app versions that are currently receiving HTTP.
  For each version that is listed, the list of instances running for that version are fetched.
  Once all of the instances have been received, they attempt to connect to each other.

  **Note**: This strategy only connects nodes that are able to receive HTTP traffic.

  Here's an example configuration:

  ```elixir
  config :libcluster,
    topologies: [
      my_app: [
        strategy: Cluster.Strategy.GoogleAppEngine,
        config: [
          polling_interval: 10_000
        ]
      ]
    ]
  ```

  ## Configurable Options

  Options can be set for the strategy under the `:config` key when defining the topology.

  * `:polling_interval` - Interval for checking for the list of running instances. Defaults to `10_000`

  ## Application Setup

  ### Google Cloud

  Enable the **App Engine Admin API** for your application's Google Cloud Project. Follow the guide on [enabling APIs](https://cloud.google.com/apis/docs/enable-disable-apis).

  ### Release Configuration

  Update your release's `vm.args` file to include the following lines.

  ```
  ## Name of the node
  -sname <%= release_name %>@${GAE_INSTANCE}

  ## Limit distributed erlang ports to a single port
  -kernel inet_dist_listen_min 9999
  -kernel inet_dist_listen_max 9999
  ```

  ### GAE Configuration File

  Update the `app.yaml` configuration file for Google App Engine.

  ```yaml
  env_variables:
    REPLACE_OS_VARS: true

  network:
    forwarded_ports:
      # epmd
      - 4369
      # erlang distribution
      - 9999
  ```
  """

  use GenServer
  use Cluster.Strategy

  alias Cluster.Strategy.State

  @default_polling_interval 10_000
  @access_token_path 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token'

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init([%State{} = state]) do
    {:ok, load(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    handle_info(:load, state)
  end

  def handle_info(:load, %State{} = state) do
    {:noreply, load(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp load(%State{} = state) do
    connect = state.connect
    list_nodes = state.list_nodes
    topology = state.topology

    nodes = get_nodes(state)

    Cluster.Strategy.connect_nodes(topology, connect, list_nodes, nodes)

    Process.send_after(self(), :load, polling_interval(state))

    state
  end

  defp polling_interval(%State{config: config}) do
    Keyword.get(config, :polling_interval, @default_polling_interval)
  end

  defp get_nodes(%State{}) do
    instances = get_running_instances()

    release_name = System.get_env("REL_NAME")

    Enum.map(instances, & :"#{release_name}@#{&1}")
  end

  defp get_running_instances do
    project_id = System.get_env("GOOGLE_CLOUD_PROJECT")
    service_id = System.get_env("GAE_SERVICE")

    versions = get_running_versions(project_id, service_id)

    Enum.flat_map(versions, &get_instances_for_version(project_id, service_id, &1))
  end

  defp get_running_versions(project_id, service_id) do
    access_token = access_token()
    headers = [{'Authorization', 'Bearer #{access_token}'}]

    api_url = 'https://appengine.googleapis.com/v1/apps/#{project_id}/services/#{service_id}'

    case :httpc.request(:get, {api_url, headers}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        %{"split" => %{"allocations" => allocations}} = Jason.decode!(body)
        Map.keys(allocations)
    end
  end

  defp get_instances_for_version(project_id, service_id, version) do
    access_token = access_token()
    headers = [{'Authorization', 'Bearer #{access_token}'}]

    api_url = 'https://appengine.googleapis.com/v1/apps/#{project_id}/services/#{service_id}/versions/#{version}/instances'

    case :httpc.request(:get, {api_url, headers}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        handle_instances(Jason.decode!(body))
    end
  end

  defp handle_instances(%{"instances" => instances}) do
    instances
    |> Enum.filter(& &1["vmStatus"] == "RUNNING")
    |> Enum.map(& &1["id"])
  end

  defp handle_instances(_), do: []

  defp access_token do
    headers = [{'Metadata-Flavor', 'Google'}]

    case :httpc.request(:get, {@access_token_path, headers}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        %{"access_token" => token} = Jason.decode!(body)
        token
    end
  end
end
