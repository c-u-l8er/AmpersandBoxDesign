defmodule AmpersandCore.TestFixtures do
  @moduledoc false

  def project_root do
    Path.expand("../../../..", __DIR__)
  end

  def schema_path do
    Path.join(project_root(), "schema/v0.1.0/ampersand.schema.json")
  end

  def registry_path do
    Path.join(project_root(), "registry/v0.1.0/capabilities.registry.json")
  end

  def contracts_dir do
    Path.join(project_root(), "contracts/v0.1.0")
  end

  def example_path(filename) do
    Path.join(project_root(), "examples/#{filename}")
  end

  def load_example!(filename) do
    filename
    |> example_path()
    |> File.read!()
    |> Jason.decode!()
  end

  def contracts_registry do
    %{
      "&time.anomaly" => %{
        "capability" => "&time.anomaly",
        "operations" => %{
          "detect" => %{"in" => "stream_data", "out" => "anomaly_set"}
        },
        "accepts_from" => ["raw_data"],
        "feeds_into" => ["&memory.*"]
      },
      "&memory.graph" => %{
        "capability" => "&memory.graph",
        "operations" => %{
          "enrich" => %{"in" => "anomaly_set", "out" => "enriched_context"},
          "learn" => %{"in" => "decision", "out" => "ack"}
        },
        "accepts_from" => ["&time.*", "&reason.*"],
        "feeds_into" => ["&reason.*", "output"]
      },
      "&reason.argument" => %{
        "capability" => "&reason.argument",
        "operations" => %{
          "evaluate" => %{"in" => "enriched_context", "out" => "decision"}
        },
        "accepts_from" => ["&memory.*"],
        "feeds_into" => ["&memory.*", "output"]
      }
    }
  end
end

defmodule AmpersandCoreSchemaTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "default schema path points at the canonical protocol schema" do
    assert File.exists?(Fixtures.schema_path())
    assert AmpersandCore.Schema.default_schema_path() == Fixtures.schema_path()
  end

  test "all reference examples validate against the canonical schema" do
    for file <- [
          "infra-operator.ampersand.json",
          "fleet-manager.ampersand.json",
          "research-agent.ampersand.json"
        ] do
      assert {:ok, document} = AmpersandCore.Schema.validate_file(Fixtures.example_path(file))
      assert is_map(document)
      assert document["$schema"] == "https://protocol.ampersandboxdesign.com/v0.1/schema.json"
    end
  end

  test "auto provider declarations require a natural language need" do
    invalid_document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "AutoButUnderspecified",
      "version" => "0.1.0",
      "capabilities" => %{
        "&memory.episodic" => %{
          "provider" => "auto"
        }
      }
    }

    assert {:error, errors} = AmpersandCore.Schema.validate(invalid_document)
    assert Enum.any?(errors, &String.contains?(&1, "need"))
  end

  test "invalid capability identifiers are rejected" do
    invalid_document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
      "agent" => "BadCapability",
      "version" => "0.1.0",
      "capabilities" => %{
        "memory.graph" => %{
          "provider" => "graphonomous"
        }
      }
    }

    assert {:error, errors} = AmpersandCore.Schema.validate(invalid_document)
    assert Enum.any?(errors, &String.contains?(&1, "capability"))
  end
end

defmodule AmpersandCoreArtifactLoadingTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "contract artifacts load from the versioned contracts directory" do
    assert {:ok, contracts} = AmpersandCore.load_contracts()

    assert Map.has_key?(contracts, "&memory.graph")
    assert Map.has_key?(contracts, "&memory.episodic")
    assert Map.has_key?(contracts, "&reason.argument")
    assert Map.has_key?(contracts, "&time.forecast")
    assert Map.has_key?(contracts, "&space.fleet")

    assert contracts["&memory.graph"]["operations"]["recall"]["out"] == "memory_hits"

    assert contracts["&time.forecast"]["a2a_skills"] == [
             "temporal-forecasting",
             "demand-prediction",
             "trend-explanation"
           ]
  end

  test "registry artifact loads from the canonical registry path" do
    assert {:ok, registry} = AmpersandCore.load_registry()

    assert AmpersandCore.Registry.default_registry_path() == Fixtures.registry_path()
    assert "&memory.graph" in AmpersandCore.Registry.list_capabilities(registry)

    assert registry["&time"]["subtypes"]["forecast"]["contract_ref"] ==
             "/contracts/v0.1.0/time.forecast.contract.json"

    assert AmpersandCore.Registry.provider(registry, "graphonomous")["protocol"] == "mcp_v1"
  end

  test "artifact-backed contract loading can be scoped to a declaration" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    assert {:ok, contracts} = AmpersandCore.Contracts.load_contracts_for_document(infra)

    assert Map.keys(contracts) |> Enum.sort() == [
             "&memory.graph",
             "&reason.argument",
             "&space.fleet"
           ]
  end
