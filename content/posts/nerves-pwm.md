+++
title = "Using PWM with Nerves"
date = "2022-04-04T19:07:10-06:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie" #do not include @
cover = ""
tags = ["elixir", "nerves", "linux", "PWM"]
keywords = ["nerves", "PWM"]
description = "Learn how to use Linux's PWM subsystem with Nerves"
showFullContent = false
readingTime = false
+++

## TLDR

This is probably what you need. Take it and modify it as you see fit.

```elixir
defmodule MyAPP.PWM do
  @moduledoc """
  Basic control

  pwm:
     ehrpwm1A == pwmchip2/pwm0 (LED R)
     ehrpwm1B == pwmchip2/pwm1 (LED G)
     ehrpwm2A == pwmchip0/pwm0 (LED B)
  """

  @pwms [
    led_r: {2, 0},
    led_g: {2, 1},
    led_b: {0, 0},
  ]

  # Period for 25kHz PWM
  @period 40_000

  def init() do
    @pwms
    |> Enum.each(fn {_pwm, {chip, pin}} ->
      File.write("/sys/class/pwm/pwmchip#{chip}/export", to_string(pin))
      File.write("/sys/class/pwm/pwmchip#{chip}/pwm#{pin}/period", to_string(@period))
    end)
  end

  def period(pwm, period) do
    {chip, pwm} = Keyword.fetch!(@pwms, pwm)
    File.write("/sys/class/pwm/pwmchip#{chip}/pwm#{pwm}/period", to_string(period))
  end

  def period(pwm) do
    {chip, pwm} = Keyword.fetch!(@pwms, pwm)

    File.read!("/sys/class/pwm/pwmchip#{chip}/pwm#{pwm}/period")
    |> String.trim()
    |> String.to_integer()
  end

  def duty_cycle(pwm, duty_cycle) do
    {chip, pwm} = Keyword.fetch!(@pwms, pwm)
    File.write("/sys/class/pwm/pwmchip#{chip}/pwm#{pwm}/duty_cycle", to_string(duty_cycle))
  end

  def duty_cycle(pwm) do
    {chip, pwm} = Keyword.fetch!(@pwms, pwm)

    File.read!("/sys/class/pwm/pwmchip#{chip}/pwm#{pwm}/duty_cycle")
    |> String.trim()
    |> String.to_integer()
  end

  def enable(pwm, enable) do
    {chip, pwm} = Keyword.fetch!(@pwms, pwm)
    enable = if enable, do: 1, else: 0
    File.write("/sys/class/pwm/pwmchip#{chip}/pwm#{pwm}/enable", to_string(enable))
  end

  def enable(pwm) do
    {chip, pwm} = Keyword.fetch!(@pwms, pwm)
    "1" == File.read!("/sys/class/pwm/pwmchip#{chip}/pwm#{pwm}/enable") |> String.trim()
  end
end
```

## PWM In Linux

I've always found using PWM in Linux unnecessarily tedious. When I first got started in Embedded Linux, I was coming from experience with Arduino. Love it or hate it, Arduino has this particular feature dialed in from the beginning.

```c
void setup() {
  pinMode(A0, OUTPUT);
  analogWrite(A0, 255);
}
```

That's it.

