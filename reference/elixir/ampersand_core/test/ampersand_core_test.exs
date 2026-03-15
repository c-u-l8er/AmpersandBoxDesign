defmodule AmpersandCore.TestFixtures do
  @moduledoc false

  def project_root do
    Path.expand("../../../..", __DIR__)
  end

  def schema_path do
    Path.join(project_root(), "schema/v0.1.0/ampersand.schema.json")
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

    assert manifest["unresolved_providers"] == [
             %{
               "provider" => "deliberatic",
               "capabilities" => ["&reason.argument"],
               "reason" => "no MCP resolver registered for provider"
             },
             %{
               "provider" => "geofleetic",
               "capabilities" => ["&space.fleet"],
               "reason" => "no MCP resolver registered for provider"
             },
             %{
               "provider" => "ticktickclock",
               "capabilities" => ["&time.anomaly"],
               "reason" => "no MCP resolver registered for provider"
             }
           ]
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

    assert manifest["unresolved_providers"] == [
             %{
               "provider" => "auto",
               "capabilities" => [
                 "&memory.episodic",
                 "&reason.argument",
                 "&space.fleet",
                 "&time.forecast"
               ],
               "reason" => "no MCP resolver registered for provider"
             }
           ]
  end
end
