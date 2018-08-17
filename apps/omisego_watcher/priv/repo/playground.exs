# Script for experimenting with the database. You can run it as:
#
#     mix run priv/repo/playground.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     OmiseGOWatcher.Repo.insert!(%OmiseGOWatcher.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
defmodule OmiseGOWatcher.Playground do
  @moduledoc false

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.{Signed, Recovered}
  alias OmiseGO.API.Crypto
  alias OmiseGOWatcher.TransactionDB

  import Ecto.Query

  @eth Crypto.zero_address()

  require Logger

  defp generate_entity do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  defp ensure_all_started(app_list) do
    app_list
    |> Enum.reduce([], fn app, list ->
      {:ok, started_apps} = Application.ensure_all_started(app)
      list ++ started_apps
    end)
  end

  defp ensure_all_stoped(started_apps) do
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    :ok
  end

  defp setup() do
    setup(Enum.any?(Application.started_applications(), &(elem(&1, 0) == :ecto)))
  end

  defp setup(true), do: []

  defp setup(false) do
    apps = ensure_all_started([:postgrex, :ecto, ])
    child = [Supervisor.Spec.supervisor(OmiseGOWatcher.Repo, [])]
    {:ok, tree} = Supervisor.start_link(child, [strategy: :one_for_one])

    {tree, apps}
  end

  defp teardown({tree, apps}) do
    Supervisor.stop(tree)
    ensure_all_stoped(apps)
  end

  ## Put your code here
  def go do
    Logger.warn("Hello in Playground")

    Logger.debug("Starting dependencies")
    all_apps = setup()

    alice = generate_entity()
    bob = generate_entity()

    utxos = %{
      address: alice.addr,
      utxos: [
        %{
          blknum: 20,
          txindex: 42,
          oindex: 1,
          currency: @eth,
          amount: 100
        },
        %{
          blknum: 2,
          txindex: 21,
          oindex: 0,
          currency: @eth,
          amount: 43,
        }
      ]
    }

    {:ok, raw_tx} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: 53})
    IO.puts(inspect raw_tx, pretty: true)

    signed_tx = raw_tx |> Transaction.sign(alice.priv, <<>>)
    IO.puts(inspect signed_tx, pretty: true)

    {:ok, transaction} = Recovered.recover_from(signed_tx)
    IO.puts(inspect transaction, pretty: true)

    result = TransactionDB.insert(transaction, 1000, 557, 20890)
    IO.inspect(result)


    # Clean up
    Logger.warn("Cleaning the playground")
    Process.sleep(500)
    # teardown(all_apps)
  end

end
