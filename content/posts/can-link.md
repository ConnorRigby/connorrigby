+++
title = "Can Link"
date = "2022-04-01T23:17:51-06:00"
author = "Connor Rigby"
authorTwitter = "@PressY4Pie" 
cover = "https://raw.githubusercontent.com/miata-bot/can-link/main/hardware/PCB-Render.png?token=GHSAT0AAAAAABPXTHEURDTPBNZ7ORQPU5AOYSH3TPQ"
tags = ["can-link", "elixir", "nerves", "embedded linux", "linux"]
keywords = ["linux", "elixir", "nerves"]
description = "Automotive Nerves Project - RGB Controller with CAN Interface"
showFullContent = false
readingTime = false
+++

I've been working on an idea off and on for the last year or so, and it's finally culminated
into a real thing that exists. What I want is a device that can interface an aftermarket
[ECU](https://en.wikipedia.org/wiki/Electronic_control_unit) in my car, and mesh network with
other nodes to syncronize RGB LEDs. This is of course a silly idea and would not make a real
sustainable product or business, but I think it's fun.

Like I said, I've been working on this for quite a while, so there's quite a bit to catch up
on. Instead of blabbing about the software (which will be blabbed about in the future), I'm
gonna write up a quick summary of my experience doing an entire PCB "from scratch", since that's
the most recent portion of the project I've completed.

## Designing PCB for Nerves Firmware

I picked the BeagleBoneBlue as my development board because it had *almost* all the stuff I
wanted for the final design. It also uses the [OSD335x](https://octavosystems.com/octavo_products/osd335x/) CPU, which is a very well supported device in the Nerves world. I
use it for my current work product, I've worked with other companies using Nerves that use it,
etc.

The first step (after making a prototype ofc) was to make the schematic. Another reason I picked
this devboard was beause of how simple it is. The entire schematic is 5 pages long, and fits
into a single PDF. [Here it is](https://github.com/beagleboard/beaglebone-blue/blob/9812bd927a0157a0a326debb858e36678e6eed64/BeagleBone_Blue_sch.pdf).
I [tricked a friend of mine into importing it into kicad](https://github.com/miata-bot/can-link/commit/69d136ebbe92c61059c85afc6919afc3817271a1) for me, then got to modifying it. 

## The Schematic

![schematic](https://media.discordapp.net/attachments/643947340453118019/958716169408352256/unknown.png?width=2160&height=864)

The easy part was removing things I didn't need:

* EMMC - I plan on using an SD card for this. It's just easier.
* GPIO connectors - I wanted to keep these, but routing was just too hard for me.
* Motor controllers - No motor to control

Next up was to change out some parts:

* Barrel jack changed for a somewhat standard connector used by many aftermarket ECUs.
* USB Mini changed out for a USB C connector - this port is used for firmware debugging
* USB A changed out for USB B - this port is used for a mass storage gadget
* Battery connector changed out for one that I happen to have.
* Changed all the passives out for bigger packages. This was because I'm hand soldering it.

And finally I added some parts:

* JST connector for GPS modules
* 3 Mosfets - used for PWMing the RGB LEDs
* RF69 Packet radio - used for syncing devices without internet
* TAG Connect serial console - used for firmware debugging

And that's it. Pretty much everything else was a standard BeagleBone Blue. I moved some pins
during routing after consulting the datasheet.

## The Layout

After the schematic was mostly together, next up was to lay all the components out. I picked 0603 and 0805 size packages for everything, and laid all the components on the top side. I'm no expert so anyone with real experience in Electrical Engineering will probably have something to say. I guess here is a good place to put: if you, the reader use this for something and it doesn't work; sorry and also I'm not responsible for whatever happens.

I started out with just plopping everything down.

![layout](https://media.discordapp.net/attachments/643947340453118019/958094663275925524/unknown.png).

The first goal was to make sure I have 3d models for every part. I know it seems overkill, but it
just helps me with part placement to be able to visualize things. Kicad's 3d viewer is pretty good once you get the models loaded. If you don't do this, you really should.

Next I sorted the components out into their respective "systems". Decoupling caps per device, pullup/pulldown resistors in some sort of structure, power components, radio, connectors etc.
The goal here is to make sure there's room on the board for everything and to start thinking of everything in relationship to the other components. A good layout here is going to pay off later when it comes to routing.

![layout-progress](https://media.discordapp.net/attachments/643947340453118019/958814194273243146/unknown.png)

What happens next is sort of non-linear. I pretty much just arbitrarily started pecking around
the design, juggling parts around into the correct general shape so it can be moved around as a unit. I didn't have an requirements for where anything should go, which was sort of hard for me to reason about, so I just started assembling sections into blocks.

![layout-progress](https://media.discordapp.net/attachments/643947340453118019/958883714396487722/unknown.png)

The general layout started to take place at this point. The WiFi module was laid out and placed permenantly at the edge of the board. The RF69 radio goes right under it.
Right around this point is when I put some serious thought into how the device should look and
feel when it exists in the real world. I moved the connectors around, made cardboard boxes in about the same shape, etc. Just to see how it would feel to actually use.

Eventually, I decided that the USB and CAN interfaces should be on the right. This is where power
and CAN signal are provided to the board. Technically, that is all that is required to run the device.

![connectors](https://cdn.discordapp.com/attachments/643947340453118019/959123883582169098/unknown.png)

## The Routing

After all the main systems were layed out on the board, it was time to route the board. This is
the second BGA package I've fanned out, and this one was far larger than the last. I did what
I think is an okay job. I'm certain it could be improved, and I'm sure one day I will think this
is the worst thing ever. I ended up removing a bunch of extra stuff I wanted, but didn't need.
Notably, GPIO connectors, extra buttons and extra LEDs. This is the gist of what I came up with for
fanning the package out.

![fanout](https://media.discordapp.net/attachments/643947340453118019/959291652126679080/unknown.png)

While working on that, I took breaks to do other sections that could be built independently.
The WiFi / Bluetooth module was a particularly neat one.

![bluetooth-layout](https://media.discordapp.net/attachments/643947340453118019/959184408865284156/unknown.png)

Once I got all the tracks out of the BGA, all that was left was to shuffle all the signals
to where they needed to go. If I were to do it over again, I'd move the SD Card over to the right
side of the board. I originally put the SD Card on the top of the board thinking I could fan the
MMC pins that direction. I don't remember exactly why i couldn't, but I think it was because
of the big power pours.

This is pretty much the final layout and routing.

![final-layout-routing](https://media.discordapp.net/attachments/643947340453118019/959527063302307960/unknown.png)

Lastly, I sprinkled some text, a logo, and connector descriptions onto the silkscreen.

![final-pcb-model](https://media.discordapp.net/attachments/957852929254113300/959576291563163708/unknown.png)

And that's pretty much as far as I got this weekend. Next up is to pick out each of the individual components.
One notable issue with that is there's this whole global chip shortage thing..

![chip-shortage](https://media.discordapp.net/attachments/643947340453118019/959626650935517194/unknown.png?width=2160&height=144)

I ordered a few OSD335X chips on Aliexpress. Tune back in next week to see if they show up or not.
