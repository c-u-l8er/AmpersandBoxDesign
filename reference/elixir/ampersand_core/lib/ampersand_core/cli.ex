defmodule AmpersandCore.CLI do
  @moduledoc """
  Minimal `ampersand` CLI entrypoint.

  Supported commands:

    * `ampersand validate <file>`
    * `ampersand validate-contract <file>`
    * `ampersand validate-registry`
    * `ampersand validate-registry <file>`
    * `ampersand compose <file>`
    * `ampersand check <file> <pipeline>`
    * `ampersand plan <file> <pipeline>`
    * `ampersand run <file> <pipeline>`
    * `ampersand run <file> <pipeline> <input>`
    * `ampersand generate mcp <file>`
    * `ampersand generate a2a <file>`
    * `ampersand registry list`
    * `ampersand registry providers <capability>`

  Pipeline arguments may be provided as:

    * an inline pipeline expression such as
      `"stream_data |> &time.anomaly.detect() |> &memory.graph.enrich() |> &reason.argument.evaluate()"`
    * an inline JSON payload with `"steps"` or `"pipeline"`
    * a path to a JSON or text file containing the pipeline payload

  Input arguments for `run` may be provided as:

    * an inline JSON object
    * a path to a JSON file
    * any other inline value, which will be wrapped as `%{"value" => ...}`

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
  """
  @spec run([String.t()]) :: cli_result()
  def run(argv) when is_list(argv) do
    case argv do
      [] ->
        help_result()

      ["help"] ->
        help_result()

      ["--help"] ->
        help_result()

      ["-h"] ->
        help_result()

      ["version"] ->
        version_result()

      ["--version"] ->
        version_result()

      ["validate", path] ->
        validate_command(path)

      ["validate-contract", path] ->
        validate_contract_command(path)

      ["validate-registry"] ->
        validate_registry_command(AmpersandCore.Registry.default_registry_path())

      ["validate-registry", path] ->
        validate_registry_command(path)

      ["compose", path] ->
        compose_command(path)

      ["check", path, pipeline_ref] ->
        check_command(path, pipeline_ref)

      ["plan", path, pipeline_ref] ->
        plan_command(path, pipeline_ref)

      ["run", path, pipeline_ref] ->
        run_command(path, pipeline_ref, nil)

      ["run", path, pipeline_ref, input_ref] ->
        run_command(path, pipeline_ref, input_ref)

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

      ["registry", "list"] ->
        registry_list_command()

      ["registry", "providers", capability] ->
        registry_providers_command(capability)

      ["registry", subcommand | _rest] ->
        error_result(
          "unknown_registry_command",
          "unsupported registry command #{inspect(subcommand)}",
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

  defp help_result do
    ok_result(%{
      "command" => "help",
      "status" => "ok",
      "version" => version_string(),
      "usage" => usage_lines()
    })
  end

  defp version_result do
    ok_result(%{
      "command" => "version",
      "status" => "ok",
      "version" => version_string()
    })
  end

  defp validate_command(path) do
    case AmpersandCore.validate_file(path) do
      {:ok, document} ->
        ok_result(%{
          "command" => "validate",
          "status" => "ok",
          "valid" => true,
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

  defp validate_contract_command(path) do
    case AmpersandCore.Contracts.load_contract(path) do
      {:ok, contract} ->
        operations =
          contract
          |> Map.get("operations", %{})
          |> Map.keys()
          |> Enum.sort()

        ok_result(%{
          "command" => "validate-contract",
          "status" => "ok",
          "valid" => true,
          "file" => path,
          "capability" => contract["capability"],
          "provider" => contract["provider"],
          "version" => contract["version"],
          "schema" => contract["$schema"],
          "operation_count" => length(operations),
          "operations" => operations
        })

      {:error, errors} ->
        error_result("contract_validation_failed", errors, 1, %{
          "command" => "validate-contract",
          "file" => path
        })
    end
  end

  defp validate_registry_command(path) do
    case AmpersandCore.Registry.load(path) do
      {:ok, registry} ->
        primitives = AmpersandCore.Registry.list_primitives(registry)
        capabilities = AmpersandCore.Registry.list_capabilities(registry)
        providers = registry_provider_ids(registry)

        ok_result(%{
          "command" => "validate-registry",
          "status" => "ok",
          "valid" => true,
          "file" => path,
          "registry" => registry["registry"],
          "version" => registry["version"],
          "generated_at" => registry["generated_at"],
          "schema" => registry["$schema"],
          "primitive_count" => length(primitives),
          "capability_count" => length(capabilities),
          "provider_count" => length(providers)
        })

      {:error, errors} ->
        error_result("registry_validation_failed", errors, 1, %{
          "command" => "validate-registry",
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

  defp check_command(path, pipeline_ref) do
    with {:ok, document} <- AmpersandCore.validate_file(path),
         {:ok, pipeline_input, pipeline_meta} <- load_pipeline_reference(pipeline_ref),
         {:ok, parsed_pipeline} <- AmpersandCore.Runtime.normalize_pipeline(pipeline_input),
         :ok <-
           AmpersandCore.Contracts.check_pipeline_for_document(
             document,
             parsed_pipeline.steps,
             source_type: parsed_pipeline.source_type,
             source_ref: parsed_pipeline.source_ref
           ) do
      ok_result(
        %{
          "command" => "check",
          "status" => "ok",
          "valid" => true,
          "file" => path,
          "agent" => document["agent"],
          "version" => document["version"],
          "source" => %{
            "type" => parsed_pipeline.source_type,
            "ref" => parsed_pipeline.source_ref
          },
          "step_count" => length(parsed_pipeline.steps),
          "pipeline" => Enum.map(parsed_pipeline.steps, &stringify_map_keys/1)
        }
        |> Map.merge(pipeline_meta)
      )
    else
      {:error, errors} when is_list(errors) ->
        error_result("pipeline_check_failed", errors, 1, %{
          "command" => "check",
          "file" => path,
          "pipeline" => pipeline_ref
        })

      {:error, reason} ->
        error_result("pipeline_check_failed", inspect(reason), 1, %{
          "command" => "check",
          "file" => path,
          "pipeline" => pipeline_ref
        })
    end
  end

  defp plan_command(path, pipeline_ref) do
    with {:ok, pipeline_input, pipeline_meta} <- load_pipeline_reference(pipeline_ref),
         {:ok, plan} <- AmpersandCore.plan_pipeline_file(path, pipeline_input, []) do
      ok_result(
        plan
        |> Map.put("command", "plan")
        |> Map.put("file", path)
        |> Map.merge(pipeline_meta)
      )
    else
      {:error, errors} when is_list(errors) ->
        error_result("pipeline_plan_failed", errors, 1, %{
          "command" => "plan",
          "file" => path,
          "pipeline" => pipeline_ref
        })

      {:error, reason} ->
        error_result("pipeline_plan_failed", inspect(reason), 1, %{
          "command" => "plan",
          "file" => path,
          "pipeline" => pipeline_ref
        })
    end
  end

  defp run_command(path, pipeline_ref, input_ref) do
    with {:ok, pipeline_input, pipeline_meta} <- load_pipeline_reference(pipeline_ref),
         {:ok, runtime_input, input_meta} <- load_runtime_input(input_ref),
         {:ok, result} <- AmpersandCore.run_pipeline_file(path, pipeline_input, runtime_input, []) do
      ok_result(
        result
        |> Map.put("command", "run")
        |> Map.put("file", path)
        |> Map.merge(pipeline_meta)
        |> Map.merge(input_meta)
        |> Map.put("provenance_count", length(Map.get(result, "provenance", [])))
      )
    else
      {:error, errors} when is_list(errors) ->
        error_result("pipeline_run_failed", errors, 1, %{
          "command" => "run",
          "file" => path,
          "pipeline" => pipeline_ref
        })

      {:error, reason} ->
        error_result("pipeline_run_failed", inspect(reason), 1, %{
          "command" => "run",
          "file" => path,
          "pipeline" => pipeline_ref
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

  defp registry_list_command do
    case AmpersandCore.load_registry() do
      {:ok, registry} ->
        primitives = AmpersandCore.Registry.list_primitives(registry)
        capabilities = AmpersandCore.Registry.list_capabilities(registry)
        providers = registry_provider_ids(registry)

        contract_backed_capabilities =
          capabilities
          |> Enum.filter(&(not is_nil(AmpersandCore.Registry.contract_ref_for(registry, &1))))

        ok_result(%{
          "command" => "registry",
          "subcommand" => "list",
          "status" => "ok",
          "registry" => %{
            "id" => registry["registry"],
            "version" => registry["version"],
            "generated_at" => registry["generated_at"]
          },
          "primitives" => primitives,
          "capabilities" => capabilities,
          "providers" => providers,
          "primitive_count" => length(primitives),
          "capability_count" => length(capabilities),
          "provider_count" => length(providers),
          "contract_backed_capabilities" => contract_backed_capabilities
        })

      {:error, errors} ->
        error_result("registry_load_failed", errors, 1, %{
          "command" => "registry",
          "subcommand" => "list"
        })
    end
  end

  defp registry_providers_command(capability) do
    case AmpersandCore.load_registry() do
      {:ok, registry} ->
        if AmpersandCore.Registry.capability_defined?(registry, capability) do
          providers =
            registry
            |> AmpersandCore.Registry.providers_for_capability(capability)
            |> Enum.map(&provider_details/1)

          ok_result(%{
            "command" => "registry",
            "subcommand" => "providers",
            "status" => "ok",
            "capability" => capability,
            "contract_ref" => AmpersandCore.Registry.contract_ref_for(registry, capability),
            "operations" => AmpersandCore.Registry.operations_for(registry, capability),
            "a2a_skills" => AmpersandCore.Registry.a2a_skills_for(registry, capability),
            "providers" => providers,
            "provider_count" => length(providers)
          })
        else
          error_result(
            "unknown_capability",
            "capability #{inspect(capability)} is not defined in the registry",
            1,
            %{
              "command" => "registry",
              "subcommand" => "providers",
              "capability" => capability
            }
          )
        end

      {:error, errors} ->
        error_result("registry_load_failed", errors, 1, %{
          "command" => "registry",
          "subcommand" => "providers",
          "capability" => capability
        })
    end
  end

  defp load_pipeline_reference(reference) when is_binary(reference) do
    if File.regular?(reference) do
      with {:ok, contents} <- File.read(reference) do
        {:ok, decode_jsonish(contents), %{"pipeline_file" => reference}}
      else
        {:error, reason} ->
          {:error, ["unable to read pipeline file #{reference}: #{inspect(reason)}"]}
      end
    else
      {:ok, decode_jsonish(reference), %{}}
    end
  end

  defp load_runtime_input(nil), do: {:ok, %{}, %{}}

  defp load_runtime_input(reference) when is_binary(reference) do
    if File.regular?(reference) do
      with {:ok, contents} <- File.read(reference) do
        {:ok, normalize_runtime_input(decode_jsonish(contents)), %{"input_file" => reference}}
      else
        {:error, reason} ->
          {:error, ["unable to read input file #{reference}: #{inspect(reason)}"]}
      end
    else
      {:ok, normalize_runtime_input(decode_jsonish(reference)), %{}}
    end
  end

  defp decode_jsonish(value) when is_binary(value) do
    trimmed = String.trim(value)

    case Jason.decode(trimmed) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> value
    end
  end

  defp normalize_runtime_input(%{} = input), do: input
  defp normalize_runtime_input(value), do: %{"value" => value}

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

  defp registry_provider_ids(registry) do
    registry
    |> AmpersandCore.Registry.list_primitives()
    |> Enum.flat_map(fn primitive ->
      AmpersandCore.Registry.providers_for_capability(registry, primitive)
    end)
    |> Enum.map(&Map.get(&1, "id"))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp provider_details(provider) do
    %{}
    |> put_if_present("id", provider["id"])
    |> put_if_present("name", provider["name"])
    |> put_if_present("description", provider["description"])
    |> put_if_present("subtypes", provider["subtypes"])
    |> put_if_present("protocol", provider["protocol"])
    |> put_if_present("transport", provider["transport"])
    |> put_if_present("status", provider["status"])
    |> put_if_present("url", provider["url"])
    |> put_if_present("command", provider["command"])
    |> put_if_present("args", provider["args"])
    |> put_if_present("contract_ref", provider["contract_ref"])
  end

  defp stringify_map_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, []), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

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
      "ampersand validate-contract <file>",
      "ampersand validate-registry",
      "ampersand validate-registry <file>",
      "ampersand compose <file>",
      "ampersand check <file> <pipeline>",
      "ampersand plan <file> <pipeline>",
      "ampersand run <file> <pipeline>",
      "ampersand run <file> <pipeline> <input>",
      "ampersand generate mcp <file>",
      "ampersand generate a2a <file>",
      "ampersand registry list",
      "ampersand registry providers <capability>",
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
