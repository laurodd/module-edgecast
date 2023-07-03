-- datadome_support.lua 
-- THandley/RYu 20230401

-- Core from https://package.datadome.co/linux/DataDome-HaproxyLua-latest.tgz

--
-- luacheck: globals  DATADOME_MODULE_NAME DATADOME_MODULE_VERSION log truncateHeaders getCurrentMicroTime charToHex urlencode split buildBody extractHeaderList get_post_response_headers table_to_encoded_string main headersLength handleClientId buildKeyList
--
--


DATADOME_MODULE_NAME  = 'datadome_support.lua'
DATADOME_MODULE_VERSION  = '0.0.1'

local script_name = "datadome_support.lua"
function log(v, ...)
    --[[
    v: log tag / response header value
    ...: list of things to log

    logs a message stdout and http response header
    sets debug response header with "x-ec-debug-helper" or sailfish.debug
    ]]--
    local function msg(...)
        -- format list to str and avoid runtime nil errors
        local tmap = {}
        for _,v in pairs({...}) do
            if v then
                table.insert(tmap,v)
            end
        end
        return "[" .. table.concat(tmap, "|") .. "]"
    end
    local function print_message(v, t)
        print(table.concat({"DEBUG ", v, script_name,
            os.date("!%Y%m%dT%H:%M:%SZ", os.time()), os.time(), t}, " ; "))
    end
    local txt = msg(...)
    if sailfish.debug()
        or sailfish.get_request_header("x-ec-debug-helper")
        or sailfish.get_request_header("x-ec-log-it") then
            sailfish.set_response_header("x-" .. v, txt)
            print_message(v, txt)
    else
        if sailfish.get_request_header("x-ec-log-it") then
            print_message(v,  txt)
        end
    end
    return nil
end

-- Maximun lenght allowed for each header value in POST content
headersLength = {
  ['SecCHUAMobile']           = 8,
  ['SecCHDeviceMemory']       = 8,
  ['SecFetchUser']            = 8,
  ['SecCHUAArch']             = 16,
  ['SecCHUAPlatform']         = 32,
  ['SecFetchDest']            = 32,
  ['SecFetchMode']            = 32,
  ['ContentType']             = 64,
  ['SecFetchSite']            = 64,
  ['SecCHUA']                 = 128,
  ['SecCHUAModel']            = 128,
  ['AcceptCharset']           = 128,
  ['AcceptEncoding']          = 128,
  ['CacheControl']            = 128,
  ['ClientID']                = 128,
  ['Connection']              = 128,
  ['Pragma']                  = 128,
  ['X-Requested-With']        = 128,
  ['From']                    = 128,
  ['TrueClientIP']            = 128,
  ['X-Real-IP']               = 128,
  ['AcceptLanguage']          = 256,
  ['SecCHUAFullVersionList']  = 256,
  ['Via']                     = 256,
  ['XForwardedForIP']         = -512,
  ['Accept']                  = 512,
  ['HeadersList']             = 512,
  ['Host']                    = 512,
  ['Origin']                  = 512,
  ['ServerHostname']          = 512,
  ['ServerName']              = 512,
  ['UserAgent']               = 768,
  ['Referer']                 = 1024,
  ['Request']                 = 2048
}


function truncateHeaders(headers)
    for k,v in pairs(headers) do
      if headersLength[k] ~= nil then
        if headersLength[k] > 0 then
          headers[k] = string.sub(v, 1, headersLength[k])
        else  -- backward truncation
          headers[k] = string.sub(v, headersLength[k])
        end
      end
    end
    return headers
end

--//
function getCurrentMicroTime()
  -- we need time up to microseccconds, but at lua we can do up to seconds :( round it
  return tostring(os.time()) .. "000000"
end
--

function charToHex(c)
	return string.format("%%%02X", string.byte(c))
end

function urlencode(url)
   if url == nil then
	  return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w_%%%-%.~])", charToHex)
  url = url:gsub(" ", "+")
  return url
end

function dump(o)
	if type(o) == 'table' then
	   local s = '{ '
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. dump(v) .. ','
	   end
	   return s .. '} '
	else
	   return tostring(o)
	end
 end

