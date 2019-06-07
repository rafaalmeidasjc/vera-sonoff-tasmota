

	local HS_SID = "urn:mios-nullx8-com:serviceId:HttpSwitch1"
	local HAD_SID = "urn:micasaverde-com:serviceId:HaDevice1"	
	local DEFAULT_ADDRESS = "127.0.0.1"
	

	-- just a function to decode (decode only) json responses
	function decode_json(json)
		if (not json) then 
			return nil
		end
		local str = {} 
		local escapes = { r='\r', n='\n', b='\b', f='\f', t='\t', Q='"', ['\\'] = '\\', ['/']='/' } 
		json = json:gsub('([^\\])\\"', '%1\\Q'):gsub('"(.-)"', function(s) 
			str[#str+1] = s:gsub("\\(.)", function(c) return escapes[c] end) 
			return "$"..#str 	
		end):gsub("%s", ""):gsub("%[","{"):gsub("%]","}"):gsub("null", "nil") 
		json = json:gsub("(%$%d+):", "[%1]="):gsub("%$(%d+)", function(s) 
		return ("%q"):format(str[tonumber(s)])
		end)
		return assert(loadstring("return "..json))()
	end

	local function log(text)
		local id = PARENT_DEVICE or "unknown"
			luup.log("HttpSwitch Plugin #" .. id .. " " .. text)
		end
	
	local function InitSettings(address)
		address = address or DEFAULT_ADDRESS
		luup.variable_set(HS_SID, "Address", address, parentDevice)
		luup.variable_set(HS_SID, "Poll", "120", parentDevice)
		luup.variable_set(HS_SID, "RELAY", "1", parentDevice)
		if (address == DEFAULT_ADDRESS) then
			luup.variable_set(HS_SID, "LinkStatus", "SET IP!", parentDevice)
		else
			luup.variable_set(HS_SID, "LinkStatus", "...", parentDevice)
		end
		luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", "0", parentDevice)
		luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Target", "0", parentDevice)

		log("Initialized variable: 'Address' = " .. address)
		log("Initialized variable: 'Target' = " .. Target)
		log("Initialized variable: 'Status' = " .. Status)
		log("Initialized variable: 'Poll' = " .. Poll)
		
		luup.task("Please restart Luup to initialize the plugin.", 1, "HttpSwitch Plugin", -1)
		
		return address
	end
	
	local function readLocalSettings(parentDevice)
	
		local address = luup.variable_get(HS_SID, "Address", parentDevice)
		local Poll = luup.variable_get(HS_SID, "Poll", parentDevice)
		local RELAY = luup.variable_get(HS_SID, "RELAY", parentDevice)
		
		if (address == nil) then
		log("Init Settings")
			address = InitSettings(address)
		end
		
		if (Poll == nil) then
			Poll = InitSettings(address)
		end
		
		if (RELAY == nil) then
			RELAY = InitSettings(address)
		end
		
		return address, Poll, RELAY
		
	end
	
	function GetRemoteStatus()
		local address, Poll = readLocalSettings(parentDevice)
		local RELAY = luup.variable_get(HS_SID, "RELAY", parentDevice)
		--status command for ESP Easy
		local url = "http://".. address .."/cm?cmnd=power".. RELAY
		local status, result = luup.inet.wget(url,6)
		--local trndon = '{"POWER":"ON"}'
		--local trndoff = '{"POWER":"OFF"}'
		
		if status == 0 then
			--luup.variable_set(HS_SID, "LinkStatus", result, parentDevice) usei essa linha so pra imprimir {POWER:ON} e OFF 
			if string.find(result,"ON")==nil then -- estado é OFF
				luup.variable_set(HS_SID, "Status", "0", parentDevice)
				luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", "0", parentDevice)
			end

			if string.find(result,"OFF")==nil then -- estado é ON
				luup.variable_set(HS_SID, "Status", "1", parentDevice)
				luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", "1", parentDevice)
			end	

			--local data = decode_json(result)
			--local PowerState = data.state

			--luup.variable_set(HS_SID, "Status", PowerState, parentDevice)
			--luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", PowerState, parentDevice)
			--luup.variable_set(HS_SID, "LinkStatus", LinkStatus, parentDevice)
		end
		luup.call_delay ("GetRemoteStatus", Poll, "")
	end
	
	function PingCheck()
		local address, Poll = readLocalSettings(parentDevice)
		pingcommand = "ping -c 1 " ..address
		log("executing [ ping -c 1 " .. address .. " ]")
		pingresponse = os.execute(pingcommand)
		if (pingresponse == 0) then
			luup.variable_set(HS_SID,"PingStatus","up",parentDevice)
			luup.variable_set(HS_SID, "LinkStatus", "Online!", parentDevice)
			log("Ping reply ")
		else
			luup.variable_set(HS_SID,"PingStatus","down",parentDevice)
			luup.variable_set(HS_SID, "LinkStatus", "Offline!", parentDevice)
			log("No ping reply ")
		end
		PingInterval = luup.variable_get(HS_SID,"Poll", parentDevice)
		luup.call_delay("PingCheck", Poll, "")
	end
	
	function main(parentDevice)
		--
		-- Note these are "pass-by-Global" values that refreshCache will later use.
		--
		PARENT_DEVICE = parentDevice

		log("starting up..")
		
		luup.variable_set(HAD_SID, "LastUpdate", os.time(os.date('*t')), parentDevice)
		luup.variable_set(HAD_SID, "Configured", "1", parentDevice)
	  
		--
		-- Validate that the Address/Delay are configured in Vera, otherwise this
		-- code wont work.
		--
		local address = readLocalSettings(parentDevice)
		local Poll = readLocalSettings(parentDevice)
		if (address == nil) then
			log("could not be started.")
			log("adress value " .. address)
			luup.set_failure(true, parentDevice)
			return false
		end
      
		luup.call_delay ("GetRemoteStatus", 30, "")
		luup.call_delay("PingCheck", 10, "")
		return true
	end
	
	
	local function FlipOn()
		local address = readLocalSettings(parentDevice)
		local RELAY = luup.variable_get(HS_SID, "RELAY", parentDevice)
                luup.inet.wget("http://" .. address .. "/cm?cmnd=Power".. RELAY .."%20on")
		luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", "1", parentDevice)
        	luup.variable_set(HS_SID, "Status", "1", parentDevice)
		--GetRemoteStatus()
	end	
	
	local function FlipOff()
		local address = readLocalSettings(parentDevice)
		local RELAY = luup.variable_get(HS_SID, "RELAY", parentDevice)
    		luup.inet.wget("http://" .. address .. "/cm?cmnd=Power".. RELAY .."%20off")
		luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", "0", parentDevice)
        	luup.variable_set(HS_SID, "Status", "0", parentDevice)
		--GetRemoteStatus()
	end

-- last line 
