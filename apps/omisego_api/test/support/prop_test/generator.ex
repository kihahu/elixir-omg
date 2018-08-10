defmodule OmiseGO.API.State.PropTest.Generators do
  use OmiseGO.API.LoggerExt
  import PropCheck.BasicTypes

  def generate_new_owners(utxos, output_number) do
    Logger.info(utxos)
    oneof([1, 2])
  end

  def get_currency do
    frequency([{10, <<0::160>>}, {1, <<1::160>>}])
  end

  def entitie() do
    addresses =
      OmiseGO.API.TestHelper.entities_stable()
      |> Map.values()

    oneof(addresses)
  end
end