function split(s, delimiter)
  local result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
  end
  return result;
end

function buildKeyList(params)
    if type(params) == "table" then
      local headersName = {}
      for key, _ in pairs(params) do
        table.insert(headersName, key);
      end
      return table.concat(headersName, ',')
    end
    return '';
end

function handleClientId( body, datadomeHeaders, client_id)
  if sailfish.get_request_header("x-datadome-clientid") ~= nil then
    log( "info", 'sessionByHeader')
    body['ClientID'] = string.sub(sailfish.get_request_header("x-datadome-clientid"), 1, 128)
    datadomeHeaders["X-DataDome-X-Set-Cookie"] = "true"
  else
    if client_id ~= nil then
      body['ClientID'] = string.sub(client_id, 1, 128)
    end
  end
  return body, datadomeHeaders
end

function buildBody(cookie_length)

    local body = {
        ['Key']                = sailfish.get_user_var("datadome-key"),
        ['RequestModuleName']  = DATADOME_MODULE_NAME,
        ['ModuleVersion']      = DATADOME_MODULE_VERSION,
        ['ServerName']         = sailfish.get_user_var("hostname"),
        ['APIConnectionState'] = "new",
        ['IP']                 = sailfish.virt_dst_addr(), 
        ['Port']               = sailfish.get_request_header("True-Client-Port"), 
        ['TimeRequest']        = getCurrentMicroTime(),
        ['Protocol']           = sailfish.uri.scheme,
        ['Method']             = sailfish.request.method,
        ['ServerHostname']     = sailfish.get_user_var("hostname"),
        ['Request']            = sailfish.request.orig_uri,
        ['HeadersList']        = buildKeyList( sailfish.import_request_headers() ),
        ['Host']               = sailfish.uri.authority,
        ['UserAgent']          = sailfish.get_request_header("User-Agent"),
        ['Referer']            = sailfish.get_request_header("Referer"),
        ['Accept']             = sailfish.get_request_header("Accept"),
        ['AcceptEncoding']     = sailfish.get_request_header("AcceptEncoding"),
        ['AcceptLanguage']     = sailfish.get_request_header("AcceptLanguage"),
        ['AcceptCharset']      = sailfish.get_request_header("Accept-Charset"),
        ['Origin']             = sailfish.get_request_header("Origin"),
        ['XForwardedForIP']    = sailfish.get_request_header("X-Forwarded-For"),
        ['X-Requested-With']   = sailfish.get_request_header("X-Requested-With"),
        ['Connection']         = sailfish.get_request_header("Connection"),
        ['Pragma']             = sailfish.get_request_header("Pragma"),
        ['CacheControl']       = sailfish.get_request_header("CacheControl"),
        ['ContentType']        = sailfish.get_request_header("ContentType"),
        ['From']               = sailfish.get_request_header('from'),
        ['X-Real-IP']          = sailfish.get_request_header("X-Real-IP"),
        ['Via']                = sailfish.get_request_header("Via"),
        ['TrueClientIP']       = sailfish.get_request_header("True-Client-IP"),
        ['CookiesLen']         = tostring(cookie_length),
        ['AuthorizationLen']   = tostring(string.len(sailfish.get_request_header("Authorization") or "")),
        ['PostParamLen']       = sailfish.get_request_header("content"),
        ['SecCHUA']            = sailfish.get_request_header("Sec-CH-UA"),
        ['SecCHUAArch']        = sailfish.get_request_header("Sec-CH-UA-Arch"),
        ['SecCHUAModel']       = sailfish.get_request_header("Sec-CH-UA-Model"),
        ['SecCHUAMobile']      = sailfish.get_request_header("Sec-CH-UA-Mobile"),
        ['SecCHUAPlatform']    = sailfish.get_request_header("Sec-CH-UA-Platform"),
        ['SecCHUAFullVersionList'] = sailfish.get_request_header("Sec-CH-UA-Full-Version-List"),
        ['SecCHDeviceMemory']  = sailfish.get_request_header("Sec-CH-Device-Memory"),
        ['SecFetchDest']       = sailfish.get_request_header("Sec-Fetch-Dest"),
        ['SecFetchMode']       = sailfish.get_request_header("Sec-Fetch-Mode"),
        ['SecFetchSite']       = sailfish.get_request_header("Sec-Fetch-Site"),
        ['SecFetchUser']       = sailfish.get_request_header("Sec-Fetch-User"),
    }
    -- APIConnectionState
    if (sailfish.get_request_header("Keep-Alive") ) then 
        body['APIConnectionState'] = "reuse"
    end
    truncateHeaders(body)
    return body;
