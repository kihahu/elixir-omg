defmodule OmiseGO.API.State.PropTest.FormBlock do
  defmacro __using__(_opt) do
    quote do
      defcommand :form_block do
        alias OmiseGO.API.Block
        alias OmiseGO.API.State.Transaction
        def impl(), do: StateCoreGS.form_block(1_000)

        def post(%{model: %{history: history}}, [], {:ok, {%Block{transactions: transaction}, _, _}}) do
          expected_transactions =
            history
            |> Enum.take_while(&(!match?({:form_block, _, _}, &1)))
            |> Enum.filter(&match?({:transaction, _, _}, &1))
            |> Enum.map(fn {:transaction,
                            [%Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: tx_bytes}}, _],
                            _} ->
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
    end
  end
end