end

defmodule AmpersandCoreComposeTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "normalize returns a sorted set-like view of capability identifiers" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    assert AmpersandCore.Compose.normalize(infra["capabilities"]) == [
             "&memory.graph",
             "&reason.argument",
             "&space.fleet",
             "&time.anomaly"
           ]
  end

  test "compose merges disjoint capability sets" do
    left = %{
      "&memory.graph" => %{"provider" => "graphonomous"}
    }

    right = %{
      "&time.anomaly" => %{"provider" => "ticktickclock"}
    }

    assert {:ok, composed} = AmpersandCore.Compose.compose([left, right])

    assert composed == %{
             "&memory.graph" => %{"provider" => "graphonomous"},
             "&time.anomaly" => %{"provider" => "ticktickclock"}
           }
  end

  test "composition is commutative for compatible capability sets" do
    left = %{
      "&memory.graph" => %{"provider" => "graphonomous"}
    }

    right = %{
      "&reason.argument" => %{"provider" => "deliberatic"}
    }

    assert AmpersandCore.Compose.commutative?(left, right)
  end

  test "composition is idempotent for repeated declarations" do
    capabilities = %{
      "&space.fleet" => %{"provider" => "geofleetic"}
    }

    assert AmpersandCore.Compose.idempotent?(capabilities)
  end

  test "identity composes cleanly with any capability set" do
    capabilities = %{
      "&time.anomaly" => %{"provider" => "ticktickclock"},
      "&memory.graph" => %{"provider" => "graphonomous"}
    }

    assert AmpersandCore.Compose.identity?(capabilities)
  end

  test "composition is associative for compatible groupings" do
    left = %{
      "&memory.graph" => %{"provider" => "graphonomous"}
    }

    middle = %{
      "&time.anomaly" => %{"provider" => "ticktickclock"}
    }

    right = %{
      "&reason.argument" => %{"provider" => "deliberatic"}
    }

    assert AmpersandCore.Compose.associative?(left, middle, right)
  end

  test "conflicting bindings for the same capability are rejected" do
    left = %{
      "&memory.graph" => %{"provider" => "graphonomous"}
    }

    right = %{
      "&memory.graph" => %{"provider" => "neo4j-memory"}
    }

    assert {:error, {:conflicting_binding, "&memory.graph", _, _}} =
             AmpersandCore.Compose.compose([left, right])
  end
end

defmodule AmpersandCoreContractsTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "a valid pipeline passes contract and type checks end to end" do
    contracts = Fixtures.contracts_registry()

    pipeline = [
      {"&time.anomaly", "detect"},
      {"&memory.graph", "enrich"},
      {"&reason.argument", "evaluate"},
      {"&memory.graph", "learn"}
    ]

    assert :ok =
             AmpersandCore.Contracts.check_pipeline(
               contracts,
               pipeline,
               source_type: "stream_data",
               source_ref: "raw_data"
             )
  end

  test "pipeline validation rejects output and input type mismatches" do
    contracts =
      put_in(
        Fixtures.contracts_registry(),
        ["&memory.graph", "operations", "enrich", "in"],
        "context"
      )

    pipeline = [
      {"&time.anomaly", "detect"},
      {"&memory.graph", "enrich"}
    ]

    assert {:error, errors} =
             AmpersandCore.Contracts.check_pipeline(
               contracts,
               pipeline,
               source_type: "stream_data",
               source_ref: "raw_data"
             )

    assert Enum.any?(errors, &String.contains?(&1, "type mismatch"))
  end

  test "pipeline validation rejects incompatible capability adjacency" do
    contracts =
      put_in(
        Fixtures.contracts_registry(),
        ["&reason.argument", "accepts_from"],
        ["&space.*"]
      )

    pipeline = [
      {"&time.anomaly", "detect"},
      {"&memory.graph", "enrich"},
      {"&reason.argument", "evaluate"}
    ]

    assert {:error, errors} =
             AmpersandCore.Contracts.check_pipeline(
               contracts,
               pipeline,
               source_type: "stream_data",
               source_ref: "raw_data"
             )

    assert Enum.any?(errors, &String.contains?(&1, "cannot accept input"))
  end

  test "wildcard capability patterns are honored in accepts_from and feeds_into" do
    contracts = Fixtures.contracts_registry()

    pipeline = [
      %{capability: "&time.anomaly", operation: "detect"},
      %{capability: "&memory.graph", operation: "enrich"}
    ]

    assert :ok =
             AmpersandCore.Contracts.check_pipeline(
               contracts,
               pipeline,
               source_type: "stream_data",
               source_ref: "raw_data"
             )
  end