end

function extractHeaderList(headers, headerListName)
  -- See here, LUA Concat is slow : https://fossies.org/linux/haproxy/doc/lua-api/index.rst
  local result = {}  -- concat()
  if headers[headerListName] ~= nil then
    local listHeaders = split(headers[headerListName][0], " ")
    for _,v in pairs(listHeaders) do
      result:add(string.lower(v))
      result:add(': ')
      result:add(headers[string.lower(v)][0])
      result:add("@@")
    end
  end
    return result:dump()
end

function get_post_response_headers(response)
    -- Set response headers
    local headers = {}
    string.gsub(response.headers, "([%-%w]+)[:%s]+([^\r\n]+)",
        function (i, j)
            if i ~= nil and j ~= nil then
              headers[tostring(i):lower()] = tostring(j) 
        end
    end)
    log( "x-ec-info" , "response_headers " .. table_to_encoded_string(headers))
    return headers
end

function table_to_encoded_string(tablein)
    --[[
    yield an apersand separated string <key>=<value>&<key>=<value>&...
    where the <value> is encoded
    ]]--
    local encoded_string = ""
    for k,v in pairs(tablein) do 
        local new_entry = tostring(k) ..
                          "=" ..
                          urlencode(v) .. 
                          "&"
        encoded_string = encoded_string .. new_entry 
    end
    -- remove trailing &
    encoded_string = encoded_string:sub(1, -2)
    return encoded_string
end


