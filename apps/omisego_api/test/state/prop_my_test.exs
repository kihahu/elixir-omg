defmodule OmiseGO.API.State.PropMYTest do
  @moduledoc """
  Defines the state machine for chain state.
  """

  use PropCheck
  use PropCheck.StateM.DSL
  import PropCheck.BasicTypes
  use ExUnit.Case
  alias OmiseGO.API.State.Core

  use OmiseGO.API.LoggerExt
  alias OmiseGO.API.LoggerExt

  require OmiseGO.API.BlackBoxMe
  require Logger
  OmiseGO.API.BlackBoxMe.create(OmiseGO.API.State.Core, CoreGS2)

  @moduletag :wip11

  @inspect_opts [
    pretty: true,
    width: 120,
    syntax_colors: [
      number: "\e[38;2;97;175;239m",
      atom: "\e[38;2;86;182;194m",
      tuple: :light_magenta,
      map: :light_white,
      list: :light_green
    ]
  ]

  defp insp(value), do: value |> inspect(@inspect_opts)
  defp print(value, rgb \\ {40, 44, 52}), do: value |> insp |> background(rgb) |> IO.puts()

  defp background(str, {r, g, b}),
    do: String.replace(IO.ANSI.reset() <> str, IO.ANSI.reset(), "\e[48;2;#{r};#{g};#{b}m") <> IO.ANSI.reset()

  # TODO: make aggregation and statistics informative
  # [:verbose, :noshrink, max_size: 10, constraint_tries: 1, numtests: 3, start_size: 3]
  property "OmiseGO.API.State.Core prope check", max_size: 100, numtests: 100, start_size: 1 do
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
            Result: #{inspect(result, @inspect_opts)}
            Commands: #{inspect(cmds, @inspect_opts)}
            History: #{inspect(history, @inspect_opts)}
            State: #{inspect(state, @inspect_opts)}
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

  # def initial_state do
  #  print("initial_state", {40, 80, 52})
  #  {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
  #  CoreGS2.set_state(state)
  #
  #  %{
  #    model: %{history: []},
  #    eth: %{blknum: 1_000}
  #  }
  # end
  def initial_state do
    [1]
  end

  def address do
    addresses =
      OmiseGO.API.TestHelper.entities()
      |> Map.split([:stable_alice, :stable_bob, :stable_mallory])
      |> elem(0)
      |> Map.values()
      |> Enum.map(&Map.get(&1, :addr))

    # IO.puts(addresses)
    List.first(addresses)
  end

  def currency do
    <<0::160>>
  end

  # defcommand :deposit do
  #  def impl(arg) do
  #    CoreGS2.deposit(arg)
  #  end
  #
  #  def args(%{eth: %{blknum: blknum}} = str) do
  #    state_ful = CoreGS2.get_state()
  #    IO.puts(inspect(state_ful))
  #    IO.puts(inspect(str))
  #
  #    let [number_of_deposit <- oneof([1, 2, 3, 4]), amount <- pos_integer()] do
  #      # number_of_deposit = :rand.uniform(4)
  #
  #      deposits =
  #        for number <- 1..number_of_deposit,
  #            do: %{blknum: blknum + number, currency: currency(), owner: address(), amount: amount}
  #
  #      [deposits]
  #    end
  #  end
  #
  #  def pre(%{eth: %{blknum: blknum}}, [list_deposits]) do
  #    IO.puts(inspect(blknum))
  #    list_block = list_deposits |> Enum.map(fn %{blknum: blknum} -> blknum end)
  #    expected = for i <- (blknum + 1)..(blknum + length(list_deposits)), do: i
  #    IO.puts(inspect(expected) <> " == " <> inspect(list_block))
  #    IO.puts("pre blknum: #{inspect(blknum)}")
  #    ret = rem(blknum, 1000) + length(list_deposits) < 1000 and expected == list_block
  #    IO.puts(inspect(ret))
  #    ret
  #  end
  #
  #  def post(entries, [arg], {:ok, {_, dp_update}}) do
  #    new_utxo =
  #      dp_update
  #      |> Enum.filter(fn
  #        {:put, :utxo, _} -> true
  #        _ -> false
  #      end)
  #      |> length
  #
  #    ret = length(arg) == new_utxo
  #    IO.puts("POST #{inspect(length(arg))} == #{inspect(new_utxo)}\t#{inspect(ret)}")
  #    IO.puts("OST2 #{inspect(CoreGS2.get_state())}")
  #    ret
  #  end
  #
  #  def next(state, _, {:var, _}), do: state
  #
  #  def next(%{eth: %{blknum: blknum} = eth} = state, [args], {:ok, _}) do
  #    # IO.puts(inspect(args))
  #    state = %{state | eth: %{eth | blknum: blknum + length(args)}}
  #    IO.puts("next state: #{inspect(state)}")
  #    state
  #  end
  #
  #  def next(state, args, wtf) do
  #    IO.puts("wtf ????: " <> inspect(wtf))
  #    state
  #  end
  # end

  defcommand :deposit do
    def impl(arg) do
      print(arg)
      arg + 1
    end

    def args([state]) do
      "args:[#{1 + state}]" |> background({10, 10, 10}) |> IO.puts()
      [1 + state]
    end

    def pre([state], [arg]) do
      IO.puts("pre: #{inspect(state)}, arg: #{inspect(arg)}")
      true
    end

    def next([state], [arg], _res) do
      "deposit state change:#{state} to: #{arg}" |> background({10, 10, 10}) |> IO.puts()
      [arg]
    end
  end
end
