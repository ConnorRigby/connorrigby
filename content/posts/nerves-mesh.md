+++
title = "Creating mesh networks with Nerves"
date = "2024-03-25T17:36:33-06:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie" #do not include @
cover = "nerves-mesh/pcbs.webp"
tags = ["elixir", "nerves", "embedded linux", "linux"]
keywords = ["linux", "elixir", "nerves"]
description = "Erlang Distribution over 802.11s mesh network"
showFullContent = false
readingTime = false
+++

## TLDR

Here's the sample code. read on to get a breakdown.

```elixir
defmodule MyAppFw.Mesh do
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    VintageNet.subscribe(["interface", "mesh0"])
    {:ok, %{socket: nil, select: nil, node: nil}, {:continue, :init_mesh}}
  end

  def terminate(_, state) do
    if Node.alive? do
      for node <- Node.list(), do: Node.disconnect(node)
      Node.stop()
    end
    if state.socket, do: :socket.close(state.socket)
    VintageNet.reset_to_defaults("mesh0")
  end

  def handle_continue(:init_mesh, state) do
    :os.cmd('ip link set wlan0 down')
    VintageNet.configure("mesh0", %{
      type: VintageNetWiFi,
      ipv4: %{method: :disabled},
      vintage_net_wifi: %{
        root_interface: "wlan0",
        user_mpm: 1,
        networks: [
          %{
            ssid: "myapp",
            key_mgmt: :none,
            mode: :mesh,
            frequency: 2412,
          }
        ],
      }
    }, persist: false)
    {:noreply, state}
  end

  def handle_continue(:recvfrom, state) do
    case :socket.recvfrom(state.socket, [], :nowait) do
      {:select, {:select_info, _tag, select}} ->
        Logger.info(%{select: select})
        {:noreply, %{state | select: select}}

      {:ok, {source, data}} ->
        Logger.info(%{source: source, data: data})
        case :inet.parse_ipv6_address(String.to_charlist(data)) do
          {:ok, _addr} -> 
            if :"myapp@#{data}" not in Node.list() do
              Logger.info(%{connecting_node: :"myapp@#{data}"})
              Node.connect(:"myapp@#{data}")
            else
              Logger.info(%{already_connected: :"myapp@#{data}"})
            end
          data -> 
            Logger.warning(%{unknown_data: data}) 
        end
        {:noreply, state, {:continue, :recvfrom}}
    end
  end

  def handle_continue(:sendto, state) do
    "AH" <> id = Nerves.Runtime.serial_number
    <<_::binary-2, serial::binary-6, _::binary-1>> = Base.decode16!(id)
    addr_sufix = Base.encode16(serial, case: :lower)  |> String.to_charlist() |> Enum.chunk_every(4) |> Enum.join(":")
    case :socket.sendto(state.socket, "fd12:3456:789a:1::#{addr_sufix}", %{family: :inet6, port: 49999, addr: {0xFF02, 0, 0, 0, 0, 0, 0, 0x69}}) do
      :ok -> {:noreply, state}
      {:error, reason} -> 
        Logger.error(%{sendto: reason})
        {:noreply, state, {:continue, :sendto}}
    end
  end

  def handle_info({:"$socket", socket, :select, select}, %{socket: socket, select: select} = state) do
    Logger.info(%{select: select})
    {:noreply, %{state | select: nil}, {:continue, :recvfrom}}
  end 

  def handle_info({VintageNet, ["interface", "mesh0", "wifi", "peers"], _old, new, _}, state) do
    Logger.info(%{peers: new, socket: state.socket})
    {:noreply, state, {:continue, :sendto}}
  end

  def handle_info({VintageNet, ["interface", "mesh0", "lower_up"], false, true, _}, state) do
    "AH" <> id = Nerves.Runtime.serial_number
    <<_::binary-2, serial::binary-6, _::binary-1>> = Base.decode16!(id)
    addr_sufix = Base.encode16(serial, case: :lower)  |> String.to_charlist() |> Enum.chunk_every(4) |> Enum.join(":")
    :os.cmd('ip addr add fd12:3456:789a:1::#{addr_sufix}/48 dev mesh0')

    {:ok, socket} = :socket.open(:inet6, :dgram, :udp)
    :ok = :socket.setopt(socket, :socket, :bindtodevice, 'mesh0')
    :ok = :socket.setopt(socket, :socket, :reuseport, true)
    :ok = :socket.setopt(socket, :socket, :reuseaddr, true)
    :ok = :socket.setopt(socket, :ipv6, :multicast_loop, false)
    :ok = :socket.setopt(socket, :ipv6, :multicast_hops, 255)
    {:ok, interface} = :net.if_name2index('mesh0')
    :ok = :socket.setopt(socket, :ipv6, :multicast_if, interface)
    :ok = :socket.bind(socket, %{family: :inet6, port: 49999})
    :ok = :socket.setopt(socket, :ipv6, :add_membership, %{
        multiaddr: {0xFF02, 0, 0, 0, 0, 0, 0, 0x69},
        interface: interface
      })
    {:ok, node} = Node.start(:"myapp@fd12:3456:789a:1::#{addr_sufix}")
    Node.set_cookie(:democookie)
    {:noreply, %{state | socket: socket, node: node}, {:continue, :recvfrom}}
  end

  def handle_info({VintageNet, _, _, _, _}, state) do
    {:noreply, state}
  end
end
```