Okay, so obviously it's not a completely fair comparison, Arduino is a C++ framework, Linux is an operating system yada yada. Anyway here's the snippit from the [Linux
Kernel Documentation](https://www.kernel.org/doc/html/latest/driver-api/pwm.html)

```c
static struct pwm_lookup board_pwm_lookup[] = {
        PWM_LOOKUP("tegra-pwm", 0, "pwm-backlight", NULL,
                   50000, PWM_POLARITY_NORMAL),
};

static void __init board_init(void)
{
        ...
        pwm_add_table(board_pwm_lookup, ARRAY_SIZE(board_pwm_lookup));
        ...
}
```

Alright **what?** So as it turns out that part of the document is completely irelevant to actually *using* PWM. If you read down further, you'll find

```c
int pwm_apply_state(struct pwm_device *pwm, struct pwm_state *state);
```

after no less than 7 links to other functions you need to call first. Continue reading on, and oh! Linux will let you use PWM via [Sysfs](https://en.wikipedia.org/wiki/Sysfs), just like GPIO and many other systems. The document however won't tell you exactly how to use that interface directly, you'll have to actually *read* the document. This upset me, so here's something you can copy and paste.

The root directory you want to be in is `/sys/class/pwm`. To use a PWM output, you'll need to `export` it. (replace `N` with your PWM chip, and `C` with the channel)

```bash
echo 1 > /sys/class/pwm/pwmchipN/export
```

In Elixir, we can do

```elixir
File.write!("/sys/class/pwm/pwmchipN/export", "1")
```

Next, it must be enabled:

```bash
echo 1 > /sys/class/pwm/pwmchipN/enable
```

And you know the deal in Elixir:

```elixir
File.write!("/sys/class/pwm/pwmchipN/export", "1")
```

Next, you need to set the `period` and `duty_cycle`. If you don't know what these are, (possibly because you came here from Arduino that doesn't tell you anything about either of these two words), Check [Wikipedia](https://en.wikipedia.org/wiki/Pulse-width_modulation).

The short of it is, `duty_cycle` is the percentage of time that the signal is active. `period` is how long that signal is active. The values provided to Linux are in nanoseconds, so to set a 1 millisecond period, you would do:

```bash
echo 1000000 > /sys/class/pwm/pwmchipN/pwmC/period
```

or in Elixir:

```elixir
File.write!("/sys/class/pwm/pwmchipN/pwmC/period", "1000000")
```

And to set the a duty cycle of 50%, you'd set the `duty_cycle` to half of the `period`:

```bash
echo 500000 > /sys/class/pwm/pwmchipN/pwmC/duty_cycle
```

or in Elixir:

```elixir
File.write!("/sys/class/pwm/pwmchipN/pwmC/duty_cycle", "500000")
```

And that's pretty much it. I encourage you to study the official document further, it may be a little dense, but all the information you need *is* there. Hopefully this helped someone along their way to controlling something interesting with PWM.

## Bonus Round: RGB LED control

The entire reason, I had to learn this information was to control RGB LEDs for a [device I'm building](/posts/can-link/) to control LEDs based on an engine control unit. This is what I use for that.

```elixir
defmodule MyApp.RGB do
  alias MyApp.PWM
  use GenServer
  require Logger

  @all_channels [:led_r, :led_g, :led_b]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def on() do
    GenServer.call(__MODULE__, :on)
  end

  def off() do
    GenServer.call(__MODULE__, :off)
  end

  def set_color(val) do
    GenServer.call(__MODULE__, {:set_color, val})
  end

  def set_brightness(val) do
    GenServer.call(__MODULE__, {:set_brightness, val})
  end

  def init(_opts) do
    @all_channels
    |> Enum.each(fn channel ->
      PWM.enable(channel, false)
    end)

    state = %{
      color: :white,
      brightness: 100
    }

    {:ok, state}
  end

  def handle_call(:on, _from, state) do
    set(state.color, state.brightness)

    @all_channels
    |> Enum.each(fn channel ->
      PWM.enable(channel, true)
    end)

    {:reply, :ok, state}
  end

  def handle_call(:off, _from, state) do
    @all_channels
    |> Enum.each(fn channel ->
      PWM.enable(channel, false)
    end)

    {:reply, :ok, state}
  end

  def handle_call({:set_color, val}, _from, state) do
    set(val, state.brightness)

    {:reply, :ok, %{state | color: val}}
  end

  def handle_call({:set_brightness, val}, _from, state) do
    set(state.color, val)

    {:reply, :ok, %{state | brightness: val}}
  end

  defp set(color, brightness) do
    rgb_val = rgb_from_color(color, brightness)

    Enum.zip([:led_r, :led_g, :led_b], rgb_val)
    |> Enum.each(fn {channel, val} ->
      duty_cycle = floor(PWM.period(channel) * val / 255)
      PWM.duty_cycle(channel, duty_cycle)
    end)
  end

  defp rgb_from_color(val, brightness) do
    max = 255 * brightness / 100

    case val do
      :white -> [max, max, max]
      :red -> [max, 0, 0]
      :green -> [0, max, 0]
      :blue -> [0, 0, max]
      :yellow -> [max, max, 0]
      :cyan -> [0, max, max]
      :magenta -> [max, 0, max]
      {r, g, b} -> [r, g, b]
      [r, g, b] -> [r, g, b]
    end
  end
end
```
