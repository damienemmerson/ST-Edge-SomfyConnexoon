-- Required ST provided libraries
local log = require('log')
local caps = require('st.capabilities')

-- Local imports
local commands = require('commands')
local config = require('config')


-----------------------------------------------------------------
-- Lifecycle functions
-----------------------------------------------------------------

local lifecycles = {}

-- This function is called once a device is added by the cloud and synchronized down to the hub
function lifecycles.init(driver, device)
  log.info("[" .. device.id .. "] Initializing device")

  
  -- Set inital values of devices
  if device.vendor_provided_label == "Somfy-Connexoon" then
    log.info('handling refresh')
    commands.handle_refresh(driver, device)
  elseif device.vendor_provided_label == "Somfy-Blind" then
    device:emit_event(caps.windowShade.windowShade('open'))
  elseif device.vendor_provided_label == "Somfy-IO-Shutter" then
    device:emit_event(caps.windowShade.windowShade('open'))
    device:emit_event(caps.windowShadeLevel.shadeLevel(100))
  elseif device.vendor_provided_label == "Somfy-GarageDoor" then
    device:emit_event(caps.doorControl.door('closed'))
  elseif device.vendor_provided_label == "Somfy-TempSensor" then
    device:emit_event(caps.temperatureMeasurement.temperature('0'))
  elseif device.vendor_provided_label == "Somfy-LightSensor" then
    device:emit_event(caps.illuminanceMeasurement.illuminance('0'))
  elseif device.vendor_provided_label == "Somfy-ContactSensor" then
    device:emit_event(caps.contactSensor.contact('open'))
  end
end

-- This function is called both when a device is added (but after `added`) and after a hub reboots
function lifecycles.added(driver, device)
  log.info("[" .. device.id .. "] Adding new device")
end

-- This function is called when a device is removed by the cloud and synchronized down to the hub
function lifecycles.removed(_, device)
  log.info("[" .. device.id .. "] Removing device")
end

-- This function is called when the preferences of the device have changed
function lifecycles.infoChanged(driver, device, event, args)
  log.info("[" .. device.id .. "] Info changed")

  if device.vendor_provided_label == "Somfy-Connexoon" then
    log.info('handling refresh')
    commands.handle_refresh(driver, device)
  elseif device.vendor_provided_label == "Somfy-IO-Shutter" then
    local action = 'setMemorized1Position'
    local presetPosition = 100 - device.preferences.presetPosition1 --transform number for somfy
    log.info ('Preset position set to ', presetPosition)
    commands.sendCommand(driver, device, action, presetPosition)
  end
end

-- This function is called when the platform believes the device needs to go through provisioning for it to work as expected
function lifecycles.doConfigure(driver, device)
  log.info("[" .. device.id .. "] Do configure")
end

return lifecycles
