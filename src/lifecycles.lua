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

  -- Setting the Health Check schedule
  device.thread:call_on_schedule(
    config.SCHEDULE_PERIOD,
    function ()
      local success, response = commands.checkConnection()
      if device.vendor_provided_label == "Somfy-Connexoon" then
        device:emit_event(Cap_status.status(response))
      end
      if success then
        device:online()
      else
        device:offline()
      end
    end,
    'healthcheck')

  -- Calling Refresh to check configuration and connection to Connexoon
  commands.handle_refresh(driver, device)

  -- Setting the initial value of the Window Shade capability
  if device.vendor_provided_label == "Somfy-Blind" then
    device:emit_event(caps.windowShade.windowShade('open'))
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
  commands.handle_refresh(driver, device)
end


-- This function is called when the platform believes the device needs to go through provisioning for it to work as expected
function lifecycles.doConfigure(driver, device)
  log.info("[" .. device.id .. "] Do configure")
end

return lifecycles