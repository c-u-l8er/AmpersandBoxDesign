defmodule AmpersandCoreRuntimeAutoResolutionTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "runtime plan resolves provider:auto from the capability registry" do
    document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "AutoRuntime",
      "version" => "0.1.0",
      "capabilities" => %{
        "&time.anomaly" => %{
          "provider" => "auto",
          "need" => "stream anomaly detection for telemetry"
        }
      },
      "provenance" => true
    }

    pipeline = [%{"capability" => "&time.anomaly", "operation" => "detect"}]

    assert {:ok, plan} =
             AmpersandCore.Runtime.plan(
               document,
               pipeline,
               source_type: "stream_data",
               source_ref: "raw_data"
             )

    assert [step] = plan["steps"]
    assert step["provider"] == "ticktickclock"

    assert step["provider_resolution"] == %{
             "published_in_registry" => true,
             "provider" => "auto",
             "protocol" => "mcp_v1",
             "selected_provider" => "ticktickclock",
             "status" => "resolved-from-registry",
             "transport" => "custom",
             "url" => "https://ticktickclock.com"
           }
  end

  test "runtime plan returns a clear error when auto provider cannot be resolved" do
    document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "AutoRuntimeNoMatch",
      "version" => "0.1.0",
      "capabilities" => %{
        "&time.anomaly" => %{
          "provider" => "auto",
          "need" => "stream anomaly detection for telemetry"
        }
      },
      "provenance" => true
    }

    pipeline = [%{"capability" => "&time.anomaly", "operation" => "detect"}]

    assert {:error, errors} =
             AmpersandCore.Runtime.plan(
               document,
               pipeline,
               source_type: "stream_data",
               source_ref: "raw_data",
               capability_registry: %{}
             )

    assert Enum.any?(errors, fn error ->
             String.contains?(error, "unable to resolve auto provider for &time.anomaly")
           end)
  end
end

defmodule AmpersandCoreMCPAutoResolutionTest do
  use ExUnit.Case, async: true

  test "mcp generation resolves auto providers from registry-backed capabilities" do
    document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "AutoMCP",
      "version" => "0.1.0",
      "capabilities" => %{
        "&time.anomaly" => %{
          "provider" => "auto",
          "need" => "stream anomaly detection for telemetry"
        },
        "&memory.graph" => %{
          "provider" => "auto",
          "need" => "graph memory for incident context"
        }
      },
      "provenance" => true
    }

    assert {:ok, manifest} = AmpersandCore.MCP.generate(document)

    assert manifest["config"]["context_servers"]["ticktickclock"]["command"] == "npx"
    assert manifest["config"]["context_servers"]["graphonomous"]["command"] == "npx"
    assert manifest["unresolved_providers"] == []
  end

  test "mcp generation preserves unresolved auto providers when registry has no matches" do
    document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "AutoMCPNoMatch",
      "version" => "0.1.0",
      "capabilities" => %{
        "&time.anomaly" => %{
          "provider" => "auto",
          "need" => "stream anomaly detection for telemetry"
        }
      },
      "provenance" => true
    }

    assert {:ok, manifest} =
             AmpersandCore.MCP.generate(document, capability_registry: %{})

    assert manifest["config"] == %{"context_servers" => %{}}

    assert manifest["unresolved_providers"] == [
             %{
               "provider" => "auto",
               "capabilities" => ["&time.anomaly"],
               "reason" => "no registry provider found for capability &time.anomaly",
               "published_in_registry" => false
             }
           ]

    assert {:error, errors} =
             AmpersandCore.MCP.generate(
               document,
               capability_registry: %{},
               strict: true
             )

    assert Enum.any?(errors, fn error ->
             String.contains?(error, "unresolved provider auto")
           end)
  end
end

