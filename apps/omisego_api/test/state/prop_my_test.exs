defmodule OmiseGO.API.State.PropMYTest do
  @moduledoc """
  Defines the state machine for chain state.
  """
  import OmiseGO.API.State.PropTest.Deposits
  use PropCheck
  use PropCheck.StateM.DSL
  import PropCheck.BasicTypes
  use ExUnit.Case
  alias OmiseGO.API.State.{Core, Transaction}
  alias OmiseGO.API.Block

  use OmiseGO.API.LoggerExt
  alias OmiseGO.API.LoggerExt

  require OmiseGO.API.BlackBoxMe
  require Logger
  OmiseGO.API.BlackBoxMe.create(OmiseGO.API.State.Core, CoreGS2)

  @moduletag :wip11

  defp background(str, {r, g, b}),
    do: String.replace(IO.ANSI.reset() <> str, IO.ANSI.reset(), "\e[48;2;#{r};#{g};#{b}m") <> IO.ANSI.reset()

  defp print(value, rgb \\ {40, 44, 52}), do: value |> inspect |> background(rgb) |> IO.puts()
  # TODO: make aggregation and statistics informative
  # [:verbose, :noshrink, max_size: 10, constraint_tries: 1, numtests: 3, start_size: 3]
  property "OmiseGO.API.State.Core prope check", [:quiet, max_size: 300, numtests: 10, start_size: 3] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        # print(cmds)
        %{history: history, result: result, state: state, env: _env} = response = run_commands(cmds)
        # print(response, {80, 80, 40})

        ret =
          (result == :ok)
          |> when_fail(
            (fn ->
               print("Commands: #{inspect(cmds)}", {40, 44, 92})
               Logger.warn("State: #{inspect(state)}")
               # IO.puts("History: #{inspect(history)}")
               Logger.error("Result: #{inspect(result)}")
             end).()
          )
          |> aggregate(command_names(cmds))
          |> collect(length(cmds))

        print("=> stop", {20, 60, 80})
        ret
      end
    end
  end

  def initial_state do
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    CoreGS2.set_state(state)

    %{
      model: %{history: []},
      eth: %{blknum: 1_000}
    }
  end

  def entitie() do
    addresses =
      OmiseGO.API.TestHelper.entities_stable()
      |> Map.values()

    oneof(addresses)
  end

  def get_currency do
    frequency([{10, <<0::160>>}, {1, <<1::160>>}])
  end

  defcommand :form_block do
    def impl(), do: CoreGS2.form_block(1_000)

    def post(%{model: %{history: history}}, [], {:ok, {%Block{transactions: transaction}, _, _}}) do
      expected_transactions =
        history
        |> Enum.take_while(&(!match?({:form_block, _, _}, &1)))
        |> Enum.filter(&match?({:transaction, _, _}, &1))
        |> Enum.map(fn {:transaction,
                        [%Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: tx_bytes}}, _], _} ->
          tx_bytes
        end)
        |> Enum.reverse()

      expected_transactions == transaction
    end

    def next(%{model: %{history: history} = model, eth: %{blknum: number} = eth} = state, [], ret) do
      %{
        state
        | eth: %{eth | blknum: (div(number, 1000) + 1) * 1000},
          model: %{model | history: [{:form_block, [], ret} | history]}
      }
    end
  end

  def spendable(history) do
    history = Enum.reverse(history)
    spendable(history, %{})
  end

  def spendable([{:deposits, utxos, _} | history], unspent) do
    entities = OmiseGO.API.TestHelper.entities_stable()

    unspent =
      utxos
      |> Enum.map(&Map.merge(&1, %{oindex: 0, txindex: 0}))
      |> Enum.reduce(unspent, fn %{
                                   owner: owner,
                                   amount: amount,
                                   blknum: blknum,
                                   currency: currency,
                                   oindex: oindex,
                                   txindex: txindex
                                 },
                                 acc ->
        {_, owner} = Enum.find(entities, fn element -> match?({_, %{addr: ^owner}}, element) end)
        Map.put_new(acc, {blknum, txindex, oindex}, %{amount: amount, currency: currency, owner: owner})
      end)

    spendable(history, unspent)
  end

  def spendable([{:form_block, [], _} | history], unspent), do: spendable(history, unspent)

  def spendable(
        [
          {:transaction,
           [
             %Transaction.Recovered{
               signed_tx: %Transaction.Signed{
                 raw_tx: %Transaction{
                   blknum1: blknum1,
                   txindex1: txindex1,
                   oindex1: oindex1,
                   blknum2: blknum2,
                   txindex2: txindex2,
                   oindex2: oindex2
                 }
               }
             },
             _
           ], _}
          | history
        ],
        unspent
      ) do
    {_, unspent} = Map.pop(unspent, {blknum1, txindex1, oindex1})
    {_, unspent} = Map.pop(unspent, {blknum2, txindex2, oindex2})
    spendable(history, unspent)
  end

  def spendable([why | history], unspent) do
    Logger.warn("spendable")
    print(why, {80, 40, 50})
    throw("ble")
    spendable(history, unspent)
  end

  def spendable([], unspent) do
    unspent
  end

  def generate_new_owners(utxos, output_number) do
    Logger.info(utxos)
    oneof([1, 2])
  end

  defcommand :transaction do
    def impl(transaction, fee_map) do
      CoreGS2.exec(transaction, fee_map)
    end

    def args(%{model: %{history: history}}) do
      spentable = spendable(history)

      let [currency <- get_currency(), new_owner1 <- entitie(), new_owner2 <- entitie(), new_owners <- range(1, 2)] do
        spentable = [nil | :maps.filter(fn _, %{currency: val} -> val == currency end, spentable) |> Map.to_list()]

        let [utxo1 <- oneof(spentable), utxo2 <- oneof(spentable)] do
          utxos = [utxo1, utxo2] |> Enum.filter(&(&1 != nil)) |> Enum.uniq()
          total_amount = Enum.reduce(utxos, 0, fn {_, %{amount: amount}}, acc -> amount + acc end)

          let [amount1 <- range(0, Enum.max([total_amount - 10, 0])), fee <- range(0, 10)] do
            amount2 = Enum.max([total_amount - amount1 - fee, 0])

            [
              OmiseGO.API.TestHelper.create_recovered(
                utxos |> Enum.map(fn {position, %{owner: owner}} -> Tuple.append(position, owner) end),
                currency,
                Enum.zip(Enum.take([new_owner1, new_owner2], new_owners), [amount1, amount2])
              ),
              %{currency => 0}
            ]
          end
        end
      end
    end

    def pre(%{model: %{history: history}}, [
          %Transaction.Recovered{
            signed_tx: %Transaction.Signed{
              raw_tx: %Transaction{
                amount1: amount1,
                amount2: amount2,
                cur12: currency,
                blknum1: blknum1,
                txindex1: txindex1,
                oindex1: oindex1,
                blknum2: blknum2,
                txindex2: txindex2,
                oindex2: oindex2
              }
            },
            spender1: spender1,
            spender2: spender2
          },
          fees_map
        ]) do
      spendable = spendable(history)
      spender2_valid = if amount2 > 0, do: spender2 != nil, else: true

      amount1 >= 0 and amount2 >= 0 and spender1 != nil and spender2_valid and
        Map.has_key?(spendable, {blknum1, txindex1, oindex1}) and Map.has_key?(spendable, {blknum2, txindex2, oindex2}) and
        Map.get(spendable, {blknum1, txindex1, oindex1}).currency == currency and
        Map.get(spendable, {blknum2, txindex2, oindex2}).currency == currency
    end

    def pre(_model, _any), do: false

    def post(state, args, {:error, msg}) do
      Logger.error("error: #{inspect(msg)} ")
      Logger.error("args: #{inspect(args)}")
      Logger.error("state: #{inspect(state)}")
      false
    end

    def post(_state, args, response) do
      true
    end

    def next(%{model: %{history: history} = model} = state, args, ret) do
      %{state | model: %{model | history: [{:transaction, args, ret} | history]}}
    end
  end
end
