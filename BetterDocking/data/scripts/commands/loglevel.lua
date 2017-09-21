package.path = package.path .. ";mods/LogLevels/scripts/lib/?.lua"
local levels = require("LogLevels")

function execute(sender, commandName, level, ...)
  local args = {...}
  local Server = Server()
  local Player = Player(sender)


  if not level then
    return 0, "", ""
  end

  for levelName, logLevel in pairs(levels) do

    if level == levelName then

      if sender ~= nil then
        Player:sendChatMessage('Server', 0, 'log level set to: ' .. level)
      end

      if onServer() then
        print('-- log level set to: ' .. level ..' --')
      end

      Server():setValue('log_level',logLevel)
      return 0, "", ""
    end

  end

  if sender ~= nil then
    Player:sendChatMessage('Server', 0, 'Unkown loglevel option, use: /help loglevel')
  end
  return 0, "", ""
end

function getDescription()
    return "Sets the log level."
end

function getHelp()
    local availableOptions = ''
    for levelName, logLevel in pairs(levels) do
      if availableOptions == '' then
        availableOptions = levelName
      else
        availableOptions = availableOptions..'/'..levelName
      end
    end
    return "Sets the log level, use: /loglevel ["..availableOptions.."]"
end
