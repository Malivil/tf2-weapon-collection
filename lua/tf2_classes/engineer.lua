if SERVER then
    util.AddNetworkString("TF2EngineerSetClientSentryWrench")

    hook.Add("TF2ClassChanged", "TF2Engineer_ClassChangeReset", function(ply, class)
        if class and class.name == "engineer" then
            timer.Simple(1, function()
                local wrench = ply:GetWeapon("weapon_ttt_tf2_eurekaeffect")

                if IsValid(wrench) then
                    TF2WC:AddSentryPlacerFunctions(wrench)
                    net.Start("TF2EngineerSetClientSentryWrench")
                    net.WriteEntity(wrench)
                    net.Send(ply)
                end
            end)
        end
    end)
end

TF2WC = TF2WC or {}

function TF2WC:AddSentryPlacerFunctions(SWEP)
    SWEP.PlaceRange = 128
    SWEP.DamageAmount = 10
    SWEP.PlaceOffset = 10
    SWEP.SentryModel = "models/buildables/sentry1.mdl"
    SWEP.TTTPAPSentryWrenchSpawned = false

    function SWEP:SecondaryAttack()
        if not self.TTTPAPSentryWrenchSpawned then
            self:SpawnSentry()
        end
    end

    function SWEP:SpawnSentry()
        local owner = self:GetOwner()
        if not IsValid(owner) then return end
        local tr = owner:GetEyeTrace()
        if not tr.HitWorld then return end

        if tr.HitPos:Distance(owner:GetPos()) > self.PlaceRange then
            owner:PrintMessage(HUD_PRINTCENTER, "Look at the ground to place the sentry")

            return
        end

        self.TTTPAPSentryWrenchSpawned = true
        if CLIENT then return end
        local Views = owner:EyeAngles().y
        local sentry = ents.Create("ttt_tf2_sentry")
        sentry:SetOwner(owner)
        sentry:SetPos(tr.HitPos + tr.HitNormal)
        sentry:SetAngles(Angle(0, Views, 0))
        sentry.Damage = self.DamageAmount
        sentry:Spawn()
        sentry:Activate()
        owner:EmitSound("player/engineer/sentry_build" .. math.random(2) .. ".wav")
    end

    function SWEP:RemoveHologram()
        if IsValid(self.Hologram) then
            self.Hologram:Remove()
        end
    end

    -- Draw hologram when placing down the sentry
    function SWEP:DrawHologram()
        if self.TTTPAPSentryWrenchSpawned then
            self:RemoveHologram()

            return
        end

        if not CLIENT then return end
        local owner = self:GetOwner()
        if not IsValid(owner) then return end
        local TraceResult = owner:GetEyeTrace()
        local startPos = TraceResult.StartPos
        local endPos = TraceResult.HitPos
        local dist = math.Distance(startPos.x, startPos.y, endPos.x, endPos.y)

        if dist < self.PlaceRange then
            local hologram

            if IsValid(self.Hologram) then
                hologram = self.Hologram
            else
                -- Make the hologram see-through to indicate it isn't placed yet
                hologram = ClientsideModel(self.SentryModel)
                hologram:SetColor(Color(200, 200, 200, 200))
                hologram:SetRenderMode(RENDERMODE_TRANSCOLOR)
                self.Hologram = hologram
            end

            endPos.z = endPos.z + self.PlaceOffset
            local pitch, yaw, roll = owner:EyeAngles():Unpack()
            pitch = 0
            hologram:SetPos(endPos)
            hologram:SetAngles(Angle(pitch, yaw, roll))
            hologram:DrawModel()
        else
            self:RemoveHologram()
        end
    end

    SWEP.PAPOldThink = SWEP.Think

    function SWEP:Think()
        self:DrawHologram()

        return self:PAPOldThink()
    end

    function SWEP:Holster()
        self:RemoveHologram()

        return true
    end

    function SWEP:OwnerChanged()
        self:RemoveHologram()
    end

    function SWEP:OnRemove()
        self:RemoveHologram()
    end

    if CLIENT then
        function SWEP:DrawHUD()
            if self.TTTPAPSentryWrenchSpawned then return end
            draw.WordBox(8, TF2WC:GetXHUDOffset(), ScrH() - 50, "Right-click to place sentry", "TF2Font", color_black, color_white, TEXT_ALIGN_LEFT)
        end
    end
end

if CLIENT then
    net.Receive("TF2EngineerSetClientSentryWrench", function()
        local wrench = net.ReadEntity()
        TF2WC:AddSentryPlacerFunctions(wrench)
    end)
end