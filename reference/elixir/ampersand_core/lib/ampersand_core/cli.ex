defmodule AmpersandCore.CLI do
  @moduledoc """
  Minimal `ampersand` CLI entrypoint.

  Supported commands:

    * `ampersand validate <file>`
    * `ampersand compose <file>`
    * `ampersand generate mcp <file>`
    * `ampersand generate a2a <file>`

  The CLI prints JSON to stdout on success and JSON to stderr on failure.
  """

  @type cli_result :: {:ok, String.t()} | {:error, String.t(), pos_integer()}

  @doc """
  Escript entrypoint.
  """
  @spec main([String.t()]) :: no_return()
  def main(argv) when is_list(argv) do
    argv
    |> run()
    |> emit_and_halt()
  end

  @doc """
  Executes a CLI command and returns a printable result.

  This is exposed separately from `main/1` so the command behavior remains easy
  to test without halting the BEAM.
  """
  @spec run([String.t()]) :: cli_result()
  def run(argv) when is_list(argv) do
    case argv do
      [] ->
        ok_result(%{
          "command" => "help",
          "status" => "ok",
          "version" => version_string(),
          "usage" => usage_lines()
        })

      ["help"] ->
        ok_result(%{
          "command" => "help",
          "status" => "ok",
          "version" => version_string(),
          "usage" => usage_lines()
        })

      ["--help"] ->
        ok_result(%{
          "command" => "help",
          "status" => "ok",
          "version" => version_string(),
          "usage" => usage_lines()
        })

      ["-h"] ->
        ok_result(%{
          "command" => "help",
          "status" => "ok",
          "version" => version_string(),
          "usage" => usage_lines()
        })

      ["version"] ->
        ok_result(%{
          "command" => "version",
          "status" => "ok",
          "version" => version_string()
        })

      ["--version"] ->
        ok_result(%{
          "command" => "version",
          "status" => "ok",
          "version" => version_string()
        })

      ["validate", path] ->
        validate_command(path)

      ["compose", path] ->
        compose_command(path)

      ["generate", "mcp", path] ->
        generate_mcp_command(path)

      ["generate", "a2a", path] ->
        generate_a2a_command(path)

      ["generate", target | _rest] ->
        error_result(
          "unknown_generate_target",
          "unsupported generate target #{inspect(target)}",
          1,
          %{"usage" => usage_lines()}
        )

      _ ->
        error_result(
          "invalid_arguments",
          "unrecognized command line arguments",
          1,
          %{"usage" => usage_lines()}
        )
    end
  end

  defp validate_command(path) do
    case AmpersandCore.validate_file(path) do
      {:ok, document} ->
        ok_result(%{
          "command" => "validate",
          "status" => "ok",
          "file" => path,
          "agent" => document["agent"],
          "version" => document["version"],
          "schema" => document["$schema"],
          "capability_count" => document |> Map.get("capabilities", %{}) |> map_size()
        })

      {:error, errors} ->
        error_result("validation_failed", errors, 1, %{
          "command" => "validate",
          "file" => path
        })
    end
  end

  defp compose_command(path) do
    with {:ok, document} <- AmpersandCore.validate_file(path),
         {:ok, composed} <- AmpersandCore.compose([document]) do
      capabilities = AmpersandCore.normalize_capabilities(document)

      ok_result(%{
        "command" => "compose",
        "status" => "ok",
        "file" => path,
        "agent" => document["agent"],
        "version" => document["version"],
        "capabilities" => capabilities,
        "capability_count" => length(capabilities),
        "aci" => aci_report(document),
        "contracts" => contract_report(document),
        "registry" => registry_report(document),
        "composed" => composed
      })
    else
      {:error, errors} when is_list(errors) ->
        error_result("compose_failed", errors, 1, %{
          "command" => "compose",
          "file" => path
        })

      {:error, reason} ->
        error_result("compose_failed", inspect(reason), 1, %{
          "command" => "compose",
          "file" => path
        })
    end
  end

  defp generate_mcp_command(path) do
    case AmpersandCore.MCP.client_config_file(path) do
      {:ok, config} ->
        ok_result(config)

      {:error, errors} ->
        error_result("mcp_generation_failed", errors, 1, %{
          "command" => "generate",
          "target" => "mcp",
          "file" => path
        })
    end
  end

  defp generate_a2a_command(path) do
    case AmpersandCore.generate_a2a_card_file(path) do
      {:ok, card} ->
        ok_result(card)

      {:error, errors} ->
        error_result("a2a_generation_failed", errors, 1, %{
          "command" => "generate",
          "target" => "a2a",
          "file" => path
        })
    end
  end

  defp aci_report(document) do
    capability_sets = singleton_capability_sets(document)

    %{
      "commutative" => commutative_report(capability_sets),
      "associative" => associative_report(capability_sets),
      "idempotent" => AmpersandCore.idempotent?(document),
      "identity" => AmpersandCore.identity?(document)
    }
  end

  defp singleton_capability_sets(document) do
    document
    |> Map.get("capabilities", %{})
    |> Enum.sort_by(fn {capability, _binding} -> capability end)
    |> Enum.map(fn {capability, binding} -> %{capability => binding} end)
  end

  defp commutative_report([left, right | _rest]), do: AmpersandCore.commutative?(left, right)
  defp commutative_report(_), do: true

  defp associative_report([left, middle, right | _rest]),
    do: AmpersandCore.associative?(left, middle, right)

  defp associative_report([left, middle]),
    do: AmpersandCore.associative?(left, middle, %{})

  defp associative_report(_), do: true

  defp contract_report(document) do
    capabilities = declared_capabilities(document)

    case AmpersandCore.load_contracts() do
      {:ok, contracts} ->
        loaded =
          contracts
          |> Enum.filter(fn {capability, _contract} -> capability in capabilities end)
          |> Enum.into(%{})

        %{
          "loaded" => loaded |> Map.keys() |> Enum.sort(),
          "missing" => capabilities |> Enum.reject(&Map.has_key?(loaded, &1)),
          "contract_count" => map_size(loaded)
        }

      {:error, errors} ->
        %{
          "loaded" => [],
          "missing" => capabilities,
          "errors" => errors
        }
    end
  end

  defp registry_report(document) do
    capabilities = declared_capabilities(document)
    providers = declared_providers(document)

    case AmpersandCore.load_registry() do
      {:ok, registry} ->
        %{
          "known_capabilities" =>
            capabilities
            |> Enum.filter(&AmpersandCore.Registry.capability_defined?(registry, &1))
            |> Enum.sort(),
          "unknown_capabilities" =>
            capabilities
            |> Enum.reject(&AmpersandCore.Registry.capability_defined?(registry, &1))
            |> Enum.sort(),
          "known_providers" =>
            providers
            |> Enum.filter(&(not is_nil(AmpersandCore.Registry.provider(registry, &1))))
            |> Enum.sort(),
          "unknown_providers" =>
            providers
            |> Enum.reject(&(not is_nil(AmpersandCore.Registry.provider(registry, &1))))
            |> Enum.sort(),
          "provider_matches" =>
            capabilities
            |> Enum.map(fn capability ->
              {capability,
               registry
               |> AmpersandCore.Registry.providers_for_capability(capability)
               |> Enum.map(& &1["id"])
               |> Enum.sort()}
            end)
            |> Enum.into(%{})
        }

      {:error, errors} ->
        %{
          "known_capabilities" => [],
          "unknown_capabilities" => capabilities,
          "known_providers" => [],
          "unknown_providers" => providers,
          "provider_matches" => %{},
          "errors" => errors
        }
    end
  end

  defp declared_capabilities(document) do
    AmpersandCore.normalize_capabilities(document)
  end

  defp declared_providers(document) do
    document
    |> Map.get("capabilities", %{})
    |> Enum.map(fn {_capability, binding} -> Map.get(binding, "provider") end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp emit_and_halt({:ok, output}) do
    IO.binwrite(output)
    System.halt(0)
  end

  defp emit_and_halt({:error, output, code}) do
    IO.binwrite(:stderr, output)
    System.halt(code)
  end

  defp ok_result(payload) when is_map(payload) do
    {:ok, encode_json(payload)}
  end

  defp error_result(kind, message_or_messages, exit_code, extra) do
    errors =
      case message_or_messages do
        messages when is_list(messages) -> Enum.map(messages, &to_string/1)
        message -> [to_string(message)]
      end

    payload =
      Map.merge(
        %{
          "status" => "error",
          "error" => kind,
          "errors" => errors
        },
        extra
      )

    {:error, encode_json(payload), exit_code}
  end

  defp encode_json(payload) do
    Jason.encode!(payload, pretty: true) <> "\n"
  end

  defp usage_lines do
    [
      "ampersand validate <file>",
      "ampersand compose <file>",
      "ampersand generate mcp <file>",
      "ampersand generate a2a <file>",
      "ampersand version",
      "ampersand help"
    ]
  end

  defp version_string do
    Application.load(:ampersand_core)

    case Application.spec(:ampersand_core, :vsn) do
      nil -> "0.1.0"
      vsn when is_list(vsn) -> List.to_string(vsn)
      vsn -> to_string(vsn)
    end
  end
end
