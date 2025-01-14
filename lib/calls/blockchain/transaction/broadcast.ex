defmodule ElectrumClient.Calls.Blockchain.Transaction.Broadcast do
  @moduledoc """
  Manages blockchain.transaction.broadcast params and results

  ref: https://electrumx-spesmilo.readthedocs.io/en/latest/protocol-methods.html#blockchain-transaction-broadcast
  """

  @doc """
  Calls the electrum server with the required parameters to broadcast a transaction
  """
  @spec call(any(), binary()) :: {:ok, binary()} | {:error, integer(), binary()}
  def call(socket, transaction) do
    params = encode_params(transaction)

    :ok = :gen_tcp.send(socket, params)

    receive do
      {:tcp, _socket, message} -> parse_result(message)
    end
  end

  @doc """
  Sends a transation to the mempool

  ## Examples
    iex> "0100000001fda3efeb2c0b5567d8426a6e77784ddfbe2ae36dedcc6e0f1a34022d04b7ef39000000006b483045022100ede2ace59d0153e9116a5d871028a2ef2769bac140875f2723438592ebb92a27022075751eb503d1c6e10fa20500ad7c5060ca1752d06f0e195cb309e0920a6a86e8012102f942091e070d59e2f86e17b77e4f96539752f19f360dbf87ef15ea1f0fe8a4e2ffffffff0260ea0000000000001976a91409d6cbc4a478c8f1cbde9085b10fb84519591afb88ac881300000000000017a91451caa671181d8819ccff9b81ffeb8fdafd95f91f8700000000"
    ...> |> ElectrumClient.Calls.Blockchain.Transaction.Broadcast.encode_params()
    \"""
    {\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"blockchain.transaction.broadcast\",\"params\":[\"0100000001fda3efeb2c0b5567d8426a6e77784ddfbe2ae36dedcc6e0f1a34022d04b7ef39000000006b483045022100ede2ace59d0153e9116a5d871028a2ef2769bac140875f2723438592ebb92a27022075751eb503d1c6e10fa20500ad7c5060ca1752d06f0e195cb309e0920a6a86e8012102f942091e070d59e2f86e17b77e4f96539752f19f360dbf87ef15ea1f0fe8a4e2ffffffff0260ea0000000000001976a91409d6cbc4a478c8f1cbde9085b10fb84519591afb88ac881300000000000017a91451caa671181d8819ccff9b81ffeb8fdafd95f91f8700000000\"]}
    \"""
  """
  def encode_params(transaction) do
    data = %{
      jsonrpc: "2.0",
      id: 1,
      method: "blockchain.transaction.broadcast",
      params: [transaction]
    }

    encoded = Jason.encode!(data)
    "#{encoded}\n"
  end

  @doc """
  Converts a blockchain.transaction.broadcast's call result into an elixir map containing
  the resulting status of the broadcast

  ## Examples
    iex>  \"""
    ...>   {\"id\":1,\"jsonrpc\":\"2.0\",\"result\":\"ba9e74b6359c5ff49bb5a1dc0979ce85db8ee45aa90fbf170ff72dec0aad542f\"}
    ...>  \"""
    ...>  |> ElectrumClient.Calls.Blockchain.Transaction.Broadcast.parse_result()
    {
      :ok,
      "ba9e74b6359c5ff49bb5a1dc0979ce85db8ee45aa90fbf170ff72dec0aad542f"
    }
  """
  @spec parse_result(list()) :: {:ok, binary()} | {:error, integer(), binary()}
  def parse_result(message) do
    Jason.decode!(message)
    |> decode_message
  end

  defp decode_message(%{"result" => transaction_id}) do
    {:ok, transaction_id}
  end

  defp decode_message(%{
         "error" => %{
           "code" => code,
           "message" => message
         },
         "id" => _id,
         "jsonrpc" => "2.0"
       }) do
    {:error, code, message}
  end
end
