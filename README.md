# Somfy Connexoon Edge Driver
Smartthings Edge Driver for the Somfy Connexoon hub. The driver has been developed for Connexoon (RTS) users and tested only for Somfy RTS blinds.

More supported Somfy RTS devices can be added - Just ask me!

## Prerequisites
- Smartthings Hub
- Somfy Connexoon Hub

## Setup

### Configure Connexoon 

1. Register all your Somfy RTS products on the Connexoon hub
1. Activate your Connexoon hub
1. Generate and Activate an API Token using using the instructions [here](https://github.com/Somfy-Developer/Somfy-TaHoma-Developer-Mode)

> [!IMPORTANT]
> Australian users should use the instructions above but replace `{{url}}` with `ha201-1.overkiz.com`

### Configure Smartthings 

1. Enroll your hub into my production channel [here](https://callaway.smartthings.com/channels/d9a44c51-f5db-4849-81a6-dc7c6b3540ff)
1. Select ***Available Drivers***.
1. Find the Edge Driver called ST-Edge-SomfyConnexoon and select ***Install***
1. Discover the Somfy Connexoon device in the Smartthings App by selecting ***Add device*** > ***Scan for nearby devices*** 

> [!NOTE]
> Once the Somfy Connexoon hub has been discovered, it will appear offline until you configure the IP address and Token in the device settings

1. Tap the vertical ellipsis and choose settings.
1. Enter the IP address and token for the Connexoon hub.
1. Tap on the discover button in the detailed view.

## Limitationsabove 