defmodule AmpersandCoreRuntimeGovernanceEnforcementTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "normal execution proceeds with no escalation when escalate_when is absent" do
    document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "GovernancePass",
      "version" => "0.1.0",
      "capabilities" => %{
        "&time.anomaly" => %{
          "provider" => "ticktickclock",
          "config" => %{"streams" => ["cpu"]}
        }
      },
      "governance" => %{
        "hard" => ["input.requires_review=true"]
      },
      "provenance" => true
    }

    pipeline = [%{"capability" => "&time.anomaly", "operation" => "detect"}]

    assert {:ok, execution} =
             AmpersandCore.Runtime.run(
               document,
               pipeline,
               %{"requires_review" => false},
               source_type: "stream_data",
               source_ref: "raw_data"
             )

    assert execution["status"] == "ok"
    assert execution["governance"] == document["governance"]
    assert execution["escalation_triggered"] == nil
    assert Enum.all?(execution["steps"], fn step -> is_nil(step["escalation"]) end)
  end

  test "execution annotates steps and top-level result when escalation is triggered" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    pipeline = [
      %{"capability" => "&time.anomaly", "operation" => "detect"},
      %{"capability" => "&memory.graph", "operation" => "enrich"},
      %{"capability" => "&reason.argument", "operation" => "evaluate"}
    ]

    executors = %{
      {"&reason.argument", "evaluate"} => fn _step, _input, _ctx ->
        %{"decision" => "hold", "confidence" => 0.42}
      end
    }

    assert {:ok, execution} =
             AmpersandCore.Runtime.run(
               infra,
               pipeline,
               %{"stream" => "cpu", "samples" => [0.2, 0.8, 0.9]},
               source_type: "stream_data",
               source_ref: "raw_data",
               executors: executors
             )

    assert execution["status"] == "ok"
    assert execution["escalation_triggered"] == true
    assert execution["governance"] == infra["governance"]

    assert Enum.any?(execution["steps"], fn step ->
             is_map(step["escalation"]) and step["escalation"]["triggered"] == true
           end)
  end

  test "hard governance constraints block execution" do
    document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "GovernanceBlock",
      "version" => "0.1.0",
      "capabilities" => %{
        "&time.anomaly" => %{
          "provider" => "ticktickclock",
          "config" => %{"streams" => ["cpu"]}
        }
      },
      "governance" => %{
        "hard" => ["input.cross_region_impact=true"]
      },
      "provenance" => true
    }

    pipeline = [%{"capability" => "&time.anomaly", "operation" => "detect"}]

    assert {:ok, execution} =
             AmpersandCore.Runtime.run(
               document,
               pipeline,
               %{"cross_region_impact" => true},
               source_type: "stream_data",
               source_ref: "raw_data"
             )

    assert execution["status"] == "blocked"
    assert execution["blocked_constraint"] == "hard"
    assert execution["step_count"] == 0
    assert execution["governance"] == document["governance"]
  end

  test "cli run output includes escalation fields when governance escalation condition matches output" do
    declaration_path =
      Fixtures.write_json_fixture!("governance-escalation", %{
        "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
        "agent" => "GovernanceEscalationCLI",
        "version" => "0.1.0",
        "capabilities" => %{
          "&time.anomaly" => %{
            "provider" => "ticktickclock",
            "config" => %{"streams" => ["cpu"]}
          }
        },
        "governance" => %{
          "escalate_when" => %{
            "type" => "anomaly_set"
          }
        },
        "provenance" => true
      })

    pipeline_path =
      Fixtures.pipeline_fixture!([
        %{"capability" => "&time.anomaly", "operation" => "detect"}
      ])

    input_path =
      Fixtures.input_fixture!(%{
        "stream" => "cpu",
        "samples" => [0.1, 0.95, 0.2]
      })

    assert {:ok, output} =
             AmpersandCore.CLI.run(["run", declaration_path, pipeline_path, input_path])

    decoded = Jason.decode!(output)

    assert decoded["status"] == "ok"
    assert decoded["escalation_triggered"] == true

    assert Enum.any?(decoded["steps"], fn step ->
             is_map(step["escalation"]) and
               step["escalation"]["triggered"] == true and
               step["escalation"]["condition"] == "escalate_when"
           end)
  end
end

defmodule AmpersandCoreCLIMultiFileComposeTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "compose command accepts multiple compatible declaration files" do
    infra_path = Fixtures.example_path("infra-operator.ampersand.json")

    additive_path =
      Fixtures.write_json_fixture!("compose-compatible", %{
        "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
        "agent" => "ComposeCompatibleAddon",
        "version" => "0.1.0",
        "capabilities" => %{
          "&memory.vector" => %{
            "provider" => "pgvector",
            "config" => %{
              "index" => "incidents",
              "namespace" => "infra"
            }
          }
        },
        "provenance" => true
      })

    assert {:ok, output} = AmpersandCore.CLI.run(["compose", infra_path, additive_path])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "compose"
    assert decoded["status"] == "ok"
    assert decoded["file_count"] == 2
    assert Enum.sort(decoded["files"]) == Enum.sort([infra_path, additive_path])
    assert "&memory.vector" in decoded["capabilities"]
    assert "&memory.graph" in decoded["capabilities"]
  end

  test "compose command reports conflicts for incompatible declaration files" do
    infra_path = Fixtures.example_path("infra-operator.ampersand.json")

    conflicting_path =
      Fixtures.write_json_fixture!("compose-conflict", %{
        "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
        "agent" => "ComposeConflictAddon",
        "version" => "0.1.0",
        "capabilities" => %{
          "&memory.graph" => %{
            "provider" => "neo4j-memory"
          }
        },
        "provenance" => true
      })

    assert {:error, output, 1} = AmpersandCore.CLI.run(["compose", infra_path, conflicting_path])

    decoded = Jason.decode!(output)

    assert decoded["status"] == "error"
    assert decoded["error"] == "compose_failed"

    assert Enum.any?(decoded["errors"], fn error ->
             String.contains?(error, "conflicting_binding")
           end)
  end
end
