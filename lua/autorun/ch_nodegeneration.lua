CH_NODEDATA = CH_NODEDATA or {}
CH_NODEENTITIES = CH_NODEENTITIES or {}

// Editable Variables
CH_NODESIZE = 8
CH_NODELINK_DISTANCE = 450
CH_NODELINK_DISTANCE_MIN = 250
CH_MAX_NODE_ATTEMPTS = 400
CH_MAX_NODES = 4096

// Static Variables
CH_MAP_SIZE = 32000
CH_NODESIZE_MIN = Vector(-CH_NODESIZE, -CH_NODESIZE, -CH_NODESIZE)
CH_NODESIZE_MAX = Vector(CH_NODESIZE, CH_NODESIZE, CH_NODESIZE)

CH_NODE_GROUND = 1001
CH_NODE_HINT = 1002
CH_NODE_AIR = 1003
CH_NODE_CLIMB = 1004
CH_NODE_WATER = 1005

CH_NODEMODELS = {
    [CH_NODE_GROUND] = "models/editor/ground_node.mdl",
    [CH_NODE_HINT] = "models/editor/ground_node.mdl",
    [CH_NODE_AIR] = "models/editor/air_node.mdl",
    [CH_NODE_CLIMB] = "models/editor/climb_node.mdl",
    [CH_NODE_WATER] = "models/editor/water_node.mdl",
}

include("ch_nodesave.lua")

if SERVER then
    util.AddNetworkString("CH_NODES_UPDATE")
end

CreateClientConVar("ch_node_show","1",true,true,"Visible show nodes in the world?",0,1)
CreateClientConVar("ch_node_size",tonumber(CH_NODESIZE),true,true,"The hull size for nodes when generating them. The larger the value, the harder it is for them to spawn.",4,16)
CreateClientConVar("ch_node_linkdist",tonumber(CH_NODELINK_DISTANCE),true,true,"The maximum link distance between nodes. Nodes not within this distance won't link!",CH_NODELINK_DISTANCE_MIN,1000)
CreateClientConVar("ch_node_attempts",tonumber(CH_MAX_NODE_ATTEMPTS),true,true,"How many times will the system attempt to generate a single node? Example: node failed to generate the first time, try X more times until it generates.",1,1000)
CreateClientConVar("ch_node_max",tonumber(CH_MAX_NODES),true,true,"Maximum amount of nodes that can be generated. The maximum possible amount in Source engine is 4,096. Any higher and the system will prevent the nodegraph from running/saving.",1,CH_MAX_NODES)

local _R = debug.getregistry()

