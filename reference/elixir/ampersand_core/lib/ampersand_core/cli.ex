defmodule AmpersandCore.CLI do
  @moduledoc """
  Minimal `ampersand` CLI entrypoint.

  Supported commands:

    * `ampersand validate <file>`
    * `ampersand validate-contract <file>`
    * `ampersand validate-registry`
    * `ampersand validate-registry <file>`
    * `ampersand compose <file>`
    * `ampersand compose <file1> <file2> [file3...]`
    * `ampersand check <file> <pipeline>`
    * `ampersand check <file> --pipeline <name>`
    * `ampersand plan <file> <pipeline>`
    * `ampersand plan <file> --pipeline <name>`
    * `ampersand run <file> <pipeline>`
    * `ampersand run <file> <pipeline> <input>`
    * `ampersand run <file> --pipeline <name>`
    * `ampersand run <file> --pipeline <name> <input>`
    * `ampersand generate mcp <file> [--format zed|generic] [-o|--output <path>]`
    * `ampersand generate a2a <file> [-o|--output <path>]`
    * `ampersand diff <file1> <file2>`
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
        compose_command([path])

      ["compose", first_path, second_path | rest_paths] ->
        compose_command([first_path, second_path | rest_paths])

      ["compose" | _invalid_args] ->
        error_result(
          "invalid_arguments",
          "compose requires at least one declaration file",
          1,
          %{"usage" => usage_lines()}
        )

      ["check", path, "--pipeline", pipeline_name] ->
        check_named_pipeline_command(path, pipeline_name)

      ["check", path, pipeline_ref] ->
        check_command(path, pipeline_ref)

      ["plan", path, "--pipeline", pipeline_name] ->
        plan_named_pipeline_command(path, pipeline_name)

      ["plan", path, pipeline_ref] ->
        plan_command(path, pipeline_ref)

      ["run", path, "--pipeline", pipeline_name] ->
        run_named_pipeline_command(path, pipeline_name, nil)

      ["run", path, "--pipeline", pipeline_name, input_ref] ->
        run_named_pipeline_command(path, pipeline_name, input_ref)

      ["run", path, pipeline_ref] ->
        run_command(path, pipeline_ref, nil)

      ["run", path, pipeline_ref, input_ref] ->
        run_command(path, pipeline_ref, input_ref)

      ["generate", "mcp", path | option_args] ->
        generate_mcp_command(path, option_args)

      ["generate", "a2a", path | option_args] ->
        generate_a2a_command(path, option_args)

      ["diff", left_path, right_path] ->
        diff_command(left_path, right_path)

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

  defp compose_command(paths) when is_list(paths) do
    with {:ok, documents} <- load_and_validate_documents(paths),
         {:ok, composed} <- AmpersandCore.compose(documents) do
      composed_document = %{"capabilities" => composed}

      capabilities = AmpersandCore.normalize_capabilities(composed_document)

      payload =
        case {paths, documents} do
          {[path], [document]} ->
            %{
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
            }

          _ ->
            %{
              "command" => "compose",
              "status" => "ok",
              "files" => paths,
              "file_count" => length(paths),
              "agents" => documents |> Enum.map(& &1["agent"]) |> Enum.uniq() |> Enum.sort(),
              "versions" => documents |> Enum.map(& &1["version"]) |> Enum.uniq() |> Enum.sort(),
              "capabilities" => capabilities,
              "capability_count" => length(capabilities),
              "aci" => aci_report(composed_document),
              "contracts" => contract_report(composed_document),
              "registry" => registry_report(composed_document),
              "composed" => composed
            }
        end

      ok_result(payload)
    else
      {:error, errors} when is_list(errors) ->
        error_result("compose_failed", errors, 1, %{
          "command" => "compose",
          "files" => paths
        })

      {:error, reason} ->
        error_result("compose_failed", inspect(reason), 1, %{
          "command" => "compose",
          "files" => paths
        })
    end
  end

  defp load_and_validate_documents(paths) when is_list(paths) do
    paths
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, documents} ->
      case AmpersandCore.validate_file(path) do
        {:ok, document} ->
          {:cont, {:ok, documents ++ [document]}}

        {:error, errors} when is_list(errors) ->
          {:halt, {:error, Enum.map(errors, fn error -> "#{path}: #{error}" end)}}

        {:error, reason} ->
          {:halt, {:error, ["#{path}: #{inspect(reason)}"]}}
      end
    end)
  end

  defp check_command(path, pipeline_ref) do
    with {:ok, document} <- AmpersandCore.validate_file(path),
         {:ok, pipeline_input, pipeline_meta} <- load_pipeline_reference(pipeline_ref) do
      do_check_command(path, document, pipeline_input, pipeline_meta, pipeline_ref)
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

  defp check_named_pipeline_command(path, pipeline_name) do
    with {:ok, document} <- AmpersandCore.validate_file(path),
         {:ok, pipeline_input, pipeline_meta} <- load_named_pipeline_reference(document, pipeline_name) do
      do_check_command(path, document, pipeline_input, pipeline_meta, pipeline_name)
    else
      {:error, errors} when is_list(errors) ->
        error_result("pipeline_check_failed", errors, 1, %{
          "command" => "check",
          "file" => path,
          "pipeline_name" => pipeline_name
        })

      {:error, reason} ->
        error_result("pipeline_check_failed", inspect(reason), 1, %{
          "command" => "check",
          "file" => path,
          "pipeline_name" => pipeline_name
        })
    end
  end

  defp do_check_command(path, document, pipeline_input, pipeline_meta, pipeline_ref) do
    with {:ok, parsed_pipeline} <- AmpersandCore.Runtime.normalize_pipeline(pipeline_input),
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
    with {:ok, pipeline_input, pipeline_meta} <- load_pipeline_reference(pipeline_ref) do
      do_plan_command(path, pipeline_input, pipeline_meta, pipeline_ref)
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

  defp plan_named_pipeline_command(path, pipeline_name) do
    with {:ok, document} <- AmpersandCore.validate_file(path),
         {:ok, pipeline_input, pipeline_meta} <- load_named_pipeline_reference(document, pipeline_name) do
      do_plan_command(path, pipeline_input, pipeline_meta, pipeline_name)
    else
      {:error, errors} when is_list(errors) ->
        error_result("pipeline_plan_failed", errors, 1, %{
          "command" => "plan",
          "file" => path,
          "pipeline_name" => pipeline_name
        })

      {:error, reason} ->
        error_result("pipeline_plan_failed", inspect(reason), 1, %{
          "command" => "plan",
          "file" => path,
          "pipeline_name" => pipeline_name
        })
    end
  end

  defp do_plan_command(path, pipeline_input, pipeline_meta, pipeline_ref) do
    with {:ok, plan} <- AmpersandCore.plan_pipeline_file(path, pipeline_input, []) do
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
    with {:ok, pipeline_input, pipeline_meta} <- load_pipeline_reference(pipeline_ref) do
      do_run_command(path, pipeline_input, pipeline_meta, pipeline_ref, input_ref)
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

  defp run_named_pipeline_command(path, pipeline_name, input_ref) do
    with {:ok, document} <- AmpersandCore.validate_file(path),
         {:ok, pipeline_input, pipeline_meta} <- load_named_pipeline_reference(document, pipeline_name) do
      do_run_command(path, pipeline_input, pipeline_meta, pipeline_name, input_ref)
    else
      {:error, errors} when is_list(errors) ->
        error_result("pipeline_run_failed", errors, 1, %{
          "command" => "run",
          "file" => path,
          "pipeline_name" => pipeline_name
        })

      {:error, reason} ->
        error_result("pipeline_run_failed", inspect(reason), 1, %{
          "command" => "run",
          "file" => path,
          "pipeline_name" => pipeline_name
        })
    end
  end

  defp do_run_command(path, pipeline_input, pipeline_meta, pipeline_ref, input_ref) do
    with {:ok, runtime_input, input_meta} <- load_runtime_input(input_ref),
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

  defp generate_mcp_command(path, option_args) when is_list(option_args) do
    with {:ok, options} <- parse_generate_options(option_args, :mcp),
         {:ok, config} <- AmpersandCore.MCP.client_config_file(path, mcp_generate_opts(options)),
         :ok <- maybe_write_output(options.output, config) do
      case options.output do
        nil ->
          ok_result(config)

        output_path ->
          ok_result(%{
            "command" => "generate",
            "target" => "mcp",
            "status" => "ok",
            "file" => path,
            "format" => options.format,
            "output" => output_path,
            "config" => config
          })
      end
    else
      {:error, errors} when is_list(errors) ->
        error_result("mcp_generation_failed", errors, 1, %{
          "command" => "generate",
          "target" => "mcp",
          "file" => path
        })

      {:error, reason} ->
        error_result("mcp_generation_failed", inspect(reason), 1, %{
          "command" => "generate",
          "target" => "mcp",
          "file" => path
        })
    end
  end

  defp generate_a2a_command(path, option_args) when is_list(option_args) do
    with {:ok, options} <- parse_generate_options(option_args, :a2a),
         {:ok, card} <- AmpersandCore.generate_a2a_card_file(path),
         :ok <- maybe_write_output(options.output, card) do
      case options.output do
        nil ->
          ok_result(card)

        output_path ->
          ok_result(%{
            "command" => "generate",
            "target" => "a2a",
            "status" => "ok",
            "file" => path,
            "output" => output_path,
            "card" => card
          })
      end
    else
      {:error, errors} when is_list(errors) ->
        error_result("a2a_generation_failed", errors, 1, %{
          "command" => "generate",
          "target" => "a2a",
          "file" => path
        })

      {:error, reason} ->
        error_result("a2a_generation_failed", inspect(reason), 1, %{
          "command" => "generate",
          "target" => "a2a",
          "file" => path
        })
    end
  end

  defp diff_command(left_path, right_path) do
    with {:ok, left_document} <- AmpersandCore.validate_file(left_path),
         {:ok, right_document} <- AmpersandCore.validate_file(right_path) do
      left_capabilities = Map.get(left_document, "capabilities", %{})
      right_capabilities = Map.get(right_document, "capabilities", %{})

      left_keys = left_capabilities |> Map.keys() |> Enum.sort()
      right_keys = right_capabilities |> Map.keys() |> Enum.sort()

      added = right_keys -- left_keys
      removed = left_keys -- right_keys
      shared = left_keys -- removed

      binding_changes =
        shared
        |> Enum.filter(fn capability ->
          Map.get(left_capabilities, capability) != Map.get(right_capabilities, capability)
        end)
        |> Enum.map(fn capability ->
          %{
            "capability" => capability,
            "left" => Map.get(left_capabilities, capability),
            "right" => Map.get(right_capabilities, capability)
          }
        end)

      provider_changes =
        binding_changes
        |> Enum.map(fn change ->
          %{
            "capability" => change["capability"],
            "left_provider" => get_in(change, ["left", "provider"]),
            "right_provider" => get_in(change, ["right", "provider"])
          }
        end)
        |> Enum.filter(fn change ->
          change["left_provider"] != change["right_provider"]
        end)

      governance_changed = Map.get(left_document, "governance") != Map.get(right_document, "governance")
      provenance_changed = Map.get(left_document, "provenance") != Map.get(right_document, "provenance")

      ok_result(%{
        "command" => "diff",
        "status" => "ok",
        "left_file" => left_path,
        "right_file" => right_path,
        "capabilities" => %{
          "added" => added,
          "removed" => removed,
          "binding_changes" => binding_changes,
          "provider_changes" => provider_changes
        },
        "governance" => %{
          "changed" => governance_changed,
          "left" => Map.get(left_document, "governance"),
          "right" => Map.get(right_document, "governance")
        },
        "provenance" => %{
          "changed" => provenance_changed,
          "left" => Map.get(left_document, "provenance"),
          "right" => Map.get(right_document, "provenance")
        },
        "summary" => %{
          "added_count" => length(added),
          "removed_count" => length(removed),
          "binding_change_count" => length(binding_changes),
          "provider_change_count" => length(provider_changes),
          "governance_changed" => governance_changed,
          "provenance_changed" => provenance_changed
        }
      })
    else
      {:error, errors} when is_list(errors) ->
        error_result("diff_failed", errors, 1, %{
          "command" => "diff",
          "left_file" => left_path,
          "right_file" => right_path
        })

      {:error, reason} ->
        error_result("diff_failed", inspect(reason), 1, %{
          "command" => "diff",
          "left_file" => left_path,
          "right_file" => right_path
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

  defp load_named_pipeline_reference(document, pipeline_name)
       when is_map(document) and is_binary(pipeline_name) do
    pipelines = Map.get(document, "pipelines", %{})

    case Map.get(pipelines, pipeline_name) do
      %{} = pipeline ->
        {:ok, pipeline, %{"pipeline_name" => pipeline_name}}

      _ ->
        {:error, ["pipeline #{inspect(pipeline_name)} is not defined in declaration pipelines"]}
    end
  end

  defp parse_generate_options(args, target) when is_list(args) do
    parse_generate_options(args, %{output: nil, format: :zed}, target)
  end

  defp parse_generate_options([], options, :mcp), do: {:ok, options}

  defp parse_generate_options([], options, :a2a) do
    case options.format do
      :zed -> {:ok, options}
      _ -> {:error, ["--format is only supported for generate mcp"]}
    end
  end

  defp parse_generate_options(["-o", output_path | rest], options, target) do
    parse_generate_options(rest, %{options | output: output_path}, target)
  end

  defp parse_generate_options(["--output", output_path | rest], options, target) do
    parse_generate_options(rest, %{options | output: output_path}, target)
  end

  defp parse_generate_options(["--format", format | rest], options, :mcp) do
    case format do
      "zed" -> parse_generate_options(rest, %{options | format: :zed}, :mcp)
      "generic" -> parse_generate_options(rest, %{options | format: :generic}, :mcp)
      _ -> {:error, ["unsupported --format #{inspect(format)}; expected zed or generic"]}
    end
  end

  defp parse_generate_options(["--format", _format | _rest], _options, :a2a) do
    {:error, ["--format is only supported for generate mcp"]}
  end

  defp parse_generate_options([option], _options, _target)
       when option in ["-o", "--output", "--format"] do
    {:error, ["missing value for option #{option}"]}
  end

  defp parse_generate_options([unknown | _rest], _options, _target) do
    {:error, ["unknown option #{inspect(unknown)}"]}
  end

  defp mcp_generate_opts(options) do
    [format: options.format]
  end

  defp maybe_write_output(nil, _payload), do: :ok

  defp maybe_write_output(path, payload) when is_binary(path) and is_map(payload) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, encoded} <- Jason.encode(payload, pretty: true),
         :ok <- File.write(path, encoded <> "\n") do
      :ok
    else
      {:error, reason} ->
        {:error, ["unable to write output file #{path}: #{inspect(reason)}"]}
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
      "ampersand compose <file1> <file2> [file3...]",
      "ampersand check <file> <pipeline>",
      "ampersand check <file> --pipeline <name>",
      "ampersand plan <file> <pipeline>",
      "ampersand plan <file> --pipeline <name>",
      "ampersand run <file> <pipeline>",
      "ampersand run <file> <pipeline> <input>",
      "ampersand run <file> --pipeline <name>",
      "ampersand run <file> --pipeline <name> <input>",
      "ampersand generate mcp <file> [--format zed|generic] [-o|--output <path>]",
      "ampersand generate a2a <file> [-o|--output <path>]",
      "ampersand diff <file1> <file2>",
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
