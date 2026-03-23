defmodule AmpersandCoreCLINamedPipelinesPhaseTwoTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "schema validation accepts declarations with named pipelines" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, document} = AmpersandCore.Schema.validate_file(path)
    assert is_map(document["pipelines"])
    assert is_map(document["pipelines"]["incident_triage"])
  end

  test "check command resolves named pipeline from declaration with --pipeline" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["check", path, "--pipeline", "incident_triage"])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "check"
    assert decoded["status"] == "ok"
    assert decoded["valid"] == true
    assert decoded["pipeline_name"] == "incident_triage"
    assert decoded["step_count"] == 3
    assert decoded["source"] == %{"type" => "stream_data", "ref" => "raw_data"}
  end

  test "plan command resolves named pipeline from declaration with --pipeline" do
    path = Fixtures.example_path("infra-operator.ampersand.json")

    assert {:ok, output} = AmpersandCore.CLI.run(["plan", path, "--pipeline", "incident_triage"])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "plan"
    assert decoded["status"] == "ok"
    assert decoded["pipeline_name"] == "incident_triage"
    assert decoded["step_count"] == 3

    assert Enum.map(decoded["steps"], & &1["provider"]) == [
             "ticktickclock",
             "graphonomous",
             "deliberatic"
           ]
  end
end

defmodule AmpersandCoreCLIGenerateFlagsPhaseTwoTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "generate mcp supports --format and --output flags" do
    path = Fixtures.example_path("infra-operator.ampersand.json")
    output_path = Fixtures.temp_path("mcp-generic-output")

    assert {:ok, output} =
             AmpersandCore.CLI.run([
               "generate",
               "mcp",
               path,
               "--format",
               "generic",
               "--output",
               output_path
             ])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "generate"
    assert decoded["target"] == "mcp"
    assert decoded["status"] == "ok"
    assert decoded["file"] == path
    assert decoded["format"] == "generic"
    assert decoded["output"] == output_path

    assert File.exists?(output_path)
    persisted = output_path |> File.read!() |> Jason.decode!()
    assert is_map(persisted["mcpServers"])
    assert persisted["mcpServers"]["graphonomous"]["command"] == "npx"
  end

  test "generate a2a supports -o output flag" do
    path = Fixtures.example_path("infra-operator.ampersand.json")
    output_path = Fixtures.temp_path("a2a-output")

    assert {:ok, output} =
             AmpersandCore.CLI.run(["generate", "a2a", path, "-o", output_path])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "generate"
    assert decoded["target"] == "a2a"
    assert decoded["status"] == "ok"
    assert decoded["output"] == output_path

    assert File.exists?(output_path)
    persisted = output_path |> File.read!() |> Jason.decode!()
    assert persisted["name"] == "InfraOperator"
    assert is_list(persisted["skills"])
  end
end

defmodule AmpersandCoreCLIDiffPhaseTwoTest do
  use ExUnit.Case, async: true

  alias AmpersandCore.TestFixtures, as: Fixtures

  test "diff command reports capability, provider, governance, and provenance changes" do
    left_path = Fixtures.example_path("infra-operator.ampersand.json")

    right_document = %{
      "$schema" => "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
      "agent" => "InfraOperatorV2",
      "version" => "1.1.0",
      "capabilities" => %{
        "&memory.graph" => %{"provider" => "neo4j-memory"},
        "&time.anomaly" => %{"provider" => "ticktickclock"},
        "&reason.argument" => %{"provider" => "deliberatic"},
        "&memory.vector" => %{"provider" => "pgvector"}
      },
      "governance" => %{
        "hard" => ["Never scale beyond 3x in a single action"],
        "soft" => ["Prefer gradual scaling over spikes"],
        "escalate_when" => %{"confidence_below" => 0.8}
      },
      "provenance" => false
    }

    right_path = Fixtures.write_json_fixture!("diff-right", right_document)

    assert {:ok, output} = AmpersandCore.CLI.run(["diff", left_path, right_path])

    decoded = Jason.decode!(output)

    assert decoded["command"] == "diff"
    assert decoded["status"] == "ok"
    assert decoded["left_file"] == left_path
    assert decoded["right_file"] == right_path

    assert decoded["capabilities"]["added"] == ["&memory.vector"]
    assert decoded["capabilities"]["removed"] == [
             "&reason.attend",
             "&reason.deliberate",
             "&space.fleet"
           ]

    assert Enum.any?(decoded["capabilities"]["provider_changes"], fn change ->
             change["capability"] == "&memory.graph" and
               change["left_provider"] == "graphonomous" and
               change["right_provider"] == "neo4j-memory"
           end)

    assert decoded["governance"]["changed"] == true
    assert decoded["provenance"]["changed"] == true
    assert decoded["summary"]["provider_change_count"] >= 1
  end
end

