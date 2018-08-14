defmodule OmiseGO.API.State.PropTest.Transaction do
  defmacro __using__(_opt) do
    quote do
      defcommand :transaction do
        alias OmiseGO.API.State.PropTest.Generators
        alias OmiseGO.API.State.Transaction
        alias OmiseGO.API.State.PropTest.Helper
        alias OmiseGO.API.LoggerExt

        def impl(transaction, fee_map) do
          StateCoreGS.exec(transaction, fee_map)
        end

        def args(%{model: %{history: history}}) do
          spentable = Helper.spendable(history)

          let [
            currency <- Generators.get_currency(),
            new_owner1 <- Generators.entitie(),
            new_owner2 <- Generators.entitie(),
            new_owners <- range(1, 2)
          ] do
            new_owners = 2
            spentable = [nil | :maps.filter(fn _, %{currency: val} -> val == currency end, spentable) |> Map.to_list()]

            let [utxo1 <- oneof(spentable), utxo2 <- oneof([nil, oneof(spentable)])] do
              utxos = [utxo1, utxo2] |> Enum.filter(&(&1 != nil)) |> Enum.uniq()
              total_amount = Enum.reduce(utxos, 0, fn {_, %{amount: amount}}, acc -> amount + acc end)

              let [amount1 <- range(0, Enum.max([total_amount - 10, 0])), fee <- range(0, 10)] do
                amount2 = Enum.max([total_amount - amount1 - fee, 0])
                amount1 = if new_owners == 1, do: amount1 + amount2, else: amount1

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
          spendable = Helper.spendable(history)
          spender2_valid = if amount2 > 0, do: spender2 != nil, else: true

          amount1 >= 0 and amount2 >= 0 and spender1 != nil and spender2_valid and
            Map.has_key?(spendable, {blknum1, txindex1, oindex1}) and
            Map.has_key?(spendable, {blknum2, txindex2, oindex2}) and
            Map.get(spendable, {blknum1, txindex1, oindex1}).currency == currency and
            Map.get(spendable, {blknum2, txindex2, oindex2}).currency == currency
        end

        def pre(_model, _any), do: false

        def post(%{model: %{history: history}}, [transaction_recovered, _], {:error, msg}) do
          # |> Enum.map(fn {key, val} -> {key, Map.delete(val, :owner)} end)
          spendable = Helper.spendable(history) |> Helper.format_utxo()
          Logger.error("message: #{LoggerExt.ins(msg)} ", Map.to_list(unquote(Macro.escape(__ENV__))))

          Logger.error(
            "args: #{LoggerExt.ins(Helper.format_transaction(transaction_recovered))}",
            Map.to_list(unquote(Macro.escape(__ENV__)))
          )

          Logger.error("utxo: #{LoggerExt.ins(spendable)}", Map.to_list(unquote(Macro.escape(__ENV__))))

          Logger.error(
            "history: #{LoggerExt.ins(Helper.format_history(history))}",
            Map.to_list(unquote(Macro.escape(__ENV__)))
          )

          LoggerExt.print(StateCoreGS.get_state())

          false
        end

        def post(_state, args, response) do
          true
        end

        def next(%{model: %{history: history, balance: balance} = model} = state, args, ret) do
          %{state | model: %{model | history: [{:transaction, args, ret} | history], balance: balance}}
        end
      end
    end
  end
end