-- 
--
---------------
--
--
function main() 

    -- get account parameters
    -- enable, key, post-request-timeout, post-request-endpoint ....
    local key =  sailfish.get_user_var("datadome-key")
    local post_request_timeout = sailfish.get_user_var("post-request-timeout")
    local post_request_endpoint = sailfish.get_user_var("post-request-endpoint")
    if not ( key and post_request_timeout and post_request_endpoint) then
        local msg = "Required initial input missing " ..
                    " key " .. tostring(key) .. 
                    " post_request_timeout " .. tostring(post_request_timeout) ..
                    " post_request_endpoint " .. tostring(post_request_endpoint) 
        log( "edgeio fail" , msg)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-fail", msg) 
        end
        return 403
    end

    local datadomeHeaders = {
		["Connection"]      = "keep-alive",
		['Content-Type']    = "application/x-www-form-urlencoded" ,
        -- ["Accept"]          = "application/json",
        ["Keep-Alive"]      = "timeout=" .. tostring(post_request_timeout) .. 
                               ", max=" .. tostring(post_request_timeout),
        ["X-EC-FClean"]     = 1,
	}
    if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
        datadomeHeaders["x-ec-pragma"] = "trace,cache-verbose,log-all,lua-debug,track"
    end

    local client_id
    local cookie_length
    local datadome_cookie = sailfish.cookie["datadome"]
    -- note: the first time thru there will not be a cookie.
    -- after the first post, the resultant cookies will be propagated. 
    if not datadome_cookie then 
        client_id = nil 
        cookie_length = 0 
        local msg = "Must be first time, no datadome cookie "
        log( "edgeio info" , msg)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-info", msg)
        end
    else 
	    client_id = datadome_cookie:match("([^;].+)")  
        cookie_length = client_id:len()
        if not client_id or not cookie_length then 
            local msg = "Failed to parse cookie " .. 
                        " datadome cookie " .. tostring(datadome_cookie)
            log( "edgeio fail" , msg)
            if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
                sailfish.set_response_header( "x-ec-fail", msg)
            end
            return 403
        end
    end

	local bodyDD = buildBody( cookie_length)

	bodyDD, datadomeHeaders = handleClientId( bodyDD, datadomeHeaders, client_id);
    local content  = table_to_encoded_string( bodyDD)
    datadomeHeaders["content-length"] = content:len()
    local post_url = sailfish.uri.scheme .. 
                      "://localhost/80" .. sailfish.get_customer() .."/" ..
                     post_request_endpoint ..
                    "/validate-request"
    local datadome_request = {
                        {
                            ["method"]        = "POST",
                            ["url"]           = post_url,
                            ["version"]       = "HTTP/1.1",
                            ["fe-protocol"]   = "https",
                            ["content"]       = content,
                            ["headers"]       = datadomeHeaders
                        }
                    }
    local responses = sailfish.http.dispatch(datadome_request)

    local response = responses[1]
    -- propagate POST response content   
    -- sailfish.set_content(response.content)
    -- need POST response headers
    local post_response_headers = get_post_response_headers(response)
    -- DataDome Cookie
    local datadome_cookie = post_response_headers["set-cookie"]
    -- propagate datadome cookie 
    sailfish.set_response_header("Set-Cookie",datadome_cookie)

    if ( response.status == "504" ) then -- gateway timeout
        local msg = "Gateway timeout"
        log( "edgeio fail" , msg)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-fail", msg)
        end
        return
    elseif ( response.status == "400" ) then -- Bad request
        local msg = "Bad request "
        log( "edgeio fail" , msg)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-fail", msg)
        end
        return
    end
    if ( post_response_headers["x-datadomeresponse"] == nil or (post_response_headers["x-datadomeresponse"] ~= response.status )) then
        local msg = "503 - Invalid X-DataDomeResponse header, is it ApiServer response?" ..
                    " post_response_headers[x-datadomeresponse]=" .. tostring(post_response_headers["x-datadomeresponse"]) ..
                    " post_response_headers[x-datadomeresponse]=" .. tostring(post_response_headers["x-datadomeresponse"]) ..
                    " response.status=" .. tostring(response.status)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-fail", msg)
        end
      log("edgio fail ", msg)
      return 503 
    end

    -- Validate the return status
    if ( response.status == "401" or response.status == "403" ) then
        --[[ 
        The module should stop processing the hit and output the HTML code returned by the API in the body section.
        ]]--
        local msg = "Request was not validated " .. tostring(response.status)
        log( "edgeio fail" , msg)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-fail", msg)
        end
        --[[
        Module should add the below to client request:
        HTTP Request
        X-DataDome-botname: Crawler fake Google
        X-DataDome-botfamily: bad_bot
        X-DataDome-isbot: 1
        ]]--
        sailfish.set_response_header( "X-DataDome-botname", post_response_headers["X-DataDome-botname"])
        sailfish.set_response_header( "X-DataDome-botfamily", post_response_headers["X-DataDome-botfamily"])
        sailfish.set_response_header( "X-DataDome-isbot", post_response_headers["X-DataDome-isbot"])
        sailfish.set_content(response.content)
        return tonumber(response.status)
    elseif ( response.status == "301" or response.status == "302" ) then
        -- redirect to the “Location” field found in API Response header.
        if post_response_headers["Location"] then 
            sailfish.set_response_header("Location", post_response_headers["Location"])
            return tonumber(response.status)
        else
            -- no Location header a real error
            local msg = "No Location header in the post_response_headers"
            log( "edgeio info " , msg)
            if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
                sailfish.set_response_header( "x-ec-fail", msg)
            end
        end
    else
        --[[
        response.status == 200 The module should let the application proceed.
        Anything else the request is honored.
        ]]-- 
        local msg = "Request proceeding "
        log( "edgeio info " , msg)
        if sailfish.debug() or sailfish.get_request_header("x-ec-debug-helper") then
            sailfish.set_response_header( "x-ec-fail", msg)
        end
    end

end
if sailfish.get_user_var("enable-datadome")  == "true" then
    return main() 
end

