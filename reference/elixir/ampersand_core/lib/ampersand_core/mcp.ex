defmodule AmpersandCore.MCP do
  @moduledoc """
  Minimal MCP configuration generator for canonical `ampersand.json` documents.

  This module is intentionally pragmatic rather than exhaustive:

    * it validates agent declarations with `AmpersandCore.Schema`
    * it groups declared capabilities by provider
    * it resolves known providers into stdio MCP server launch configs
    * it reports unresolved providers without inventing runtime details

  The generator supports two output styles:

    * `:zed` - emits a `context_servers` config block
    * `:generic` - emits an `mcpServers` config block

  Because this repository currently only contains enough concrete runtime evidence
  for `graphonomous`, that provider ships with a built-in resolver. Other
  providers may be supplied through `:provider_registry` in `opts`.

  Example usage:

      {:ok, manifest} =
        AmpersandCore.MCP.generate(document, format: :zed)

      {:ok, json} =
        AmpersandCore.MCP.to_json(document, format: :zed)

  Example provider registry override:

      custom_registry = %{
        "ticktickclock" => fn _provider, capabilities, _binding_opts ->
          {:ok,
           {"ticktickclock",
            %{
              "command" => "ticktickclock",
              "args" => [],
              "env" => %{},
              "transport" => "stdio",
              "capabilities" => capabilities
            }}}
        end
      }

      AmpersandCore.MCP.generate(document, provider_registry: custom_registry)
  """

  alias AmpersandCore.Schema

  @type document :: map()
  @type capability_id :: String.t()
  @type provider_id :: String.t()

  @type binding :: %{
          required(:capability) => capability_id(),
          required(:provider) => provider_id(),
          optional(:config) => map(),
          optional(:need) => String.t()
        }

  @type unresolved_provider :: map()

  @type client_format :: :zed | :generic

  @type manifest :: map()

  @type result :: {:ok, manifest()} | {:error, [String.t()]}

  @graphonomous_wrapper_path Path.expand(
                               "../../../../../../graphonomous/scripts/graphonomous_mcp_wrapper.sh",
                               __DIR__
                             )

  @doc """
  Generates an MCP manifest from a validated ampersand agent declaration.

  Supported options:

    * `:format` - `:zed` or `:generic` (default: `:zed`)
    * `:strict` - when true, unresolved providers cause an error (default: `false`)
    * `:include_metadata` - when false, omits top-level governance/provenance fields (default: `true`)
    * `:provider_registry` - map of provider resolvers to merge with built-ins
    * `:graphonomous_mode` - `:npx` or `:local_wrapper` (default: `:npx`)
    * `:graphonomous_db_path` - db path for the built-in Graphonomous resolver
    * `:graphonomous_embedder_backend` - backend for the built-in Graphonomous resolver
    * `:graphonomous_env` - extra env vars for the built-in Graphonomous resolver
  """
  @spec generate(document(), keyword()) :: result()
  def generate(document, opts \\ [])

  def generate(document, opts) when is_map(document) and is_list(opts) do
    with {:ok, validated} <- Schema.validate(document) do
      do_generate(validated, opts)
    end
  end

  def generate(_document, _opts) do
    {:error, ["document must be a validated ampersand.json object"]}
  end

  @doc """
  Reads an ampersand declaration from disk and generates an MCP manifest.
  """
  @spec generate_file(Path.t(), keyword()) :: result()
  def generate_file(path, opts \\ []) when is_binary(path) and is_list(opts) do
    with {:ok, document} <- Schema.validate_file(path) do
      do_generate(document, opts)
    end
  end

  @doc """
  Returns only the client configuration block, without the surrounding manifest.
  """
  @spec client_config(document(), keyword()) :: {:ok, map()} | {:error, [String.t()]}
  def client_config(document, opts \\ []) do
    case generate(document, opts) do
      {:ok, %{"config" => config}} -> {:ok, config}
      {:error, errors} -> {:error, errors}
    end
  end

  @doc """
  Reads an ampersand declaration from disk and returns only the client config.
  """
  @spec client_config_file(Path.t(), keyword()) :: {:ok, map()} | {:error, [String.t()]}
  def client_config_file(path, opts \\ []) do
    case generate_file(path, opts) do
      {:ok, %{"config" => config}} -> {:ok, config}
      {:error, errors} -> {:error, errors}
    end
  end

  @doc """
  Encodes a generated MCP manifest as pretty JSON.
  """
  @spec to_json(document(), keyword()) :: {:ok, String.t()} | {:error, [String.t()]}
  def to_json(document, opts \\ []) do
    case generate(document, opts) do
      {:ok, manifest} ->
        case Jason.encode(manifest, pretty: true) do
          {:ok, json} -> {:ok, json}
          {:error, reason} -> {:error, ["unable to encode MCP manifest: #{inspect(reason)}"]}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp do_generate(document, opts) do
    format = Keyword.get(opts, :format, :zed)
    strict? = Keyword.get(opts, :strict, false)
    include_metadata? = Keyword.get(opts, :include_metadata, true)

    bindings = normalize_bindings(document)
    registry = provider_registry(opts)

    {resolved, unresolved} =
      bindings
      |> Enum.group_by(& &1.provider)
      |> Enum.sort_by(fn {provider, _bindings} -> provider end)
      |> Enum.reduce({%{}, []}, fn {provider, provider_bindings}, {resolved_acc, unresolved_acc} ->
        case resolve_provider(provider, provider_bindings, registry, opts) do
          {:ok, {server_name, server_config}} ->
            {
              Map.put(resolved_acc, server_name, strip_internal_fields(server_config)),
              unresolved_acc
            }

          {:unresolved, reason} ->
            unresolved_entry = %{
              "provider" => provider,
              "capabilities" => provider_bindings |> Enum.map(& &1.capability) |> Enum.sort(),
              "reason" => reason
            }

            {resolved_acc, unresolved_acc ++ [unresolved_entry]}
        end
      end)

    if strict? and unresolved != [] do
      {:error,
       Enum.map(unresolved, fn entry ->
         "unresolved provider #{entry["provider"]}: #{entry["reason"]}"
       end)}
    else
      {:ok,
       build_manifest(
         document,
         format,
         resolved,
         unresolved,
         bindings,
         include_metadata?
       )}
    end
  end

  defp build_manifest(document, format, resolved_servers, unresolved, bindings, include_metadata?) do
    config = %{root_key(format) => resolved_servers}

    base_manifest = %{
      "agent" => document["agent"],
      "version" => document["version"],
      "format" => format_name(format),
      "config" => config,
      "providers" => provider_summary(bindings, resolved_servers),
      "unresolved_providers" => unresolved
    }

    if include_metadata? do
      metadata =
        %{}
        |> maybe_put("governance", document["governance"])
        |> maybe_put("provenance", document["provenance"])

      Map.merge(base_manifest, metadata)
    else
      base_manifest
    end
  end

  defp provider_summary(bindings, resolved_servers) do
    bindings
    |> Enum.group_by(& &1.provider)
    |> Enum.sort_by(fn {provider, _} -> provider end)
    |> Enum.into(%{}, fn {provider, provider_bindings} ->
      server_name =
        resolved_servers
        |> Enum.find_value(fn {name, config} ->
          if Map.get(config, "provider") == provider, do: name, else: nil
        end)

      {provider,
       %{
         "server_name" => server_name,
         "capabilities" => provider_bindings |> Enum.map(& &1.capability) |> Enum.sort()
       }}
    end)
  end

  defp normalize_bindings(document) do
    document
    |> Map.get("capabilities", %{})
    |> Enum.map(fn {capability, binding} ->
      %{
        capability: capability,
        provider: Map.get(binding, "provider"),
        config: Map.get(binding, "config", %{}),
        need: Map.get(binding, "need")
      }
    end)
    |> Enum.sort_by(&{&1.provider || "", &1.capability})
  end

  defp resolve_provider(provider, bindings, registry, opts) do
    case Map.get(registry, provider) do
      resolver when is_function(resolver, 3) ->
        resolver.(provider, bindings, opts)

      _ ->
        {:unresolved, "no MCP resolver registered for provider"}
    end
  end

  defp provider_registry(opts) do
    Map.merge(default_provider_registry(), Keyword.get(opts, :provider_registry, %{}))
  end

  defp default_provider_registry do
    %{
      "graphonomous" => &resolve_graphonomous/3
    }
  end

  defp resolve_graphonomous(provider, bindings, opts) do
    mode = Keyword.get(opts, :graphonomous_mode, :npx)
    db_path = Keyword.get(opts, :graphonomous_db_path, "~/.graphonomous/knowledge.db")
    embedder_backend = Keyword.get(opts, :graphonomous_embedder_backend, "fallback")
    extra_env = Keyword.get(opts, :graphonomous_env, %{})

    capability_names = bindings |> Enum.map(& &1.capability) |> Enum.sort()

    server =
      case mode do
        :local_wrapper ->
          %{
            "command" => @graphonomous_wrapper_path,
            "args" => [],
            "env" => stringify_map(extra_env),
            "transport" => "stdio",
            "provider" => provider,
            "capabilities" => capability_names
          }

        _ ->
          %{
            "command" => "npx",
            "args" => [
              "-y",
              "graphonomous",
              "--db",
              db_path,
              "--embedder-backend",
              embedder_backend
            ],
            "env" =>
              stringify_map(
                Map.merge(
                  %{
                    "GRAPHONOMOUS_EMBEDDING_MODEL" =>
                      "sentence-transformers/all-MiniLM-L6-v2"
                  },
                  extra_env
                )
              ),
            "transport" => "stdio",
            "provider" => provider,
            "capabilities" => capability_names
          }
      end

    {:ok, {provider, server}}
  end

  defp strip_internal_fields(server_config) do
    server_config
    |> Map.drop(["provider", "capabilities"])
    |> normalize_server_config()
  end

  defp normalize_server_config(server_config) do
    %{}
    |> maybe_put("command", Map.get(server_config, "command"))
    |> maybe_put("args", Map.get(server_config, "args", []))
    |> maybe_put("env", Map.get(server_config, "env", %{}))
    |> maybe_put("transport", Map.get(server_config, "transport"))
    |> maybe_put("url", Map.get(server_config, "url"))
  end

  defp root_key(:generic), do: "mcpServers"
  defp root_key(:zed), do: "context_servers"
  defp root_key(_other), do: "context_servers"

  defp format_name(:generic), do: "mcpServers"
  defp format_name(:zed), do: "context_servers"
  defp format_name(other), do: to_string(other)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp stringify_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Enum.into(%{})
  end
end
