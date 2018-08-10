defmodule OmiseGO.API.State.PropTest.Helper do
  alias OmiseGO.API.State.Transaction

  def spendable(history) do
    history = Enum.reverse(history)
    spendable(history, %{})
  end

  def spendable([{:deposits, utxos, _} | history], unspent) do
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
        {_, owner} = Enum.find(entities, fn element -> match?({_, %{addr: ^owner}}, element) end)
        Map.put_new(acc, {blknum, txindex, oindex}, %{amount: amount, currency: currency, owner: owner})
      end)

    spendable(history, unspent)
  end

  def spendable([{:form_block, [], _} | history], unspent), do: spendable(history, unspent)

  def spendable(
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
                   oindex2: oindex2
                 }
               }
             },
             _
           ], _}
          | history
        ],
        unspent
      ) do
    {_, unspent} = Map.pop(unspent, {blknum1, txindex1, oindex1})
    {_, unspent} = Map.pop(unspent, {blknum2, txindex2, oindex2})
    spendable(history, unspent)
  end

  def spendable([], unspent) do
    unspent
  end
end
