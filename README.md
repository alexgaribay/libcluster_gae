This library is a strategy for `libcluster` for connecting nodes in Google App Engine. If you're unfamiliar with `libcluster`, please read the [documentation](https://github.com/bitwalker/libcluster).

This library makes the assumption that the elixir application is using [mix releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)

## Installation

Add `:libcluster_gae` to your project's mix dependencies.

```elixir
def deps do
  [
    {:libcluster_gae, "~> 0.2"}
  ]
end
```

## Deployment Assumptions

Clustering will only apply to nodes that are configured to receive HTTP traffic in App Engine are currently running and belong to the same service. If this doesn't fit your deployment strategy, please open a Github issue describing your deployment configuration.

## Configuration

### Google Cloud

Before clustering can work, enable the **App Engine Admin API** for your application's Google Cloud Project. Follow the guide on [enabling APIs](https://cloud.google.com/apis/docs/enable-disable-apis).

![Video demonstrating how to enable the App Engine Admin API](https://i.imgur.com/jBhOGYG.gif)

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

Update the `app.yaml` configuration file for Google App Engine.

```yaml
runtime_config:
  ...
  packages:
    ...
    - jq

env_variables:
  REPLACE_OS_VARS: true

network:
  forwarded_ports:
    # epmd
    - 4369
    # erlang distribution
    - 9999
```

Add the following to, or create a `rel/env.sh.eex`

```bash
#!/bin/sh


if [ ! -f /tmp/zone ]; then
  curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token > /tmp/access_token
  curl -H "Authorization: Bearer $(cat /tmp/access_token)" https://appengine.googleapis.com/v1/apps/${GOOGLE_CLOUD_PROJECT}/services/${GAE_SERVICE}/versions/${GAE_VERSION}/instances/${GAE_INSTANCE} | jq -r .vmZoneName > /tmp/zone
fi

export RELEASE_DISTRIBUTION="name"
export RELEASE_NODE="${REL_NAME}@${GAE_INSTANCE}.$(cat /tmp/zone).c.${GOOGLE_CLOUD_PROJECT}.internal"

case $RELEASE_COMMAND in
  start*|daemon*)
    ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min 9999 inet_dist_listen_max 9999"
    export ELIXIR_ERL_OPTIONS
    ;;
  *)
    ;;
esac
```

Now run `gcloud app deploy` and enjoy clustering on GAE!
