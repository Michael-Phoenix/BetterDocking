--LogLevels - Dirtyredz|David McClain
package.path = package.path .. ";mods/LogLevels/scripts/lib/?.lua"
require("PrintLog")
local logLevels = require("LogLevels")

local closestPos
local closestDir
local dockingCache = false
local oldPosition
local dockTimer = 0
local retVar


dockStage = 0

function inM(avorionUnits) -- return AvorionUnits in meters
    return getReadableValue(avorionUnits *10.0)
end

function getNearestDockingPosition(cache)


	local docks = {cache.station:getDockingPositions()}

	-- check if cached dock still exists
    if dockingCache == true then
		dockingCache = false

		for i=1,#docks,2 do
			mypos = docks[i]
			if mypos.x == closestPos.x and mypos.y == closestPos.y and mypos.z == closestPos.z then
				dockingCache = true
				break
			end
		end
		if dockingCache == false then
			cache.ai:setPassive()
			dockStage = 0
		end

		oldPosition = oldPosition or cache.stationPosition.pos
		local newPosition = cache.stationPosition.pos
		if  newPosition.x ~= oldPosition.x or newPosition.y ~= oldPosition.y or newPosition.z ~= oldPosition.z then
			print(cache.station.name.." STATION MOVED: "..tostring(newPosition).." and old: "..tostring(oldPosition), logLevels.debug)
			oldPosition = newPosition
			cache.ai:setPassive()
		end
    end
	if dockingCache == false then
		closestPos = nil
		closestDir = nil
		local closestSqDist = -1.0
		local currDist
		local mypos
		local mydir
		local i
		for i=1,#docks,2 do
			mypos = docks[i]
			mydir = docks[i+1]
			currDist = distance2(cache.boundingSphere.center, cache.stationPosition:transformCoord(mypos + mydir * cache.config.LandingStripDistance))
			if closestSqDist == -1.0 or currDist < closestSqDist then
				closestPos = mypos
				closestDir = mydir
				closestSqDist = currDist
			end
		end
		dockingCache = true
    end
    return closestPos, closestDir
end

function flyToDock(cache)
    dockStage = dockStage or 0
    retVar = false
    --failsafe if a ship can't for the life of it, make a proper docking connection
    if dockStage > 1 then dockTimer = dockTimer + cache.timeStep else dockTimer = 0 end
    if dockTimer > cache.config.FallBackSeconds then
        cache.ai:setPassive()
        dockStage = 3
    end

	if dockStage == 0 then
		if not cache.announcement then
			cache.announcement = true
			print("Approaching: "..cache.ship.name.." -> "..cache.station.name..", Brake thrust: "..inM(cache.engine.brakeThrust)..", MaxVel: "..inM(cache.engine.maxVelocity), logLevels.trace)
		end
		local target = cache.landingStripPosition
		if cache.ai.state ~= AIState.Fly then
			cache.ai:setFly(target, 0)
		end
		local dist = distance(target, cache.boundingSphere.center)
		-- once the ship is in the light line, fly towards the dock
		if dist < cache.boundingSphere.radius * 2.0 then
			cache.ai:setPassive()
			dockStage = 1
			print("Switching To Docking Mode: "..cache.ship.name, logLevels.trace)
			cache.announcement = false
		end
	end

	-- stage 1 is flying towards the dock inside the light-line
	if dockStage == 1 then
		if cache.ai.state ~= AIState.Fly then
			cache.ai:setFly(cache.dockPosition, 0)
		end
		if cache.dist < cache.boundingSphere.radius * 6.0 then
			cache.ai:setPassive()
			dockStage = 2
			cache.announcement = false
		end
	end

    --stage 2: closing in on the docking area, trying to predict the right moment when to stop. Keep in mind, those checks can only be performend once every update (2 sec usually).
	if dockStage == 2 then
        if cache.ai.state ~= AIState.Fly then
            cache.ai:setFlyLinear(cache.dockPosition, cache.config.DockRange*0.75)
		end
		local brakingTime = cache.velocity.linear / (cache.engine.brakeThrust )
		local brakingDistance =  (0.5 * (cache.engine.brakeThrust )) * brakingTime^2
		local distance  = cache.station:getNearestDistance(cache.ship)
		print(  "Brake distance: "..cache.ship.name.." "..inM(brakingDistance+5.0) .." vs. distance to dock range:"..inM(distance-cache.config.DockRange),
                logLevels.trace
             )
		if distance - cache.config.DockRange <= brakingDistance +5.0 or cache.station:isDocked(cache.ship) then
	        cache.ai:setPassive()
			print("Engine cutoff: ( clearance:"..inM(distance)..", brakeDistance:"..inM(brakingDistance) .."), took "..tostring(cache.elapsed).." "..cache.ship.name, logLevels.trace)
			cache.announcement = false
			dockStage = 3
		end
	end

    --stage 3: waiting for a full stop and then checking if the ship is within docking Port range. If not: retry from Stage 2; If yes, end approach and docking procedure
	if dockStage == 3 then
        if cache.velocity.linear2 <= 0.01 then
            local isDocked = cache.station:isDocked(cache.ship)
            local clearance = cache.station:getNearestDistance(cache.ship)
            if not isDocked and dockTimer < cache.config.FallBackSeconds and clearance > 6.0 then
                dockStage = 2
                cache.ai:setFlyLinear(cache.dockPosition, 0)
            else
            	local sectorX, sectorY = Sector():getCoordinates()
            	print(  "Final docking info: "..sectorX..","..sectorY..", "..cache.ship.name.."->"..cache.station.name..", docked after: "..cache.elapsed..", clamps: "..
                    tostring(isDocked)..", actual distance to Port: "..inM(cache.dist+cache.config.DockDistance)..", clearance: "..
                    inM(clearance)..", maxVelocity: "..inM(cache.engine.maxVelocity)..
                    ", ship dimensions (Z,X,Y): "..inM(cache.ship.size.z)..","..inM(cache.ship.size.x)..","..inM(cache.ship.size.y),
                    logLevels.debug
                )
            	cache.announcement = false
            	retVar = true
            end


        end
    end
	return retVar
end
