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

defmodule OMG.Watcher.Eventer.CoreTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.Watcher.Eventer
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.TestHelper

  @tag fixtures: [:alice, :bob]
  test "notify function generates 2 proper address_received events", %{alice: alice, bob: bob} do
    recovered_tx =
      API.TestHelper.create_recovered([{1, 0, 0, alice}, {2, 0, 0, bob}], API.Crypto.zero_address(), [
        {alice, 100},
        {bob, 5}
      ])

    {:ok, encoded_alice_address} = Crypto.encode_address(alice.addr)
    {:ok, encoded_bob_address} = Crypto.encode_address(bob.addr)
    topic_alice = TestHelper.create_topic("transfer", encoded_alice_address)
    topic_bob = TestHelper.create_topic("transfer", encoded_bob_address)

    event_1 = {topic_alice, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_2 = {topic_bob, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_3 = {topic_alice, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    event_4 = {topic_bob, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    assert [event_1, event_2, event_3, event_4] == Eventer.Core.prepare_events([%{tx: recovered_tx}])
  end

  @tag fixtures: [:alice, :bob]
  test "prepare_events function generates 1 proper address_received events", %{alice: alice} do
    recovered_tx = API.TestHelper.create_recovered([{1, 0, 0, alice}], Crypto.zero_address(), [{alice, 100}])

    {:ok, encoded_alice_address} = Crypto.encode_address(alice.addr)
    topic = TestHelper.create_topic("transfer", encoded_alice_address)

    event_1 = {topic, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_2 = {topic, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    assert [event_1, event_2] == Eventer.Core.prepare_events([%{tx: recovered_tx}])
  end

  test "prepare_events function generates one block_withholdings event" do
    block_withholding_event = %Event.BlockWithholding{blknum: 1}
    event = {"byzantine", "block_withholding", block_withholding_event}

    assert [event] == Eventer.Core.prepare_events([block_withholding_event])
  end
end
