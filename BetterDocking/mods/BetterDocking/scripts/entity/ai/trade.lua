--LogLevels - Dirtyredz|David McClain
package.path = package.path .. ";mods/LogLevels/scripts/lib/?.lua"
require("PrintLog")
local logLevels = require("LogLevels")

--For EXTERNAL configuration files
package.path = package.path .. ";mods/BetterDocking/config/?.lua"
local BetterDockingConfig = nil
exsist, BetterDockingConfig = pcall(require, 'BetterDockingConfig')

local config = {}

config.FallBackSeconds = BetterDockingConfig.FallBackSeconds  or 120.0
config.AbortTimer = BetterDockingConfig.AbortTimer or 900.0
config.DockRange = BetterDockingConfig.DockRange or 20.0
config.DockDistance = BetterDockingConfig.DockDistance or 0.0
config.LandingStripDistance = BetterDockingConfig.LandingStripDistance or 300.0

-- keep cache local and pass it to the depending functions. byRef is 30% faster than global lookup, according to https://www.lua.org/gems/sample.pdf
local cache = {ship = nil, station = nil, config = nil, stationPosition = nil, engine = nil, boundingSphere = nil, dist = nil, velocity = nil,boundingBox = nil, ai = nil, elapsed = nil, dockPosition = nil, landingStripPosition = nil, announcement = nil}

local stationIndex
local script
local stage
local waitCount

local pos
local dir

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
	cache.config = cache.config or config
    cache.ship = cache.ship or Entity()
    cache.station = cache.station or Entity(stationIndex)
	cache.timeStep = timeStep
	cache.elapsed = cache.elapsed or 0
	cache.elapsed = cache.elapsed + timeStep
	cache.engine = cache.engine or Engine(cache.ship.index)
	cache.announcement = cache.announcement or false


    -- in case the station doesn't exist any more, leave the sector
    if not cache.station then
        cache.ship:addScript("ai/passsector.lua", random():getDirection() * 2000)
        terminate()
        return
    end

	cache.stationPosition = cache.station.position
	cache.boundingSphere = cache.ship:getBoundingSphere()
	--cache.boundingBox = cache.ship:getBoundingBox()
	cache.ai = cache.ai or ShipAI(cache.ship.index)
    pos, dir = getNearestDockingPosition(cache) -- see dock.lua

    -- stages

    if not pos or not dir or not valid(cache.station) or cache.elapsed > cache.config.AbortTimer then
		local sectorX, sectorY = Sector():getCoordinates()
		print("ABORTING trade run in sector "..sectorX..":"..sectorY.." after "..cache.elapsed.."sec. Details: "..cache.ship.name.."->"..cache.station.name..", maxVelocity:"..(cache.engine.maxVelocity*10.0).."m/s, DockStage: "..tostring(dockStage)..", Stage: "..tostring(stage).." distance: "..tostring(cache.station:getNearestDistance(cache.ship)*10.0).."m, ship dimensions (Z,X,Y): "..(cache.ship.size.z*10.0).."m,"..(cache.ship.size.x*10.0).."m,"..(cache.ship.size.y*10.0).."m", logLevels.info)
        -- something is not right, abort
        onTradingFinished(cache.ship)
    else
        stage = stage or 0
    end

    -- stage 0 is flying towards the light-line
    if stage == 0 then
		cache.dockPosition = cache.stationPosition:transformCoord(pos + dir *(cache.config.DockRange*0.5))
		cache.landingStripPosition = cache.stationPosition:transformCoord(pos + dir * config.LandingStripDistance)
		cache.dist = distance(cache.dockPosition, cache.boundingSphere.center) -(cache.ship.size.z * 0.5) + (cache.config.DockRange*0.5)
		cache.velocity = Velocity(cache.ship.index)
        if flyToDock(cache) then  -- see dock.lua
            stage = 2
			cache.announcement = false
        end
    end

    -- stage 2 is waiting
    if stage == 2 then
		if not cache.announcement then
			cache.announcement = true
			print("Waiting: "..cache.ship.name, logLevels.trace)
		end
        waitCount = waitCount or 0
        waitCount = waitCount + timeStep

        if waitCount > 40 then -- seconds waiting
            doTransaction(cache.ship, cache.station, script)
            -- fly away
            stage = 3
			cache.announcement = false
        end
    end

    -- fly back to the end of the lights
    if stage == 3 then
		if not cache.announcement then
			cache.announcement = true
			print("Egress: "..cache.ship.name, logLevels.trace)
		end
		local target = cache.stationPosition:transformCoord(pos + dir * config.LandingStripDistance)

        if cache.ai.state ~= AIState.Fly then
			cache.ai:setFly(target, 0)
		end

        local dist = distance(target, cache.boundingSphere.center)

        -- once the ship reached the end of the light line, trading is done
        if dist < cache.boundingSphere.radius * 2.0 then
			print("Leaving System: "..cache.ship.name, logLevels.trace)
            onTradingFinished(cache.ship)
        end
    end
end
