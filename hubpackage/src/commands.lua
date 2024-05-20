-- Required ST provided libraries
local log = require('log')
local ltn12 = require('ltn12')
local cosock = require "cosock"
local https = cosock.asyncify "ssl.https"
local caps = require('st.capabilities')
local json = require('dkjson')

-- local imports
local config = require('config')

-- Mappings
local mapWindowShadeAction = {
  -- Mapping for Window Shade capability actions
  pause = 'stop',
  close = 'close',
  open = 'open'
}

local mapWindowShadeState = {
  -- Mapping for Window Shade capability states
  stop = 'partially open',
  close = 'closed',
  open = 'open'
}


local commands = {}

-----------------------------------------------------------------
-- Capability Handlers
-----------------------------------------------------------------

-- Handle Window Shade commands
function commands.handle_blind(driver, device, command)
  
  -- Constants
  local API_BASE_URL='https://'..IpAddress..':8443/enduser-mobile-web/1/enduserAPI'
  local API_EXECUTE_PATH='/exec/apply'

  -- Handle Window Shade action mapping
  local action = mapWindowShadeAction[command.command] or command.command

  -- API request body
  local body_table = {
    label = device.label,
    actions = {
      {
        commands = {
          {
            name = action
          }
        },
        deviceURL = device.device_network_id
      }
    }
  }
  local body = json.encode(body_table) -- Convert the Lua table to a JSON string
  
  log.info('Sending API request...')
  local success, response = commands.send_lan_command(API_BASE_URL, 'POST', API_EXECUTE_PATH, body)
  
  -- Handle Window Shade state mapping
  action = mapWindowShadeState[action] or action

  if success then 
    log.info('API request completed successfully.')
    -- Set the state of the Window Shade capability based on the action
    device:emit_event(caps.windowShade.windowShade(action))
  else 
    log.debug('Error completing API request: ', response)
  end
end


-- Handle Discovery command
function commands.handle_discover(driver, device)
  
  -- Constants
  local API_BASE_URL='https://'..IpAddress..':8443/enduser-mobile-web/1/enduserAPI'
  local API_GET_DEVICES_PATH='/setup/devices'

  -- Emit a discovery event
  device:emit_event(Cap_status.status('Running discovery'))

  log.info('Sending API request...')
  local success, response = commands.send_lan_command(API_BASE_URL, 'GET', API_GET_DEVICES_PATH)

  if success then
    if response then
      -- Iterate over each device
      for _, deviceInfo in ipairs(response) do    
        -- Create child devices
        commands.create_child_edge_driver(driver, device, deviceInfo)
      end
      -- Emit a discovery status
       device:emit_event(Cap_status.status('Connected'))
    else
          log.error("Failed to decode JSON response for devices.")
      end
  else
    log.debug('Error completing API request: ', response)
  end
end


-- Handle Refresh command
function commands.handle_refresh(driver, device)
  -- Handle refresh for Connexoon
  if device.vendor_provided_label == "Somfy-Connexoon" then
    -- First check the configuration
    local success, response = commands.checkConfig(driver, device)
    -- If the device is configured then check for the connection
    if success then
      local success, response = commands.checkConnection(driver, device)
      device:emit_event(Cap_status.status(response))

      if success then
        device:online()
      else
        device:offline()
      end 
    -- If the connexoon is not configured emit 'Not configured' status
    else
      device:emit_event(Cap_status.status(response))
      device:offline()
    end
  -- Handle refresh for all other devices
  else
    local success, response = commands.checkConnection(driver, device)
    if success then
      device:online()
    end
  end
end


-----------------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------------

-- Creates child devices
function commands.create_child_edge_driver(driver, device, deviceInfo)

  local device_profile

  -- Set device profile for Somfy RTS Blinds
  if deviceInfo.controllableName == "rts:BlindRTSComponent" then        
    device_profile = 'Somfy-Blind'
  elseif deviceInfo.controllableName == "rts:CellularBlindRTSComponent" then        
    device_profile = 'Somfy-Blind' 
  elseif deviceInfo.controllableName == "io:HorizontalAwningIOComponent" then        
    device_profile = 'Somfy-Blind' 
  end

  -- Set child device metadata
  if device_profile then
    local child_device_metadata = {
      type = config.DEVICE_TYPE,
      label = deviceInfo.label,
      device_network_id = deviceInfo.deviceURL,
      profile = device_profile,
      manufacturer = config.DEVICE_MANUFACTURER,
      model = config.DEVICE_MODEL,
      vendor_provided_label = device_profile,
      parent_device_id = device.id
    }

    -- Create the child device
    driver:try_create_device(child_device_metadata)
  end
end


-- Send API calls to Connexoon
function commands.send_lan_command(url, method, path, body)
  local dest_url = url .. path
  local res_body = {}
  
  local headers = {
    ['Content-Type'] = 'application/json',
    ['accept'] = 'application/json',
    ['Authorization'] = 'Bearer '..Token
  }

  if method ~= 'GET' then
    local content_length = #body
    headers['Content-Length'] = content_length
  end

  log.info('url:', dest_url)
  local _, code, _, status = https.request({
    method = method,
    url = dest_url,
    sink = ltn12.sink.table(res_body),
    headers = headers,
    source = method ~= 'GET' and ltn12.source.string(body) or nil
  })

  if code == 200 then
    local response_string = table.concat(res_body)
    local decoded_response = json.decode(response_string)
    return true, decoded_response
  else
    log.error('API request failed with code:', code)
    return false, nil
  end
end


-- Checks if device has been configured
function commands.checkConfig(driver, device)
  -- Initialise global variables
  Token = device.preferences.token
  IpAddress = device.preferences.ipAddress
  
  if device.preferences.token ~= "00000000000000000000" and device.preferences.ipAddress ~= "0.0.0.0" then  
    return true, 'Configured'
  else
    return false, 'Not Configured'
  end 
end


-- Checks connection to Connexoon
function commands.checkConnection(driver, device)
   -- Constants
   local API_BASE_URL='https://'..IpAddress..':8443/enduser-mobile-web/1/enduserAPI'
   local API_GET_DEVICES_PATH='/setup/devices'
 
   log.info('Sending API request...')
   local success, response = commands.send_lan_command(API_BASE_URL, 'GET', API_GET_DEVICES_PATH)
  
  if success then 
    return true, 'Connected'
  else
    return false, 'Disconnected'
  end
end

return commands
