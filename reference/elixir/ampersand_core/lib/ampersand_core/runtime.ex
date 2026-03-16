defmodule AmpersandCore.Runtime do
  @moduledoc """
  Runtime support for the [&] protocol reference implementation.

  This module adds the missing operational layer on top of schema validation and
  contract loading:

    * parse pipeline expressions
    * build a validated runtime plan
    * simulate pipeline execution
    * emit hash-linked provenance records when enabled

  The runtime is intentionally conservative. It does not attempt to launch real
  providers or invent transport semantics. Instead, it turns a valid declaration
  plus a valid pipeline into deterministic plan and execution artifacts that are
  useful for testing, documentation, and downstream adapters.
  """

  alias AmpersandCore.Contracts
  alias AmpersandCore.Governance
  alias AmpersandCore.Registry
  alias AmpersandCore.Schema

  @type capability_id :: String.t()
  @type operation_name :: String.t()

  @type pipeline_step :: %{
          required(:capability) => capability_id(),
          required(:operation) => operation_name()
        }

  @type parsed_pipeline :: %{
          required(:source_type) => String.t() | nil,
          required(:source_ref) => String.t() | nil,
          required(:steps) => [pipeline_step()],
          optional(:raw) => String.t()
        }

  @type result(t) :: {:ok, t} | {:error, [String.t()]}

  @doc """
  Parses a pipeline expression such as:

      "stream_data |> &time.anomaly.detect() |> &memory.graph.enrich()"

  into a normalized runtime structure.
  """
  @spec parse_pipeline(String.t()) :: result(parsed_pipeline())
  def parse_pipeline(pipeline) when is_binary(pipeline) do
    cleaned =
      pipeline
      |> strip_code_fences()
      |> String.trim()

    cond do
      cleaned == "" ->
        {:error, ["pipeline string cannot be empty"]}

      true ->
        tokens =
          cleaned
          |> String.split(~r/\s*\|>\s*/, trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        case tokens do
          [] ->
            {:error, ["pipeline string cannot be empty"]}

          [single] ->
            if String.starts_with?(single, "&") do
              {:error, ["pipeline must include a source token before the first capability step"]}
            else
              {:error, ["pipeline must contain at least one capability step"]}
            end

          [first | rest] ->
            {source_type, step_tokens} =
              if String.starts_with?(first, "&") do
                {nil, [first | rest]}
              else
                {normalize_optional_string(first), rest}
              end

            with {:ok, steps} <- normalize_pipeline_steps(step_tokens) do
              {:ok,
               %{
                 source_type: source_type,
                 source_ref: default_source_ref(source_type),
                 steps: steps,
                 raw: cleaned
               }}
            end
        end
    end
  end

  def parse_pipeline(_pipeline) do
    {:error, ["pipeline must be a string"]}
  end

  @doc """
  Normalizes any supported pipeline representation into a parsed pipeline.

  Supported inputs are:

    * pipeline string
    * list of steps
    * map with `steps` or `pipeline`
  """
  @spec normalize_pipeline(term()) :: result(parsed_pipeline())
  def normalize_pipeline(pipeline) when is_binary(pipeline) do
    parse_pipeline(pipeline)
  end

  def normalize_pipeline(pipeline) when is_list(pipeline) do
    with {:ok, steps} <- normalize_pipeline_steps(pipeline) do
      {:ok,
       %{
         source_type: nil,
         source_ref: nil,
         steps: steps
       }}
    end
  end

  def normalize_pipeline(%{} = pipeline) do
    source_type =
      fetch_any(pipeline, ["source_type", :source_type, "source", :source])
      |> normalize_optional_string()

    source_ref =
      fetch_any(pipeline, ["source_ref", :source_ref])
      |> normalize_optional_string(default_source_ref(source_type))

    cond do
      is_binary(fetch_any(pipeline, ["pipeline", :pipeline])) ->
        with {:ok, parsed} <- parse_pipeline(fetch_any(pipeline, ["pipeline", :pipeline])) do
          {:ok,
           %{
             source_type: source_type || parsed.source_type,
             source_ref: source_ref || parsed.source_ref,
             steps: parsed.steps,
             raw: parsed.raw
           }}
        end

      is_list(fetch_any(pipeline, ["pipeline", :pipeline])) ->
        with {:ok, steps} <- normalize_pipeline_steps(fetch_any(pipeline, ["pipeline", :pipeline])) do
          {:ok,
           %{
             source_type: source_type,
             source_ref: source_ref,
             steps: steps
           }}
        end

      is_list(fetch_any(pipeline, ["steps", :steps])) ->
        with {:ok, steps} <- normalize_pipeline_steps(fetch_any(pipeline, ["steps", :steps])) do
          {:ok,
           %{
             source_type: source_type,
             source_ref: source_ref,
             steps: steps,
             raw:
               fetch_any(pipeline, ["raw", :raw])
               |> normalize_optional_string()
           }}
        end

      true ->
        {:error, ["pipeline map must contain a pipeline string or a steps list"]}
    end
  end

  def normalize_pipeline(_pipeline) do
    {:error, ["pipeline must be a string, a list of steps, or a pipeline map"]}
  end

  @doc """
  Builds a validated runtime plan for a declaration and pipeline.
  """
  @spec plan(map(), term(), keyword()) :: result(map())
  def plan(document, pipeline, opts \\ [])

  def plan(document, pipeline, opts) when is_map(document) and is_list(opts) do
    with {:ok, validated} <- Schema.validate(document),
         {:ok, parsed_pipeline} <- normalize_pipeline(pipeline),
         {:ok, contracts} <- Contracts.load_contracts_for_document(validated, strict: true),
         :ok <-
           Contracts.check_pipeline(
             contracts,
             parsed_pipeline.steps,
             source_type: effective_source_type(parsed_pipeline, opts),
             source_ref: effective_source_ref(parsed_pipeline, opts)
           ) do
      capability_registry = load_registry(opts)

      runtime_plan =
        build_plan(
          validated,
          parsed_pipeline,
          contracts,
          capability_registry,
          opts
        )

      case unresolved_auto_resolution_errors(runtime_plan) do
        [] -> {:ok, runtime_plan}
        errors -> {:error, errors}
      end
    else
      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, reason} ->
        {:error, [inspect(reason)]}
    end
  end

  def plan(_document, _pipeline, _opts) do
    {:error, ["document must be a validated ampersand.json object"]}
  end

  @doc """
  Reads a declaration from disk and builds a validated runtime plan.
  """
  @spec plan_file(Path.t(), term(), keyword()) :: result(map())
  def plan_file(path, pipeline, opts \\ [])

  def plan_file(path, pipeline, opts) when is_binary(path) and is_list(opts) do
    with {:ok, document} <- Schema.validate_file(path) do
      plan(document, pipeline, opts)
    end
  end

  def plan_file(_path, _pipeline, _opts) do
    {:error, ["path must be a string and opts must be a keyword list"]}
  end

  @doc """
  Simulates execution of a validated runtime pipeline.

  By default this function emits synthetic outputs for each step. You can supply
  custom executors through `opts[:executors]`.

  Supported executor keys:

    * `{capability, operation}`
    * `"\#{capability}.\#{operation}"`
    * `capability`
    * `provider`

  Supported executor arities:

    * `fn step, input -> output end`
    * `fn step, input, context -> output end`
  """
  @spec run(map(), term(), map(), keyword()) :: result(map())
  def run(document, pipeline, input \\ %{}, opts \\ [])

  def run(document, pipeline, input, opts)
      when is_map(document) and is_map(input) and is_list(opts) do
    with {:ok, runtime_plan} <- plan(document, pipeline, opts) do
      execute_plan(runtime_plan, input, opts)
    end
  end

  def run(_document, _pipeline, _input, _opts) do
    {:error, ["document must be a map, input must be a map, and opts must be a keyword list"]}
  end

  @doc """
  Reads a declaration from disk and simulates execution.
  """
  @spec run_file(Path.t(), term(), map(), keyword()) :: result(map())
  def run_file(path, pipeline, input \\ %{}, opts \\ [])

  def run_file(path, pipeline, input, opts)
      when is_binary(path) and is_map(input) and is_list(opts) do
    with {:ok, document} <- Schema.validate_file(path) do
      run(document, pipeline, input, opts)
    end
  end

  def run_file(_path, _pipeline, _input, _opts) do
    {:error, ["path must be a string, input must be a map, and opts must be a keyword list"]}
  end

  defp build_plan(document, parsed_pipeline, contracts, capability_registry, opts) do
    capabilities = Map.get(document, "capabilities", %{})
    source_type = effective_source_type(parsed_pipeline, opts)
    source_ref = effective_source_ref(parsed_pipeline, opts)

    steps =
      parsed_pipeline.steps
      |> Enum.with_index(1)
      |> Enum.map(fn {%{capability: capability, operation: operation}, index} ->
        binding = Map.get(capabilities, capability, %{})
        contract = Map.get(contracts, capability, %{})
        operation_signature = operation_signature(contract, operation)
        provider = Map.get(binding, "provider")
        {resolved_provider, provider_resolution} =
          resolve_provider_binding(capability_registry, capability, provider)

        %{
          "index" => index,
          "capability" => capability,
          "operation" => operation,
          "provider" => resolved_provider,
          "config" => Map.get(binding, "config", %{}),
          "need" => Map.get(binding, "need"),
          "input_type" => get_field(operation_signature, "in"),
          "output_type" => get_field(operation_signature, "out"),
          "description" => get_field(operation_signature, "description"),
          "deterministic" => get_field(operation_signature, "deterministic"),
          "side_effects" => get_field(operation_signature, "side_effects", false),
          "accepts_from" => get_field(contract, "accepts_from", []),
          "feeds_into" => get_field(contract, "feeds_into", []),
          "a2a_skills" => get_field(contract, "a2a_skills", []),
          "contract_ref" => registry_contract_ref(capability_registry, capability),
          "provider_resolution" => provider_resolution
        }
        |> drop_nil_values()
      end)

    %{
      "agent" => document["agent"],
      "version" => document["version"],
      "status" => "ok",
      "mode" => "plan",
      "source" => %{"type" => source_type, "ref" => source_ref},
      "pipeline" => render_pipeline(source_type, parsed_pipeline.steps),
      "step_count" => length(steps),
      "steps" => steps,
      "governance" => document["governance"],
      "provenance" => provenance_summary(document["provenance"]),
      "registry" => registry_summary(capability_registry),
      "resolution" => resolution_summary(steps)
    }
    |> drop_nil_values()
  end

  defp execute_plan(plan, input, opts) do
    provenance_enabled? = provenance_enabled?(plan["provenance"])
    executors = Keyword.get(opts, :executors, %{})
    governance = plan["governance"] || %{}
    hard_constraints = get_field(governance, "hard", [])
    escalate_when = get_field(governance, "escalate_when", %{})

    initial_input = normalize_input(input, plan["source"])

    preflight_subject = %{
      "agent" => plan["agent"],
      "source" => plan["source"],
      "input" => initial_input
    }

    case Governance.evaluate_hard(hard_constraints, preflight_subject) do
      {:block, reason} ->
        {:ok,
         blocked_execution_result(
           plan,
           [],
           initial_input,
           [],
           reason,
           nil
         )}

      _ ->
        reduction =
          plan["steps"]
          |> Enum.reduce_while(
            {[], initial_input, [], nil, false},
            fn step, {results_acc, current_input, provenance_acc, parent_hash, escalation_triggered?} ->
              context = %{
                plan: plan,
                step_results: results_acc,
                provenance: provenance_acc
              }

              hard_subject = %{
                "step" => step,
                "input" => current_input,
                "context" => context
              }

              case Governance.evaluate_hard(hard_constraints, hard_subject) do
                {:block, reason} ->
                  {:halt,
                   {:blocked,
                    {results_acc, current_input, provenance_acc, parent_hash, escalation_triggered?},
                    step, reason}}

                _ ->
                  output =
                    step
                    |> execute_step(current_input, context, executors)
                    |> normalize_executor_output(step)

                  timestamp = step_timestamp(step["index"], opts)
                  input_hash = hash_payload(current_input)
                  output_hash = hash_payload(output)

                  provenance_record =
                    if provenance_enabled? do
                      %{
                        "source" => step["capability"],
                        "provider" => step["provider"],
                        "operation" => step["operation"],
                        "timestamp" => timestamp,
                        "input_hash" => input_hash,
                        "output_hash" => output_hash,
                        "parent_hash" => parent_hash
                      }
                    else
                      nil
                    end

                  escalation =
                    case Governance.evaluate_escalate_when(escalate_when, output) do
                      {:escalate, reason} ->
                        %{
                          "triggered" => true,
                          "reason" => reason,
                          "condition" => "escalate_when"
                        }

                      _ ->
                        nil
                    end

                  step_result =
                    %{
                      "index" => step["index"],
                      "capability" => step["capability"],
                      "operation" => step["operation"],
                      "provider" => step["provider"],
                      "input_type" => step["input_type"],
                      "output_type" => step["output_type"],
                      "timestamp" => timestamp,
                      "input" => current_input,
                      "output" => output
                    }
                    |> maybe_put("provenance", provenance_record)
                    |> maybe_put("escalation", escalation)

                  {:cont,
                   {results_acc ++ [step_result], output,
                    append_if_present(provenance_acc, provenance_record), output_hash,
                    escalation_triggered? or not is_nil(escalation)}}
              end
            end
          )

        case reduction do
          {:blocked, {step_results, current_input, provenance_records, _parent_hash, _escalation?}, step,
           reason} ->
            {:ok,
             blocked_execution_result(
               plan,
               step_results,
               current_input,
               provenance_records,
               reason,
               step
             )}

          {step_results, final_output, provenance_records, _last_output_hash, escalation_triggered?} ->
            {:ok,
             %{
               "agent" => plan["agent"],
               "version" => plan["version"],
               "status" => "ok",
               "mode" => "simulated",
               "source" => plan["source"],
               "pipeline" => plan["pipeline"],
               "steps" => step_results,
               "step_count" => length(step_results),
               "output" => final_output,
               "governance" => plan["governance"],
               "provenance" => provenance_records
             }
             |> maybe_put("escalation_triggered", if(escalation_triggered?, do: true, else: nil))
             |> drop_nil_values()}
        end
    end
  end

  defp execute_step(step, current_input, context, executors) do
    case resolve_executor(executors, step) do
      executor when is_function(executor, 3) ->
        executor.(step, current_input, context)

      executor when is_function(executor, 2) ->
        executor.(step, current_input)

      _ ->
        default_simulated_output(step, current_input)
    end
  end

  defp resolve_executor(executors, step) when is_map(executors) do
    Map.get(executors, {step["capability"], step["operation"]}) ||
      Map.get(executors, "#{step["capability"]}.#{step["operation"]}") ||
      Map.get(executors, step["capability"]) ||
      Map.get(executors, step["provider"])
  end

  defp resolve_executor(_executors, _step), do: nil

  defp normalize_executor_output({:ok, output}, step), do: normalize_executor_output(output, step)

  defp normalize_executor_output(%{"type" => _type} = output, _step), do: output

  defp normalize_executor_output(output, step) when is_map(output) do
    Map.put_new(output, "type", step["output_type"])
  end

  defp normalize_executor_output(output, step) do
    %{
      "type" => step["output_type"],
      "value" => output
    }
  end

  defp default_simulated_output(step, current_input) do
    case step["output_type"] do
      "ack" ->
        %{
          "type" => "ack",
          "acknowledged" => true,
          "source" => step["capability"],
          "operation" => step["operation"],
          "provider" => step["provider"]
        }

      output_type ->
        %{
          "type" => output_type,
          "source" => step["capability"],
          "operation" => step["operation"],
          "provider" => step["provider"],
          "summary" => "Simulated #{step["capability"]}.#{step["operation"]} -> #{output_type}",
          "input" => current_input
        }
    end
  end

  defp normalize_input(%{} = input, %{"type" => source_type}) do
    input
    |> Map.put_new("type", source_type)
  end

  defp normalize_input(input, %{"type" => source_type}) do
    %{
      "type" => source_type,
      "value" => input
    }
  end

  defp normalize_pipeline_steps(steps) when is_list(steps) do
    steps
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {step, index}, {:ok, acc} ->
      case normalize_pipeline_step(step) do
        {:ok, normalized} ->
          {:cont, {:ok, acc ++ [normalized]}}

        {:error, reason} ->
          {:halt, {:error, ["invalid pipeline step #{index}: #{reason}"]}}
      end
    end)
    |> case do
      {:ok, []} -> {:error, ["pipeline must contain at least one step"]}
      other -> other
    end
  end

  defp normalize_pipeline_step(%{capability: capability, operation: operation})
       when is_binary(capability) and is_binary(operation) do
    {:ok, %{capability: capability, operation: operation}}
  end

  defp normalize_pipeline_step(%{"capability" => capability, "operation" => operation})
       when is_binary(capability) and is_binary(operation) do
    {:ok, %{capability: capability, operation: operation}}
  end

  defp normalize_pipeline_step({capability, operation})
       when is_binary(capability) and is_binary(operation) do
    {:ok, %{capability: capability, operation: operation}}
  end

  defp normalize_pipeline_step(step) when is_binary(step) do
    parse_step_token(step)
  end

  defp normalize_pipeline_step(other) do
    {:error, "unsupported step format #{inspect(other)}"}
  end

  defp parse_step_token(token) do
    normalized =
      token
      |> String.trim()
      |> String.trim_trailing("()")

    parts = String.split(normalized, ".", trim: true)

    cond do
      length(parts) < 3 ->
        {:error, "expected &primitive.subtype.operation() syntax, got #{inspect(token)}"}

      not String.starts_with?(hd(parts), "&") ->
        {:error, "capability must start with &: #{inspect(token)}"}

      true ->
        operation = List.last(parts)
        capability = Enum.drop(parts, -1) |> Enum.join(".")

        if capability == "" or operation == "" do
          {:error, "invalid pipeline step #{inspect(token)}"}
        else
          {:ok, %{capability: capability, operation: operation}}
        end
    end
  end

  defp effective_source_type(parsed_pipeline, opts) do
    parsed_pipeline.source_type || Keyword.get(opts, :source_type)
  end

  defp effective_source_ref(parsed_pipeline, opts) do
    parsed_pipeline.source_ref || Keyword.get(opts, :source_ref) || default_source_ref(effective_source_type(parsed_pipeline, opts))
  end

  defp render_pipeline(source_type, steps) do
    tokens =
      []
      |> append_if_present(normalize_optional_string(source_type))
      |> Kernel.++(
        Enum.map(steps, fn %{capability: capability, operation: operation} ->
          "#{capability}.#{operation}()"
        end)
      )

    Enum.join(tokens, " |> ")
  end

  defp strip_code_fences(text) do
    text
    |> String.split("\n")
    |> Enum.reject(fn line ->
      trimmed = String.trim(line)
      String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~")
    end)
    |> Enum.join("\n")
  end

  defp operation_signature(contract, operation) do
    contract
    |> get_field("operations", %{})
    |> Map.get(operation, %{})
  end

  defp resolve_provider_binding(%{} = capability_registry, capability, "auto")
       when is_binary(capability) do
    providers =
      capability_registry
      |> Registry.providers_for_capability(capability)
      |> Enum.sort_by(&Map.get(&1, "id", ""))

    case providers do
      [%{} = selected_provider | _rest] ->
        selected_provider_id = selected_provider["id"]

        {selected_provider_id,
         %{}
         |> maybe_put("status", "resolved-from-registry")
         |> maybe_put("provider", "auto")
         |> maybe_put("selected_provider", selected_provider_id)
         |> maybe_put("protocol", selected_provider["protocol"])
         |> maybe_put("transport", selected_provider["transport"])
         |> maybe_put("url", selected_provider["url"])
         |> maybe_put("published_in_registry", true)}

      _ ->
        {"auto",
         %{
           "status" => "unresolved-auto",
           "provider" => "auto",
           "capability" => capability,
           "reason" => "no registry provider found for capability #{capability}"
         }}
    end
  end

  defp resolve_provider_binding(%{} = capability_registry, _capability, provider)
       when is_binary(provider) do
    registry_provider = registry_provider(capability_registry, provider)
    {provider, provider_resolution(provider, registry_provider)}
  end

  defp resolve_provider_binding(_capability_registry, _capability, provider)
       when is_binary(provider) do
    {provider, provider_resolution(provider, nil)}
  end

  defp resolve_provider_binding(_capability_registry, _capability, _provider) do
    {nil, %{"status" => "unknown"}}
  end

  defp provider_resolution(provider, %{} = registry_provider) when is_binary(provider) do
    %{}
    |> maybe_put("status", "registry-known")
    |> maybe_put("provider", provider)
    |> maybe_put("protocol", registry_provider["protocol"])
    |> maybe_put("transport", registry_provider["transport"])
    |> maybe_put("url", registry_provider["url"])
    |> maybe_put("published_in_registry", true)
  end

  defp provider_resolution(provider, nil) when is_binary(provider) do
    %{
      "status" => "opaque",
      "provider" => provider,
      "published_in_registry" => false
    }
  end

  defp provider_resolution(_provider, _registry_provider) do
    %{"status" => "unknown"}
  end

  defp unresolved_auto_resolution_errors(plan) when is_map(plan) do
    plan
    |> Map.get("steps", [])
    |> Enum.filter(fn step ->
      get_in(step, ["provider_resolution", "status"]) == "unresolved-auto"
    end)
    |> Enum.map(fn step ->
      capability = step["capability"]
      reason = get_in(step, ["provider_resolution", "reason"]) || "unknown resolution error"
      "unable to resolve auto provider for #{capability}: #{reason}"
    end)
  end

  defp unresolved_auto_resolution_errors(_plan), do: []

  defp blocked_execution_result(plan, step_results, current_input, provenance_records, reason, step) do
    %{
      "agent" => plan["agent"],
      "version" => plan["version"],
      "status" => "blocked",
      "mode" => "simulated",
      "source" => plan["source"],
      "pipeline" => plan["pipeline"],
      "steps" => step_results,
      "step_count" => length(step_results),
      "output" => current_input,
      "governance" => plan["governance"],
      "provenance" => provenance_records,
      "blocked_reason" => reason,
      "blocked_constraint" => "hard"
    }
    |> maybe_put("blocked_at_step", step && step["index"])
    |> drop_nil_values()
  end

  defp resolution_summary(steps) do
    steps
    |> Enum.reduce(%{}, fn step, acc ->
      status =
        step
        |> get_in(["provider_resolution", "status"])
        |> normalize_optional_string("unknown")

      Map.update(acc, status, 1, &(&1 + 1))
    end)
    |> Enum.sort_by(fn {status, _count} -> status end)
    |> Enum.into(%{})
  end

  defp provenance_summary(nil), do: %{"enabled" => false}
  defp provenance_summary(false), do: %{"enabled" => false}
  defp provenance_summary(true), do: %{"enabled" => true}

  defp provenance_summary(%{} = provenance) do
    %{"enabled" => true}
    |> Map.merge(stringify_map_keys(provenance))
  end

  defp provenance_summary(other) do
    %{
      "enabled" => true,
      "value" => other
    }
  end

  defp provenance_enabled?(%{"enabled" => true}), do: true
  defp provenance_enabled?(%{enabled: true}), do: true
  defp provenance_enabled?(true), do: true
  defp provenance_enabled?(%{}), do: true
  defp provenance_enabled?(_), do: false

  defp load_registry(opts) do
    case Keyword.get(opts, :capability_registry) do
      %{} = registry ->
        registry

      _ ->
        case Keyword.get(opts, :registry_path) do
          path when is_binary(path) ->
            case Registry.load(path) do
              {:ok, registry} -> registry
              _ -> %{}
            end

          _ ->
            case Registry.load() do
              {:ok, registry} -> registry
              _ -> %{}
            end
        end
    end
  end

  defp registry_provider(%{} = registry, provider) when is_binary(provider) do
    Registry.provider(registry, provider)
  end

  defp registry_provider(_registry, _provider), do: nil

  defp registry_contract_ref(%{} = registry, capability) when is_binary(capability) do
    Registry.contract_ref_for(registry, capability)
  end

  defp registry_contract_ref(_registry, _capability), do: nil

  defp registry_summary(%{} = registry) when map_size(registry) > 0 do
    %{}
    |> maybe_put("id", registry["registry"])
    |> maybe_put("version", registry["version"])
    |> maybe_put("generated_at", registry["generated_at"])
  end

  defp registry_summary(_registry), do: nil

  defp step_timestamp(index, opts) do
    case Keyword.get(opts, :clock) do
      clock when is_function(clock, 0) ->
        case clock.() do
          %DateTime{} = dt -> DateTime.to_iso8601(DateTime.truncate(dt, :second))
          value when is_binary(value) -> value
          other -> normalize_optional_string(other, generated_timestamp(index))
        end

      _ ->
        generated_timestamp(index)
    end
  end

  defp generated_timestamp(index) do
    DateTime.utc_now()
    |> DateTime.add(index - 1, :second)
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp hash_payload(payload) do
    encoded =
      case Jason.encode(payload) do
        {:ok, json} ->
          json

        {:error, _reason} ->
          inspect(payload, pretty: false, limit: :infinity)
      end

    "sha256:" <> Base.encode16(:crypto.hash(:sha256, encoded), case: :lower)
  end

  defp fetch_any(map, keys) when is_map(map) and is_list(keys) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} -> value
        :error -> nil
      end
    end)
  end

  defp fetch_any(_map, _keys), do: nil

  defp get_field(map, key, default \\ nil)

  defp get_field(map, key, default) when is_map(map) and is_binary(key) do
    cond do
      Map.has_key?(map, key) ->
        Map.get(map, key)

      atom_key_exists?(map, key) ->
        Map.get(map, String.to_atom(key))

      true ->
        default
    end
  end

  defp get_field(_map, _key, default), do: default

  defp atom_key_exists?(map, key) do
    atom_key = String.to_atom(key)
    Map.has_key?(map, atom_key)
  rescue
    ArgumentError -> false
  end

  defp stringify_map_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  defp normalize_optional_string(nil), do: nil

  defp normalize_optional_string(value) do
    normalize_optional_string(value, nil)
  end

  defp normalize_optional_string(value, default) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> default
      normalized -> normalized
    end
  end

  defp default_source_ref(nil), do: "raw_data"
  defp default_source_ref(source_type), do: source_type

  defp append_if_present(list, nil), do: list
  defp append_if_present(list, value), do: list ++ [value]

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp drop_nil_values(map) do
    map
    |> Enum.reject(fn
      {_key, nil} -> true
      _ -> false
    end)
    |> Enum.into(%{})
  end
end
