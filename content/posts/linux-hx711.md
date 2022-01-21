+++
title = "Using HX711 with Linux"
date = "2022-01-20T16:24:27-07:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie" #do not include @
tags = ["embedded", "linux"]
keywords = ["linux"]
description = "DeviceTree configuration and setup for Linux HX711"
+++

# TLDR

Here's the code you probably want. Modify it as you see fit.

```c
loadcell_en_reg: fixedregulator@3 {
  compatible = "regulator-fixed";
  regulator-name = "loadcell-en-regulator";
  regulator-min-microvolt = <3300000>;
  regulator-max-microvolt = <3300000>;

  /* ADC_PWR_EN */
  gpio = <&gpio1 13 0>;
  enable-active-high;
};

hx711: hx711 {
  compatible = "avia,hx711";
  sck-gpios = <&gpio1 14 GPIO_ACTIVE_HIGH>;
  dout-gpios = <&gpio1 15 GPIO_ACTIVE_HIGH>;
  avdd-supply = <&loadcell_en_reg>;
};
```

```bash
$ cat /sys/bus/iio/devices/iio:device2/in_voltage0_raw
6818404
```

# Using HX711 from Linux

The HX711 is a really common device, most commonly used to
measure weight via a load cell. It uses a simple 2 wire interface
with a clock and signal. It's not a standard protocol, but simple
anyway.

You can find devboards at [SparkFun](https://www.sparkfun.com/products/13879).
You will also probably need a load cell, which can also be found
at [SparkFun](https://www.sparkfun.com/products/13329).

There are a ton of implementations out there for using this particular
device:

* [Arduino](https://www.arduino.cc/reference/en/libraries/hx711-arduino-library/)
* [Python](https://github.com/tatobari/hx711py)
* [Javscript](https://www.npmjs.com/package/hx711)

But for embedded Linux, none of these are particulary suitable.
Luckily, there is a Linux Kernel Module available for that use
case. [Source](https://github.com/torvalds/linux/blob/master/drivers/iio/adc/hx711.c)

Unfortunately, as is common with these sorts of devices in Linux, there is almost
no documentation for it besides the
[Kernel patch's original submission](https://lore.kernel.org/lkml/20170105175156.GA12221@andreas/)
and a small blurb in the [Device Tree](https://elixir.bootlin.com/linux/v5.1-rc5/source/Documentation/devicetree/bindings/iio/adc/avia-hx711.txt).

By the way, there's a typo in the above document. Don't spend an entire work day
figuring that out like me.

## Enable the Kernel Module

To use this device with Linux, the first thing you will need to do is enable the
kernel module. The name of the module is `CONFIG_HX711`. You can enable it
in the `make menuconfig` menu. Use `/` to search for it.

## Configure the Device Tree

This is the hardest part for me to getting this device working was setting up the
Device tree. The first section has the code required, but I'll walk thru the parts
that held me up.

```c
  avdd-supply = <&loadcell_en_reg>;
```

This was probably the single most time consuming part of the entire project. In my particular
case, the regulator is external too my system regulator.

```c
loadcell_en_reg: fixedregulator@3 {
  compatible = "regulator-fixed";
  regulator-name = "loadcell-en-regulator";
  regulator-min-microvolt = <3300000>;
  regulator-max-microvolt = <3300000>;

  /* ADC_PWR_EN */
  gpio = <&gpio1 13 0>;
  enable-active-high;
};
```

This looks pretty simple now that I know what everything does. The trick was finding out
I needed a `regulator-fixed` device. I spent a lot of time trying to get a different node
functioning: [regulator-gpio](https://www.kernel.org/doc/Documentation/devicetree/bindings/regulator/gpio-regulator.txt).
My thought process being

> I have a regulator, it's enabled by gpio, therefor I must want `gpio regulator`.

This turned out to be false, and `regulator-fixed` itself actually supports using
`gpio` to enable it.

## Getting Data from the HX711

The module uses the [`iio`](https://www.kernel.org/doc/html/v5.4/driver-api/iio/index.html)
subsystem. That document was a little overwealming to me, so here's the cheat codes:

```bash
/sys/bus/iio/devices/iio:device2/in_voltage0_raw
```

## Calibration

Read that file, it will give you the voltage from the device. This value will need
to be calibrated in userspace as documented by the original author of the driver.
This varries depending on which load cell you have and how your device is positioned in
the real world. I may update this post in the future with how i calibrate the device, for
now you probably want to consult the [Datasheet](https://cdn.sparkfun.com/assets/learn_tutorials/5/4/6/hx711F_EN.pdf).
