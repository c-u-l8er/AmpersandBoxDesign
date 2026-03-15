defmodule AmpersandCore do
  @moduledoc """
  Focused public API for the minimal [&] protocol reference implementation.

  The implementation is intentionally split into three concerns:

  * `AmpersandCore.Schema` — validate canonical `ampersand.json` documents
  * `AmpersandCore.Compose` — normalize and compose capability sets with ACI semantics
  * `AmpersandCore.Contracts` — validate capability pipelines against typed contracts
  * `AmpersandCore.MCP` — generate MCP server configuration from protocol declarations
  * `AmpersandCore.A2A` — generate A2A agent cards from protocol declarations

  This facade keeps the public surface area small while the underlying modules
  stay independently testable.
  """

  alias AmpersandCore.Compose
  alias AmpersandCore.Contracts
  alias AmpersandCore.Schema

  @type capability_id :: String.t()
  @type capability_binding :: map()
  @type capability_map :: %{optional(capability_id()) => capability_binding()}
  @type document :: map()

  @type pipeline_step ::
          %{required(:capability) => capability_id(), required(:operation) => String.t()}
          | {capability_id(), String.t()}

  @type contract_registry :: %{optional(capability_id()) => map()}

  @type validation_result :: {:ok, document()} | {:error, [String.t()]}
  @type compose_result :: {:ok, capability_map()} | {:error, term()}
  @type contract_result :: :ok | {:error, [String.t()]}
  @type mcp_result :: {:ok, map()} | {:error, [String.t()]}
  @type a2a_result :: {:ok, map()} | {:error, [String.t()]}

  @doc """
  Returns the default path to the canonical `ampersand.schema.json`.
  """
  @spec default_schema_path() :: Path.t()
  defdelegate default_schema_path(), to: Schema

  @doc """
  Validates a decoded `ampersand.json` document against the canonical schema.
  """
  @spec validate_document(document()) :: validation_result()
  defdelegate validate_document(document), to: Schema, as: :validate

  @doc """
  Reads and validates an `ampersand.json` file against the canonical schema.
  """
  @spec validate_file(Path.t()) :: validation_result()
  defdelegate validate_file(path), to: Schema

  @doc """
  Reads and validates an `ampersand.json` file against the provided schema path.
  """
  @spec validate_file(Path.t(), Path.t()) :: validation_result()
  defdelegate validate_file(path, schema_path), to: Schema

  @doc """
  Returns a sorted, normalized capability list from either a full document or a
  raw capability map.
  """
  @spec normalize_capabilities(document() | capability_map()) :: [capability_id()]
  defdelegate normalize_capabilities(input), to: Compose, as: :normalize

  @doc """
  Composes one or more capability maps or full agent documents into a single
  normalized capability set.

  Conflicting bindings for the same capability should return an error.
  """
  @spec compose([document() | capability_map()]) :: compose_result()
  defdelegate compose(inputs), to: Compose

  @doc """
  Checks whether two declarations are equivalent under ACI normalization.
  """
  @spec aci_equivalent?(document() | capability_map(), document() | capability_map()) :: boolean()
  defdelegate aci_equivalent?(left, right), to: Compose

  @doc """
  Verifies the commutative property for two capability declarations.
  """
  @spec commutative?(document() | capability_map(), document() | capability_map()) :: boolean()
  defdelegate commutative?(left, right), to: Compose

  @doc """
  Verifies the associative property for three capability declarations.
  """
  @spec associative?(
          document() | capability_map(),
          document() | capability_map(),
          document() | capability_map()
        ) :: boolean()
  defdelegate associative?(left, middle, right), to: Compose

  @doc """
  Verifies the idempotent property for a capability declaration.
  """
  @spec idempotent?(document() | capability_map()) :: boolean()
  defdelegate idempotent?(input), to: Compose

  @doc """
  Verifies the identity property for a capability declaration.
  """
  @spec identity?(document() | capability_map()) :: boolean()
  defdelegate identity?(input), to: Compose

  @doc """
  Validates a pipeline against a registry of capability contracts.
  """
  @spec check_pipeline(contract_registry(), [pipeline_step()]) :: contract_result()
  defdelegate check_pipeline(contracts, pipeline), to: Contracts

  @doc """
  Validates a pipeline against a registry of capability contracts with options.

  Supported options are implementation-defined by `AmpersandCore.Contracts`,
  but typically include source metadata such as `:source_type` and `:source_ref`.
  """
  @spec check_pipeline(contract_registry(), [pipeline_step()], keyword()) :: contract_result()
  defdelegate check_pipeline(contracts, pipeline, opts), to: Contracts

  @doc """
  Generates MCP server configuration from a validated protocol document.

  If the dedicated MCP generator module is not yet available, this function
  returns an informative error instead of raising.
  """
  @spec generate_mcp_config(document(), keyword()) :: mcp_result()
  def generate_mcp_config(document, opts \\ []) when is_map(document) and is_list(opts) do
    cond do
      Code.ensure_loaded?(AmpersandCore.MCP) and function_exported?(AmpersandCore.MCP, :generate, 2) ->
        AmpersandCore.MCP.generate(document, opts)

      true ->
        {:error, ["MCP config generator is not available"]}
    end
  end

  @doc """
  Reads an `ampersand.json` file, validates it, and generates MCP server
  configuration from the resulting declaration.

  If the dedicated MCP generator module is not yet available, this function
  returns an informative error instead of raising.
  """
  @spec generate_mcp_config_file(Path.t(), keyword()) :: mcp_result()
  def generate_mcp_config_file(path, opts \\ []) when is_binary(path) and is_list(opts) do
    with {:ok, document} <- validate_file(path) do
      generate_mcp_config(document, opts)
    end
  end

  @doc """
  Generates an A2A agent card from a validated protocol document.

  If the dedicated A2A generator module is not yet available, this function
  returns an informative error instead of raising.
  """
  @spec generate_a2a_card(document(), keyword()) :: a2a_result()
  def generate_a2a_card(document, opts \\ []) when is_map(document) and is_list(opts) do
    cond do
      Code.ensure_loaded?(AmpersandCore.A2A) and function_exported?(AmpersandCore.A2A, :generate, 2) ->
        AmpersandCore.A2A.generate(document, opts)

      true ->
        {:error, ["A2A agent card generator is not available"]}
    end
  end

  @doc """
  Reads an `ampersand.json` file, validates it, and generates an A2A agent card
  from the resulting declaration.

  If the dedicated A2A generator module is not yet available, this function
  returns an informative error instead of raising.
  """
  @spec generate_a2a_card_file(Path.t(), keyword()) :: a2a_result()
  def generate_a2a_card_file(path, opts \\ []) when is_binary(path) and is_list(opts) do
    with {:ok, document} <- validate_file(path) do
      generate_a2a_card(document, opts)
    end
  end
end
