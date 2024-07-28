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
local mapCommand = {
  -- Maps device commands to Somfy actions
  pause = 'stop',
  close = 'close',
  open = 'open',
  presetPosition = 'my'
}

StoredData = {}

local commands = {}

-----------------------------------------------------------------
-- Capability Handlers
-----------------------------------------------------------------

function commands.handle_windowShade(driver, device, command)
  -- Handle Window Shade action mapping
  local action = mapCommand[command.command] or command.command
  commands.sendCommand(driver, device, action, nil)
end

function commands.handle_windowShadeLevel(driver, device, command)
  local action = 'setPosition'
  local shadeLevel = command.args.shadeLevel
  log.info ('Window shade level changed to ', shadeLevel)
  commands.sendCommand(driver, device, action, shadeLevel)
end

function commands.handle_windowShadePreset(driver, device, command)
  -- Handle Window Shade action mapping
  local action = mapCommand[command.command] or command.command
  commands.sendCommand(driver, device, action, nil)
end

function commands.handle_doorControl(driver, device, command)
  -- Handle Window Shade action mapping
  local action = mapCommand[command.command] or command.command
  commands.sendCommand(driver, device, action, nil)
end


-- Handle executed actions
function commands.sendCommand(driver, device, command, parameter)
  -- Constants
  local API_BASE_URL = 'https://' .. IpAddress .. ':8443/enduser-mobile-web/1/enduserAPI'
  local API_EXECUTE_PATH = '/exec/apply'

  -- API request body
  local body_table = {
    label = device.label,
    actions = {
      {
        commands = {
          {
            name = command,
            parameters = {parameter}
          }
        },
        deviceURL = device.device_network_id
      }
    }
  }
  local body = json.encode(body_table) -- Convert the Lua table to a JSON string
  
  log.info('Sending API request...')
  local success, response = commands.send_lan_command(API_BASE_URL, 'POST', API_EXECUTE_PATH, body)

  if success then 
    log.info('API request completed successfully.')
  else
    log.error('Error completing API request: ', response)
  end
end


-- Handle Discovery command
function commands.handle_discover(driver, device)
  -- Constants
  local API_BASE_URL = 'https://' .. IpAddress .. ':8443/enduser-mobile-web/1/enduserAPI'
  local API_GET_DEVICES_PATH = '/setup/devices'

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
  log.info('Device refresh initiated...')
  
  if HealthCheckTimer then
    device.thread:cancel_timer(HeathCheckTimer)
  end
  if FetchEventsTimer then
  device.thread:cancel_timer(FetchEventsTimer)
  end

  -- First check the configuration
  local success, response = commands.checkConfig(driver, device)
 
  -- If the device is configured then check for the connection
  if success then
    local success, response = commands.checkConnection(driver, device)
    device:emit_event(Cap_status.status(response))
    if success then
      device:online()
      commands.setHealthCheckSchedule(driver, device)
      commands.setFetchEventsSchedule(driver, device)
    else
      device:offline()
    end 
  -- If the connexoon is not configured emit 'Not configured' status
  else
    device:emit_event(Cap_status.status(response))
    device:offline()
  end
  log.info('Device refresh complete')
end


-----------------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------------