end

defmodule AmpersandCoreMCPTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "client_config emits zed-compatible MCP config for resolvable providers" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    assert {:ok, %{"context_servers" => context_servers}} =
             AmpersandCore.MCP.client_config(infra)

    assert %{"graphonomous" => graphonomous} = context_servers

    assert graphonomous["command"] == "npx"

    assert graphonomous["args"] == [
             "-y",
             "graphonomous",
             "--db",
             "~/.graphonomous/knowledge.db",
             "--embedder-backend",
             "fallback"
           ]

    assert graphonomous["env"] == %{
             "GRAPHONOMOUS_EMBEDDING_MODEL" =>
               "sentence-transformers/all-MiniLM-L6-v2"
           }

    assert graphonomous["transport"] == "stdio"
  end

  test "manifest preserves unresolved providers as metadata" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    assert {:ok, manifest} = AmpersandCore.MCP.generate(infra)

    assert manifest["agent"] == "InfraOperator"
    assert manifest["format"] == "context_servers"
    assert manifest["providers"]["graphonomous"]["capabilities"] == ["&memory.graph"]
    assert manifest["providers"]["graphonomous"]["published_in_registry"] == true
    assert manifest["providers"]["graphonomous"]["protocol"] == "mcp_v1"

    assert manifest["registry"] == %{
             "generated_at" => "2026-03-15T00:00:00Z",
             "id" => "registry.ampersandboxdesign.com",
             "version" => "0.1.0"
           }

    assert Enum.map(manifest["unresolved_providers"], & &1["provider"]) == [
             "deliberatic",
             "geofleetic",
             "ticktickclock"
           ]

    assert Enum.all?(manifest["unresolved_providers"], fn entry ->
             entry["published_in_registry"] == true and
               entry["reason"] ==
                 "provider is published in registry but no local MCP resolver is implemented" and
               is_map(entry["registry_provider"])
           end)
  end

  test "client config accepts provider registry overrides for local development" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    custom_registry = %{
      "graphonomous" => fn provider, bindings, _opts ->
        {:ok,
         {provider,
          %{
            "command" =>
              "/home/travis/ProjectAmp2/graphonomous/scripts/graphonomous_mcp_wrapper.sh",
            "args" => [],
            "env" => %{},
            "transport" => "stdio",
            "provider" => provider,
            "capabilities" => Enum.map(bindings, & &1.capability)
          }}}
      end
    }

    assert {:ok, %{"context_servers" => %{"graphonomous" => graphonomous}}} =
             AmpersandCore.MCP.client_config(
               infra,
               provider_registry: custom_registry
             )

    assert graphonomous["command"] ==
             "/home/travis/ProjectAmp2/graphonomous/scripts/graphonomous_mcp_wrapper.sh"

    assert graphonomous["args"] == []
    assert graphonomous["env"] == %{}
    assert graphonomous["transport"] == "stdio"
  end

  test "manifest leaves auto-resolved capabilities pending until registry resolution occurs" do
    fleet = Fixtures.load_example!("fleet-manager.ampersand.json")

    assert {:ok, manifest} = AmpersandCore.MCP.generate(fleet)

    assert manifest["config"] == %{"context_servers" => %{}}
    assert manifest["registry"]["id"] == "registry.ampersandboxdesign.com"

    assert manifest["unresolved_providers"] == [
             %{
               "provider" => "auto",
               "capabilities" => [
                 "&memory.episodic",
                 "&reason.argument",
                 "&space.fleet",
                 "&time.forecast"
               ],
               "reason" => "provider resolution required from capability registry",
               "published_in_registry" => false
             }
           ]
  end
end

