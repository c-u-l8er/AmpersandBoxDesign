defmodule AmpersandCore.Compose do
  @moduledoc """
  Capability composition utilities for the minimal [&] protocol reference
  implementation.

  This module models capability declarations as set-like maps keyed by protocol
  capability identifiers such as `&memory.graph` or `&reason.argument`.

  The composition rules are intentionally simple:

  - capability identifiers are normalized into a sorted list for comparison
  - composing disjoint capability sets merges them
  - composing identical bindings is idempotent
  - composing conflicting bindings for the same capability returns an error

  These rules give the implementation practical ACI-style behavior:

  - commutative for compatible declarations
  - associative for compatible declarations
  - idempotent for repeated declarations
  - identity via the empty capability set
  """

  @type capability_id :: String.t()
  @type capability_binding :: map()
  @type capability_map :: %{optional(capability_id()) => capability_binding()}
  @type input :: capability_map() | map()
  @type compose_error ::
          {:conflicting_binding, capability_id(), capability_binding(), capability_binding()}
          | {:invalid_input, term()}
  @type compose_result :: {:ok, capability_map()} | {:error, compose_error()}

  @identity %{}

  @doc """
  Returns the identity value for composition.
  """
  @spec identity() :: capability_map()
  def identity, do: @identity

  @doc """
  Returns a sorted, normalized list of capability identifiers from either a full
  ampersand document or a raw capability map.
  """
  @spec normalize(input()) :: [capability_id()]
  def normalize(input) do
    input
    |> capabilities_from_input!()
    |> Map.keys()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Composes one or more capability maps or full documents into a single
  capability map.

  If the same capability appears multiple times with the same binding, the
  duplicate collapses cleanly. If the same capability appears with different
  bindings, composition fails with a conflict.
  """
  @spec compose([input()]) :: compose_result()
  def compose(inputs) when is_list(inputs) do
    Enum.reduce_while(inputs, {:ok, identity()}, fn input, {:ok, acc} ->
      case capabilities_from_input(input) do
        {:ok, capabilities} ->
          case merge(acc, capabilities) do
            {:ok, merged} -> {:cont, {:ok, merged}}
            {:error, _reason} = error -> {:halt, error}
          end

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  @doc """
  Checks whether two declarations are equivalent after normalization.
  """
  @spec aci_equivalent?(input(), input()) :: boolean()
  def aci_equivalent?(left, right) do
    normalize(left) == normalize(right) and bindings_equivalent?(left, right)
  end

  @doc """
  Checks the commutative property for two compatible declarations.
  """
  @spec commutative?(input(), input()) :: boolean()
  def commutative?(left, right) do
    case {compose([left, right]), compose([right, left])} do
      {{:ok, forward}, {:ok, reverse}} -> forward == reverse
      _ -> false
    end
  end

  @doc """
  Checks the associative property for three compatible declarations.
  """
  @spec associative?(input(), input(), input()) :: boolean()
  def associative?(left, middle, right) do
    with {:ok, left_middle} <- compose([left, middle]),
         {:ok, middle_right} <- compose([middle, right]),
         {:ok, grouped_left} <- compose([left_middle, right]),
         {:ok, grouped_right} <- compose([left, middle_right]) do
      grouped_left == grouped_right
    else
      _ -> false
    end
  end

  @doc """
  Checks the idempotent property for a declaration.
  """
  @spec idempotent?(input()) :: boolean()
  def idempotent?(input) do
    case {compose([input]), compose([input, input])} do
      {{:ok, once}, {:ok, twice}} -> once == twice
      _ -> false
    end
  end

  @doc """
  Checks the identity property for a declaration.
  """
  @spec identity?(input()) :: boolean()
  def identity?(input) do
    case {compose([identity(), input]), compose([input, identity()]), compose([input])} do
      {{:ok, left_identity}, {:ok, right_identity}, {:ok, original}} ->
        left_identity == original and right_identity == original

      _ ->
        false
    end
  end

  @doc false
  @spec merge(capability_map(), capability_map()) :: compose_result()
  def merge(left, right) when is_map(left) and is_map(right) do
    Enum.reduce_while(right, {:ok, left}, fn {capability, binding}, {:ok, acc} ->
      case Map.fetch(acc, capability) do
        :error ->
          {:cont, {:ok, Map.put(acc, capability, binding)}}

        {:ok, existing} when existing == binding ->
          {:cont, {:ok, acc}}

        {:ok, existing} ->
          {:halt, {:error, {:conflicting_binding, capability, existing, binding}}}
      end
    end)
  end

  defp bindings_equivalent?(left, right) do
    case {capabilities_from_input(left), capabilities_from_input(right)} do
      {{:ok, left_caps}, {:ok, right_caps}} -> left_caps == right_caps
      _ -> false
    end
  end

  defp capabilities_from_input!(input) do
    case capabilities_from_input(input) do
      {:ok, capabilities} -> capabilities
      {:error, {:invalid_input, reason}} -> raise ArgumentError, "invalid composition input: #{inspect(reason)}"
    end
  end

  defp capabilities_from_input(%{"capabilities" => capabilities}) when is_map(capabilities),
    do: {:ok, capabilities}

  defp capabilities_from_input(%{capabilities: capabilities}) when is_map(capabilities),
    do: {:ok, capabilities}

  defp capabilities_from_input(input) when is_map(input) do
    if capability_map?(input) do
      {:ok, input}
    else
      {:error, {:invalid_input, input}}
    end
  end

  defp capabilities_from_input(input), do: {:error, {:invalid_input, input}}

  defp capability_map?(map) when map_size(map) == 0, do: true

  defp capability_map?(map) do
    Enum.all?(map, fn
      {capability, binding} when is_binary(capability) and is_map(binding) -> true
      _ -> false
    end)
  end
end
