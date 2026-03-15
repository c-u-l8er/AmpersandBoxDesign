defmodule AmpersandCore.Contracts do
  @moduledoc """
  Validates capability pipelines against a registry of protocol contracts.

  Each contract is expected to describe:

    * supported `operations`
    * `accepts_from` adjacency constraints
    * `feeds_into` adjacency constraints

  A pipeline is considered valid when:

    * every step references a known capability
    * every step references a known operation for that capability
    * the first step accepts the declared source
    * each adjacent pair satisfies both capability adjacency rules
    * the output type of the left operation matches the input type of the right operation
  """

  @type capability_id :: String.t()
  @type operation_name :: String.t()

  @type pipeline_step :: map() | {capability_id(), operation_name()}

  @type contract_registry :: %{optional(capability_id()) => map()}

  @type result :: :ok | {:error, [String.t()]}

  @spec check_pipeline(contract_registry(), [pipeline_step()]) :: result()
  def check_pipeline(contracts, pipeline) do
    check_pipeline(contracts, pipeline, [])
  end

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
        wildcard_match?(pattern, capability)

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
end