defmodule AmpersandCoreA2ATest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "agent card generation advertises composed capabilities as skills" do
    infra = Fixtures.load_example!("infra-operator.ampersand.json")

    assert {:ok, card} = AmpersandCore.A2A.generate(infra)

    assert card["name"] == "InfraOperator"
    assert card["version"] == "1.0.0"

    skill_ids =
      card["skills"]
      |> Enum.map(& &1["capability"])
      |> Enum.sort()

    assert skill_ids == [
             "&memory.graph",
             "&reason.argument",
             "&space.fleet",
             "&time.anomaly"
           ]

    assert Enum.any?(card["skills"], fn skill ->
             skill["capability"] == "&memory.graph" and
               skill["provider"] == "graphonomous" and
               "memory" in skill["tags"]
           end)

    assert card["metadata"]["providers"] == [
             "deliberatic",
             "geofleetic",
             "graphonomous",
             "ticktickclock"
           ]
  end

  test "agent card keeps unresolved auto providers visible in metadata" do
    fleet = Fixtures.load_example!("fleet-manager.ampersand.json")

    assert {:ok, card} = AmpersandCore.A2A.generate(fleet)

    assert card["name"] == "FleetManager"

    assert card["metadata"]["providers"] == ["auto"]

    assert card["metadata"]["a2a_skill_map"] == %{
             "&memory.episodic" => [
               "episodic-memory-recall",
               "experience-replay",
               "session-history-enrichment"
             ],
             "&reason.argument" => [
               "decision-evaluation",
               "decision-justification",
               "evidence-based-deliberation"
             ],
             "&space.fleet" => [
               "fleet-state-enrichment",
               "regional-capacity-lookup",
               "route-feasibility-evaluation"
             ],
             "&time.forecast" => [
               "demand-prediction",
               "temporal-forecasting",
               "trend-explanation"
             ]
           }

    assert Enum.all?(card["skills"], fn skill ->
             skill["provider"] == "auto" and "provider:auto" not in (skill["tags"] || [])
           end)

    assert Enum.map(card["skills"], & &1["capability"]) == [
             "&memory.episodic",
             "&reason.argument",
             "&space.fleet",
             "&time.forecast"
           ]
  end
end

defmodule AmpersandCoreCLITest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "validate command returns ok for a valid declaration" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["validate", path])
    assert output =~ "valid"
    assert output =~ "InfraOperator"
  end

  test "generate mcp command returns direct client configuration JSON" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["generate", "mcp", path])

    decoded = Jason.decode!(output)

    assert decoded["context_servers"]["graphonomous"]["command"] == "npx"

    assert decoded["context_servers"]["graphonomous"]["args"] == [
             "-y",
             "graphonomous",
             "--db",
             "~/.graphonomous/knowledge.db",
             "--embedder-backend",
             "fallback"
           ]
  end

  test "generate a2a command returns direct agent card JSON" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["generate", "a2a", path])

    decoded = Jason.decode!(output)

    assert decoded["name"] == "InfraOperator"
    assert Enum.any?(decoded["skills"], &(&1["capability"] == "&memory.graph"))
    assert Enum.any?(decoded["skills"], &(&1["capability"] == "&time.anomaly"))
  end

  test "compose command summarizes normalized capabilities and artifact coverage" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["compose", path])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "compose"
    assert decoded["capabilities"] == [
             "&memory.graph",
             "&reason.argument",
             "&space.fleet",
             "&time.anomaly"
           ]

    assert decoded["aci"] == %{
             "associative" => true,
             "commutative" => true,
             "idempotent" => true,
             "identity" => true
           }

    assert decoded["contracts"] == %{
             "contract_count" => 3,
             "loaded" => [
               "&memory.graph",
               "&reason.argument",
               "&space.fleet"
             ],
             "missing" => ["&time.anomaly"]
           }

    assert decoded["registry"]["known_capabilities"] == [
             "&memory.graph",
             "&reason.argument",
             "&space.fleet",
             "&time.anomaly"
           ]

    assert decoded["registry"]["known_providers"] == [
             "deliberatic",
             "geofleetic",
             "graphonomous",
             "ticktickclock"
           ]
  end

  test "unknown generate target returns a helpful error" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:error, output, 1} = AmpersandCore.CLI.run(["generate", "invalid-target", path])

    assert output =~ "unknown_generate_target"
    assert output =~ "mcp"
    assert output =~ "a2a"
  end
end
