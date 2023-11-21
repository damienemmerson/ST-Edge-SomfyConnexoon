-- Required ST provided libraries
local log = require('log')

-- Local imoprts
local config = require('config')


-----------------------------------------------------------------
-- Discovery
-----------------------------------------------------------------

local discovery = {}

-- handle discovery events, normally you'd try to discover devices on your
-- network in a loop until calling `should_continue()` returns false.
function discovery.start(driver, _should_continue)
  log.info("Starting Discovery")

  local metadata = {
    type = config.DEVICE_TYPE,
    -- the DNI must be unique across your hub, using static ID here so that we
    -- only ever have a single instance of this "device"
    device_network_id = config.DEVICE_NETWORK_ID,
    label = config.DEVICE_LABEL,
    profile = config.DEVICE_PROFILE,
    manufacturer = config.DEVICE_MANUFACTURER,
    model = config.DEVICE_MODEL,
    vendor_provided_label = config.DEVICE_PROFILE
  }


  -- tell the cloud to create a new device record, will get synced back down
  -- and `device_added` and `device_init` callbacks will be called
  driver:try_create_device(metadata)
end 
return discovery