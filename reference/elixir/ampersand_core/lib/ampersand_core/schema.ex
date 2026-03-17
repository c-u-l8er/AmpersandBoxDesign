defmodule AmpersandCore.Schema do
  @moduledoc """
  Canonical JSON Schema validation for `ampersand.json` agent declarations.

  This module treats `AmpersandBoxDesign/protocol/schema/v0.1.0/ampersand.schema.json`
  as the source of truth and delegates low-level JSON loading and AJV-backed
  validation to `AmpersandCore.Artifact`.
  """

  alias AmpersandCore.Artifact

  @type document :: map()
  @type validation_result :: {:ok, document()} | {:error, [String.t()]}

  @project_root Path.expand("../../../../../", __DIR__)
  @default_schema_path Path.join(@project_root, "protocol/schema/v0.1.0/ampersand.schema.json")

  @doc """
  Returns the absolute path to the protocol repository root.
  """
  @spec project_root() :: Path.t()
  def project_root, do: @project_root

  @doc """
  Returns the absolute path to the canonical `ampersand.schema.json`.
  """
  @spec default_schema_path() :: Path.t()
  def default_schema_path, do: @default_schema_path

  @doc """
  Checks that the canonical agent declaration schema exists and is valid JSON.
  """
  @spec load_schema() :: {:ok, Path.t()} | {:error, [String.t()]}
  def load_schema, do: load_schema(@default_schema_path)

  @doc """
  Checks that the schema at `schema_path` exists and is valid JSON.
  """
  @spec load_schema(Path.t()) :: {:ok, Path.t()} | {:error, [String.t()]}
  def load_schema(schema_path) when is_binary(schema_path) do
    with {:ok, _decoded} <- Artifact.load_json_file(schema_path, label: "schema") do
      {:ok, schema_path}
    end
  end

  def load_schema(_schema_path) do
    {:error, ["schema_path must be a string"]}
  end

  @doc """
  Validates a decoded `ampersand.json` document against the canonical schema.
  """
  @spec validate(document()) :: validation_result()
  def validate(document) when is_map(document) do
    validate(document, @default_schema_path)
  end

  def validate(_document) do
    {:error, ["document must be a map"]}
  end

  @doc """
  Validates a decoded `ampersand.json` document against the schema at `schema_path`.
  """
  @spec validate(document(), Path.t()) :: validation_result()
  def validate(document, schema_path) when is_map(document) and is_binary(schema_path) do
    Artifact.validate_document(document, schema_path, label: "agent document")
  end

  def validate(_document, _schema_path) do
    {:error, ["document must be a map and schema_path must be a string"]}
  end

  @doc """
  Reads and validates a JSON file against the canonical schema.
  """
  @spec validate_file(Path.t()) :: validation_result()
  def validate_file(path) when is_binary(path) do
    validate_file(path, @default_schema_path)
  end

  def validate_file(_path) do
    {:error, ["path must be a string"]}
  end

  @doc """
  Reads and validates a JSON file against the schema at `schema_path`.
  """
  @spec validate_file(Path.t(), Path.t()) :: validation_result()
  def validate_file(path, schema_path) when is_binary(path) and is_binary(schema_path) do
    Artifact.validate_file(path, schema_path, label: "agent document")
  end

  def validate_file(_path, _schema_path) do
    {:error, ["path and schema_path must be strings"]}
  end
end
