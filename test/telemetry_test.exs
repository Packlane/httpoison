defmodule TelemetryTest do
  use ExUnit.Case, async: true
  import PathHelpers

  describe "#truncate_body" do
    test "returns untruncated response for short content" do
      assert Telemetry.truncate_body(%{a: 1}, 10) == %{a: 1}
    end

    test "returns truncated response for long content" do
      #expected = %{truncated: true, msg: String.slice(string, 0..max_length)}
      assert Telemetry.truncate_body(%{a: 100000000000}, 10) == %{msg: "{\"a\":100000", truncated: true}
    end

    test "returns truncated response for invalid content" do
      assert Telemetry.truncate_body(%{a: <<508>>}, 10) == Telemetry.failure_placeholder()
    end
  end
end
