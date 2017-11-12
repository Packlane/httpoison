ExUnit.start

# Turn off logging during tests
Application.put_env(:logger, :level, :error)
defmodule PathHelpers do
  def fixture_path do
    Path.expand("fixtures", __DIR__)
  end

  def fixture_path(file_path) do
    Path.join fixture_path(), file_path
  end
end
