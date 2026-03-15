defmodule AmpersandCore.Artifact do
  @moduledoc """
  Generic JSON artifact loading and AJV-backed validation helpers.

  This module is intended to sit underneath higher-level protocol modules such as:

    * declaration/schema validation
    * capability contract loaders
    * registry loaders

  It provides a small set of reusable behaviors:

    * read and decode JSON object files
    * load all JSON object files from a directory
    * validate decoded documents against an arbitrary JSON Schema
    * validate on-disk JSON files against an arbitrary JSON Schema
    * validate all JSON files in a directory against an arbitrary JSON Schema

  The implementation is intentionally generic so protocol-specific modules can
  supply their own schema paths, labels, and post-processing logic without
  duplicating AJV invocation and JSON decoding behavior.
  """

  @type document :: map()
  @type path_document :: {Path.t(), document()}
  @type result :: {:ok, document()} | {:error, [String.t()]}
  @type directory_result :: {:ok, [path_document()]} | {:error, [String.t()]}

  @default_glob "*.json"

  @ajv_base_args [
    "--yes",
    "ajv-cli",
    "validate",
    "--spec=draft2020",
    "--all-errors",
    "--errors=text"
  ]

  @project_root Path.expand("../../../../../", __DIR__)

  @doc """
  Returns the absolute path to the protocol repository root.
  """
  @spec project_root() :: Path.t()
  def project_root, do: @project_root

  @doc """
  Loads a JSON object artifact from disk.

  Supported options:

    * `:label` - human-readable label used in error messages
  """
  @spec load_json_file(Path.t(), keyword()) :: result()
  def load_json_file(path, opts \\ []) when is_binary(path) and is_list(opts) do
    label = Keyword.get(opts, :label, "JSON artifact")

    with {:ok, contents} <- read_file(path, label),
         {:ok, decoded} <- decode_json(contents, path, label) do
      {:ok, decoded}
    end
  end

  @doc """
  Loads all JSON object artifacts from a directory.

  Supported options:

    * `:label` - human-readable label used in error messages
    * `:glob` - file glob relative to the directory (defaults to `"*.json"`)

  The returned entries are sorted by file path.
  """
  @spec load_json_directory(Path.t(), keyword()) :: directory_result()
  def load_json_directory(directory, opts \\ []) when is_binary(directory) and is_list(opts) do
    label = Keyword.get(opts, :label, "JSON artifact")
    glob = Keyword.get(opts, :glob, @default_glob)

    with {:ok, paths} <- json_paths(directory, glob, label) do
      paths
      |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
        case load_json_file(path, label: label) do
          {:ok, document} -> {:cont, {:ok, acc ++ [{path, document}]}}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  @doc """
  Validates a decoded JSON object against the schema at `schema_path`.

  Supported options:

    * `:label` - human-readable label used in error messages
    * `:strict` - whether AJV strict mode should be enabled (defaults to `false`)
  """
  @spec validate_document(document(), Path.t(), keyword()) :: result()
  def validate_document(document, schema_path, opts \\ [])

  def validate_document(document, schema_path, opts)
      when is_map(document) and is_binary(schema_path) and is_list(opts) do
    label = Keyword.get(opts, :label, "JSON artifact")

    with {:ok, _schema_path} <- load_json_file(schema_path, label: "schema"),
         {:ok, encoded} <- encode_document(document, label),
         result <- with_temp_json(encoded, fn temp_path -> run_ajv(schema_path, temp_path, opts) end) do
      case result do
        :ok -> {:ok, document}
        {:error, errors} -> {:error, errors}
      end
    end
  end

  def validate_document(_document, _schema_path, _opts) do
    {:error, ["document must be a map"]}
  end

  @doc """
  Validates a JSON object file against the schema at `schema_path`.

  Supported options:

    * `:label` - human-readable label used in error messages
    * `:strict` - whether AJV strict mode should be enabled (defaults to `false`)
  """
  @spec validate_file(Path.t(), Path.t(), keyword()) :: result()
  def validate_file(path, schema_path, opts \\ [])

  def validate_file(path, schema_path, opts)
      when is_binary(path) and is_binary(schema_path) and is_list(opts) do
    label = Keyword.get(opts, :label, "JSON artifact")

    with {:ok, _schema_path} <- load_json_file(schema_path, label: "schema"),
         {:ok, contents} <- read_file(path, label),
         {:ok, document} <- decode_json(contents, path, label),
         :ok <- run_ajv(schema_path, path, opts) do
      {:ok, document}
    end
  end

  @doc """
  Validates all matching JSON files in a directory against the schema at `schema_path`.

  Supported options:

    * `:label` - human-readable label used in error messages
    * `:glob` - file glob relative to the directory (defaults to `"*.json"`)
    * `:strict` - whether AJV strict mode should be enabled (defaults to `false`)
  """
  @spec validate_directory(Path.t(), Path.t(), keyword()) :: directory_result()
  def validate_directory(directory, schema_path, opts \\ [])
      when is_binary(directory) and is_binary(schema_path) and is_list(opts) do
    label = Keyword.get(opts, :label, "JSON artifact")
    glob = Keyword.get(opts, :glob, @default_glob)

    with {:ok, _schema_path} <- load_json_file(schema_path, label: "schema"),
         {:ok, paths} <- json_paths(directory, glob, label) do
      paths
      |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
        case validate_file(path, schema_path, label: label, strict: Keyword.get(opts, :strict, false)) do
          {:ok, document} -> {:cont, {:ok, acc ++ [{path, document}]}}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  @doc """
  Returns all matching JSON file paths in a directory.

  Supported options:

    * `:glob` - file glob relative to the directory (defaults to `"*.json"`)
    * `:label` - human-readable label used in error messages
  """
  @spec list_json_files(Path.t(), keyword()) :: {:ok, [Path.t()]} | {:error, [String.t()]}
  def list_json_files(directory, opts \\ []) when is_binary(directory) and is_list(opts) do
    glob = Keyword.get(opts, :glob, @default_glob)
    label = Keyword.get(opts, :label, "JSON artifact")
    json_paths(directory, glob, label)
  end

  defp json_paths(directory, glob, label) do
    cond do
      not File.exists?(directory) ->
        {:error, ["#{label} directory not found: #{directory}"]}

      not File.dir?(directory) ->
        {:error, ["expected #{label} directory, got file: #{directory}"]}

      true ->
        paths =
          directory
          |> Path.join(glob)
          |> Path.wildcard()
          |> Enum.sort()

        if paths == [] do
          {:error, ["no #{label} files found in #{directory} matching #{glob}"]}
        else
          {:ok, paths}
        end
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

  defp encode_document(document, label) do
    case Jason.encode(document) do
      {:ok, encoded} ->
        {:ok, encoded}

      {:error, reason} ->
        {:error, ["unable to encode #{label} for validation: #{inspect(reason)}"]}
    end
  end

  defp with_temp_json(encoded_json, fun) when is_binary(encoded_json) and is_function(fun, 1) do
    tmp_dir = System.tmp_dir!()
    filename = "ampersand-artifact-#{System.unique_integer([:positive, :monotonic])}.json"
    path = Path.join(tmp_dir, filename)

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

  defp run_ajv(schema_path, data_path, opts) do
    args = @ajv_base_args ++ strict_args(opts) ++ ["-s", schema_path, "-d", data_path]

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

  defp strict_args(opts) do
    case Keyword.get(opts, :strict, false) do
      true -> []
      _ -> ["--strict=false"]
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
    |> Enum.reject(&String.starts_with?(&1, "unknown format "))
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

      String.contains?(line, "/operations") or
          String.contains?(line, "operations") or
          String.contains?(line, "accepts_from") or
          String.contains?(line, "feeds_into") ->
        "contract validation error: #{line}"

      String.contains?(line, "/providers") or
          String.contains?(line, "/subtypes") or
          String.contains?(line, "registry") ->
        "registry validation error: #{line}"

      true ->
        "schema validation error: #{line}"
    end
  end
end
