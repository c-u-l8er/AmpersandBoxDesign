defmodule AmpersandCore.Governance do
  @moduledoc """
  Parsing and evaluation helpers for governance constraints.

  This module supports compact string conditions such as:

    * `"confidence_below:0.75"`
    * `"cross_region_impact=true"`
    * `"cost_exceeds_usd:1000"`

  It evaluates parsed conditions against a subject map (for example, runtime
  context before execution or step output after execution) and returns one of:

    * `{:ok, :pass}` when no condition is triggered
    * `{:escalate, reason}` when an escalation condition is triggered
    * `{:block, reason}` when a hard constraint condition is triggered
  """

  @type evaluation_result :: {:ok, :pass} | {:escalate, String.t()} | {:block, String.t()}

  @type parsed_condition :: %{
          required(:raw) => String.t(),
          required(:field) => String.t(),
          required(:operator) => :lt | :gt | :eq,
          required(:expected) => term(),
          required(:source_key) => String.t()
        }

  @doc """
  Parses a single governance condition string into a normalized condition map.
  """
  @spec parse_condition(String.t()) :: {:ok, parsed_condition()} | {:error, String.t()}
  def parse_condition(condition) when is_binary(condition) do
    trimmed = String.trim(condition)

    cond do
      trimmed == "" ->
        {:error, "condition cannot be empty"}

      String.contains?(trimmed, "=") ->
        [left, right] = String.split(trimmed, "=", parts: 2)

        source_key = normalize_key(left)
        expected = parse_scalar(right)
        field = field_for_key(source_key)

        {:ok,
         %{
           raw: trimmed,
           source_key: source_key,
           field: field,
           operator: :eq,
           expected: expected
         }}

      String.contains?(trimmed, ":") ->
        [left, right] = String.split(trimmed, ":", parts: 2)

        source_key = normalize_key(left)
        expected = parse_scalar(right)
        {field, operator} = infer_field_and_operator(source_key)

        {:ok,
         %{
           raw: trimmed,
           source_key: source_key,
           field: field,
           operator: operator,
           expected: expected
         }}

      true ->
        {:error, "condition is non-machine-readable"}
    end
  end

  def parse_condition(_condition) do
    {:error, "condition must be a string"}
  end

  @doc """
  Evaluates hard constraints against a subject map.

  The first triggered condition returns `{:block, reason}`.
  """
  @spec evaluate_hard([String.t()] | map() | String.t() | nil, map()) :: evaluation_result()
  def evaluate_hard(constraints, subject) when is_map(subject) do
    evaluate(constraints, subject, mode: :block)
  end

  def evaluate_hard(_constraints, _subject) do
    {:block, "subject must be a map"}
  end

  @doc """
  Evaluates escalation conditions against a subject map.

  The first triggered condition returns `{:escalate, reason}`.
  """
  @spec evaluate_escalate_when([String.t()] | map() | String.t() | nil, map()) :: evaluation_result()
  def evaluate_escalate_when(constraints, subject) when is_map(subject) do
    evaluate(constraints, subject, mode: :escalate)
  end

  def evaluate_escalate_when(_constraints, _subject) do
    {:escalate, "subject must be a map"}
  end

  @doc """
  Evaluates one or more conditions against a subject map.

  Supported options:

    * `:mode` - `:escalate` (default) or `:block`
  """
  @spec evaluate([String.t()] | map() | String.t() | nil, map(), keyword()) :: evaluation_result()
  def evaluate(constraints, subject, opts \\ [])

  def evaluate(constraints, subject, opts) when is_map(subject) and is_list(opts) do
    mode = Keyword.get(opts, :mode, :escalate)

    constraints
    |> normalize_conditions()
    |> Enum.reduce_while({:ok, :pass}, fn condition, _acc ->
      case parse_condition(condition) do
        {:ok, parsed} ->
          case condition_triggered?(parsed, subject) do
            {:ok, true} ->
              {:halt, result_for_mode(mode, trigger_reason(parsed, subject))}

            {:ok, false} ->
              {:cont, {:ok, :pass}}

            {:error, _reason} ->
              {:cont, {:ok, :pass}}
          end

        {:error, _reason} ->
          {:cont, {:ok, :pass}}
      end
    end)
  end

  def evaluate(_constraints, _subject, _opts) do
    {:escalate, "subject must be a map and opts must be a keyword list"}
  end

  defp normalize_conditions(nil), do: []

  defp normalize_conditions(condition) when is_binary(condition) do
    [condition]
  end

  defp normalize_conditions(conditions) when is_list(conditions) do
    conditions
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_conditions(%{} = conditions) do
    conditions
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> "#{to_string(key)}:#{value_to_string(value)}" end)
  end

  defp normalize_conditions(_other), do: []

  defp condition_triggered?(parsed, subject) do
    case fetch_value(subject, parsed.field) do
      {:ok, actual} ->
        compare(parsed.operator, actual, parsed.expected)

      :error ->
        {:ok, false}
    end
  end

  defp compare(:eq, actual, expected) do
    {:ok, normalize_value(actual) == normalize_value(expected)}
  end

  defp compare(:lt, actual, expected) do
    with {:ok, actual_number} <- to_number(actual),
         {:ok, expected_number} <- to_number(expected) do
      {:ok, actual_number < expected_number}
    end
  end

  defp compare(:gt, actual, expected) do
    with {:ok, actual_number} <- to_number(actual),
         {:ok, expected_number} <- to_number(expected) do
      {:ok, actual_number > expected_number}
    end
  end

  defp normalize_key(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp infer_field_and_operator(key) do
    cond do
      String.ends_with?(key, "_below") ->
        {String.replace_suffix(key, "_below", ""), :lt}

      String.ends_with?(key, "_above") ->
        {String.replace_suffix(key, "_above", ""), :gt}

      String.contains?(key, "_exceeds_") ->
        [left, right] = String.split(key, "_exceeds_", parts: 2)
        {left <> "_" <> right, :gt}

      String.ends_with?(key, "_exceeds") ->
        {String.replace_suffix(key, "_exceeds", ""), :gt}

      true ->
        {field_for_key(key), :eq}
    end
  end

  defp field_for_key(key) do
    key
    |> String.replace("__", ".")
    |> String.trim()
  end

  defp value_to_string(value) when is_binary(value), do: value
  defp value_to_string(value), do: to_string(value)

  defp parse_scalar(value) when is_binary(value) do
    normalized = String.trim(value)

    cond do
      normalized == "true" -> true
      normalized == "false" -> false
      Regex.match?(~r/^-?\d+$/, normalized) -> String.to_integer(normalized)
      Regex.match?(~r/^-?\d+\.\d+$/, normalized) -> String.to_float(normalized)
      true -> strip_wrapping_quotes(normalized)
    end
  end

  defp parse_scalar(value), do: value

  defp strip_wrapping_quotes(value) do
    if String.length(value) >= 2 and
         ((String.starts_with?(value, "\"") and String.ends_with?(value, "\"")) or
            (String.starts_with?(value, "'") and String.ends_with?(value, "'"))) do
      String.slice(value, 1, String.length(value) - 2)
    else
      value
    end
  end

  defp normalize_value(value) when is_binary(value) do
    parse_scalar(value)
  end

  defp normalize_value(value), do: value

  defp to_number(value) when is_number(value), do: {:ok, value}

  defp to_number(value) when is_binary(value) do
    parsed = parse_scalar(value)

    if is_number(parsed) do
      {:ok, parsed}
    else
      {:error, "numeric comparison requires numbers; got #{inspect(value)}"}
    end
  end

  defp to_number(value) do
    {:error, "numeric comparison requires numbers; got #{inspect(value)}"}
  end

  defp fetch_value(subject, field) when is_map(subject) and is_binary(field) do
    path =
      field
      |> String.split(".", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    fetch_path(subject, path)
  end

  defp fetch_value(_subject, _field), do: :error

  defp fetch_path(value, []), do: {:ok, value}

  defp fetch_path(%{} = value, [segment | rest]) do
    cond do
      Map.has_key?(value, segment) ->
        fetch_path(Map.get(value, segment), rest)

      atom_key_exists?(value, segment) ->
        fetch_path(Map.get(value, String.to_atom(segment)), rest)

      true ->
        :error
    end
  end

  defp fetch_path(_value, _path), do: :error

  defp atom_key_exists?(map, key) do
    atom_key = String.to_atom(key)
    Map.has_key?(map, atom_key)
  rescue
    ArgumentError -> false
  end

  defp result_for_mode(:block, reason), do: {:block, reason}
  defp result_for_mode(:escalate, reason), do: {:escalate, reason}
  defp result_for_mode(_mode, reason), do: {:escalate, reason}

  defp trigger_reason(parsed, subject) do
    {:ok, actual} = fetch_value(subject, parsed.field)

    "condition #{inspect(parsed.raw)} triggered with #{inspect(parsed.field)}=#{inspect(actual)}"
  end
end
