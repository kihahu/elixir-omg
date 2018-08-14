defmodule OmiseGO.API.State.PropTest do
  @moduledoc """
  Defines the state machine for chain state.
  """
  use PropCheck
  use PropCheck.StateM.DSL

  use ExUnit.Case
  alias OmiseGO.API.State.Core
  use OmiseGO.API.LoggerExt
  alias OmiseGO.API.LoggerExt
  require OmiseGO.API.BlackBoxMe
  OmiseGO.API.BlackBoxMe.create(OmiseGO.API.State.Core, StateCoreGS)
  use OmiseGO.API.State.PropTest.FormBlock
  use OmiseGO.API.State.PropTest.Deposits
  use OmiseGO.API.State.PropTest.Transaction
  use OmiseGO.API.State.PropTest.ExitUtxos
  alias OmiseGO.API.State.PropTest.Helper
  @moduletag :wip11
  def initial_state do
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    StateCoreGS.set_state(state)

    %{
      model: %{history: [], balance: 0},
      eth: %{blknum: 1_000}
    }
  end

  def weight(state) do
    %{model: %{history: history}} = state

    deposits = Enum.count(history, &match?({:deposits, _, _}, &1))
    transaction = Enum.count(history, &match?({:transaction, _, _}, &1))
    utxo = Helper.spendable(history)

    Logger.warn(
      "deposits = #{deposits}  transactions: #{transaction}  utxo size: #{map_size(utxo)}\nutxo:#{
        inspect(Helper.format_utxo(utxo))
      } "
    )

    # history =
    #  Enum.map(history, fn
    #    {:deposits, _, _} -> :deposits
    #    {:transaction, _, _} -> :transaction
    #    msg -> msg
    #  end)
    #
    # Logger.info("check weight #{inspect(history)}")
    [deposits: 2, transaction: deposits * 10 + 1, form_block: 1, exit_utxos: 1]
    # [deposits: 2, transaction: 1, form_block: 1, exit_utxos: 1]
  end

  # TODO: make aggregation and statistics informative
  # [:verbose, :noshrink, max_size: 10, constraint_tries: 1, numtests: 3, start_size: 3]
  @tag timeout: 400_000
  property "OmiseGO.API.State.Core prope check", max_size: 3000, numtests: 2, start_size: 3 do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        %{history: history, result: result, state: state, env: _env} = response = run_commands(cmds)

        ret =
          (result == :ok)
          |> when_fail(
            (fn ->
               Logger.debug("Commands: #{inspect(cmds)}")
               # Logger.warn("State: #{inspect(state)}")
               # IO.puts("History: #{inspect(history)}")
               Logger.error("Result: #{inspect(result)}")
             end).()
          )
          |> aggregate(command_names(cmds))
          |> collect(length(cmds))

        LoggerExt.print("=> stop", {20, 60, 80})
        ret
      end
    end
  end
end
