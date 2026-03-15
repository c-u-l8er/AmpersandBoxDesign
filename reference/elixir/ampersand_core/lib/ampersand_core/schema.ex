defmodule AmpersandCore.Schema do
  @moduledoc """
  AJV-backed validation for canonical `ampersand.json` documents.

  This module treats `AmperSandboxDesign/schema/v0.1.0/ampersand.schema.json`
  as the source of truth and delegates validation to `ajv-cli` with
  JSON Schema draft 2020-12 support.

  Public API:

    * `default_schema_path/0`
    * `load_schema/0`
    * `load_schema/1`
    * `validate/1`
    * `validate/2`
    * `validate_file/1`
    * `validate_file/2`
  """

  @type document :: map()
  @type validation_result :: {:ok, document()} | {:error, [String.t()]}

  @default_schema_path Path.expand(
                         "../../../../../schema/v0.1.0/ampersand.schema.json",
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
  Returns the absolute path to the canonical schema.
  """
  @spec default_schema_path() :: Path.t()
  def default_schema_path, do: @default_schema_path

  @doc """
  Checks that the canonical schema exists and is valid JSON.
  """
  @spec load_schema() :: {:ok, Path.t()} | {:error, [String.t()]}
  def load_schema, do: load_schema(@default_schema_path)

  @doc """
  Checks that the schema at `schema_path` exists and is valid JSON.
  """
  @spec load_schema(Path.t()) :: {:ok, Path.t()} | {:error, [String.t()]}
  def load_schema(schema_path) when is_binary(schema_path) do
    with {:ok, contents} <- read_file(schema_path, "schema"),
         {:ok, _decoded} <- decode_json(contents, schema_path, "schema") do
      {:ok, schema_path}
    end
  end

  @doc """
  Validates a decoded document against the canonical schema.
  """
  @spec validate(document()) :: validation_result()
  def validate(document) when is_map(document) do
    validate(document, @default_schema_path)
  end

  def validate(_document), do: {:error, ["document must be a map"]}

  @doc """
  Validates a decoded document against the schema at `schema_path`.
  """
  @spec validate(document(), Path.t()) :: validation_result()
  def validate(document, schema_path) when is_map(document) and is_binary(schema_path) do
    with {:ok, _schema_path} <- load_schema(schema_path),
         {:ok, encoded} <- encode_document(document),
         result <- with_temp_json(encoded, fn temp_path -> run_ajv(schema_path, temp_path) end) do
      case result do
        :ok -> {:ok, document}
        {:error, errors} -> {:error, errors}
      end
    end
  end

  @doc """
  Reads and validates a JSON file against the canonical schema.
  """
  @spec validate_file(Path.t()) :: validation_result()
  def validate_file(path) when is_binary(path) do
    validate_file(path, @default_schema_path)
  end

  @doc """
  Reads and validates a JSON file against the schema at `schema_path`.
  """
  @spec validate_file(Path.t(), Path.t()) :: validation_result()
  def validate_file(path, schema_path) when is_binary(path) and is_binary(schema_path) do
    with {:ok, _schema_path} <- load_schema(schema_path),
         {:ok, contents} <- read_file(path, "agent document"),
         {:ok, document} <- decode_json(contents, path, "agent document"),
         :ok <- run_ajv(schema_path, path) do
      {:ok, document}
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

  defp encode_document(document) do
    case Jason.encode(document) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, reason} -> {:error, ["unable to encode document for validation: #{inspect(reason)}"]}
    end
  end

  defp with_temp_json(encoded_json, fun) when is_binary(encoded_json) and is_function(fun, 1) do
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "ampersand-ajv-#{System.unique_integer([:positive, :monotonic])}.json")

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
    |> Enum.map(&classify_error/1)
    |> case do
      [] -> ["schema validation failed with no diagnostic output from AJV"]
      lines -> lines
    end
  end

  defp classify_error(line) do
    cond do
      String.contains?(line, "/capabilities") or
          String.contains?(line, "capabilities") or
          String.contains?(line, "property name") ->
        "capability validation error: #{line}"

      String.contains?(line, "'need'") or String.contains?(line, " need ") ->
        "schema validation error: #{line}"

      true ->
        "schema validation error: #{line}"
    end
  end
end
