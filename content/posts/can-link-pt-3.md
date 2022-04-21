+++
title = "CAN Link Part 3"
date = 2022-04-13T06:29:07-06:00
author = "Connor Rigby"
authorTwitter = "PressY4Pie"
cover = "https://media.discordapp.net/attachments/957852929254113300/963603624628469770/unknown.png?width=807&height=418"
tags = ["can-link", "nerves", "kicad", "embedded linux", "linux"]
keywords = ["linux", "kicad"]
description = "Automotive Nerves Project - RGB Controller with CAN Interface Part 3"
+++

Another day, another hardware redesign. I'm getting pretty good at it by this point, but this should be the last major revision. It's been sent to production at PCBWay and I've ordered components, so there's no going back now.

Right before clicking buy on the last revision's PCBs, a friend of mine tricked me into breaking the remaining pins out on the board. This concept was simple enough, just find connectors that are in stock and plumb up the remaining pins. What i ended up with at first came out looking pretty cool

![pcb pre-revision](https://cdn.discordapp.com/attachments/957852929254113300/962854818156773406/unknown.png)

I mulled on this design overnight, planning to order it the next day. That is, until a different friend tricked me yet again. For good reason tho, look at [these enclosures](https://www.te.com/usa-en/product-CAT-D485-EN17.html?q=&n=41628&type=products&samples=N&inStoreWithoutPL=false&instock=N) and the accompanying [connector](https://www.te.com/usa-en/product-DTM1312PA12PBR008.html).

![enclosure](https://www.te.com/content/dam/te-com/catalog/part/CAT/D48/5EN/CAT-D485-EN17-t2.jpg/jcr:content/renditions/product-details.png)
![connector](https://www.te.com/content/dam/te-com/catalog/part/DTM/131/2PA/DTM1312PA12PBR008-t1.jpg/jcr:content/renditions/product-details.png)

Only problem, my current design was no where near fitting

![pcb-enclosure-disagreement](https://cdn.discordapp.com/attachments/957852929254113300/963054779372814366/unknown.png)

So of course that lead me to the final redesign. I'm getting pretty quick at it by now. It only took me a few hours on Monday afternoon. The gritty details of this revision weren't that interesting. The only net-new part I chose was [this waterproof USB connector](https://octopart.com/uc-31pffp-qs8001-amphenol+ltw-81782226). It took me a little bit to deside where exactly to put it, but ultimately I decided the opposite side of the main connectors was suitable. This will require modification of the enclosure, but it should be simple.

![PCB with USB](https://media.discordapp.net/attachments/957852929254113300/963064627242078248/unknown.png?width=514&height=605)

Nothing else was really that interesting here, so here's a few beauty shots.

|||
|:-|-:|
|![front-no-case](https://media.discordapp.net/attachments/957852929254113300/963236288918585404/unknown.png?width=467&height=605)|![front-case](https://media.discordapp.net/attachments/957852929254113300/963237763535224842/unknown.png?width=519&height=605)|
|![back-no-case](https://media.discordapp.net/attachments/957852929254113300/963236289325461574/unknown.png?width=467&height=605)|![back-case](https://media.discordapp.net/attachments/957852929254113300/963237763874955314/unknown.png?width=539&height=604)

I'm also absolutely obsessed with the "export STEP" feature of KiCAD. I even installed Fusion 360 for the first time to play with the model.

![cad](https://media.discordapp.net/attachments/957852929254113300/963603624628469770/unknown.png?width=807&height=418)

In other tangentally related news, I made the repository [public](https://github.com/miata-bot/can-link). Stay tuned for next time, I plan to write up a quick post on "porting" all the existing software to the new hardware platform.
