defmodule OmiseGO.API.State.PropTest.Deposits do
  defmacro __using__(_opt) do
    quote do
      defcommand :deposits do
        alias OmiseGO.API.State.PropTest.Generators
        import OmiseGO.API.LoggerExt

        def impl(deposits), do: StateCoreGS.deposit(deposits)

        def args(%{eth: %{blknum: blknum}} = str) do
          let [number_of_deposit <- integer(1, 2)] do
            [
              for number <- 1..number_of_deposit do
                let [
                  currency <- Generators.get_currency(),
                  %{addr: owner} <- Generators.entitie(),
                  amount <- integer(10_000, 300_000)
                ] do
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

        def next(
              %{eth: %{blknum: blknum} = eth, model: %{history: history, balance: balance} = model} = state,
              [args],
              ret
            ) do
          new_balance = Enum.reduce(args, balance, fn %{amount: amount}, balance -> balance + amount end)

          %{
            state
            | eth: %{eth | blknum: blknum + length(args)},
              model: %{model | history: [{:deposits, args, ret} | history], balance: new_balance}
          }
        end
      end
    end
  end
end
