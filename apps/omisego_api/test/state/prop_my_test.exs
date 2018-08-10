defmodule OmiseGO.API.State.PropTest do
  @moduledoc """
  Defines the state machine for chain state.
  """
  use PropCheck
  use PropCheck.StateM.DSL

  use ExUnit.Case
  alias OmiseGO.API.State.Core
  use OmiseGO.API.LoggerExt
  require OmiseGO.API.BlackBoxMe
  OmiseGO.API.BlackBoxMe.create(OmiseGO.API.State.Core, StateCoreGS)
  use OmiseGO.API.State.PropTest.{FormBlock, Deposits, Transaction}
  @moduletag :wip11
  def initial_state do
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    StateCoreGS.set_state(state)

    %{
      model: %{history: []},
      eth: %{blknum: 1_000}
    }
  end

  # TODO: make aggregation and statistics informative
  # [:verbose, :noshrink, max_size: 10, constraint_tries: 1, numtests: 3, start_size: 3]
  property "OmiseGO.API.State.Core prope check", [:quiet, max_size: 300, numtests: 10, start_size: 3] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        %{history: history, result: result, state: state, env: _env} = response = run_commands(cmds)

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
end