## Building a Erlang Distribution Cluster Over a 802.11s Mesh Network

* The goal: [Distributed Erlang](https://www.erlang.org/doc/reference_manual/distributed.html)
* The network: [802.11s Mesh](https://en.wikipedia.org/wiki/IEEE_802.11s)
* The IP Addresses: [V6](https://en.wikipedia.org/wiki/IPv6)

## Required Hardware

There are two specific pieces of hardware used in this project. These two parts are required, but should generally be applicable to any Nerves device with support for them. (most).

### 802.11S Compatible WiFi

This isn't a *new* standard by any means, but it's not an old one either. Support for it exists in modern Linux kernel and userspace applications, but drivers often don't implement it for one reason or another, or the hardware
simply does not support it. I found a lovely list of compatible devices at [phillymesh/802.11s-adapters](https://github.com/phillymesh/802.11s-adapters). As seen in the cover photo, I'm using unbranded "802.11n" marked WiFi dongles that support it.

### ATECC508A/ATECC608A Crypto Module

This isn't actually **required**, it just solves a complicated problem of creating unique id numbers. The ATECC608A chip is responsible for providing a 48 unique serial number that we are going to use as a way of identifying nodes on the network.
This is a wide problem space with many solutions. This is just *one* of them. 

## Package Setup

Not much code needs to be written from scratch here. We're mostly gluing pieces together. The first pieces we'll look at is [VintageNet](https://github.com/nerves-networking/vintage_net) and [VintageNetWiFi](https://github.com/nerves-networking/vintage_net_wifi).
These two libraries are going to be responsible for creating and managing the physical network. 

```elixir
    VintageNet.configure("mesh0", %{
      type: VintageNetWiFi,
      ipv4: %{method: :disabled},
      vintage_net_wifi: %{
        root_interface: "wlan0",
        user_mpm: 1,
        networks: [
          %{
            ssid: "myapp",
            key_mgmt: :none,
            mode: :mesh,
            frequency: 2412,
          }
        ],
      }
    }, persist: false)
```

This configures the root_interface `wlan0`, which in my case happens to be a USB WiFi dongle into `:mesh` mode. `ipv4` is disabled. We'll see why in just a second. We also set `persist: false` to  prevent VintageNet from saving this config and applying it at boot. 
The reason for that is because internally, when the kernel registers the `mesh0` interface, the order in which we bring the interface up is important. We want to first bring `wlan0` down:

```elixir
:os.cmd('ip link set wlan0 down')
```

then configure the mesh interface using the above `configure/3` command which will internally call `:os.cmd('ip link set mesh0 up')` and kick off the internal state management and `wpa_supplicant`. With just these two commands, the mesh is now running. 
When we run those two commands on two different nodes, we can check the current network with something like this at the IEX console:

```
iex()1> cmd("iw dev mesh0 station dump")
Station 1c:bf:ce:17:1d:7a (on mesh0)
        inactive time:  770 ms
        rx bytes:       2112019
        rx packets:     30557
        tx bytes:       280280
        tx packets:     2789
        tx retries:     158
        tx failed:      3
        rx drop misc:   15
        signal:         -35 dBm
        signal avg:     -35 dBm
        Toffset:        18446744073682909240 us
        tx bitrate:     72.2 MBit/s MCS 7 short GI
        tx duration:    0 us
        rx bitrate:     72.2 MBit/s MCS 7 short GI
        rx duration:    0 us
        expected throughput:    32.134Mbps
        mesh llid:      0
        mesh plid:      0
        mesh plink:     ESTAB
        mesh airtime link metric: 249
        mesh connected to gate: no
        mesh connected to auth server:  no
        mesh local PS mode:     ACTIVE
        mesh peer PS mode:      ACTIVE
        mesh non-peer PS mode:  ACTIVE
        authorized:     yes
        authenticated:  yes
        associated:     yes
        preamble:       long
        WMM/WME:        yes
        MFP:            no
        TDLS peer:      no
        DTIM period:    2
        beacon interval:1000
        connected time: 13770 seconds
        associated at [boottime]:       15037.896s
        associated at:  1711397904710 ms
        current time:   1711411674604 ms
```

Now this is great, but there's no way currently to communicate between these nodes. To make that happen, we **COULD** try to come up with some algorithm to attempt to request an IP address from a DHCP server, if there isn't one available start it etc etc. Or even run
an `mdns` server and client on both devices, and attempt to discover eachother. But I've employed what I think is a much neater solution that allows for discovery of other nodes without the need for a central authority on IP addresses.

This brings me to the other library we will use for this network: [NervesKey](https://github.com/nerves-hub/nerves_key). I've already provisioned my keys, so I wont explain that here, but all I've done for this setup is run the "standard" config as outlined in the README of the NervesKey repo. 

This device communicates over the I2C bus. So to use the NervesKey library, we need to provide it with a `transport` of sorts telling the library where to find our key on the bus. 

```elixir
{:ok, i2c} = ATECC508A.Transport.I2C.init([bus_name: "i2c-0"])
```

This is where it is for my device. On Raspberry Pi for example, it's usually on `"i2c-1"` which is the default for the `init` function.

The ATECC chip can do a lot, but we only need one feature right now. the Device Serial number, and wwe get that with:

```elixir
iex(2)> {:ok, id} = NervesKey.Config.device_sn(i2c)
{:ok, <<1, 35, 111, 68, 227, 198, 184, 2, 238>>}
```

Notice this id is in binary. We can turn it into something more readable with something like:

```elixir
iex(3)> Base.encode16(id, case: :lower)
"01236f44e3c6b802ee"
```

There's actually a shortcut to the above operation that comes with Nerves.Runtime. We can use `Nerves.Runtime.serial_number` to do all the above stuff for us if configured correctly. Now all we need to do is create an IPV6 address
and assign it to our mesh0  interface and the two nodes should be able to communicate.

```elixir
"AH" <> id = Nerves.Runtime.serial_number
<<_::binary-2, serial::binary-6, _::binary-1>> = Base.decode16!(id) # isn't it funny I used the shortcut then changed it back into binary anyway?
addr_sufix = Base.encode16(serial, case: :lower)  |> String.to_charlist() |> Enum.chunk_every(4) |> Enum.join(":")
```

Here I take the serial number and trim off the `AH` "header" value. The first two bytes of the serial number encode the date manufacturing run of the device whose serial number is attached. These values are usually the same on this chip, 
so we don't really want to use them for our IPV6 address. Similarly, the very last byte of the serial number encodes **where** the chip was made. This is almost always `0xEE` and again, we don't really want it in our IP address either.
This leaves 48 bits, or 6 bytes of values that will be unique for every device. Finally, I split that hex string every 4 characters and join by the `:` to lazily create the ID part of our ipv6 address. Now we just need to assign it to
the interface with:

```elixir
:os.cmd('ip addr add fd12:3456:789a:1::#{addr_sufix}/48 dev mesh0')
```

Now our nodes can directly communicate with eachother:

```
iex(1)> cmd("ping fd12:3456:789a:1:0:6f44:e3c6:b802")
PING fd12:3456:789a:1:0:6f44:e3c6:b802 (fd12:3456:789a:1:0:6f44:e3c6:b802): 56 data bytes
64 bytes from fd12:3456:789a:1:0:6f44:e3c6:b802: seq=0 ttl=64 time=0.885 ms
64 bytes from fd12:3456:789a:1:0:6f44:e3c6:b802: seq=1 ttl=64 time=1.305 ms
64 bytes from fd12:3456:789a:1:0:6f44:e3c6:b802: seq=2 ttl=64 time=0.968 ms
```

And with direct communication, means we can setup Distributed Erlang:

```elixir
iex(1)> {:ok, node} = Node.start(:"myapp@fd12:3456:789a:1::#{addr_sufix}")

iex(myapp@fd12:3456:789a:1::6f44:e3c6:b802)2> Node.set_cookie(:democookie)
true
iex(myapp@fd12:3456:789a:1::6f44:e3c6:b802)3> Node.list()
[:"myapp@fd12:3456:789a:1::e0f9:2f20:de47"]
```

The one final thing we need before we automate this whole process is a method to discover nodes on the network when we connect. I accomplished this with a very simple UDP socket on a multicast address to exchange information. 

```elixir
{:ok, socket} = :socket.open(:inet6, :dgram, :udp)
:ok = :socket.setopt(socket, :socket, :bindtodevice, 'mesh0')
:ok = :socket.setopt(socket, :socket, :reuseport, true)
:ok = :socket.setopt(socket, :socket, :reuseaddr, true)
:ok = :socket.setopt(socket, :ipv6, :multicast_loop, false)
:ok = :socket.setopt(socket, :ipv6, :multicast_hops, 255)
{:ok, interface} = :net.if_name2index('mesh0')
:ok = :socket.setopt(socket, :ipv6, :multicast_if, interface)
:ok = :socket.bind(socket, %{family: :inet6, port: 49999})
:ok = :socket.setopt(socket, :ipv6, :add_membership, %{
    multiaddr: {0xFF02, 0, 0, 0, 0, 0, 0, 0x69},
    interface: interface
    })
:socket.recvfrom(state.socket, [], :nowait)
```

This creates a socket on `ff02::/8` and starts receiving packets on it. When we successfully join the mesh, we send our address on the socket with something like:

```elixir
:socket.sendto(state.socket, "fd12:3456:789a:1::#{addr_sufix}", %{family: :inet6, port: 49999, addr: {0xFF02, 0, 0, 0, 0, 0, 0, 0x69}})
```

When we receive this message on other nodes, attempt to connect to it like this:

```elixir
case :socket.recvfrom(state.socket, [], :nowait) do
    {:select, {:select_info, _tag, select}} ->
    Logger.info(%{select: select})
    {:noreply, %{state | select: select}}

    {:ok, {source, data}} ->
    Logger.info(%{source: source, data: data})
    case :inet.parse_ipv6_address(String.to_charlist(data)) do
        {:ok, _addr} -> 
        if :"myapp@#{data}" not in Node.list() do
            Logger.info(%{connecting_node: :"myapp@#{data}"})
            Node.connect(:"myapp@#{data}")
        else
            Logger.info(%{already_connected: :"myapp@#{data}"})
        end
        data -> 
            Logger.warning(%{unknown_data: data}) 
    end
    {:noreply, state, {:continue, :recvfrom}}
end
```

Which just tries to decode the data from the socket as a string'd ip address, and checks to see if our node is already connected. If not, attempt to connect to it. 

## Conclusion

Now wrap all of that up into a small GenServer process as shown in the begining, and it's job-done. Now of course there are **many** optimizations to be made from this starting point. in no particular order, some of the low hanging fruit is

* use a PSK on the mesh network. The network in this example is completely open. anyone who knows how could connect and mess things up, or even passively listen to packets. 
* use the TLS Erlang distribution transport. The NervesKey hardware supports hardware enabled encryption and other related features. This would involve some SSL work but would encrypt the distribution network.
* monitor other nodes. This could be done to validate the network is working. Depends on the end use application, but probably good practice.
* bridge the mesh network with other links. ULA addresses aren't meant to be exposed on the public ipv6 internet, but this same addressing strategy would also work for global addresses. 
* smarter discovery protocol. MDNS, upnp or similar solutions may be easy to setup here.
