local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment

-- Utility function for getting seconds per frame in a room
local function time_increment_room(shipId, roomId)
    return time_increment()*Hyperspace.TemporalSystemParser.GetDilationStrength(Hyperspace.ShipGraph.GetShipInfo(shipId).rooms[roomId].extend.timeDilation)
end

-- Init drowning data
local drownTime = 8
local drownBarBubbles = 4
local drownBarPopInterval = 0.25
local drownBarSpacing = 6
local drownRecoverSpeed = 2
local drownDamage = 10
local drownBubble = Hyperspace.Resources:CreateImagePrimitiveString("people/rvs_drown_bubble.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local drownBubblePop = Hyperspace.Resources:CreateImagePrimitiveString("people/rvs_drown_bubble_pop.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local drownImmuneCrew = {}
do
    local drownImmuneCrewLists = {
        "LIST_CREW_AQUATIC",
        "LIST_CREW_AQUA_IMMUNE",
        "LIST_CREW_GHOST",
        "LIST_CREW_SLUG",
        "LIST_CREW_SHELL"
    }
    for _, drownImmuneCrewList in ipairs(drownImmuneCrewLists) do
        for crew in vter(Hyperspace.Blueprints:GetBlueprintList(drownImmuneCrewList)) do
            drownImmuneCrew[crew] = true
        end
    end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_CREWMEMBER, function(crew)
    crew.table.rvsAquaFlowerDrownTimer = 0
end)

-- Manage drowning
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crew)
    local step = time_increment_room(crew.currentShipId, crew.iRoomId)
    local suffAmount = step*select(1, crew.extend:CalculateStat(Hyperspace.CrewStat.SUFFOCATION_MODIFIER))
    local doDrowning
    do
        local ownerShip = Hyperspace.ships(crew.iShipId)
        doDrowning = (not ownerShip or ownerShip:GetAugmentationValue("O2_MASKS") <= 0) and
                     Hyperspace.ships(crew.currentShipId):HasAugmentation("RVS_WATER_FILLED") > 0 and
                     select(2, crew.extend:CalculateStat(Hyperspace.CrewStat.CAN_SUFFOCATE)) and
                     not crew.bSuffocating and
                     not drownImmuneCrew[crew.blueprint.name]
    end
    if doDrowning then
        crew.table.rvsAquaFlowerDrownTimer = math.min(drownTime, crew.table.rvsAquaFlowerDrownTimer + suffAmount)
    elseif crew.table.rvsAquaFlowerDrownTimer > 0 and not crew.bSuffocating then
        crew.table.rvsAquaFlowerDrownTimer = math.max(0, crew.table.rvsAquaFlowerDrownTimer - step*drownRecoverSpeed)
    end
    if crew.table.rvsAquaFlowerDrownTimer >= drownTime then
        crew:DirectModifyHealth(-suffAmount*drownDamage)
    end
end)

-- Render drowning bubble bar
script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function() end, function(crew)
    local drownTimer = crew.table.rvsAquaFlowerDrownTimer
    if drownTimer > 0 and drownTimer < drownTime then
        Graphics.CSurface.GL_PushMatrix()
        
        -- Greater y offset to make space for healthbar if it's being drawn
        if crew.selectionState > 0 or crew.lastHealthChange > 0 or crew.health.first < crew.health.second*0.55 then
            Graphics.CSurface.GL_Translate(crew.x - 13, crew.y - 19)
        else
            Graphics.CSurface.GL_Translate(crew.x - 13, crew.y - 12)
        end
        
        -- Offset for melee
        if crew.bFighting and crew.bSharedSpot then
            if (crew.iShipId == crew.currentShipId) ~= crew.bMindControlled then
                Graphics.CSurface.GL_Translate(0, -7)
            else
                Graphics.CSurface.GL_Translate(0, 7)
            end
        end
        
        -- Draw bubbles
        local bubbleCount = math.min(drownBarBubbles, math.ceil(drownBarBubbles*(1 - (drownTimer + drownBarPopInterval)/drownTime)))
        for bubble = 1, bubbleCount do
            Graphics.CSurface.GL_RenderPrimitive(drownBubble)
            Graphics.CSurface.GL_Translate(drownBarSpacing, 0)
        end
        local timePerBubble = drownTime/drownBarBubbles
        if drownTimer % timePerBubble > timePerBubble - drownBarPopInterval then
            Graphics.CSurface.GL_RenderPrimitive(drownBubblePop)
        end
        Graphics.CSurface.GL_PopMatrix()
    end
end)
