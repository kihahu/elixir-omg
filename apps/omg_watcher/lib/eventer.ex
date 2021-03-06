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

defmodule OMG.Watcher.Eventer do
  @moduledoc """
  Imperative shell for handling events
  """

  alias OMG.JSONRPC
  alias OMG.Watcher.Eventer.Core
  alias OMG.Watcher.Web.Endpoint

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def emit_events(event_triggers) do
    GenServer.cast(__MODULE__, {:emit_events, event_triggers})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:emit_events, event_triggers}, state) do
    event_triggers
    |> Core.prepare_events()
    |> Enum.each(fn {topic, event_name, event} ->
      :ok = Endpoint.broadcast!(topic, event_name, JSONRPC.Client.encode(event))
    end)

    {:noreply, state}
  end
end
