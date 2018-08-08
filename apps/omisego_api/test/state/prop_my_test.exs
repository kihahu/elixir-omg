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
  property "OmiseGO.API.State.Core prope check", max_size: 4, numtests: 40, start_size: 3 do
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
    }
  end

  def entitie(what) do
    addresses =
      OmiseGO.API.TestHelper.entities()
      |> Map.split([:stable_alice, :stable_bob, :stable_mallory])
      |> elem(0)
      |> Map.values()
      |> Enum.map(&Map.get(&1, what))

    oneof(addresses)
  end

  def currency do
    frequency([{10, <<0::160>>}, {1, <<1::160>>}])
  end

  defcommand :deposits do
    def impl(deposits), do: CoreGS2.deposit(deposits)

    def args(%{eth: %{blknum: blknum}} = str) do
      let [number_of_deposit <- integer(1, 5)] do
        [
          for number <- 1..number_of_deposit do
            let [currency <- currency(), owner <- entitie(:addr), amount <- pos_integer()] do
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
      Logger.debug("form_block")
      ret = CoreGS2.form_block(1_000)
      Logger.debug("form_block__end")
      ret
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

  def get_utxo(history, currency) do
    utxo =
      history
      |> Enum.flat_map(fn
        # TODO get utxo from transaction/block
        {:form_block, _, _} ->
          []

        {:deposits, utxos, _} ->
          utxos
          |> Enum.filter(fn
            %{currency: currency} -> true
            _ -> false
          end)
          |> Enum.map(&Map.merge(&1, %{oindex: 0, txindex: 0}))

        _ ->
          []
      end)

    oneof([nil | utxo])
  end

  def generate_new_owners(utxos, output_number) do
    Logger.info(utxos)
    oneof([1, 2])
  end

  # defp create_recovered(utxos, ) do
  #   OmiseGO.API.TestHelper.create_recovered(
  #      [{1,0,0,alice}], @eth, [{bob,10}]
  #   )
  # end

  defcommand :transaction do
    def impl(transaction, fee_map) do
      CoreGS2.exec(transaction, fee_map)
    end

    def args(%{model: %{history: history}}) do
      let [currency <- currency()] do
        let [utxo1 <- get_utxo(history, currency), utxo2 <- get_utxo(history, currency)] do
          Logger.debug(inspect(utxo1))
          total_sum = Map.get(utxo1, :amount, 0) + Map.get(utxo2, :amount, 0)

          let [amount1 <- range(0, total_sum), fee <- range(0, 10)] do
            [
              %Transaction.Recovered{
                signed_tx: %Transaction.Signed{
                  raw_tx: %Transaction{
                    blknum1: Map.get(utxo1, :blknum, 0),
                    txindex1: Map.get(utxo1, :txindex, 0),
                    oindex1: Map.get(utxo1, :oindex, 0),
                    blknum2: Map.get(utxo2, :blknum, 0),
                    txindex2: Map.get(utxo2, :txindex, 0),
                    oindex2: Map.get(utxo2, :oindex, 0),
                    amount1: amount1,
                    amount2: total_sum - amount1 - fee,
                    cur12: currency
                  }
                },
                spender1: Map.get(utxo1, :owner, nil),
                spender2: Map.get(utxo2, :owner, nil)
              },
              %{currency => 1}
              #      {utxo1, utxo2, {amount1, total_sum - fee - amount1, fee}}
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

    def post(_state, args, response) do
      Logger.info(inspect(args))
      Logger.warn(inspect(response))
      true
    end

    def next(%{model: %{history: history} = model} = state, args, ret) do
      %{state | model: %{model | history: [{:transaction, args, ret} | history]}}
    end
  end
end
