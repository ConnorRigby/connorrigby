+++
title = "Can Link Part 2"
date = "2022-04-08T15:19:25-06:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie" #do not include @
cover = "https://media.discordapp.net/attachments/957852929254113300/962088847506800690/unknown.png"
tags = ["can-link", "elixir", "nerves", "embedded linux", "linux"]
keywords = ["linux", "elixir", "nerves"]
description = "Automotive Nerves Project - RGB Controller with CAN Interface"
+++

Last week, I closed with

> I ordered a few OSD335X chips on Aliexpress. Tune back in next week to see if they show up or not.

Well, it's next week, and my order got canceled. I ordered s'more from other places, and it was canceled. I Couldn't even find anywhere that had a *single* SOM for me to buy. Best I could find was [Minimum Order Quantity](https://en.wikipedia.org/wiki/MOQ) of 250 pieces. So I did what any reasonable person would do; Desoldered some from old, broken boards.

![desoldered-som](https://media.discordapp.net/attachments/643947340453118019/961053924801011712/IMG_20220405_180317.jpg?width=759&height=1012).

Then after sleeping on the idea of desoldering 10+ of these, I realized this probably isn't the move for this project.

As a side note

> FS: 1 (one) OSD3558-512M-BAS, slightly used $1000 OBO

So I had a look through [Octopart](https://octopart.com/), and decided that this project was dumb and gave up.

## Redesigning the PCB

Then I made some coffee, sat down, and got to work redesigning the PCB for a [Raspberry Pi Compute Module](https://www.raspberrypi.com/products/compute-module-4/). These are really cool modules, but not really specced for this application. They are obviously targeted at media applications, not industrial control protocols or much/any interaction with the outside world. Buuuut they do have one good thing going for them - I can get a few of them. Below is a table showing some of the important differences in the main CPUs.

|SOM | CPU Clock Speed | CPU Cores | RAM | Available PWM | USB Ports | Native CAN support | CSI (camera) ports | DSI (display) ports | HDMI ports |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| OSD335x | 900 MHz | 1 | 512MB | a lot | 2 | yes | 0 | 0 | 0 |
| CM4 | 1.4 GHz | 4 |1-8 GB | 2 (3 are required) | 1 (2 were desired ) | no (required) | 2 | 2 | 2 |

Soooo, while it technically is easier to obtain, the next issue is finding external components to do all the stuff I don't need, notably CAN and RGB (the literal only requirements for this project). 

Irritated, I hopped back onto OctoPart and started component hunting. First up was something about the PWM issue. I had two ideas for this, so to prevent further redesigns I decided to lay out both, just in case. The most straightforward solution is using some sort of IO Expander chip. I knew of one right off the top of my head: [NXP PCA9685PW,112](https://www.futureelectronics.com/p/semiconductors--analog--drivers--led-drivers-linear-mode/PCA9685PW-112-nxp-1019213?utm_source=octopart&utm_medium=aggregator&utm_campaign=crossref&utm_term=PCA9685PW%2C112). It's made specifically for controlling RGB LEDs via [I²C](https://en.wikipedia.org/wiki/I%C2%B2C). Features include: [already having a driver in Linux](https://github.com/torvalds/linux/blob/master/drivers/pwm/pwm-pca9685.c) and being pretty straight forward to design around. Bad news is it's really popular so I can't find it anywhere. So, the backup then: [A Raspberry Pi Pico](https://www.raspberrypi.com/products/raspberry-pi-pico/). I originally planned on using just the RP2040 chip, but you guessed it - out of stock. I connected it to the CM4 via I²C, and slapped it down on the board.

The other missing main component is something that speaks [CAN](https://en.wikipedia.org/wiki/CAN_bus). Again, I already had an idea for this as well. [The MCP2515](https://www.microchip.com/en-us/product/MCP2515). It's old, it's not recommended for new designs, and I have a bunch of them in different packages on the shelf. Not much else to say about this chip other than because I have a bunch of them in 2 different packages, I plopped down a footprint for both of them on the board so I can just solder whichever without spinning a new board:

![MCP Dual footprints](https://media.discordapp.net/attachments/643947340453118019/961786045333119076/unknown.png)

In the shot above, `U8` and `U5` are both a `MCP2515`, just in two different packages. (also photo'd is the `pca9685` chip above.)

The other thing I tested this week was the "hack" of using a set of BSS138 N channel transistors to do the LED PWMing.

![BSS138 prototype](https://media.discordapp.net/attachments/643947340453118019/960593404012675132/IMG_20220404_113438.jpg?width=759&height=1012)

As it turns out, they are not suitable for this application. When I threw these prototype boards on my bench supply connected to the prototype, I managed to melt the transistor at 12V @ 2A. I **could** just limit the brightness in software, but since I'm spinning the board anyway, I replaced them with a set of [Mosfets](https://en.wikipedia.org/wiki/MOSFET).

Finally, after about a day of rerouting and updating everything, I was left with the new PCB. The best part, 93% procurable component selection.

![octopart-bom](https://media.discordapp.net/attachments/957852929254113300/962089782127788072/unknown.png)

![rerouted-pcb-final](https://media.discordapp.net/attachments/957852929254113300/962088847506800690/unknown.png)

## Conclusions

I'm not super happy that I had to go through all this, but for what it's worth, using the CM4 module was *very* easy, Even if it's not the perfect selection. I really wanted to use the OSD335x chip since it's a really cool chip, and has all the stuff I need built right into it. I'm sure I **could** have hunted around for another SOM. Several come to mind, the OSD32MP1, Most of the IMX line, etc. But upon quick searches, they are all just as hard to get as the OS335x.
The other interesting part of all of this is that the BOM price actually went down by quite a bit. I wasn't keeping super good track of this since most of the components I selected for the original design are out of stock and therefor artifically inflated in price. It's kind of frustrating that it was easier to use something designed for set top boxes than it was to use something purpose built for my project but oh well.

Tune back in next week to see if I give entirely for real this time.
