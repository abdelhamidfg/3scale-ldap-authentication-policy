local policy = require('apicast.policy')
local _M = policy.new('ldap_authn', '1.0.0')
local re = require('ngx.re')

local default_error_message = "Request blocked due to ldap authentication policy"

local new = _M.new

function _M.new(config)
  local self = new(config)
  self.error_message = config.error_message or default_error_message
  self.ldap_config = {
    ldap_host = config.ldap_host,
    ldap_port=config.ldap_port,
    base_dn=config.base_dn,
    attribute = config.uid,
    starttls = config.ldap_starttls or false,
    ldaps = false,
    verify_ldap_host = false,
    tls_verify=false,
    keepalive = 60000,
    timeout = 100000
  }


  return self
end


local function deny_request(error_msg)
  ngx.status = ngx.HTTP_FORBIDDEN
  ngx.say(error_msg)
  ngx.exit(ngx.status)
end


local function extract_auth_header(authorization)
  local obj = { username = "", password = "" }
  local m, err = ngx.re.match(authorization, "Basic\\s(.+)", "jo")
  if err then
      return nil, err
  end

  if not m then
      return nil, "Invalid authorization header format"
  end
  local decoded = ngx.decode_base64(m[1])
  if not decoded then
      return nil, "Failed to decode authentication header: " .. m[1]
  end

  local res
  res, err = re.split(decoded, ":")
  if err then
      return nil, "Split authorization err:" .. err
  end
  if #res < 2 then
      return nil, "Split authorization err: invalid decoded data: " .. decoded
  end

  local gsub = ngx.re.gsub
  obj.username = gsub(res[1], "\\s+", "", "jo")
  obj.password = gsub(res[2], "\\s+", "", "jo")

  return obj, nil
end


function _M:access(context)

  local headers= ngx.req.get_headers(0, true)
  headers = headers or {}
  local auth_header=headers["Authorization"]

  if not auth_header then
    return deny_request("Missing authorization header in request")
  end
  local user, err2 = extract_auth_header(auth_header)
   
  if err2 then
    return deny_request("Invalid authorization header in request")
  end
  local ldap = require("resty.ldap")

  local res,err = ldap.ldap_authenticate(user.username, user.password, self.ldap_config)

  if  err ~=nil then
      ngx.log(ngx.ERR, "Error occured during authentication to ldap",err)
      return deny_request(self.error_message)
  end
end

return _M