defmodule AmpersandCoreComposePropertiesPhaseTwoTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @capability_ids [
    "&memory.graph",
    "&memory.episodic",
    "&memory.vector",
    "&reason.argument",
    "&reason.attend",
    "&reason.deliberate",
    "&reason.plan",
    "&reason.vote",
    "&time.anomaly",
    "&time.forecast",
    "&time.pattern",
    "&space.fleet",
    "&space.route",
    "&space.geofence"
  ]

  @providers [
    "graphonomous",
    "neo4j-memory",
    "pgvector",
    "weaviate",
    "deliberatic",
    "ticktickclock",
    "geofleetic"
  ]

  property "composition is commutative for all generated compatible pairs" do
    check all {left, right} <- compatible_pair_generator(), max_runs: 80 do
      assert AmpersandCore.Compose.commutative?(left, right)
      assert {:ok, forward} = AmpersandCore.Compose.compose([left, right])
      assert {:ok, reverse} = AmpersandCore.Compose.compose([right, left])
      assert forward == reverse
    end
  end

  property "composition is associative for all generated compatible triples" do
    check all {left, middle, right} <- compatible_triple_generator(), max_runs: 80 do
      assert AmpersandCore.Compose.associative?(left, middle, right)

      assert {:ok, left_middle} = AmpersandCore.Compose.compose([left, middle])
      assert {:ok, grouped_left} = AmpersandCore.Compose.compose([left_middle, right])

      assert {:ok, middle_right} = AmpersandCore.Compose.compose([middle, right])
      assert {:ok, grouped_right} = AmpersandCore.Compose.compose([left, middle_right])

      assert grouped_left == grouped_right
    end
  end

  property "composition is idempotent for all generated capability maps" do
    check all capabilities <- capability_map_generator(0, 10), max_runs: 100 do
      assert AmpersandCore.Compose.idempotent?(capabilities)
      assert {:ok, once} = AmpersandCore.Compose.compose([capabilities])
      assert {:ok, twice} = AmpersandCore.Compose.compose([capabilities, capabilities])
      assert once == twice
    end
  end

  property "composition has identity for all generated capability maps" do
    check all capabilities <- capability_map_generator(0, 10), max_runs: 100 do
      assert AmpersandCore.Compose.identity?(capabilities)

      assert {:ok, left_identity} =
               AmpersandCore.Compose.compose([AmpersandCore.Compose.identity(), capabilities])

      assert {:ok, right_identity} =
               AmpersandCore.Compose.compose([capabilities, AmpersandCore.Compose.identity()])

      assert {:ok, original} = AmpersandCore.Compose.compose([capabilities])

      assert left_identity == original
      assert right_identity == original
    end
  end

  property "composition detects conflicts for all generated incompatible pairs" do
    check all {left, right, capability} <- conflicting_pair_generator(), max_runs: 80 do
      assert {:error, {:conflicting_binding, conflict_capability, _existing, _incoming}} =
               AmpersandCore.Compose.compose([left, right])

      assert conflict_capability == capability
    end
  end

  defp compatible_pair_generator do
    subset_generator(@capability_ids, 6)
    |> bind(fn left_keys ->
      remaining = @capability_ids -- left_keys

      subset_generator(remaining, 6)
      |> bind(fn right_keys ->
        gen all left <- capability_map_for_keys_generator(left_keys),
                right <- capability_map_for_keys_generator(right_keys) do
          {left, right}
        end
      end)
    end)
  end

  defp compatible_triple_generator do
    subset_generator(@capability_ids, 4)
    |> bind(fn left_keys ->
      remaining_after_left = @capability_ids -- left_keys

      subset_generator(remaining_after_left, 4)
      |> bind(fn middle_keys ->
        remaining_after_middle = remaining_after_left -- middle_keys

        subset_generator(remaining_after_middle, 4)
        |> bind(fn right_keys ->
          gen all left <- capability_map_for_keys_generator(left_keys),
                  middle <- capability_map_for_keys_generator(middle_keys),
                  right <- capability_map_for_keys_generator(right_keys) do
            {left, middle, right}
          end
        end)
      end)
    end)
  end

  defp conflicting_pair_generator do
    gen all capability <- member_of(@capability_ids),
            left_binding <- binding_generator(),
            right_binding <- binding_generator(),
            left_binding != right_binding do
      {
        %{capability => left_binding},
        %{capability => right_binding},
        capability
      }
    end
  end

  defp subset_generator(values, max_length) when is_list(values) do
    list_of(member_of(values), max_length: max(max_length * 3, 1))
    |> map(fn generated ->
      generated
      |> Enum.uniq()
      |> Enum.take(max_length)
    end)
  end

  defp capability_map_generator(min_length, max_length) do
    subset_generator(@capability_ids, max_length)
    |> filter(fn keys ->
      length(keys) >= min_length and length(keys) <= max_length
    end)
    |> bind(&capability_map_for_keys_generator/1)
  end

  defp capability_map_for_keys_generator(keys) do
    list_of(binding_generator(), length: length(keys))
    |> map(fn bindings ->
      keys
      |> Enum.zip(bindings)
      |> Enum.into(%{})
    end)
  end

  defp binding_generator do
    gen all provider <- member_of(@providers),
            include_config <- boolean() do
      if include_config do
        %{
          "provider" => provider,
          "config" => %{
            "mode" => "property-test",
            "seed" => String.slice(provider, 0, 4)
          }
        }
      else
        %{"provider" => provider}
      end
    end
  end
end
