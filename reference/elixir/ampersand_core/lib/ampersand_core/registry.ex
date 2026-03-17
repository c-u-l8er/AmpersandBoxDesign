defmodule AmpersandCore.Registry do
  @moduledoc """
  Loader and query helpers for versioned capability registry artifacts.

  This module treats the JSON registry snapshot in `protocol/registry/v0.1.0` as a
  first-class protocol artifact. It can:

    * load the default registry artifact
    * validate a decoded registry or on-disk registry file against the canonical
      registry schema
    * expose simple query helpers for primitives, capabilities, providers,
      contract references, and A2A skill mappings

  The registry is intentionally modeled as data rather than runtime code so the
  protocol can support:

    * `provider: "auto"` workflows
    * capability discovery
    * provider lookup
    * generation-time enrichment
    * documentation and SEO page generation

  Validation is delegated to `ajv-cli` with JSON Schema draft 2020-12 support,
  mirroring the approach used elsewhere in the reference implementation.
  """

  @type registry :: map()
  @type result :: {:ok, registry()} | {:error, [String.t()]}
  @type primitive_id :: String.t()
  @type capability_id :: String.t()
  @type provider_id :: String.t()

  @primitive_regex ~r/^&(memory|reason|time|space)$/
  @capability_regex ~r/^&(memory|reason|time|space)(\.[A-Za-z][A-Za-z0-9_-]*)?$/

  @default_registry_path Path.expand(
                           "../../../../../protocol/registry/v0.1.0/capabilities.registry.json",
                           __DIR__
                         )

  @default_schema_path Path.expand(
                         "../../../../../protocol/schema/v0.1.0/registry.schema.json",
                         __DIR__
                       )

  @ajv_base_args [
    "--yes",
    "ajv-cli",
    "validate",
    "--spec=draft2020",
    "--strict=false",
    "--all-errors",
    "--errors=text"
  ]

  @doc """
  Returns the absolute path to the default versioned registry artifact.
  """
  @spec default_registry_path() :: Path.t()
  def default_registry_path, do: @default_registry_path

  @doc """
  Returns the absolute path to the canonical registry schema.
  """
  @spec default_schema_path() :: Path.t()
  def default_schema_path, do: @default_schema_path

  @doc """
  Loads and validates the default versioned registry artifact.
  """
  @spec load() :: result()
  def load do
    load(@default_registry_path, @default_schema_path)
  end

  @doc """
  Loads and validates a registry artifact from `registry_path` using the default
  registry schema.
  """
  @spec load(Path.t()) :: result()
  def load(registry_path) when is_binary(registry_path) do
    load(registry_path, @default_schema_path)
  end

  @doc """
  Loads and validates a registry artifact from `registry_path` using the schema
  at `schema_path`.
  """
  @spec load(Path.t(), Path.t()) :: result()
  def load(registry_path, schema_path)
      when is_binary(registry_path) and is_binary(schema_path) do
    with :ok <- validate_file(registry_path, schema_path),
         {:ok, contents} <- read_file(registry_path, "registry artifact"),
         {:ok, decoded} <- decode_json(contents, registry_path, "registry artifact") do
      {:ok, decoded}
    end
  end

  @doc """
  Validates a decoded registry against the default registry schema.
  """
  @spec validate(registry()) :: result()
  def validate(%{} = registry) do
    validate(registry, @default_schema_path)
  end

  def validate(_registry) do
    {:error, ["registry must be a map"]}
  end

  @doc """
  Validates a decoded registry against the schema at `schema_path`.
  """
  @spec validate(registry(), Path.t()) :: result()
  def validate(%{} = registry, schema_path) when is_binary(schema_path) do
    with {:ok, _schema_path} <- load_schema(schema_path),
         {:ok, encoded} <- Jason.encode(registry),
         result <- with_temp_json(encoded, fn temp_path -> run_ajv(schema_path, temp_path) end) do
      case result do
        :ok -> {:ok, registry}
        {:error, errors} -> {:error, errors}
      end
    else
      {:error, errors} when is_list(errors) -> {:error, errors}
      {:error, reason} -> {:error, [to_string(reason)]}
    end
  end

  @doc """
  Validates an on-disk registry artifact against the default registry schema.
  """
  @spec validate_file(Path.t()) :: :ok | {:error, [String.t()]}
  def validate_file(registry_path) when is_binary(registry_path) do
    validate_file(registry_path, @default_schema_path)
  end

  @doc """
  Validates an on-disk registry artifact against the schema at `schema_path`.
  """
  @spec validate_file(Path.t(), Path.t()) :: :ok | {:error, [String.t()]}
  def validate_file(registry_path, schema_path)
      when is_binary(registry_path) and is_binary(schema_path) do
    with {:ok, _schema_path} <- load_schema(schema_path),
         {:ok, _contents} <- read_file(registry_path, "registry artifact") do
      run_ajv(schema_path, registry_path)
    end
  end

  @doc """
  Returns the sorted primitive roots present in the registry.

  Example return value:

      ["&memory", "&reason", "&space", "&time"]
  """
  @spec list_primitives(registry()) :: [primitive_id()]
  def list_primitives(%{} = registry) do
    registry
    |> Map.keys()
    |> Enum.filter(&primitive?/1)
    |> Enum.sort()
  end

  def list_primitives(_registry), do: []

  @doc """
  Returns the sorted fully qualified capability identifiers present in the
  registry, such as `&memory.graph` or `&reason.argument`.
  """
  @spec list_capabilities(registry()) :: [capability_id()]
  def list_capabilities(%{} = registry) do
    registry
    |> list_primitives()
    |> Enum.flat_map(fn primitive ->
      subtype_map =
        registry
        |> primitive_entry(primitive)
        |> Map.get("subtypes", %{})

      subtype_map
      |> Map.keys()
      |> Enum.map(fn subtype -> primitive <> "." <> subtype end)
    end)
    |> Enum.sort()
  end

  def list_capabilities(_registry), do: []

  @doc """
  Returns true when the registry includes the given capability identifier.
  """
  @spec capability_defined?(registry(), capability_id()) :: boolean()
  def capability_defined?(%{} = registry, capability) when is_binary(capability) do
    case parse_capability(capability) do
      {:ok, primitive, nil} ->
        primitive in list_primitives(registry)

      {:ok, primitive, subtype} ->
        registry
        |> primitive_entry(primitive)
        |> Map.get("subtypes", %{})
        |> Map.has_key?(subtype)

      :error ->
        false
    end
  end

  def capability_defined?(_registry, _capability), do: false

  @doc """
  Returns the subtype definition map for a capability identifier.

  Returns `nil` when the capability is not a subtype-backed capability or cannot
  be found in the registry.
  """
  @spec subtype_definition(registry(), capability_id()) :: map() | nil
  def subtype_definition(%{} = registry, capability) when is_binary(capability) do
    case parse_capability(capability) do
      {:ok, primitive, subtype} when is_binary(subtype) ->
        registry
        |> primitive_entry(primitive)
        |> Map.get("subtypes", %{})
        |> Map.get(subtype)

      _ ->
        nil
    end
  end

  def subtype_definition(_registry, _capability), do: nil

  @doc """
  Returns the provider definitions that satisfy the given capability identifier.

  If the input is a primitive root like `&memory`, all providers under that
  primitive are returned. If the input is a fully qualified capability like
  `&memory.graph`, only providers advertising that subtype are returned.
  """
  @spec providers_for_capability(registry(), capability_id()) :: [map()]
  def providers_for_capability(%{} = registry, capability) when is_binary(capability) do
    case parse_capability(capability) do
      {:ok, primitive, nil} ->
        registry
        |> primitive_entry(primitive)
        |> Map.get("providers", [])
        |> ensure_map_list()
        |> Enum.sort_by(&provider_sort_key/1)

      {:ok, primitive, subtype} ->
        registry
        |> primitive_entry(primitive)
        |> Map.get("providers", [])
        |> ensure_map_list()
        |> Enum.filter(fn provider ->
          provider
          |> Map.get("subtypes", [])
          |> ensure_string_list()
          |> Enum.member?(subtype)
        end)
        |> Enum.sort_by(&provider_sort_key/1)

      :error ->
        []
    end
  end

  def providers_for_capability(_registry, _capability), do: []

  @doc """
  Returns the first provider definition with the given provider id across all
  primitive roots, or `nil` if none is found.
  """
  @spec provider(registry(), provider_id()) :: map() | nil
  def provider(%{} = registry, provider_id) when is_binary(provider_id) do
    registry
    |> list_primitives()
    |> Enum.flat_map(fn primitive ->
      registry
      |> primitive_entry(primitive)
      |> Map.get("providers", [])
      |> ensure_map_list()
    end)
    |> Enum.find(fn provider ->
      Map.get(provider, "id") == provider_id
    end)
  end

  def provider(_registry, _provider_id), do: nil

  @doc """
  Returns the declared contract reference for a capability, if present.
  """
  @spec contract_ref_for(registry(), capability_id()) :: String.t() | nil
  def contract_ref_for(%{} = registry, capability) when is_binary(capability) do
    case subtype_definition(registry, capability) do
      %{} = definition -> get_string(definition, "contract_ref")
      _ -> nil
    end
  end

  def contract_ref_for(_registry, _capability), do: nil

  @doc """
  Returns the sorted A2A skill ids declared for a capability in the registry.
  """
  @spec a2a_skills_for(registry(), capability_id()) :: [String.t()]
  def a2a_skills_for(%{} = registry, capability) when is_binary(capability) do
    registry
    |> subtype_definition(capability)
    |> case do
      %{} = definition ->
        definition
        |> Map.get("a2a_skills", [])
        |> ensure_string_list()
        |> Enum.uniq()
        |> Enum.sort()

      _ ->
        []
    end
  end

  def a2a_skills_for(_registry, _capability), do: []

  @doc """
  Returns the operations declared for a capability in the registry subtype
  metadata.

  This does not replace contract loading; it is a lightweight helper for the
  operation names surfaced directly by the registry.
  """
  @spec operations_for(registry(), capability_id()) :: [String.t()]
  def operations_for(%{} = registry, capability) when is_binary(capability) do
    registry
    |> subtype_definition(capability)
    |> case do
      %{} = definition ->
        definition
        |> Map.get("ops", [])
        |> ensure_string_list()
        |> Enum.uniq()
        |> Enum.sort()

      _ ->
        []
    end
  end

  def operations_for(_registry, _capability), do: []

  defp load_schema(schema_path) do
    with {:ok, contents} <- read_file(schema_path, "schema"),
         {:ok, _decoded} <- decode_json(contents, schema_path, "schema") do
      {:ok, schema_path}
    end
  end

  defp read_file(path, label) do
    case File.read(path) do
      {:ok, contents} ->
        {:ok, contents}

      {:error, :enoent} ->
        {:error, ["#{label} file not found: #{path}"]}

      {:error, reason} ->
        {:error, ["unable to read #{label} #{path}: #{inspect(reason)}"]}
    end
  end

  defp decode_json(contents, path, label) do
    case Jason.decode(contents) do
      {:ok, %{} = decoded} ->
        {:ok, decoded}

      {:ok, other} ->
        {:error, ["#{label} #{path} must decode to a JSON object, got: #{inspect(other)}"]}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, ["invalid JSON in #{label} #{path}: #{Exception.message(error)}"]}
    end
  end

  defp with_temp_json(encoded_json, fun) when is_binary(encoded_json) and is_function(fun, 1) do
    tmp_dir = System.tmp_dir!()

    path =
      Path.join(
        tmp_dir,
        "ampersand-registry-#{System.unique_integer([:positive, :monotonic])}.json"
      )

    try do
      File.write!(path, encoded_json)
      fun.(path)
    after
      File.rm(path)
    end
  rescue
    error ->
      {:error, ["unable to create temporary validation file: #{Exception.message(error)}"]}
  end

  defp run_ajv(schema_path, data_path) do
    args = @ajv_base_args ++ ["-s", schema_path, "-d", data_path]

    try do
      case System.cmd("npx", args, stderr_to_stdout: true) do
        {output, 0} ->
          case normalize_ajv_warnings(output) do
            [] -> :ok
            _warnings -> :ok
          end

        {output, _exit_code} ->
          {:error, normalize_ajv_output(output)}
      end
    rescue
      error in ErlangError ->
        {:error, ["unable to execute AJV validation: #{Exception.message(error)}"]}

      error in RuntimeError ->
        {:error, ["unable to execute AJV validation: #{Exception.message(error)}"]}

      error in ArgumentError ->
        {:error, ["unable to execute AJV validation: #{Exception.message(error)}"]}
    end
  end

  defp normalize_ajv_warnings(output) when is_binary(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "unknown format "))
  end

  defp normalize_ajv_output(output) when is_binary(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&String.starts_with?(&1, "npm "))
    |> Enum.reject(&String.starts_with?(&1, "npm warn"))
    |> Enum.reject(&String.starts_with?(&1, "npm notice"))
    |> Enum.reject(&String.starts_with?(&1, "unknown format "))
    |> Enum.map(&classify_error/1)
    |> case do
      [] -> ["registry validation failed with no diagnostic output from AJV"]
      lines -> lines
    end
  end

  defp classify_error(line) do
    cond do
      String.contains?(line, "&memory") or
          String.contains?(line, "&reason") or
          String.contains?(line, "&time") or
          String.contains?(line, "&space") ->
        "registry capability error: #{line}"

      String.contains?(line, "providers") ->
        "registry provider error: #{line}"

      true ->
        "registry validation error: #{line}"
    end
  end

  defp primitive?(value) when is_binary(value), do: value =~ @primitive_regex
  defp primitive?(_value), do: false

  defp primitive_entry(registry, primitive) when is_map(registry) and is_binary(primitive) do
    case Map.get(registry, primitive) do
      %{} = entry -> entry
      _ -> %{}
    end
  end

  defp parse_capability(capability) when is_binary(capability) do
    if capability =~ @capability_regex do
      trimmed = String.trim_leading(capability, "&")

      case String.split(trimmed, ".", parts: 2) do
        [primitive] ->
          {:ok, "&" <> primitive, nil}

        [primitive, subtype] ->
          {:ok, "&" <> primitive, subtype}
      end
    else
      :error
    end
  end

  defp parse_capability(_capability), do: :error

  defp provider_sort_key(provider) when is_map(provider) do
    {
      get_string(provider, "id") || "",
      get_string(provider, "name") || ""
    }
  end

  defp ensure_map_list(values) when is_list(values) do
    Enum.filter(values, &is_map/1)
  end

  defp ensure_map_list(_values), do: []

  defp ensure_string_list(values) when is_list(values) do
    values
    |> Enum.filter(&is_binary/1)
  end

  defp ensure_string_list(_values), do: []

  defp get_string(map, key) when is_map(map) and is_binary(key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end
end
