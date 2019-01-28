defmodule LibclusterGae.MixProject do
  use Mix.Project

  def project do
    [
      app: :libcluster_gae,
      description: "",
      version: "0.1.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      source_url: source_url(),
      project_url: source_url(),
      package: package()
    ]
  end

  defp description do
    """
    Clustering strategy for connecting nodes running on Google App Engine.
    """
  end

  defp source_url do
    "https://github.com/alexgaribay/libcluster_gae"
  end

  defp package do
    [
      files: ["lib", "mix.exs", "LICENSE", "README.md"],
      maintainers: ["Alex Garibay"],
      licenses: ["MIT"],
      links: %{"GitHub" => source_url()}
    ]
  end
  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:libcluster, "~> 3.0"}
    ]
  end
end
