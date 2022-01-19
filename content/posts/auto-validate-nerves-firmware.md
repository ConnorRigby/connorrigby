+++
title = "Automtatically Validating Nerves Firmware"
date = "2022-01-19T08:42:31-07:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie"
tags = ["nerves", "embedded", "elixir"]
keywords = ["nerves"]
description = "What makes a firmware 'valid' anyway?"
+++

# TLDR

Here's the code you probably want. Modify it as you see fit.

```elixir
# Copyright 2022 Connor Rigby
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
defmodule MyFirmware.Validator do
  @moduledoc """
  Validates the currently running firmware as soon as
  the device connects to NervesHub. This is implemented
  via setting a callback in `:heart`.

  Validation is implemented by polling certain functions,
  namely: `NervesHubLink.connected?()`. It is given
  5 minutes to connect. If it does not connect, the `:heart`
  module will reboot the device via `nerves_heart`.

  All the code in this module must be **VERY SAFE** a crash
  will cause the device to reboot.
  """

  use GenServer
  require Logger

  # 5 minutes
  @nerves_hub_timeout_ms 300_000

  # shoudl be started in a supervisor spec
  @doc false
  def start_link(args, opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl GenServer
  def terminate(_, _) do
    :heart.clear_callback()
  end

  @doc """
  This is the `:heart` callback entrypoint 
  """
  def heart(pid \\ __MODULE__) do
    safe_call(pid, :heart)
  end

  def safe_call(pid, call) when is_pid(pid) do
    if Process.alive?(pid) do
      try do
        GenServer.call(pid, call)
      catch
        type, error -> {:error, {type, error}}
      end
    else
      {:error, :not_alive}
    end
  end

  def safe_call(server, call) when is_atom(server) do
    if pid = Process.whereis(server) do
      safe_call(pid, call)
    else
      {:error, :no_pid}
    end
  end

  def safe_call(unknown, _call) do
    {:error, {:unknown, unknown}}
  end

  @impl GenServer
  def init(args) do
    nerves_hub_timeout = Keyword.get(args, :nerves_hub_timeout, @nerves_hub_timeout_ms)
    nerves_hub_timeout_timer = Process.send_after(self(), :nerves_hub_timeout, nerves_hub_timeout)

    # Add other timers here in the same format

    {:ok,
     %{
       timers: %{
         nerves_hub_timeout: nerves_hub_timeout_timer,
       }
     }}
  end

  @impl GenServer
  def handle_call(:heart, _from, state) do
    timers =
      Map.new(state.timers, fn
        {name, :ok} -> {name, :ok}
        {name, timer} when is_reference(timer) -> evaluate_timer(name, timer)
        {name, value} -> {name, value}
      end)

    state = %{state | timers: timers}

    failed =
      Enum.any?(timers, fn
        {_name, true} -> true
        {_name, _result} -> false
      end)

    if failed do
      Logger.error("Heart callback failed. Firmware will revert soon")
      {:reply, :fail, state}
    else
      # all checks passed
      {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_info(:initialize_heart, state) do
    :heart.set_callback(__MODULE__, :heart)
    {:noreply, state}
  end

  def handle_info(:nerves_hub_timeout, state) do
    Logger.warn("Timeout connecting to NervesHub. Firmware should not be considered valid")
    {:noreply, %{state | timers: %{state.timers | nerves_hub_timeout: true}}}
  end

  # Timer already expired
  def evaluate_timer(name, true) do
    {name, true}
  end

  def evaluate_timer(:nerves_hub_timeout, timer) do
    try do
      if NervesHubLink.connected?() do
        Process.cancel_timer(timer)
        # this is what we've all been waiting for!
        Nerves.Runtime.validate_firmware()
        {:nerves_hub_timeout, :ok}
      else
        {:nerves_hub_timeout, timer}
      end
    catch
      type, error ->
        Logger.error("Failed to check nerves_hub_timeout: #{inspect({type, error})}")
        {:nerves_hub_timeout, timer}
    end
  end
end
```

# Why, When and How

With Nerves, you get this fancy A/B partition scheme. You can think of it as 
analogous to blue/green deploys of web applications. How this works internally
is subject for another post as it differes per device. In the case of this post,
all you will need to know is that if we don't call a special function, upon the
next reboot, the device will revert to it's previous firmware.

