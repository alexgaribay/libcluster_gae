This library is a strategy for `libcluster` for connecting nodes in Google App Engine. If you're unfamiliar with `libcluster`, please read the [documentation](https://github.com/bitwalker/libcluster).

This library makes the assumption that the elixir application is using [Distillery](https://github.com/bitwalker/distillery) releases.

## Installation

Add `:libcluster_gae` to your project's mix dependencies.

```elixir
def deps do
  [
    {:libcluster_gae, "~> 0.1.0"}
  ]
end
```

## Deployment Assumptions

Clustering will only apply to nodes that are configured to receive HTTP traffic in App Engine are currently running and belong to the same service. If this doesn't fit your deployment strategy, please open a Github issue describing your deployment configuration.

## Configuration

### Google Cloud

Before clustering can work, enable the **App Engine Admin API** for your application's Google Cloud Project. Follow the guide on [enabling APIs](https://cloud.google.com/apis/docs/enable-disable-apis).

### Elixir Application

To cluster an application running in Google App Engine, define a topology for `libcluster`.

```elixir
# config.exs
config :libcluster,
  topologies: [
    my_app: [
      strategy: Cluster.Strategy.GoogleAppEngine
    ]
  ]
```

Make sure a cluster supervisor is part of your application.

```elixir
defmodule MyApp.App do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]},
      # ...
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

Update your release's `vm.args` file to include the following lines.

```
## Name of the node
-sname <%= release_name %>@${GAE_INSTANCE}

## Limit distributed erlang ports to a single port
-kernel inet_dist_listen_min 9999
-kernel inet_dist_listen_max 9999
```

Update the `app.yaml` configuration for Google App Engine.

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

Now run `gcloud app deploy` and enjoy clustering on GAE!
