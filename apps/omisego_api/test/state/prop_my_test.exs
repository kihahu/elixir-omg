defmodule OmiseGO.API.State.PropMYTest do
  @moduledoc """
  Defines the state machine for chain state.
  """

  use PropCheck
  use PropCheck.StateM.DSL
  import PropCheck.BasicTypes
  use ExUnit.Case
  alias OmiseGO.API.State.{Core, Transaction}

  use OmiseGO.API.LoggerExt
  alias OmiseGO.API.LoggerExt

  require OmiseGO.API.BlackBoxMe
  require Logger
  OmiseGO.API.BlackBoxMe.create(OmiseGO.API.State.Core, CoreGS2)

  @moduletag :wip11

  defp insp(value), do: value |> inspect()
  defp print(value, rgb \\ {40, 44, 52}), do: value |> insp |> background(rgb) |> IO.puts()

  defp background(str, {r, g, b}),
    do: String.replace(IO.ANSI.reset() <> str, IO.ANSI.reset(), "\e[48;2;#{r};#{g};#{b}m") <> IO.ANSI.reset()

  # TODO: make aggregation and statistics informative
  # [:verbose, :noshrink, max_size: 10, constraint_tries: 1, numtests: 3, start_size: 3]
  property "OmiseGO.API.State.Core prope check", [:quiet, max_size: 6, numtests: 60, start_size: 3] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        print("============> start run", {20, 60, 80})
        # print(cmds)
        %{history: history, result: result, state: state, env: _env} = response = run_commands(cmds)
        # print(response, {80, 80, 40})

        ret =
          (result == :ok)
          |> when_fail(
            """
            Result: #{inspect(result)}
            Commands: #{inspect(cmds)}
            History: #{inspect(history)}
            State: #{inspect(state)}
            """
            |> IO.puts()
          )
          |> aggregate(command_names(cmds))
          |> collect(length(cmds))

        print("============> stop", {20, 60, 80})
        ret
      end
    end
  end

  def initial_state do
    print("initial_state", {40, 80, 52})
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    CoreGS2.set_state(state)

    %{
      model: %{history: []},
      eth: %{blknum: 1_000}
      # ,utxo: []
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

  defcommand :deposits do
    def impl(deposits), do: CoreGS2.deposit(deposits)

    def args(%{eth: %{blknum: blknum}} = str) do
      let [number_of_deposit <- integer(1, 2)] do
        [
          for number <- 1..number_of_deposit do
            let [currency <- get_currency(), %{addr: owner} <- entitie(), amount <- integer(30, 300_000)] do
              %{blknum: blknum + number, currency: currency, owner: owner, amount: amount}
            end
          end
        ]
      end
    end

    def pre(%{eth: %{blknum: blknum}}, [deposits]) do
      list_block = deposits |> Enum.map(fn %{blknum: blknum} -> blknum end)
      expected = for i <- (blknum + 1)..(blknum + length(deposits)), do: i
      rem(blknum, 1000) + length(deposits) < 1000 and expected == list_block
    end

    def post(_state, [arg], {:ok, {_, dp_update}}) do
      new_utxo =
        dp_update
        |> Enum.filter(fn
          {:put, :utxo, _} -> true
          _ -> false
        end)
        |> length

      length(arg) == new_utxo
    end

    def next(%{eth: %{blknum: blknum} = eth, model: %{history: history} = model} = state, [args], ret) do
      %{
        state
        | eth: %{eth | blknum: blknum + length(args)},
          model: %{model | history: [{:deposits, args, ret} | history]}
      }
    end
  end

  defcommand :form_block do
    def impl() do
      CoreGS2.form_block(1_000)
    rescue
      msg ->
        state = CoreGS2.get_state()
        IO.puts(inspect(state))
        Logger.error("wtf #{inspect(msg)} state: #{inspect(state)} ")
        :error
    end

    # {:ok, {block, tx_events, db_update}}) do
    def post(state, [], ret) do
      # TODO add check transsaction in block with history
      :error != ret
    end

    def next(%{model: %{history: history} = model} = state, args, ret) do
      %{state | model: %{model | history: [{:form_block, args, ret} | history]}}
    end
  end

  def spendable(history) do
    spendable(Enum.reverse(history), %{})
  end

  def spendable([{:deposits, utxos, _} | history], unspent) do
    entities = OmiseGO.API.TestHelper.entities_stable()

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
      Map.put_new(acc, {blknum, txindex, oindex, owner}, %{amount: amount, currency: currency})
    end)
  end

  def spendable([why | history], unspent) do
    Logger.warn("#{inspect(why)}")
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
      Logger.info(inspect(transaction))
      Logger.warn(inspect(fee_map))
      CoreGS2.exec(transaction, fee_map)
    end

    def args(%{model: %{history: history}}) do
      spentable = spendable(history)

      let [currency <- get_currency(), new_owner1 <- entitie(), new_owner2 <- entitie(), new_owners <- range(1, 2)] do
        spentable = [nil | :maps.filter(fn _, %{currency: val} -> val == currency end, spentable) |> Map.to_list()]

        let [utxo1 <- oneof(spentable), utxo2 <- oneof(spentable)] do
          utxos = [utxo1, utxo2] |> Enum.filter(&(&1 != nil))
          total_amount = Enum.reduce(utxos, 0, fn {_, %{amount: amount}}, acc -> amount + acc end)

          let [amount1 <- range(0, Enum.max([total_amount - 10, 0])), fee <- range(0, 10)] do
            amount2 = Enum.max([total_amount - amount1 - fee, 0])

            [
              OmiseGO.API.TestHelper.create_recovered(
                utxos |> Enum.map(&elem(&1, 0)),
                currency,
                Enum.zip(Enum.take([new_owner1, new_owner2], new_owners), [amount1, amount2])
              ),
              %{currency => 0}
            ]
          end
        end
      end
    end

    def pre(_model, [
          %Transaction.Recovered{
            signed_tx: %Transaction.Signed{raw_tx: %Transaction{amount1: amount1, amount2: amount2, cur12: currency}},
            spender1: spender1,
            spender2: spender2
          },
          fees_map
        ]) do
      spender2_valid = if amount2 > 0, do: spender2 != nil, else: true
      amount1 >= 0 and amount2 >= 0 and spender1 != nil and spender2_valid
    end

    def pre(_model, _any), do: false

    def post(state, args, {:error, msg}) do
      Logger.error("error: #{inspect(msg)} ")
      Logger.error("args: #{inspect(args)}")
      Logger.error("state: #{inspect(state)}")
      false
    end

    def post(_state, args, response) do
      Logger.info(inspect(response))
      true
    end

    def next(%{model: %{history: history} = model} = state, args, ret) do
      %{state | model: %{model | history: [{:transaction, args, ret} | history]}}
    end
  end
end
