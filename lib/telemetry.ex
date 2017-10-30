defmodule Telemetry do
  def log_request(logger, env, method, url, body, headers, {elapsed_time, response}) do
    metadata = Telemetry.format_request_metadata(env, method, url, body, headers)
    response_metadata = Telemetry.format_response_metadata(response, elapsed_time)
    # Pass logger by reference in order to use logger from Primary app
    logger.("Outgoing API Request", metadata |> Map.merge(response_metadata))
    response
  end

  def format_request_metadata(env, method, url, body, headers) do
    api_request_id = Base.encode64(:crypto.strong_rand_bytes(32), padding: false)
    parsed_url = URI.parse(url)
    {_access_token, sanitized_query} = case parsed_url.query do
      nil -> {nil, ""}
      uri -> uri
             |> URI.query_decoder()
             |> Enum.to_list
             |> Enum.into(%{})
             |> get_and_update_in(["access_token"], &{&1, "[REDACTED]"})
    end

    base_url = %{parsed_url | query: nil}
    method = "#{method}" |> String.upcase
    module = env.module
    {function, arity} = env.function
    module_function = "#{module}.#{function}/#{arity}"
    %{
      function: module_function,
      api_request_id: api_request_id,
      method: method,
      url: URI.to_string(base_url),
      headers: scrubbed_headers(headers),
      request_body: parse_body(body, headers),
      query: sanitized_query,
    }
  end

  def format_response_metadata(response, elapsed_time) do
    case response do
      {:ok, content} ->
        %{
          status_code: content.status_code,
          response_body: parse_body(content.body, content.headers),
          response_headers: scrubbed_headers(content.headers),
          duration_in_ms: to_ms(elapsed_time)
        }
      {:error, error} ->
        %{
          status_code: 999,
          error: "#{error.reason}",
          response_body: "",
          response_headers: "",
          duration_in_ms: to_ms(elapsed_time)
        }
    end
  end

  def to_ms(elapsed_time) do
    elapsed_time
    |> Kernel./(1000)
    |> :erlang.float_to_binary(decimals: 3)
  end

  def parse_body(body, headers) do
    result = with %{"content-type" => "application/json"} <- headers,
                  {:ok, json} <- Poison.decode(body) do
                    json
    else
      _other -> body
    end

    # BitStrings that can't be cast to Strings blow up here.
    # So we pre-emptively check their viability with encoding.
    try do
      case Poison.encode(result) do
        {:ok, _} -> result
        {:error, _} -> "[redacted_bitstring]"
      end
    rescue
      _ -> "[redacted_bitstring]"
    end
  end

  @spec scrubbed_headers([{String.t, String.t}]) :: [{String.t, String.t}]
  defp scrubbed_headers(headers) do
    headers
    |> Enum.map(fn
      {"Authorization", _token} -> {"Authorization" , "<redacted_auth_token>"}
      other -> other
    end)
    |> Enum.into(%{})
  end
end
