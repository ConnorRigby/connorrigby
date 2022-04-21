+++
title = "i.MX6 Development board"
date = "2022-04-21T15:49:46-06:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie" #do not include @
cover = "https://media.discordapp.net/attachments/957852929254113300/966172020259831848/unknown.png"
tags = ["nerves", "kicad", "embedded linux", "linux"]
keywords = ["kicad", "linux", "imx6"]
description = "Desigining and fabricating a custom i.MX6 Development board"
showFullContent = false
readingTime = false
+++

While waiting on PCBs to come in the mail for other [projects](https://cone.codes/posts/can-link-pt-3/), a friend of mine linked me something I only wish I had found sooner. An [i.MX6 SOC](https://jlcpcb.com/parts/componentSearch?isSearch=true&searchTxt=C1555487). Most importantly, it can be found in stock! At JLCPCB nonetheless. This prompted me to consider; Could I make a Linux capable device using only components at JLCPCB? Well, spoiler alert - no. But I tried anyway.

## The Major Challenge

This was a cool discovery - I've always wanted a low cost platform I can use for small one-off designs. What originally hoped the OSD335xx or OSD32-MP1 platforms could offer me. The global chip shortage really stuffed that one up for me, a hobbiest. What's cool about the i.MX platforms, is they are (mostly) pin compatible. This means I can create a general "core" module that I can simply plop down on a design and be on my way to prototypes. The only problem - I've never routed DRAM before. The concept has always terrified me as someone with no propper training in this stuff. I knew the general concepts, some *address* wires, some *data* wires, maybe some *clocks*? Are those differential pairs? What about termination resistors? Something about inductance? Okay so I needed a bit more than a primer. I spent all my free time researching this subject for about 3 days. After reading countless arguments on StackOverflow or watching every KiCAD tutorial on Youtube, I didn't feel that much more confident so I figured it was time to just start failing. Which I did. A lot.

![kicad-pcb-view](https://media.discordapp.net/attachments/957852929254113300/965619565511974963/unknown.png)

I didn't take many screenshots throughout this process like I normally do, but this about sums the experience up.
Eventually I managed to get the entire circuit routed. NXP has a few app notes and some reference designs that I used as much as I could.

![kicad-3d-view](https://media.discordapp.net/attachments/957852929254113300/965655287711297616/unknown.png)

During this process, I found a few really useful resources:

* [mxiot](https://github.com/jaydcarlson/mxiot) - A devboard using this exact SOC. I used this a lot in the beginning for the schematic and general understanding of the platform.
* [nanoberry](https://github.com/EnzoRF/nanoberry) - More of the above, but developed in KiCAD. I used this **a lot**

## The Easy parts

After getting the high speed DRAM routed, the rest of the process was pretty familiar. I plopped down some connectors I already had laying around in my office for I/O and routed in a WiFi module. This was all that was really needed to test the device out. As I mentioned earlier, the i.MX 6 series are "pin compatible" with different models. What this means is that although I'm currently using the `6ULZ` version for this now, I could in theory use any of the other devices in this series using the same BGA289 package. So in the name of planning ahead, I added a few more things. Because I eventually want to use this circuit to replace the CM4 in [an another project](https://cone.codes/posts/can-link-pt-2/), I added a CAN transciever and a DB9 connector (which is for better or worse, standard) and of course a buck converter to get 12v down to 5v.

I also added a couple other things, for no good reason other than because they were in the library and easy to add - a RFM69 SPI radio, and a RP2040.
![back-side](https://media.discordapp.net/attachments/957852929254113300/966168700078162001/unknown.png)

## Fabrication

The original reason I toook this on was because I thought I could have it fabricated by JLCPCB. At the very beginning, I checked their [capabilities](https://jlcpcb.com/capabilities/Capabilities)
![caps](https://media.discordapp.net/attachments/957852929254113300/966840182848495636/unknown.png?width=2160&height=616)
which claim to support 0.2/0.4 vias. What it doesn't say, is that when you actually go to order boards, you have to select a special option that more than doubles the price of the board, and it's still right at the limit of their capabilities. So I ultimately went with PCBWay since I had coupons and the price came out to be cheaper overall with them instead of JLCPCB.

All said and done, 2 fully populated prototypes cost me $350 shipped to my house. The BOM cost is about $50 per device. I didn't define a firm price that I wanted, but $350 is more than I wanted, but still not *that* bad. The coolest part about it is that all components were readily available with no signifigant lead time.

Check back in a month when they arrive and I find out if I can copy/paste out of a reference design well enough to get this device to boot.
