defmodule OmiseGO.API.State.PropTest.ExitUtxos do
  require Logger

  defmacro __using__(_opt) do
    quote do
      defcommand :exit_utxos do
        alias OmiseGO.API.State.PropTest.Helper
        # use OmiseGO.API.LoggerExt
        import OmiseGO.API.LoggerExt
        def impl(), do: []

        def args(%{model: %{history: history}}) do
          spendable = Helper.spendable(history)
          # Logger.info("Args: #{ins(spendable)}", Map.to_list(unquote(Macro.escape(__ENV__))))
          []
        end

        def pre(state, args) do
          true
        end

        def post(%{model: %{history: history}}, _, _) do
          true
        end

        def next(%{model: %{history: history} = model, eth: %{blknum: number} = eth} = state, [], ret) do
          state
        end
      end
    end
  end
end
