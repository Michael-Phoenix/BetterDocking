--LogLevels - Dirtyredz|David McClain
package.path = package.path .. ";mods/LogLevels/scripts/lib/?.lua"
require("PrintLog")
local logLevels = require("LogLevels")

--For EXTERNAL configuration files
package.path = package.path .. ";mods/BetterDocking/config/?.lua"
BetterDockingConfig = nil
exsist, BetterDockingConfig = pcall(require, 'BetterDockingConfig')

stationPosition = nil
config = {}

config.FallBackSeconds = BetterDockingConfig.FallBackSeconds  or 30
config.PortDistance = BetterDockingConfig.PortDistance or 2
config.LandingStripDistance = BetterDockingConfig.LandingStripDistance or 300


cache = {}

local stationIndex
local script
local stage
local waitCount

function getStationIndex()
    return stationIndex
end

function restore(values)
    stationIndex = Uuid(values.stationIndex)
    script = values.script
    stage = values.stage
    waitCount = values.waitCount
    dockStage = values.dockStage
end

function secure()
    return
    {
        stationIndex = stationIndex.string,
        script = script,
        stage = stage,
        waitCount = waitCount,
        dockStage = dockStage,
    }
end

function initialize(stationIndex_in, script_in)
    stationIndex = stationIndex_in
    script = script_in
end

function updateServer(timeStep)

    local ship = Entity()

    local station = Entity(stationIndex)

    -- in case the station doesn't exist any more, leave the sector
    if not station then
        ship:addScript("ai/passsector.lua", random():getDirection() * 2000)
        terminate()
        return
    end
	stationPosition = station.position
	cache.boundingSphere = ship:getBoundingSphere()
    local pos, dir = getNearestDockingPosition(ship,station) -- see dock.lua

    -- stages
    if not pos or not dir or not valid(station) then
        -- something is not right, abort
        onTradingFinished(ship)
    else
        stage = stage or 0


        -- stage 0 is flying towards the light-line
        if stage == 0 then
			cache.dockPosition = stationPosition:transformCoord(pos + dir * config.PortDistance)
			cache.landingStripPosition = stationPosition:transformCoord(pos + dir * config.LandingStripDistance)
            if flyToDock(ship, station) then  --for flyToDock see dock.lua
                stage = 2
            end
        end

        -- stage 2 is waiting
        if stage == 2 then
		print("Waiting", logLevels.debug)
            waitCount = waitCount or 0
            waitCount = waitCount + timeStep

            if waitCount > 40 then -- seconds waiting
                doTransaction(ship, station, script)
                -- fly away
                stage = 3
            end
        end

        -- fly back to the end of the lights
        if stage == 3 then
			print("Egress", logLevels.debug)
			local target = stationPosition:transformCoord(pos + dir * config.LandingStripDistance)
			local ai = ShipAI()
            if ai.state ~= AIState.Fly then
				ai:setFly(target, 0)
			end

            local dist = distance(target, cache.boundingSphere.center)

            -- once the ship reached the end of the light line, trading is done
            if dist < cache.boundingSphere.radius * 2.0 then
				print("Leaving System", logLevels.debug)
                onTradingFinished(ship)
            end
        end
    end
end
