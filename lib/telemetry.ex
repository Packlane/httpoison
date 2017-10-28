defmodule Telemetry do
  require Logger
  def log_response(metadata, response_with_timing) do
    {elapsed_time, response} = response_with_timing
    {_status, sanitized_response} = response
    response_metadata = Telemetry.format_response_metadata(sanitized_response, elapsed_time)
    Logger.info("Outgoing API Response", metadata: metadata |> Map.merge(response_metadata))
    response
  end

  def log_request(method, url, body, headers) do
    metadata = Telemetry.format_request_metadata(method, url, body, headers)
    Logger.info("Outgoing API Request", metadata: metadata)
    metadata
  end
  def format_request_metadata(method, url, body, headers) do
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
    metadata = %{
                  module: inspect(__MODULE__),
                  api_request_id: api_request_id,
                  method: method,
                  url: URI.to_string(base_url),
                  headers: scrubbed_headers(headers),
                  request_body: body,
                  query: sanitized_query,
                }
  end

  def format_response_metadata(response, elapsed_time) do
    %{
       status_code: response.status_code,
       response_body: parse_response_body(response.body, response.headers),
       response_headers: scrubbed_headers(response.headers),
       duration_in_ms: elapsed_time
                       |> Kernel./(1000)
                       |> :erlang.float_to_binary(decimals: 3)
     }
  end

  def parse_response_body(body, headers) do
    with %{"content-type" => "application/json"} <- headers,
         {:ok, json} <- Poison.decode(body) do
           json
    else
      _other -> body
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
