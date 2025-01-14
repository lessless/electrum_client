defmodule ElectrumClient do
  use GenServer

  alias ElectrumClient.Endpoint

  alias ElectrumClient.Calls.Blockchain.ScriptHash.{
    GetBalance,
    GetHistory,
    ListUnspent,
    Subscribe
  }

  alias ElectrumClient.Calls.Blockchain.Transaction.{
    GetTransaction,
    Broadcast
  }

  @callback get_transaction(txid :: String.t()) :: map()
  @callback get_address_history(address :: String.t()) :: list()

  def start_link(electrum_ip, electrum_port) do
    GenServer.start_link(__MODULE__, %{electrum_ip: electrum_ip, electrum_port: electrum_port},
      name: __MODULE__
    )
  end

  @impl true
  def init(%{electrum_ip: electrum_ip, electrum_port: electrum_port} = state) do
    {:ok, socket} =
      :gen_tcp.connect(to_charlist(electrum_ip), electrum_port,
        mode: :binary,
        packet: 0,
        keepalive: true,
        active: false,
        reuseaddr: true,
        send_timeout: 5000,
        send_timeout_close: true
      )

    state =
      state
      |> Map.put(:socket, socket)

    {:ok, state}
  end

  def get_balance(address) do
    GenServer.call(__MODULE__, {:get_balance, address})
  end

  def get_address_history(address) do
    GenServer.call(__MODULE__, {:get_address_history, address})
  end

  def list_unspent(address) do
    GenServer.call(__MODULE__, {:list_unspent, address})
  end

  def subscribe_address(address) do
    GenServer.cast(__MODULE__, {:subscribe_address, address})
  end

  def get_transaction(transaction_id) do
    GenServer.call(__MODULE__, {:get_transaction, transaction_id})
  end

  def get_transaction_output(transaction_id, vout) do
    GenServer.call(__MODULE__, {:get_transaction_output, transaction_id, vout})
  end

  def broadcast_transaction(transaction) do
    GenServer.call(__MODULE__, {:broadcast_transaction, transaction})
  end

  @impl true
  def handle_call({:list_unspent, address}, _from, %{socket: socket} = state) do
    result = ListUnspent.call(socket, address)

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_balance, address}, _from, %{socket: socket} = state) do
    result = GetBalance.call(socket, address)

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_address_history, address}, _from, %{socket: socket} = state) do
    result =
      GetHistory.encode_params(address)
      |> Endpoint.request(socket)
      |> GetHistory.translate()

    {:reply, result, state}
  end

  @impl true
  def handle_call(
        {:get_transaction, transaction_id},
        _from,
        %{socket: socket} = state
      ) do
    result =
      GetTransaction.encode_params(transaction_id)
      |> Endpoint.request(socket)
      |> GetTransaction.translate()

    {:reply, result, state}
  end

  @impl true
  def handle_call(
        {:get_transaction_output, transaction_id, vout},
        _from,
        %{socket: socket} = state
      ) do
    output =
      GetTransaction.encode_params(transaction_id)
      |> Endpoint.request(socket)
      |> GetTransaction.translate()
      |> Map.get(:transaction)
      |> Map.get(:outputs)
      |> Enum.at(vout)

    {:reply, output, state}
  end

  @impl true
  def handle_call({:broadcast_transaction, transaction}, _from, %{socket: socket} = state) do
    result = Broadcast.call(socket, transaction)

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:subscribe_address, address}, %{socket: socket} = state) do
    response = Subscribe.call(socket, address)

    IO.inspect(response)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, _port, message}, state) do
    %{
      "jsonrpc" => "2.0",
      "method" => "blockchain.scripthash.subscribe",
      "params" => subscribe_params
    } = Jason.decode!(message)

    result = Subscribe.interpret_event(subscribe_params)

    IO.inspect("Something moved: #{result}")

    {:noreply, state}
  end
end
