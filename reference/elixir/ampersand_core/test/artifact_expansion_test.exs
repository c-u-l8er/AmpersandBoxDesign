defmodule AmpersandCore.ArtifactExpansionFixtures do
  @moduledoc false

  def project_root do
    Path.expand("../../../..", __DIR__)
  end

  def contracts_dir do
    Path.join(project_root(), "contracts/v0.1.0")
  end

  def registry_path do
    Path.join(project_root(), "protocol/registry/v0.1.0/capabilities.registry.json")
  end

  def example_path(filename) do
    Path.join(project_root(), "examples/#{filename}")
  end
end

defmodule AmpersandCoreExpandedArtifactsTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.ArtifactExpansionFixtures, as: Fixtures

  test "expanded contract artifacts load from the versioned contracts directory" do
    assert {:ok, contracts} = AmpersandCore.load_contracts()

    assert Map.keys(contracts) |> Enum.sort() == [
             "&body.browser",
             "&body.os",
             "&govern.escalation",
             "&govern.identity",
             "&govern.telemetry",
             "&memory.episodic",
             "&memory.graph",
             "&memory.vector",
             "&reason.argument",
             "&reason.attend",
             "&reason.deliberate",
             "&reason.plan",
             "&reason.vote",
             "&space.fleet",
             "&space.geofence",
             "&space.route",
             "&time.anomaly",
             "&time.forecast",
             "&time.pattern"
           ]

    assert contracts["&memory.vector"]["operations"]["search"]["out"] == "memory_hits"
    assert contracts["&time.anomaly"]["operations"]["detect"]["in"] == "stream_data"

    assert contracts["&reason.plan"]["a2a_skills"] == [
             "goal-plan-generation",
             "plan-revision"
           ]

    assert contracts["&space.geofence"]["operations"]["enter_exit"]["out"] == "boundary_events"
    assert contracts["&space.route"]["operations"]["optimize"]["out"] == "optimized_route"
  end

  test "expanded registry artifact publishes contract refs for the newly added capability subtypes" do
    assert {:ok, registry} = AmpersandCore.load_registry()

    expected_contract_refs = %{
      "&memory.vector" => "/contracts/v0.1.0/memory.vector.contract.json",
      "&reason.attend" => "/contracts/v0.1.0/reason.attend.contract.json",
      "&reason.deliberate" => "/contracts/v0.1.0/reason.deliberate.contract.json",
      "&reason.plan" => "/contracts/v0.1.0/reason.plan.contract.json",
      "&reason.vote" => "/contracts/v0.1.0/reason.vote.contract.json",
      "&space.geofence" => "/contracts/v0.1.0/space.geofence.contract.json",
      "&space.route" => "/contracts/v0.1.0/space.route.contract.json",
      "&time.anomaly" => "/contracts/v0.1.0/time.anomaly.contract.json",
      "&time.pattern" => "/contracts/v0.1.0/time.pattern.contract.json"
    }

    actual_contract_refs =
      expected_contract_refs
      |> Map.keys()
      |> Enum.map(fn capability ->
        {capability, AmpersandCore.Registry.contract_ref_for(registry, capability)}
      end)
      |> Enum.into(%{})

    assert actual_contract_refs == expected_contract_refs

    assert AmpersandCore.Registry.provider(registry, "deliberatic")["subtypes"] |> Enum.sort() == [
             "argument",
             "plan",
             "vote"
           ]

    assert AmpersandCore.Registry.providers_for_capability(registry, "&reason.deliberate")
           |> Enum.map(& &1["id"]) == ["graphonomous"]

    assert AmpersandCore.Registry.provider(registry, "ticktickclock")["subtypes"] == [
             "anomaly",
             "forecast",
             "pattern"
           ]

    assert AmpersandCore.Registry.provider(registry, "geofleetic")["subtypes"] == [
             "fleet",
             "route",
             "geofence"
           ]
  end

  test "scoped contract loading covers example declarations that depend on expanded artifacts" do
    assert {:ok, customer_support} =
             AmpersandCore.validate_file(Fixtures.example_path("customer-support.ampersand.json"))

    assert {:ok, research_agent} =
             AmpersandCore.validate_file(Fixtures.example_path("research-agent.ampersand.json"))

    assert {:ok, customer_support_contracts} =
             AmpersandCore.Contracts.load_contracts_for_document(customer_support, strict: true)

    assert Map.keys(customer_support_contracts) |> Enum.sort() == [
             "&memory.episodic",
             "&memory.vector",
             "&reason.argument",
             "&time.pattern"
           ]

    assert {:ok, research_contracts} =
             AmpersandCore.Contracts.load_contracts_for_document(research_agent, strict: true)

    assert Map.keys(research_contracts) |> Enum.sort() == [
             "&memory.vector",
             "&reason.argument",
             "&time.pattern"
           ]
  end
end

