defmodule OmiseGO.API.State.PropTest.Helper do
  alias OmiseGO.API.State.Transaction
  use OmiseGO.API.LoggerExt

  def format_utxo(utxos) do
    utxos
    |> Enum.map(fn {key, %{amount: amount, currency: currency, owner_name: owner}} ->
      {key, %{amount: amount, currency: currency_to_atom(currency), owner_name: owner}}
    end)
  end

  def format_transaction(transaction) do
    transaction =
      transaction
      |> Map.update!(:spender1, &addr_to_owner_name/1)
      |> Map.update!(:spender2, &addr_to_owner_name/1)
      |> Map.drop([:signed_tx_hash])
      |> Map.update!(:signed_tx, fn signed ->
        signed
        |> Map.drop([:sig1, :sig2, :signed_tx_bytes])
        |> Map.update!(:raw_tx, fn raw_tx ->
          raw_tx
          |> Map.update!(:cur12, &currency_to_atom/1)
          |> Map.update!(:newowner1, &addr_to_owner_name/1)
          |> Map.update!(:newowner2, &addr_to_owner_name/1)
        end)
      end)

    %{
      signed_tx: %{
        raw_tx: %{
          amount1: amount1,
          amount2: amount2,
          blknum1: blknum1,
          blknum2: blknum2,
          cur12: cur12,
          newowner1: newowner1,
          newowner2: newowner2,
          oindex1: oindex1,
          oindex2: oindex2,
          txindex1: txindex1,
          txindex2: txindex2
        }
      },
      spender1: spender1,
      spender2: spender2
    } = transaction

    {cur12, [{{blknum1, txindex1, oindex1}, spender1}, {{blknum2, txindex2, oindex2}, spender2}],
     [{newowner1, amount1}, {newowner2, amount2}]}
  end

  def format_deposits(deposits) do
    Enum.map(deposits, fn %{amount: amount, blknum: blknum, currency: currency, owner: owner} ->
      {amount, currency_to_atom(currency), addr_to_owner_name(owner), blknum}
    end)
  end

  def format_history(history) do
    history
    |> Enum.map(fn
      {:transaction, [recovered, fees_map], ret} -> {:transaction, format_transaction(recovered)}
      {:deposits, deposits, ret} -> {:deposits, format_deposits(deposits)}
      {:form_block, _, {:ok, {%{number: blknum}, _, _}}} -> {:form_block, blknum}
      elem -> elem
    end)
  end

  def addr_to_owner_name(addr) do
    entities = OmiseGO.API.TestHelper.entities_stable()

    case Enum.find(entities, fn element ->
           match?({_, %{addr: ^addr}}, element) or match?({_, %{priv: ^addr}}, element)
         end) do
      {owner_atom, owner} -> owner_atom
      nil -> nil
    end
  end

  def currency_to_atom(<<0::160>>), do: :ethereum
  def currency_to_atom(<<1::160>>), do: :other

  def owner_to_atom(owenr) do
  end

  def spendable(history) do
    history = Enum.reverse(history)
    spendable(history, %{}, {1_000, 0})
  end

  defp spendable([{:deposits, utxos, _} | history], unspent, position) do
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
        {owner_atom, owner} = Enum.find(entities, fn element -> match?({_, %{addr: ^owner}}, element) end)

        Map.put_new(acc, {blknum, txindex, oindex}, %{
          amount: amount,
          currency: currency,
          owner: owner,
          owner_name: owner_atom
        })
      end)

    spendable(history, unspent, position)
  end

  defp spendable([{:form_block, [], _} | history], unspent, {blknum, tx_index}),
    do: spendable(history, unspent, {blknum + 1_000, 0})

  defp spendable(
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
                    oindex2: oindex2,
                    cur12: currency,
                    newowner1: newowner1,
                    amount1: amount1,
                    newowner2: newowner2,
                    amount2: amount2
                  }
                }
              },
              _
            ], _} = trn
           | history
         ],
         unspent,
         {blknum, tx_index}
       ) do
    entities = OmiseGO.API.TestHelper.entities_stable()
    # Logger.error("owner1: #{inspect(newowner1)}\nowner2: #{inspect(newowner2)}\n#{inspect(unspent)}")
    {_, unspent} = Map.pop(unspent, {blknum1, txindex1, oindex1})
    {_, unspent} = Map.pop(unspent, {blknum2, txindex2, oindex2})
    # Logger.info("remove utxo")

    unspent =
      if Transaction.account_address?(newowner1) do
        {key, owner1} = Enum.find(entities, fn element -> match?({_, %{addr: ^newowner1}}, element) end)
        Map.put(unspent, {blknum, tx_index, 0}, %{currency: currency, owner: owner1, owner_name: key, amount: amount1})
      else
        unspent
      end

    # Logger.info("added utxo utxo1 <#{IEx.Helpers.i(newowner2)}>")

    unspent =
      if Transaction.account_address?(newowner2) do
        {key, owner2} = Enum.find(entities, fn element -> match?({_, %{addr: ^newowner2}}, element) end)
        Map.put(unspent, {blknum, tx_index, 1}, %{currency: currency, owner: owner2, owner_name: key, amount: amount2})
      else
        unspent
      end

    # Logger.info("added utxo utxo2")
    spendable(history, unspent, {blknum, tx_index + 1})
  end

  defp spendable([], unspent, {_blknum, _tx_index}) do
    unspent
  end
end
