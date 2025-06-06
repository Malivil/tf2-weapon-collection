AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ttt_basegrenade_proj"
ENT.Model = Model("models/weapons/c_models/urinejar.mdl")
ENT.Radius = 200
ENT.Duration = 10

local function ResetPlayer(ply)
    if ply.TF2JarateHP then
        ply:SetHealth(ply.TF2JarateHP)
        ply:SetColor(ply.TF2JarateColour)
        ply:StopParticles()
        ply.TF2JarateHP = nil
        ply.TF2JarateColour = nil
    end
end

function ENT:Initialize()
    ParticleEffectAttach("peejar_trail_red", PATTACH_POINT_FOLLOW, self, 1)

    if SERVER then
        util.AddNetworkString("TF2JarateHit")
    end

    -- Jarate is removed on entering waist-high water
    hook.Add("OnEntityWaterLevelChanged", "TF2JarateWaterRemove", function(ent, _, newLvl)
        if IsValid(ent) and ent:IsPlayer() and ent:Alive() and not ent:IsSpec() and newLvl > 1 then
            ResetPlayer(ent)
        end
    end)

    hook.Add("TTTPrepareRound", "TF2JarateReset", function()
        hook.Remove("OnEntityWaterLevelChanged", "TF2JarateWaterRemove")
        hook.Remove("TTTPrepareRound", "TF2JarateReset")
    end)

    return self.BaseClass.Initialize(self)
end

function ENT:PhysicsCollide()
    self:Explode()
end

function ENT:Explode()
    if CLIENT then return end
    local hitPlayers = {}
    local peeColour = Color(255, 255, 0)

    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.Radius)) do
        -- Skip players underwater
        if IsValid(ent) and ent:IsPlayer() and ent:Alive() and not ent:IsSpec() and ent:WaterLevel() < 2 then
            ent.TF2JarateHP = ent:Health()
            ent.TF2JarateColour = ent:GetColor()
            ent:SetHealth(1)
            ent:SetColor(peeColour)
            ParticleEffectAttach("peejar_drips", PATTACH_POINT_FOLLOW, ent, 1)
            table.insert(hitPlayers, ent)
            local timername = "TF2JarateHit" .. ent:SteamID64()

            timer.Create(timername, self.Duration, 1, function()
                if not IsValid(ent) then
                    timer.Remove(timername)

                    return
                end

                ResetPlayer(ent)
            end)
        end
    end

    ParticleEffect("peejar_impact", self:GetPos(), angle_zero)
    net.Start("TF2JarateHit")
    net.WriteUInt(self.Duration, 4)
    net.Send(hitPlayers)
    self:EmitSound("weapons/jar_explode.wav", 90, 100, 0.75)
    self:Remove()
end

if CLIENT then
    net.Receive("TF2JarateHit", function()
        local duration = net.ReadUInt(4)
        local client = LocalPlayer()

        hook.Add("RenderScreenspaceEffects", "TF2JarateScreenEffect", function()
            -- If the player is underwater, the effect is likely about to be removed, so disable it now
            if client:WaterLevel() > 1 then
                hook.Remove("RenderScreenspaceEffects", "TF2JarateScreenEffect")
                timer.Remove("TF2JarateScreenEffectRemove")

                return
            end

            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetTexture(surface.GetTextureID("effects/jarate_overlay"))
            surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        end)

        timer.Create("TF2JarateScreenEffectRemove", duration, 1, function()
            hook.Remove("RenderScreenspaceEffects", "TF2JarateScreenEffect")
        end)
    end)
end