-- Creates child devices
function commands.create_child_edge_driver(driver, device, deviceInfo)

  local device_profile

  -- Set device profile for Somfy RTS Blinds
  if deviceInfo.controllableName == "rts:BlindRTSComponent" then        
    --device_profile = 'Somfy-Blind'
    device_profile = 'Somfy-IO-Shutter' --TESTING ONLY
  elseif deviceInfo.controllableName == "rts:CellularBlindRTSComponent" then        
    device_profile = 'Somfy-Blind'
  elseif deviceInfo.controllableName == "io:HorizontalAwningIOComponent" then        
    device_profile = 'Somfy-Blind'
  elseif deviceInfo.controllableName == "io:RollerShutterGenericIOComponent" then        
    device_profile = 'Somfy-IO-Shutter'
  elseif deviceInfo.controllableName == "io:GarageOpenerIOComponent" then        
    device_profile = 'Somfy-GarageDoor'
  elseif deviceInfo.controllableName == "io:LightIOSystemSensor" then        
    device_profile = 'Somfy-LightSensor'
  elseif deviceInfo.controllableName == "io:SomfyContactIOSystemSensor" then        
    device_profile = 'Somfy-ContactSensor'
  elseif deviceInfo.controllableName == "io:TemperatureIOSystemSensor" then        
    device_profile = 'Somfy-TempSensor'
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
    if body == nil then
      headers['Content-Length'] = 0
    else
    local content_length = #body
    headers['Content-Length'] = content_length
    end
  end

  local _, code, _, status = https.request({
    method = method,
    url = dest_url,
    sink = ltn12.sink.table(res_body),
    headers = headers,
    source = method == 'POST' and ltn12.source.string(body) or nil
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

  log.info('Checking configuration...')

  if device.preferences.token ~= "00000000000000000000" and device.preferences.ipAddress ~= "0.0.0.0" then  
    log.info('Device is configured')
    return true, 'Configured'
  else
    log.debug('Device is not configured')
    return false, 'Not Configured'
  end 
end


-- Checks connection to Connexoon
function commands.checkConnection(driver, device)
   -- Constants
   local API_BASE_URL = 'https://'..IpAddress..':8443/enduser-mobile-web/1/enduserAPI'
   local API_GET_DEVICES_PATH = '/setup/devices'
   local METHOD = 'GET'
 
   log.info('Checking connection...')
   local success, response = commands.send_lan_command(API_BASE_URL, METHOD, API_GET_DEVICES_PATH)
  
  if success then 
    log.info('Conection established')
    return true, 'Connected'
  else
    log.debug('Conection not established')
    return false, 'Disconnected'
  end
end

function commands.setHealthCheckSchedule(driver, device)
  -- Setting the Health Check schedule
  log.info('Setting health check schedule....')
  HeathCheckTimer = device.thread:call_on_schedule(
    config.SCHEDULE_PERIOD,
    function()
      local success, response = commands.checkConnection()
      device:emit_event(Cap_status.status(response))
      if success then
        device:online()
      else
        device:offline()
      end
    end,
    'healthCheck')
    log.info('Health check schedule set')
end

function commands.setFetchEventsSchedule(driver, device)
  -- Register event listener
  log.info('Registering event listener....')
  local success, response = commands.registerEventListener()
  
  if success then
    log.info('Event listener registered')
    log.info('Setting fetch events schedule....')
    -- Fetch events on schedule
    FetchEventsTimer = device.thread:call_on_schedule(
      device.preferences.refreshInterval,
    function ()
      commands.fetchEvents(driver, device, response)
    end,
    'fetchEvents')
    log.info('Fetch events schedule set')
  else
    log.error('Failed to register event listener')
  end
end

function commands.registerEventListener()
  -- Constants
  local API_BASE_URL = 'https://'..IpAddress..':8443/enduser-mobile-web/1/enduserAPI'
  local API_GET_DEVICES_PATH = '/events/register'
  local METHOD = 'POST'

  local success, response = commands.send_lan_command(API_BASE_URL, METHOD, API_GET_DEVICES_PATH, nil)

  if success then 
    return true, response
  else
    return false, response
  end
end

function commands.fetchEvents(driver, device, response)
  -- Constants
  local API_BASE_URL = 'https://'..IpAddress..':8443/enduser-mobile-web/1/enduserAPI'
  local API_GET_DEVICES_PATH = '/events/'..response.id..'/fetch'
  local METHOD = 'POST'

  local success, response = commands.send_lan_command(API_BASE_URL, METHOD, API_GET_DEVICES_PATH, nil)

  if success then
    if response then
      for _, eventInfo in ipairs(response) do 
        log.info('Received event: ' .. json.encode(eventInfo))   
        commands.handleEvent(driver, device, eventInfo)
      end
    end
  end
end

function commands.handleEvent(driver, device, eventInfo)
  if eventInfo.name == 'ExecutionRegisteredEvent' then
    log.debug('Handling ExecutionRegisteredEvent')

    -- Store the eventInfo temporarily
    local deviceURL = eventInfo.actions[1].deviceURL
    StoredData[deviceURL] = eventInfo

  elseif eventInfo.name == 'ExecutionStateChangedEvent' then
    log.debug('Handling ExecutionStateChangedEvent')

    local execId = eventInfo.execId
    
    -- Retrieve stored event
    local storedInfo = commands.retrieveStoredDataByExecId(execId)

    if storedInfo then
      log.debug("Stored data found")
      commands.updateChildDeviceStatus(driver, device, storedInfo, eventInfo)
    else
      log.warn("No stored data found with matching execId: " .. execId)
    end
  elseif eventInfo.name == 'DeviceStateChangedEvent' then
    log.debug('Handling DeviceStateChangedEvent')

    local deviceURL = eventInfo.deviceURL
    local deviceStatesName = eventInfo.deviceStates[1].name
    local deviceStatesValue = eventInfo.deviceStates[1].value

    -- Retrieve child device to be updated
    local child = commands.getChildDevice(driver, device, deviceURL)

    -- Set child device status
    if child then
      log.debug("Child device found")
      commands.setChildStatus(child, deviceStatesName, deviceStatesValue)
    else
      log.warn("No child device found with matching deviceURL:", deviceURL)
    end
  else
    log.error('Unhandled Event: ' .. json.encode(eventInfo))
  end
end

function commands.updateChildDeviceStatus(driver, device, storedInfo, eventInfo)
  local deviceURL = storedInfo.actions[1].deviceURL
  local command = storedInfo.actions[1].command
  local executionState = eventInfo.newState
  local execId = eventInfo.execId

  -- get child using deviceURL
  local child = commands.getChildDevice(driver, device, deviceURL)

  if child then
    if executionState == "IN_PROGRESS" then
      -- update child device status
      if command == 'open' then
        log.debug('setting status to opening')
        if child.vendor_provided_label == 'Somfy-Blind' then
          child:emit_event(caps.windowShade.windowShade('opening'))
        elseif child.vendor_provided_label == 'Somfy-GarageDoor' then
          child:emit_event(caps.doorControl.door('opening'))
        end
      elseif command == 'close' then
        log.debug('setting status to closing')
        if child.vendor_provided_label == 'Somfy-Blind' then
          child:emit_event(caps.windowShade.windowShade('closing'))
        elseif child.vendor_provided_label == 'Somfy-GarageDoor' then
          child:emit_event(caps.doorControl.door('closing'))
        end
      elseif command == 'stop' then
        log.debug('setting status to partially open')
        if child.vendor_provided_label == 'Somfy-Blind' then
          child:emit_event(caps.windowShade.windowShade('partially open'))
        elseif child.vendor_provided_label == 'Somfy-GarageDoor' then
          child:emit_event(caps.doorControl.door('partially open'))
        end
      end
    elseif executionState == "COMPLETED" then
      -- update child device status
      if command == 'open' then
        log.debug('setting status to open')
        if child.vendor_provided_label == 'Somfy-Blind' then
          child:emit_event(caps.windowShade.windowShade('open'))
        elseif child.vendor_provided_label == 'Somfy-GarageDoor' then
          child:emit_event(caps.doorControl.door('open'))
        end
      elseif command == 'close' then
        log.debug('setting status to closed')
        if child.vendor_provided_label == 'Somfy-Blind' then
          child:emit_event(caps.windowShade.windowShade('closed'))
        elseif child.vendor_provided_label == 'Somfy-GarageDoor' then
          child:emit_event(caps.doorControl.door('closed'))
        end
      elseif command == 'my' then
        log.debug('setting status to partially open')
        if child.vendor_provided_label == 'Somfy-Blind' then
          child:emit_event(caps.windowShade.windowShade('partially open'))
        elseif child.vendor_provided_label == 'Somfy-GarageDoor' then
          child:emit_event(caps.doorControl.door('partially open'))
        end
      end
      --Remove stored data
      StoredData[execId] = nil
    end
  end
end

function commands.retrieveStoredDataByExecId(execId)
  for deviceURL, storedEvent in pairs(StoredData) do
    if storedEvent.execId == execId then
      return storedEvent
    end
  end
  return nil
end

function commands.getChildDevice(driver, device, deviceURL)
  local deviceList = device:get_child_list()
  local child = nil
  
  for _, dev in ipairs(deviceList) do
    if dev.device_network_id == deviceURL then
      child = dev
      break
    else 
      child = nil
    end
  end
  return child
end

function commands.setChildStatus(child, deviceStatesName, deviceStatesValue)
  if deviceStatesName == "core:TemperatureState" then
    child:emit_event(caps.temperatureMeasurement.temperature({ value = deviceStatesValue, unit = "C" }))
  elseif deviceStatesName == "core:LuminanceState" then
    child:emit_event(caps.illuminanceMeasurement.illuminance(deviceStatesValue))
  elseif deviceStatesName == "core:ContactState" then
    child:emit_event(caps.contactSensor.contact(deviceStatesValue))
  elseif deviceStatesName == "core:TargetClosureState" then
    local targetShadeLevel = 100 - deviceStatesValue
    local latestShadeLevel = child:get_latest_state("main", caps.windowShadeLevel.ID, caps.windowShadeLevel.shadeLevel.NAME)
    log.debug('Target Shade Level:', targetShadeLevel)
    log.debug('Latest Shade Level:', latestShadeLevel)
    if targetShadeLevel > latestShadeLevel then
      child:emit_event(caps.windowShade.windowShade('opening'))
      log.debug('Opening Shutter')
    elseif targetShadeLevel < latestShadeLevel then
      child:emit_event(caps.windowShade.windowShade('closing'))
      log.debug('Closing Shutter')
    end
  elseif deviceStatesName == "core:ClosureState" then
    local shadeLevel = 100 - deviceStatesValue
    child:emit_event(caps.windowShadeLevel.shadeLevel(shadeLevel))
    if shadeLevel == 0 then 
      child:emit_event(caps.windowShade.windowShade('closed'))
    elseif shadeLevel == 100 then
      child:emit_event(caps.windowShade.windowShade('open'))
    else
      child:emit_event(caps.windowShade.windowShade('partially open'))
    end
  else
    log.warn('Unknown device type: ' .. deviceStatesName)
  end
end

return commands