if CLIENT then
    local tr = {collisiongroup = COLLISION_GROUP_WORLD,output = {}}
    function util.IsInWorld(pos)
        tr.start = pos
        tr.endpos = pos

        return not util.TraceLine(tr).HitWorld
    end

    concommand.Add("ch_node_generate",function(ply)
        if !ply:IsSuperAdmin() then return end
        
        LocalPlayer():PrintMessage(HUD_PRINTTALK,"Generating nodes...this will freeze your game temporarily. Please do not close your game!")

        timer.Simple(0,function()
            local startTime = SysTime()

            local nodegraph = _R.Nodegraph.Read()
            nodegraph:Clear()

            print("Generating nodes...")

            local function isNodeLinkable(a,b)
                local tr = util.TraceLine({start = a +Vector(0,0,3),endpos = b +Vector(0,0,3),mask = MASK_NPCWORLDSTATIC})
                return !tr.Hit
            end

            local function writeNode(pos,type,disabled)
                type = type or CH_NODE_GROUND
                disabled = disabled or false
                local nodeID = nodegraph:AddNode(pos,type,0,0)
                table.insert(CH_NODEDATA,{pos=pos,type=type,ID=nodeID,disabled=false})
                return nodeID
            end

            local function saveNodegraph()
                print("Saving Nodegraph...")
                file.CreateDir("ch_nodegraph")
                file.Write("ch_nodegraph/" .. game.GetMap() .. ".dat",util.TableToJSON(CH_NODEDATA))
                nodegraph:Save()
                print("Successfully saved Nodegraph! ")
                LocalPlayer():PrintMessage(HUD_PRINTTALK,"Successfully saved nodegraph to directory [data/ch_nodegraph/" .. game.GetMap() .. ".ain" .. "] in " .. math.floor(SysTime() -startTime) .. " seconds! (" .. #CH_NODEENTITIES .. "/4096 Nodes)")
            end

            local function findNodePos(nodeID)
                // Find a clear position on the map to place a node
                local pos = Vector(0,0,0)
                local found = false
                local tries = 0

                local nodeSize = GetConVar("ch_node_size"):GetInt()
                local nodeAttempts = GetConVar("ch_node_attempts"):GetInt() or 400

                local nodeMin = Vector(-nodeSize, -nodeSize, -nodeSize)
                local nodeMax = Vector(nodeSize, nodeSize, nodeSize)

                print(nodeSize,nodeAttempts)
                while !found do
                    tries = tries +1
                    if tries > nodeAttempts then
                        -- print("Couldn't find a clear position on the map to place node #" .. nodeID .. "!")
                        return
                    end
                    pos = Vector(math.random(-nodeSize,nodeSize),math.random(-nodeSize,nodeSize),math.random(-nodeSize *0.5,nodeSize *0.5))
                    if math.random(1,2) == 1 then
                        local trace1 = util.TraceHull({start=pos,endpos=pos+Vector(0,0,nodeSize),filter=player.GetAll(),mins=nodeMin,maxs=nodeMax})
                        local trace2 = util.TraceHull({start=trace1.HitPos,endpos=trace1.HitPos +Vector(0,0,-nodeSize),filter=player.GetAll(),mins=nodeMin,maxs=nodeMax})
                        if trace2.HitWorld && util.IsInWorld(trace2.HitPos) then
                            if trace2.HitSky or trace2.HitTexture == "**studio**" or trace2.HitTexture == "TOOLS/TOOLSSKYBOX" then continue end
                            pos = trace2.HitPos

                            found = true
                            -- print("Found a clear position on the map to place node #" .. nodeID .. "!")
                        end
                    else
                        local trace1 = util.TraceHull({start=pos,endpos=pos+Vector(0,0,-nodeSize),filter=player.GetAll(),mins=nodeMin,maxs=nodeMax})
                        local trace2 = util.TraceHull({start=trace1.HitPos,endpos=trace1.HitPos +Vector(0,0,nodeSize),filter=player.GetAll(),mins=nodeMin,maxs=nodeMax})
                        if trace2.HitWorld && util.IsInWorld(trace2.HitPos) then
                            if trace2.HitSky or trace2.HitTexture == "**studio**" or trace2.HitTexture == "TOOLS/TOOLSSKYBOX" then continue end
                            local testTrace = util.TraceLine({start=trace2.HitPos,endpos=trace2.HitPos +Vector(0,0,-nodeSize),filter=player.GetAll()})
                            if testTrace.HitWorld && util.IsInWorld(testTrace.HitPos) then
                                pos = testTrace.HitPos
                            else
                                local trace3 = util.TraceLine({start=trace2.HitPos +trace2.HitNormal *-100,endpos=trace2.HitPos,filter=player.GetAll()})
                                pos = trace3.Hit && trace3.HitPos or trace2.HitPos
                            end

                            found = true
                            -- print("Found a clear position on the map to place node #" .. nodeID .. "!")
                        end
                    end
                end
                return pos
            end

            -- local test = findNodePos()
            -- if test then Entity(1):SetPos(test) end

            table.Empty(CH_NODEDATA)
            if #CH_NODEENTITIES > 0 then
                for k,v in pairs(CH_NODEENTITIES) do
                    if IsValid(v.Entity) then
                        v.Entity:Remove()
                        table.remove(CH_NODEENTITIES,k)
                    end
                end
            end

            local nodeLinkDistance = GetConVar("ch_node_linkdist"):GetInt()
            local nodeMax = GetConVar("ch_node_max"):GetInt()

            local success = 0
            for i = 1,nodeMax do
                local pos = findNodePos(i)
                if pos then
                    local nodeID = writeNode(pos,CH_NODE_GROUND)
                    nodes = nodegraph:GetNodes()
                    links = nodegraph:GetLinks()
                    lookup = nodegraph:GetLookupTable()

                    -- local foundNodes = {}
                    for _,node in pairs(nodes) do
                        if _ == nodeID then print("STOPPED") continue end
                        if node && node.pos:Distance(pos) <= nodeLinkDistance && node.type == CH_NODE_GROUND && isNodeLinkable(pos,node.pos) then
                            nodegraph:AddLink(nodeID,_)
                            -- table.insert(foundNodes,node.ID)
                        end
                    end
                    success = success +1
                end
            end

            -- print("Successfully generated " .. success .. "/4096 nodes!")

            saveNodegraph()

            -- local tbl = util.TableToJSON(CH_NODEDATA,true)
            -- net.Start("CH_NODES_UPDATE")
            --     net.WriteString(util.Compress(tbl))
            -- net.Broadcast()
        end)
    end)

    hook.Add("PopulateToolMenu", "CH_NodeMenu", function()
        spawnmenu.AddToolMenuOption("Utilities", "Nodegraph", "Generation", "Generation", "", "", function(Panel)
            if !game.SinglePlayer() && !LocalPlayer():IsSuperAdmin() then
                Panel:AddControl("Label", {Text = "This menu is for Admins only!"})
                return
            end
            Panel:AddControl("Label", {Text = "This menu is for Admins only! Your game will freeze upon generating!"})
			Panel:AddControl("CheckBox", {Label = "Show Generated Nodes",Command = "ch_node_show"})
			Panel:AddControl("Slider", {Label = "Node Hull Size",Command = "ch_node_size",min=4,max=16})
			Panel:AddControl("Slider", {Label = "Node Link Distance",Command = "ch_node_linkdist",min=250,max=1000})
			Panel:AddControl("Slider", {Label = "Generation Attempts per Node",Command = "ch_node_attempts",min=1,max=1000})
			Panel:AddControl("Slider", {Label = "Maximum Generated Nodes",Command = "ch_node_max",min=1,max=4096})
			Panel:AddControl("Button", {Label = "Generate Node Data",Command = "ch_node_generate"})
        end)
    end)

    net.Receive("CH_NODES_UPDATE",function()
        local data = net.ReadString()
        local dC = util.Decompress(data)
        data = (dC != nil && util.JSONToTable(dC)) or util.JSONToTable(data)
        CH_NODEDATA = data
    end)

    hook.Add("RenderScreenspaceEffects","CH_NodeDraw",function()
        -- local nodegraph
        if !GetConVar("ch_node_show"):GetBool() then
            if #CH_NODEENTITIES > 0 then
                for k,v in pairs(CH_NODEENTITIES) do
                    if IsValid(v.Entity) then
                        v.Entity:Remove()
                        table.remove(CH_NODEENTITIES,k)
                    end
                end
            end
            return
        else
            -- nodegraph = _R.Nodegraph.Read()
        end
        cam.Start3D()
            for index,v in pairs(CH_NODEDATA) do
                if v then
                    local pos = v.pos
                    local type = v.type
                    local ID = v.ID
                    local disabled = v.disabled
                    local links = v.links

                    if !ID then table.remove(CH_NODEDATA,index) print("Removed " .. index .. " from CS-Node Data!") continue end

                    -- if nodegraph then
                        -- for _,node in pairs(links) do
                        --     if !CH_NODEDATA[node] then continue end
                        --     render.SetMaterial(Material("trails/laser"))
                        --     render.DrawBeam(pos +Vector(0,0,3),CH_NODEDATA[node].pos +Vector(0,0,3),10,0,0,Color(0,255,0,255))
                        -- end
                    -- end

                    if !CH_NODEENTITIES[ID] then
                        CH_NODEENTITIES[ID] = {}
                        CH_NODEENTITIES[ID].Type = type
                        CH_NODEENTITIES[ID].Pos = pos
                        CH_NODEENTITIES[ID].Links = links
                        CH_NODEENTITIES[ID].Disabled = disabled
                        local ent = ClientsideModel(CH_NODEMODELS[type],RENDERMODE_NORMAL)
                        ent:SetPos(pos)
                        ent:SetMoveType(MOVETYPE_NONE)
                        ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
                        CH_NODEENTITIES[ID].Entity = ent
                        -- print("Spawned node entity #" .. ID .. "!")
                    end
                end
            end
        cam.End3D()
    end)
end