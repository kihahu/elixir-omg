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

defmodule OMG.Watcher.Web.Controller.Status do
  @moduledoc """
  Module provides operation related to the child chain health status, like: geth syncing status, last minned block
  number and time and last block verified by watcher.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.State
  alias OMG.Eth

  action_fallback(OMG.Watcher.Web.Controller.JsonFallback)

  @doc """
  Gets plasma network and Watcher status
  """
  def get_status(conn, _params) do
    with {:ok, last_mined_child_block_number} <- Eth.get_mined_child_block(),
         {:ok, {_root, last_mined_child_block_timestamp}} <- Eth.get_child_chain(last_mined_child_block_number) do
      json(conn, %{
        last_validated_child_block_number: State.get_current_child_block_height(),
        last_mined_child_block_number: last_mined_child_block_number,
        last_mined_child_block_timestamp: last_mined_child_block_timestamp,
        eth_syncing: Eth.syncing?()
      })
    end
  end

  def swagger_definitions do
    %{
      Status:
        swagger_schema do
          title("Status")
          description("Plasma network and Watcher status")

          properties do
            last_validated_child_block_number(:integer, "Number of last validated childchain block", required: true)

            last_mined_child_block_number(
              :string,
              "Number of last childchain block that was mined on the rootchain",
              required: true
            )

            last_mined_child_block_timestamp(
              :string,
              "Timestamp when last childchain block was mined on the rootchain",
              required: true
            )

            eth_syncing(:boolean, "True only when watcher is not yet synced with the rootchain", required: true)
          end

          example(%{
            last_validated_child_block_number: 10_000,
            last_mined_child_block_number: 11_000,
            last_mined_child_block_timestamp: 1_535_031_020,
            eth_syncing: true
          })
        end
    }
  end

  swagger_path :get_status do
    get("/status")
    summary("Gets plasma network and Watcher status")

    response(200, "OK", Schema.ref(:Status))
  end
end
