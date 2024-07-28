-- Required ST provided libraries
local driver = require('st.driver')
local caps = require('st.capabilities')

-- Local imports
local commands = require('commands')
local discovery = require('discovery')
local lifecycles = require('lifecycles')

-- Custom capabilities
Cap_status = caps["smoothoption15782.status"]
Cap_discovery = caps["smoothoption15782.discovery"]

-- Create the driver object
local driver =
  driver(
    'ST-Edge-Connexoon',
    {
      discovery = discovery.start,
      lifecycle_handlers = lifecycles,
      capability_handlers = {
        [caps.windowShade.ID] = {
          [caps.windowShade.commands.open.NAME] = commands.handle_windowShade,
          [caps.windowShade.commands.close.NAME] = commands.handle_windowShade,
          [caps.windowShade.commands.pause.NAME] = commands.handle_windowShade
        },
        [caps.windowShadePreset.ID] = {
          [caps.windowShadePreset.commands.presetPosition.NAME] = commands.handle_windowShadePreset
        },
        [caps.windowShadeLevel.ID] = {
          [caps.windowShadeLevel.commands.setShadeLevel.NAME] = commands.handle_windowShadeLevel,
        },
        [caps.doorControl.ID] = {
          [caps.doorControl.commands.open.NAME] = commands.handle_doorControl,
          [caps.doorControl.commands.close.NAME] = commands.handle_doorControl,
        },
        [caps.refresh.ID] = {
          [caps.refresh.commands.refresh.NAME] = commands.handle_refresh
        },
        [Cap_discovery.ID] = {
          [Cap_discovery.commands.discover.NAME] = commands.handle_discover
        }
      }
    }
  )

-- Run the driver
driver:run()