defmodule AmpersandCoreCLIRegistryCommandsTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.ArtifactExpansionFixtures, as: Fixtures

  test "validate-contract command returns artifact details for a newly added contract" do
    path = Path.join(Fixtures.contracts_dir(), "memory.vector.contract.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["validate-contract", path])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "validate-contract"
    assert decoded["status"] == "ok"
    assert decoded["valid"] == true
    assert decoded["file"] == path
    assert decoded["capability"] == "&memory.vector"
    assert decoded["provider"] == "pgvector"
    assert decoded["version"] == "0.1.0"

    assert decoded["operations"] == [
             "enrich",
             "search",
             "upsert"
           ]

    assert decoded["operation_count"] == 3
  end

  test "validate-registry command works for the default registry and an explicit registry path" do
    assert {:ok, default_output} = AmpersandCore.CLI.run(["validate-registry"])
    default_decoded = Jason.decode!(default_output)

    assert default_decoded["command"] == "validate-registry"
    assert default_decoded["status"] == "ok"
    assert default_decoded["valid"] == true
    assert default_decoded["file"] == AmpersandCore.Registry.default_registry_path()
    assert default_decoded["registry"] == "registry.ampersandboxdesign.com"
    assert default_decoded["primitive_count"] == 6
    assert default_decoded["capability_count"] == 22
    assert default_decoded["provider_count"] == 12

    explicit_path = Fixtures.registry_path()

    assert {:ok, explicit_output} = AmpersandCore.CLI.run(["validate-registry", explicit_path])

    explicit_decoded = Jason.decode!(explicit_output)

    assert explicit_decoded["command"] == "validate-registry"
    assert explicit_decoded["status"] == "ok"
    assert explicit_decoded["valid"] == true
    assert explicit_decoded["file"] == explicit_path
    assert explicit_decoded["registry"] == "registry.ampersandboxdesign.com"
    assert explicit_decoded["primitive_count"] == 6
    assert explicit_decoded["capability_count"] == 22
    assert explicit_decoded["provider_count"] == 12
  end

  test "registry list command reports expanded registry coverage" do
    assert {:ok, output} = AmpersandCore.CLI.run(["registry", "list"])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "registry"
    assert decoded["subcommand"] == "list"
    assert decoded["status"] == "ok"

    assert decoded["registry"] == %{
             "generated_at" => "2026-03-15T00:00:00Z",
             "id" => "registry.ampersandboxdesign.com",
             "version" => "0.1.0"
           }

    assert decoded["primitives"] == ["&body", "&govern", "&memory", "&reason", "&space", "&time"]
    assert decoded["primitive_count"] == 6
    assert decoded["capability_count"] == 22
    assert decoded["provider_count"] == 12

    assert decoded["providers"] == [
             "agent-browser",
             "claude-computer-use",
             "delegatic",
             "deliberatic",
             "geofleetic",
             "graphonomous",
             "neo4j-memory",
             "openclaw",
             "opensentience",
             "pgvector",
             "ticktickclock",
             "weaviate"
           ]

    assert decoded["contract_backed_capabilities"] == [
             "&body.browser",
             "&body.os",
             "&govern.escalation",
             "&govern.identity",
             "&govern.telemetry",
             "&memory.episodic",
             "&memory.graph",
             "&memory.vector",
             "&reason.argument",
             "&reason.attend",
             "&reason.deliberate",
             "&reason.plan",
             "&reason.vote",
             "&space.fleet",
             "&space.geofence",
             "&space.route",
             "&time.anomaly",
             "&time.forecast",
             "&time.pattern"
           ]
  end

  test "registry providers command returns registry-backed provider metadata for a contract-backed capability" do
    assert {:ok, output} = AmpersandCore.CLI.run(["registry", "providers", "&memory.vector"])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "registry"
    assert decoded["subcommand"] == "providers"
    assert decoded["status"] == "ok"
    assert decoded["capability"] == "&memory.vector"
    assert decoded["contract_ref"] == "/contracts/v0.1.0/memory.vector.contract.json"

    assert decoded["operations"] == [
             "enrich",
             "search",
             "upsert"
           ]

    assert decoded["a2a_skills"] == [
             "knowledge-base-enrichment",
             "semantic-retrieval"
           ]

    assert decoded["provider_count"] == 2
    assert Enum.map(decoded["providers"], & &1["id"]) == ["pgvector", "weaviate"]

    assert Enum.all?(decoded["providers"], fn provider ->
             provider["contract_ref"] == "/contracts/v0.1.0/memory.vector.contract.json" and
               provider["protocol"] == "mcp_v1"
           end)
  end

  test "registry providers command rejects unknown capabilities" do
    assert {:error, output, 1} =
             AmpersandCore.CLI.run(["registry", "providers", "&reason.not-real"])

    decoded = Jason.decode!(output)

    assert decoded["status"] == "error"
    assert decoded["error"] == "unknown_capability"
    assert decoded["command"] == "registry"
    assert decoded["subcommand"] == "providers"
    assert decoded["capability"] == "&reason.not-real"

    assert Enum.any?(decoded["errors"], fn error ->
             String.contains?(error, "is not defined in the registry")
           end)
  end
end
