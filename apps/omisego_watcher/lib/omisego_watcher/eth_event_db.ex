# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OmiseGOWatcher.EthEventDB do
  @moduledoc """
  Ecto schema for transaction's output (or input)
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @field_names [:address, :currency, :amount, :blknum, :txindex, :oindex, :txbytes]
  def field_names, do: @field_names


  schema "ethevents" do
    field :hash, :binary
    field :deposit_blknum, :integer
    field :deposit_txindex, :integer
    field :event_type, :integer

    has_one :created_utxo, TxOutputDB, foreign_key: :creating_deposit
    has_one :exited_utxo, TxOutputDB, foreign_key: :spending_exit
  end
end
