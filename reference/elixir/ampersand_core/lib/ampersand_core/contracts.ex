defmodule AmpersandCore.Contracts do
  @moduledoc """
  Loads and validates versioned capability contract artifacts, then uses those
  contracts to validate capability pipelines.

  This module has two responsibilities:

    * load contract artifacts from `contracts/v*/`
    * validate pipeline compatibility from those loaded contracts

  A pipeline is considered valid when:

    * every step references a known capability
    * every step references a known operation for that capability
    * the first step accepts the declared source
    * each adjacent pair satisfies both capability adjacency rules
    * the output type of the left operation matches the input type of the right operation

  The contract-loading API is intentionally versioned-path friendly so the
  reference implementation can consume repository artifacts directly.
  """

  @type capability_id :: String.t()
  @type operation_name :: String.t()
  @type pipeline_step :: map() | {capability_id(), operation_name()}
  @type contract_registry :: %{optional(capability_id()) => map()}
  @type result :: :ok | {:error, [String.t()]}
  @type load_result :: {:ok, contract_registry()} | {:error, [String.t()]}

  @default_contracts_dir Path.expand("../../../../../contracts/v0.1.0", __DIR__)
  @default_contract_schema_path Path.expand(
                                  "../../../../../protocol/schema/v0.1.0/capability-contract.schema.json",
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
  Returns the default directory containing versioned contract artifacts.
  """
  @spec default_contracts_dir() :: Path.t()
  def default_contracts_dir, do: @default_contracts_dir

  @doc """
  Returns the canonical schema path for contract artifacts.
  """
  @spec default_contract_schema_path() :: Path.t()
  def default_contract_schema_path, do: @default_contract_schema_path

  @doc """
  Loads every contract artifact from the default versioned contracts directory.
  """
  @spec load_contracts() :: load_result()
  def load_contracts do
    load_contracts(@default_contracts_dir, @default_contract_schema_path)
  end

  @doc """
  Loads every contract artifact from `contracts_dir`, validating each against
  the default contract schema.
  """
  @spec load_contracts(Path.t()) :: load_result()
  def load_contracts(contracts_dir) when is_binary(contracts_dir) do
    load_contracts(contracts_dir, @default_contract_schema_path)
  end

  @doc """
  Loads every contract artifact from `contracts_dir`, validating each against
  `schema_path`.
  """
  @spec load_contracts(Path.t(), Path.t()) :: load_result()
  def load_contracts(contracts_dir, schema_path)
      when is_binary(contracts_dir) and is_binary(schema_path) do
    with {:ok, paths} <- contract_paths(contracts_dir) do
      Enum.reduce_while(paths, {:ok, %{}}, fn path, {:ok, acc} ->
        case load_contract(path, schema_path) do
          {:ok, %{"capability" => capability} = contract} ->
            case Map.fetch(acc, capability) do
              :error ->
                {:cont, {:ok, Map.put(acc, capability, contract)}}

              {:ok, existing} ->
                {:halt,
                 {:error,
                  [
                    "duplicate contract artifact for #{capability}: #{path} conflicts with #{inspect(existing["__source_path__"])}"
                  ]}}
            end

          {:ok, contract} ->
            {:halt, {:error, ["contract #{path} is missing capability identifier: #{inspect(contract)}"]}}

          {:error, errors} ->
            {:halt, {:error, errors}}
        end
      end)
    end
  end

  @doc """
  Loads a single contract artifact from disk and validates it against the
  default contract schema.
  """
  @spec load_contract(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load_contract(path) when is_binary(path) do
    load_contract(path, @default_contract_schema_path)
  end

  @doc """
  Loads a single contract artifact from disk and validates it against
  `schema_path`.
  """
  @spec load_contract(Path.t(), Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load_contract(path, schema_path) when is_binary(path) and is_binary(schema_path) do
    with {:ok, _schema_path} <- ensure_json_file(schema_path, "contract schema"),
         {:ok, contents} <- read_file(path, "contract artifact"),
         {:ok, contract} <- decode_json_object(contents, path, "contract artifact"),
         :ok <- run_ajv(schema_path, path),
         :ok <- validate_loaded_contract_shape(contract, path) do
      {:ok, Map.put(contract, "__source_path__", path)}
    end
  end

  @doc """
  Loads contracts matching the capabilities declared in an ampersand document.

  By default this function is permissive: it returns the subset of available
  contracts for the requested capabilities. Pass `strict: true` in `opts` to
  require every requested capability to have a corresponding contract artifact.
  """
  @spec load_contracts_for_document(map(), keyword()) :: load_result()
  def load_contracts_for_document(document, opts \\ [])

  def load_contracts_for_document(%{"capabilities" => capabilities}, opts)
      when is_map(capabilities) and is_list(opts) do
    capability_ids =
      capabilities
      |> Map.keys()
      |> Enum.sort()

    load_contracts_for_capabilities(capability_ids, opts)
  end

  def load_contracts_for_document(_document, _opts) do
    {:error, ["document must contain a capabilities object"]}
  end

  @doc """
  Loads contracts for a specific list of capability identifiers.

  Options:

    * `:contracts_dir` - directory to scan for contract artifacts
    * `:contract_schema_path` - schema used to validate contract files
    * `:strict` - when true, returns an error if any requested capability is
      missing a matching contract artifact
  """
  @spec load_contracts_for_capabilities([capability_id()], keyword()) :: load_result()
  def load_contracts_for_capabilities(capability_ids, opts \\ [])

  def load_contracts_for_capabilities(capability_ids, opts)
      when is_list(capability_ids) and is_list(opts) do
    contracts_dir = Keyword.get(opts, :contracts_dir, @default_contracts_dir)
    schema_path = Keyword.get(opts, :contract_schema_path, @default_contract_schema_path)
    strict? = Keyword.get(opts, :strict, false)

    normalized_ids =
      capability_ids
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()
      |> Enum.sort()

    with {:ok, registry} <- load_contracts(contracts_dir, schema_path) do
      selected =
        registry
        |> Enum.filter(fn {capability, _contract} -> capability in normalized_ids end)
        |> Enum.into(%{})

      missing =
        normalized_ids
        |> Enum.reject(&Map.has_key?(selected, &1))

      cond do
        strict? and missing != [] ->
          {:error, Enum.map(missing, &"missing contract artifact for capability #{&1}")}

        true ->
          {:ok, selected}
      end
    end
  end

  @doc """
  Validates a pipeline against a registry of capability contracts.
  """
  @spec check_pipeline(contract_registry(), [pipeline_step()]) :: result()
  def check_pipeline(contracts, pipeline) do
    check_pipeline(contracts, pipeline, [])
  end

  @doc """
  Validates a pipeline against a registry of capability contracts with options.

  Supported options include:

    * `:source_type` - protocol input type provided to the first step
    * `:source_ref` - symbolic upstream source, defaulting to `"raw_data"`
  """
  @spec check_pipeline(contract_registry(), [pipeline_step()], keyword()) :: result()
  def check_pipeline(contracts, pipeline, opts)
      when is_map(contracts) and is_list(pipeline) and is_list(opts) do
    with {:ok, steps} <- normalize_pipeline(pipeline),
         :ok <- validate_step_definitions(contracts, steps) do
      errors =
        validate_initial_source(contracts, steps, opts) ++
          validate_transitions(contracts, steps)

      case errors do
        [] -> :ok
        _ -> {:error, errors}
      end
    end
  end

  def check_pipeline(_contracts, _pipeline, _opts) do
    {:error, ["contracts must be a map and pipeline must be a list"]}
  end

  @doc """
  Loads contracts for the capabilities declared in `document` and validates
  `pipeline` against that loaded subset.

  This is the main convenience entrypoint for artifact-backed pipeline checks.
  """
  @spec check_pipeline_for_document(map(), [pipeline_step()], keyword()) :: result()
  def check_pipeline_for_document(document, pipeline, opts \\ [])

  def check_pipeline_for_document(document, pipeline, opts)
      when is_map(document) and is_list(pipeline) and is_list(opts) do
    strict_opts = Keyword.put_new(opts, :strict, true)

    with {:ok, contracts} <- load_contracts_for_document(document, strict_opts) do
      check_pipeline(contracts, pipeline, opts)
    end
  end

  def check_pipeline_for_document(_document, _pipeline, _opts) do
    {:error, ["document must be a map and pipeline must be a list"]}
  end

  defp contract_paths(contracts_dir) do
    cond do
      not File.dir?(contracts_dir) ->
        {:error, ["contracts directory not found: #{contracts_dir}"]}

      true ->
        paths =
          contracts_dir
          |> Path.join("*.json")
          |> Path.wildcard()
          |> Enum.sort()

        case paths do
          [] -> {:error, ["no contract artifacts found in #{contracts_dir}"]}
          _ -> {:ok, paths}
        end
    end
  end

  defp validate_loaded_contract_shape(%{"capability" => capability, "operations" => operations}, _path)
       when is_binary(capability) and is_map(operations) and map_size(operations) > 0 do
    :ok
  end

  defp validate_loaded_contract_shape(contract, path) do
    {:error, ["contract artifact #{path} is missing required protocol fields: #{inspect(contract)}"]}
  end

  defp normalize_pipeline([]), do: {:error, ["pipeline must contain at least one step"]}

  defp normalize_pipeline(pipeline) do
    pipeline
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {step, index}, {:ok, acc} ->
      case normalize_step(step) do
        {:ok, normalized} -> {:cont, {:ok, acc ++ [normalized]}}
        {:error, message} -> {:halt, {:error, ["step #{index} #{message}"]}}
      end
    end)
  end

  defp normalize_step(%{capability: capability, operation: operation})
       when is_binary(capability) and is_binary(operation) do
    {:ok, %{capability: capability, operation: operation}}
  end

  defp normalize_step(%{"capability" => capability, "operation" => operation})
       when is_binary(capability) and is_binary(operation) do
    {:ok, %{capability: capability, operation: operation}}
  end

  defp normalize_step({capability, operation})
       when is_binary(capability) and is_binary(operation) do
    {:ok, %{capability: capability, operation: operation}}
  end

  defp normalize_step(other) do
    {:error, "is invalid: #{inspect(other)}"}
  end

  defp validate_step_definitions(contracts, steps) do
    errors =
      steps
      |> Enum.with_index()
      |> Enum.flat_map(fn {%{capability: capability, operation: operation}, index} ->
        case fetch_contract(contracts, capability) do
          {:ok, contract} ->
            case fetch_operation(contract, operation) do
              {:ok, _signature} ->
                []

              :error ->
                ["step #{index} references unknown operation #{operation} for #{capability}"]
            end

          :error ->
            ["step #{index} references unknown capability #{capability}"]
        end
      end)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp validate_initial_source(_contracts, [], _opts), do: []

  defp validate_initial_source(contracts, [%{capability: capability, operation: operation} | _], opts) do
    source_type = Keyword.get(opts, :source_type)
    source_ref = Keyword.get(opts, :source_ref, "raw_data")

    with {:ok, contract} <- fetch_contract(contracts, capability),
         {:ok, operation_signature} <- fetch_operation(contract, operation) do
      errors = []

      errors =
        case source_type do
          nil ->
            errors

          expected_input ->
            input_type = get_field(operation_signature, "in")

            if input_type == expected_input do
              errors
            else
              [
                "pipeline type mismatch at source: #{capability}.#{operation} expects #{inspect(input_type)}, but source provides #{inspect(expected_input)}"
                | errors
              ]
            end
        end

      accepts_from = get_field(contract, "accepts_from", [])

      if accepts_from == [] or allowed_match?(accepts_from, source_ref) do
        Enum.reverse(errors)
      else
        Enum.reverse([
          "#{capability} cannot accept input from #{source_ref}"
          | errors
        ])
      end
    else
      _ -> []
    end
  end

  defp validate_transitions(_contracts, [_single]), do: []
  defp validate_transitions(_contracts, []), do: []

  defp validate_transitions(contracts, steps) do
    steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [left, right] -> transition_errors(contracts, left, right) end)
  end

  defp transition_errors(
         contracts,
         %{capability: left_capability, operation: left_operation},
         %{capability: right_capability, operation: right_operation}
       ) do
    with {:ok, left_contract} <- fetch_contract(contracts, left_capability),
         {:ok, right_contract} <- fetch_contract(contracts, right_capability),
         {:ok, left_signature} <- fetch_operation(left_contract, left_operation),
         {:ok, right_signature} <- fetch_operation(right_contract, right_operation) do
      left_out = get_field(left_signature, "out")
      right_in = get_field(right_signature, "in")

      []
      |> maybe_add_type_mismatch(
        left_capability,
        left_operation,
        right_capability,
        right_operation,
        left_out,
        right_in
      )
      |> maybe_add_feeds_into_error(left_contract, left_capability, right_capability)
      |> maybe_add_accepts_from_error(right_contract, left_capability, right_capability)
      |> Enum.reverse()
    else
      _ ->
        [
          "unable to evaluate transition #{left_capability}.#{left_operation} -> #{right_capability}.#{right_operation}"
        ]
    end
  end

  defp maybe_add_type_mismatch(errors, _lc, _lo, _rc, _ro, type, type), do: errors

  defp maybe_add_type_mismatch(
         errors,
         left_capability,
         left_operation,
         right_capability,
         right_operation,
         left_out,
         right_in
       ) do
    [
      "pipeline type mismatch: #{left_capability}.#{left_operation} outputs #{inspect(left_out)}, but #{right_capability}.#{right_operation} expects #{inspect(right_in)}"
      | errors
    ]
  end

  defp maybe_add_feeds_into_error(errors, contract, left_capability, right_capability) do
    feeds_into = get_field(contract, "feeds_into", [])

    if feeds_into == [] or allowed_match?(feeds_into, right_capability) do
      errors
    else
      ["#{left_capability} cannot feed into #{right_capability}" | errors]
    end
  end

  defp maybe_add_accepts_from_error(errors, contract, left_capability, right_capability) do
    accepts_from = get_field(contract, "accepts_from", [])

    if accepts_from == [] or allowed_match?(accepts_from, left_capability) do
      errors
    else
      ["#{right_capability} cannot accept input from #{left_capability}" | errors]
    end
  end

  defp fetch_contract(contracts, capability) when is_map(contracts) and is_binary(capability) do
    case Map.fetch(contracts, capability) do
      {:ok, contract} when is_map(contract) -> {:ok, contract}
      {:ok, _contract} -> :error
      :error -> :error
    end
  end

  defp fetch_operation(contract, operation) when is_map(contract) and is_binary(operation) do
    operations = get_field(contract, "operations", %{})

    case Map.fetch(operations, operation) do
      {:ok, signature} when is_map(signature) -> {:ok, signature}
      {:ok, _signature} -> :error
      :error -> :error
    end
  end

  defp allowed_match?(patterns, capability) when is_list(patterns) and is_binary(capability) do
    Enum.any?(patterns, fn
      pattern when pattern == capability ->
        true

      pattern when is_binary(pattern) ->
        wildcard_match?(pattern, capability) or pattern == capability

      _ ->
        false
    end)
  end

  defp wildcard_match?(pattern, capability) do
    case String.split(pattern, ".*") do
      [prefix, ""] -> String.starts_with?(capability, prefix <> ".")
      _ -> false
    end
  end

  defp get_field(map, key, default \\ nil) when is_map(map) and is_binary(key) do
    cond do
      Map.has_key?(map, key) ->
        Map.get(map, key)

      Map.has_key?(map, String.to_atom(key)) ->
        Map.get(map, String.to_atom(key))

      true ->
        default
    end
  end

  defp ensure_json_file(path, label) do
    with {:ok, contents} <- read_file(path, label),
         {:ok, _decoded} <- decode_json_object(contents, path, label) do
      {:ok, path}
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

  defp decode_json_object(contents, path, label) do
    case Jason.decode(contents) do
      {:ok, %{} = decoded} ->
        {:ok, decoded}

      {:ok, other} ->
        {:error, ["#{label} #{path} must decode to a JSON object, got: #{inspect(other)}"]}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, ["invalid JSON in #{label} #{path}: #{Exception.message(error)}"]}
    end
  end

  defp run_ajv(schema_path, data_path) do
    args = @ajv_base_args ++ ["-s", schema_path, "-d", data_path]

    try do
      case System.cmd("npx", args, stderr_to_stdout: true) do
        {_output, 0} ->
          :ok

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

  defp normalize_ajv_output(output) when is_binary(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&String.starts_with?(&1, "npm "))
    |> Enum.reject(&String.starts_with?(&1, "npm warn"))
    |> Enum.reject(&String.starts_with?(&1, "npm notice"))
    |> Enum.map(&classify_schema_error/1)
    |> case do
      [] -> ["schema validation failed with no diagnostic output from AJV"]
      lines -> lines
    end
  end

  defp classify_schema_error(line) do
    cond do
      String.contains?(line, "/operations") ->
        "contract validation error: #{line}"

      String.contains?(line, "accepts_from") or String.contains?(line, "feeds_into") ->
        "contract validation error: #{line}"

      String.contains?(line, "a2a_skills") ->
        "contract validation error: #{line}"

      true ->
        "contract validation error: #{line}"
    end
  end
end
