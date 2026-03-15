defmodule AmpersandCore.A2A do
  @moduledoc """
  Minimal A2A agent card generator for canonical `ampersand.json` documents.

  This module is intentionally conservative. It does not attempt to implement the
  full Google A2A ecosystem or invent provider-specific runtime details. Instead,
  it transforms a validated protocol declaration into a stable, JSON-serializable
  agent card that:

    * identifies the composed agent
    * advertises composed capabilities as skills
    * preserves governance and provenance metadata
    * allows optional enrichment from capability contract metadata

  The generated card is suitable for writing to `/.well-known/agent.json` or for
  further adaptation by a downstream runtime.

  Supported options:

    * `:base_url` - base URL for the published agent (for example,
      `"https://agents.example.com/support-ops"`)
    * `:description` - human-friendly agent description
    * `:default_input_modes` - list of advertised input modes
    * `:default_output_modes` - list of advertised output modes
    * `:contract_registry` - optional map of capability contracts keyed by
      capability identifier; when present, `a2a_skills` entries are used to enrich
      the generated skill list
    * `:include_metadata` - when false, omits the `"metadata"` section
    * `:skill_overrides` - map keyed by capability identifier whose values are
      merged into generated skills
  """

  alias AmpersandCore.Schema

  @type document :: map()
  @type result :: {:ok, map()} | {:error, [String.t()]}

  @default_input_modes ["application/json", "text/plain"]
  @default_output_modes ["application/json", "text/plain"]

  @doc """
  Generates an A2A-style agent card from a validated ampersand declaration.
  """
  @spec generate(document(), keyword()) :: result()
  def generate(document, opts \\ [])

  def generate(document, opts) when is_map(document) and is_list(opts) do
    with {:ok, validated} <- Schema.validate(document) do
      {:ok, build_card(validated, opts)}
    end
  end

  def generate(_document, _opts) do
    {:error, ["document must be a validated ampersand.json object"]}
  end

  @doc """
  Reads an ampersand declaration from disk and generates an A2A-style agent card.
  """
  @spec generate_file(Path.t(), keyword()) :: result()
  def generate_file(path, opts \\ []) when is_binary(path) and is_list(opts) do
    with {:ok, document} <- Schema.validate_file(path) do
      {:ok, build_card(document, opts)}
    end
  end

  @doc """
  Encodes the generated A2A-style agent card as pretty JSON.
  """
  @spec to_json(document(), keyword()) :: {:ok, String.t()} | {:error, [String.t()]}
  def to_json(document, opts \\ []) do
    case generate(document, opts) do
      {:ok, card} ->
        case Jason.encode(card, pretty: true) do
          {:ok, json} -> {:ok, json}
          {:error, reason} -> {:error, ["unable to encode A2A agent card: #{inspect(reason)}"]}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp build_card(document, opts) do
    capabilities = Map.get(document, "capabilities", %{})
    contract_registry = Keyword.get(opts, :contract_registry, %{})
    include_metadata? = Keyword.get(opts, :include_metadata, true)

    skills =
      capabilities
      |> Enum.map(fn {capability, binding} ->
        build_skill(capability, binding, contract_registry, opts)
      end)
      |> Enum.sort_by(&{Map.get(&1, "name", ""), Map.get(&1, "id", "")})

    card =
      %{}
      |> put_if_present("name", document["agent"])
      |> put_if_present("description", card_description(document, opts))
      |> put_if_present("version", document["version"])
      |> put_if_present("url", Keyword.get(opts, :base_url))
      |> put_if_present("protocol", "A2A")
      |> put_if_present("skills", skills)
      |> put_if_present("provider_bindings", build_provider_bindings(capabilities))

    if include_metadata? do
      Map.put(card, "metadata", build_metadata(document, capabilities, contract_registry))
    else
      card
    end
  end

  defp build_skill(capability, binding, contract_registry, opts) do
    provider = Map.get(binding, "provider")
    contract = Map.get(contract_registry, capability, %{})
    generated_skill_ids = contract_a2a_skills(contract)
    primary_skill_id = primary_skill_id(capability, generated_skill_ids)

    base_skill =
      %{
        "id" => primary_skill_id,
        "name" => humanize_capability(capability),
        "description" => skill_description(capability, provider, binding),
        "tags" => skill_tags(capability, provider),
        "input_modes" => normalize_modes(Keyword.get(opts, :default_input_modes, @default_input_modes)),
        "output_modes" =>
          normalize_modes(Keyword.get(opts, :default_output_modes, @default_output_modes)),
        "capability" => capability,
        "provider" => provider
      }
      |> put_if_present("examples", skill_examples(capability, generated_skill_ids))
      |> put_if_present("operations", contract_operations(contract))
      |> put_if_present("accepts_from", contract_field(contract, "accepts_from"))
      |> put_if_present("feeds_into", contract_field(contract, "feeds_into"))

    overrides =
      opts
      |> Keyword.get(:skill_overrides, %{})
      |> Map.get(capability, %{})

    Map.merge(base_skill, stringify_map_keys(overrides))
  end

  defp build_metadata(document, capabilities, contract_registry) do
    capability_ids =
      capabilities
      |> Map.keys()
      |> Enum.sort()

    providers =
      capabilities
      |> Enum.map(fn {_capability, binding} -> Map.get(binding, "provider") end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    %{}
    |> put_if_present("capabilities", capability_ids)
    |> put_if_present("providers", providers)
    |> put_if_present("governance", document["governance"])
    |> put_if_present("provenance", document["provenance"])
    |> put_if_present(
      "a2a_skill_map",
      build_a2a_skill_map(capabilities, contract_registry)
    )
  end

  defp build_a2a_skill_map(capabilities, contract_registry) do
    capabilities
    |> Enum.map(fn {capability, _binding} ->
      contract = Map.get(contract_registry, capability, %{})

      {capability,
       case contract_a2a_skills(contract) do
         [] -> [default_skill_id(capability)]
         skills -> skills
       end}
    end)
    |> Enum.into(%{})
  end

  defp build_provider_bindings(capabilities) do
    capabilities
    |> Enum.map(fn {capability, binding} ->
      {capability, Map.get(binding, "provider")}
    end)
    |> Enum.into(%{})
  end

  defp card_description(document, opts) do
    case Keyword.get(opts, :description) do
      value when is_binary(value) and value != "" ->
        value

      _ ->
        capability_list =
          document
          |> Map.get("capabilities", %{})
          |> Map.keys()
          |> Enum.sort()
          |> Enum.join(", ")

        if capability_list == "" do
          "Agent generated from ampersand protocol declaration."
        else
          "Agent generated from ampersand protocol declaration with capabilities: #{capability_list}."
        end
    end
  end

  defp skill_description(capability, provider, binding) do
    need =
      case Map.get(binding, "need") do
        value when is_binary(value) and value != "" -> value
        _ -> nil
      end

    cond do
      is_binary(need) and is_binary(provider) ->
        "#{humanize_capability(capability)} provided by #{provider}; requested need: #{need}."

      is_binary(need) ->
        "#{humanize_capability(capability)} requested need: #{need}."

      is_binary(provider) ->
        "#{humanize_capability(capability)} provided by #{provider}."

      true ->
        humanize_capability(capability)
    end
  end

  defp skill_tags(capability, provider) do
    primitive =
      capability
      |> String.trim_leading("&")
      |> String.split(".")
      |> List.first()

    tags =
      ["ampersand", "a2a", primitive, capability, provider]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()

    tags
  end

  defp skill_examples(_capability, []), do: nil

  defp skill_examples(capability, skill_ids) do
    skill_ids
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn skill_id ->
      %{
        "skill" => skill_id,
        "summary" => "Invoke #{humanize_capability(capability)} via #{skill_id}."
      }
    end)
  end

  defp contract_operations(contract) do
    contract
    |> contract_field("operations")
    |> case do
      value when is_map(value) -> Map.keys(value) |> Enum.sort()
      _ -> nil
    end
  end

  defp contract_a2a_skills(contract) do
    contract
    |> contract_field("a2a_skills")
    |> case do
      values when is_list(values) ->
        values
        |> Enum.filter(&(is_binary(&1) and &1 != ""))
        |> Enum.uniq()
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp contract_field(contract, key) when is_map(contract) and is_binary(key) do
    cond do
      Map.has_key?(contract, key) ->
        Map.get(contract, key)

      Map.has_key?(contract, String.to_atom(key)) ->
        Map.get(contract, String.to_atom(key))

      true ->
        nil
    end
  end

  defp primary_skill_id(capability, []), do: default_skill_id(capability)
  defp primary_skill_id(_capability, [first | _]), do: first

  defp default_skill_id(capability) do
    capability
    |> String.trim_leading("&")
    |> String.replace(".", "-")
    |> String.replace("_", "-")
  end

  defp humanize_capability(capability) do
    capability
    |> String.trim_leading("&")
    |> String.split(".")
    |> Enum.map(&humanize_fragment/1)
    |> Enum.join(" ")
  end

  defp humanize_fragment(fragment) do
    fragment
    |> String.replace("-", " ")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &capitalize_word/1)
  end

  defp capitalize_word(""), do: ""
  defp capitalize_word(word), do: String.upcase(String.slice(word, 0, 1)) <> String.slice(word, 1..-1//1)

  defp normalize_modes(modes) when is_list(modes) do
    modes
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_modes(_other), do: @default_input_modes

  defp stringify_map_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, []), do: map
  defp put_if_present(map, _key, %{} = value) when map_size(value) == 0, do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
