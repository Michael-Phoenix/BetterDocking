package.path = package.path .. ";mods/LogLevels/scripts/lib/?.lua"
local levels = require('LogLevels')
local oldprint = print

-- override the default print function
print = function(...)
  if Server == nil then
      oldprint(...)
  else
    --Get server value set via cmd or server.lua
    local InfoLevel = levels.info or 400
    local ServerSetting = Server():getValue('log_level') or InfoLevel
    local LogCurrentLevel = tonumber(ServerSetting)

    local ConsoleServerSetting = Server():getValue('console_level') or InfoLevel
    local ConsoleCurrentLevel = tonumber(ConsoleServerSetting)

    --Assume level info
    local PrintLevel = InfoLevel
    local args = table.pack(...)
    local hadPrintLevel = false
    --Set the level at which the print is attempting to print at.
    if #args > 1 and args[#args] ~= nil then
      --cast last argument to number
      local tempArg = tonumber(args[#args])
      --if argument is a number, set the printLevel
      if type(tempArg) == "number" then
        --if the number matches one of our loglevels
        for _, logLevel in pairs(levels) do

          if tempArg == logLevel then
            PrintLevel = tempArg
            hadPrintLevel = true
            break
          end
        end
      end
    end

    --prepend messages
    local prepend = ''
    for index,value in pairs(levels) do
      if PrintLevel == value then
        prepend = '['..string.upper(index)..']  '
        break
      end
    end

    --add prepend to begging of message
    table.insert(args,1,prepend)
    --if we had a log level remove it so its not printed
    if hadPrintLevel then args[#args] = nil end

    --if were printing this message
    if PrintLevel <= ConsoleServerSetting then
      oldprint(table.unpack(args))
    elseif PrintLevel <= LogCurrentLevel then
      printlog(table.unpack(args))
    end
  end
end