## Why have a system to auto revert firmware?

To start out, it may be useful to understand *why* this setup exists. Imagine if
you will, you have a fleet of devices in production. What they do is not important,
but if you're creative, you may pretend they do something cool. If you're not creative,
just assume that a broken firmware means you have to personally go out and fix any device
personally. This is your motivation.

The general idea is that if your device is online, and able to download a new update,
it's in a "valid" state. Say the device is on firmware `A`. It was the first version of
the firmware you wrote. It has bugs, but those aren't important as you can just fix them
with an update. Firmware `A` is good enough to get you connected to a central Firmware
Update Server. (say for example [Nerves Hub](https://nerves-hub.org))
Since this was the first firmware, it's automatically considered `valid`. 
Now that firmware `A` is deployed to your fleet of devices, you **really** don't want
an update to break them. This is where the auto revert system comes in. When you
finally get around to fixing those bugs, you can use the Firmware Update Server
to dispatch your update to the devices, but you want to be really sure that they
are at least as not broken as they started out before the update. 

When an update is downloaded, it will be applied to the `B` partition, and the device
will attempt to boot from that partition after the update completes. When it does,
there are some conditions that need to be met before considering the new firmware
as `valid`. 

## When is a firmware considered valid?

The short answer is of course it depends.

The short answer that is probably most useful to you is that if your devices can
receive further updates, it's what i like to call `valid enough`. 

The long answer is as follows:

You ultimately need to decide what makes your firmware `valid`. The code provided in
the above example simply assumes that connecting to NervesHub is what makes it `valid`. 
Your use case will probably differ depending on what the device does. For example, 
some common other checks include connecting to your own networks, APIs etc. 

If your device connects to your Firmware Update Server, but doesn't perform it's 
core functionality, maybe that shouldn't be considered `valid`. 

# How to validate a firmware?

Naturally, the answer to this question is it depends yet again. However, the example
above is of course already implemented, so that's `how` you're gonna do it. The point
here is that this is not the **only** way to validate a firmware. It's just one I
and at least a couple other production projects work. 

The main system we will be working with here is called `heart`. It's an 
underappreciated system in the Erlang Runtime System with almost no documentation.
(as is customary for the most useful parts of ERTS)

What you need to know is that there's a module called `:heart` that gets started very early
in the boot process. Nerves implements a custom process ([source](https://github.com/nerves-project/nerves_heart))
to keep `:heart` and your devices watchdog in sync. This means that if Erlang (read: your firmware)
or the device watchdog becomes unresponsive, the device will reboot. The special part about
that, is that if your firmware was not validated, the reboot will revert back to the last
valid firmware, protecting you, the developer from having to fix devices manually. 

So how do you use it? there are a couple functions you will need to know about. The glue between
them is really up to you, but the example at the beginning provides a basic implementation
you can use and modify to suit your own needs. 

The first useful function is `:heart.set_callback/2`:

```elixir
:heart.set_callback(SomeModuleThatKnowsHowToValidateFirmware, :function_to_call)
```

This callback will be called every `HEART_BEAT_TIMEOUT`. By default this is once
every 60 seconds. 

The other useful function you will need is `Nerves.Runtime.validate_fw/0`:

```elixir
Nerves.Runtime.validate_fw()
```

In the above example, we wrap both of these functions up inside a GenServer
process. this process will be started during our firmware's application supervision
tree startup. I put it at the very end so that firmware can only be validated if everything
else is "up and running" whatever that means for the application.
That process schedules some timers that once expired will consider the firmware "invalid". 
The whole trick here is that your device will not be connected immediately since the network
takes time to come up. The timer essentially says that 

    upon a reboot, if the device hasn't connected to the firmware update server in
    the allowed amount of time (5 minutes in this case), the firmware should be reverted.

The other thing to note here is that any crash, exception, error etc will be considered a failure. 
(and cause a reboot) This means you should think about how the process interacts and introspects the 
rest of the system.

# Conclusion

Hopefully this at least gets you thinking about how to recover from failure **before**
you end up failing with no escape route. 

Deploying firmware to production devices has quite a few things like this that you may not
even be considering. Stay tuned for more on deploying your firmware to production
