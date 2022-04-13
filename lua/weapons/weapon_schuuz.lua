--[[
    SWEP Construction Kit base code
        Created by Clavus
    Available for public use, thread at:
       facepunch.com/threads/1032378
       
       
    DESCRIPTION:
        This script is meant for experienced scripters 
        that KNOW WHAT THEY ARE DOING. Don''t come to me 
        with basic Lua questions.
        
        Just copy into your SWEP or SWEP base of choice
        and merge with your own code.
        
        The SWEP.VElements, SWEP.WElements and
        SWEP.ViewModelBoneMods tables are all optional
        and only have to be visible to the client.
]]

if ( CLIENT ) then
    killicon.Add( "weapon_schuuz", "HUD/killicons/schuuz", Color( 255, 80, 0, 255 ) )
end

SWEP.PrintName         = "SCHUUZ"
 
SWEP.Author         = "[aka]bomb"
SWEP.Instructions     = "throw SHOES at 'em"

SWEP.Spawnable = true

SWEP.DrawAmmo = false

SWEP.AutoSwitchFrom = true
SWEP.AutoSwitchTo = true

SWEP.HoldType = "grenade"
SWEP.ViewModelFOV = 55
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_grenade.mdl"
SWEP.WorldModel = "models/weapons/w_grenade.mdl"
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = true
SWEP.ViewModelBoneMods = {
    ["ValveBiped.Grenade_body"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}

SWEP.VElements = {
    ["shoe"] = { type = "Model", model = "models/props_junk/shoe001a.mdl", bone = "ValveBiped.Grenade_body", rel = "", pos = Vector(1.557, 1.557, -1.558), angle = Angle(-180, 115.713, -26.883), size = Vector(0.755, 0.755, 0.755), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.WElements = {
    ["shoe"] = { type = "Model", model = "models/props_junk/shoe001a.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(0.518, 5.714, 0.518), angle = Angle(99.35, 57.272, -19.871), size = Vector(1.144, 1.144, 1.144), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.ShoeAimDist = 320
SWEP.ShoeAimImpreciseRight = 0
-- SWEP.ShoeAimImpreciseRight = -1/24

SWEP.ShoeDamage = 35
SWEP.ShoeDamageSpdThrsh = 320

SWEP.ShoeBounces = 1
SWEP.ShoeSpeed = 1024
SWEP.ShoeSpeedLow = 512
SWEP.ShoeUpHelpDiv = 60
SWEP.ShoePushForce = 4
SWEP.ShoeSelfDestructTime = 2

SWEP.ShoeHitSound = Sound( "Plastic_Box.ImpactHard" )

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "HavePlayedDrawAnim")
end

function SWEP:Initialize()
    
    self:SetKeyValue( "ItemOffset", 0 )
    
    -- Construction Kit code

    if CLIENT then
    
        // Create a new table for every weapon instance
        self.VElements = table.FullCopy( self.VElements )
        self.WElements = table.FullCopy( self.WElements )
        self.ViewModelBoneMods = table.FullCopy( self.ViewModelBoneMods )

        self:CreateModels(self.VElements) // create viewmodels
        self:CreateModels(self.WElements) // create worldmodels
        
        // init view model bone build function
        if IsValid(self.Owner) then
            local vm = self.Owner:GetViewModel()
            if IsValid(vm) then
                self:ResetBonePositions(vm)
                
                // Init viewmodel visibility
                if (self.ShowViewModel == nil or self.ShowViewModel) then
                    vm:SetColor(Color(255,255,255,255))
                else
                    -- we set the alpha to 1 instead of 0 because else ViewModelDrawn stops being called
                    vm:SetColor(Color(255,255,255,1))
                    -- ^ stopped working in GMod 13 because you have to do Entity:SetRenderMode(1) for translucency to kick in
                    -- however for some reason the view model resets to render mode 0 every frame so we just apply a debug material to prevent it from drawing
                    vm:SetMaterial("Debug/hsv")            
                end
            end
        end
        
    end

end

function SWEP:Deploy()

    self:GetOwner():EmitSound( "weapons/schuuz/intro.wav" )
    
    return true

end

function SWEP:ThrowShoe( low )
    
    local shoe = ents.Create( "prop_physics" )
    shoe:SetOwner( self:GetOwner() )
    shoe:SetModel( "models/props_junk/shoe001a.mdl" )
    
    shoe:Spawn()
    shoe:SetHealth( self.ShoeBounces )
    
    -- Self destruct in x seconds
    shoe:Fire( "Kill", nil, self.ShoeSelfDestructTime )
    
    local hurtDmgInfo = DamageInfo()
    hurtDmgInfo:SetAttacker( self:GetOwner() )
    hurtDmgInfo:SetInflictor( self )
    hurtDmgInfo:SetDamage( self.ShoeDamage )
    
    shoe:AddCallback( "PhysicsCollide", function( ent, data )
        local them = data.HitEntity
        if not ( them:IsPlayer() or them:IsNPC() ) then return end -- Only do stuff for players or NPCs
        if ( ent:Health() == 0 ) then ent:Remove() return end -- Ensure we don't hit more times than we can
        
        if not ( IsValid( them ) ) then return end
        
        local force = data.OurOldVelocity * self.ShoePushForce
        
        if ( data.Speed > self.ShoeDamageSpdThrsh ) then
            hurtDmgInfo:SetReportedPosition( data.HitPos )
            hurtDmgInfo:SetDamagePosition( data.HitPos )
            hurtDmgInfo:SetDamageForce( force )
            them:TakeDamageInfo( hurtDmgInfo )
        end
        
        data.HitObject:ApplyForceOffset( force, data.HitPos )

        ent:EmitSound( self.ShoeHitSound )

        local effect = EffectData() -- Create effect data
        effect:SetOrigin( data.HitPos ) -- Set origin where collision point is
        util.Effect( "cball_bounce", effect )

        ent:SetHealth( ent:Health() - 1 )
    end )
    
    local pos = self:GetOwner():EyePos()
    local ang = self:GetOwner():EyeAngles()
    local fwd = ang:Forward()
    local rght = ang:Right()
    local up = ang:Up()
    
    pos:Add( fwd * 16 )
    pos:Add( rght * 16 )
    
    if ( low ) then pos:Add( up * -12 ) end
    
    local eyeHit = self:GetOwner():GetEyeTrace().HitPos
    local targetVel = Vector()
    local distToTarget = pos:DistToSqr( eyeHit )
    
    if ( distToTarget > ( self.ShoeAimDist * self.ShoeAimDist ) ) then
        targetVel = fwd + rght * self.ShoeAimImpreciseRight
    else
        targetVel = eyeHit - pos
        targetVel:Add( up * ( distToTarget / ( self.ShoeUpHelpDiv * self.ShoeUpHelpDiv ) ) )
        targetVel:Normalize()
    end
    
    shoe:SetAngles( self:GetOwner():EyeAngles() )
    shoe:SetPos( pos )
    
    local force = self.ShoeSpeed
    if ( low ) then force = self.ShoeSpeedLow end
    
    shoe:GetPhysicsObject():SetVelocity( targetVel * force + self:GetOwner():GetVelocity() )
    
end

function SWEP:PrimaryAttack()
    
    if CLIENT then return end

    local basePitch = 100
    local deviation = ( math.random() * 2 - 1 ) * 12
    self:GetOwner():EmitSound( "weapons/schuuz/throw.wav", 75, basePitch + deviation )
    
    self:SendWeaponAnim( ACT_VM_THROW )
    
    self:SetHavePlayedDrawAnim(false)
    
    self:ThrowShoe(false)
    
    self:SetNextPrimaryFire( CurTime() + 0.6 )
    self:SetNextSecondaryFire( CurTime() + 0.6 )

end

function SWEP:SecondaryAttack()
    
    if ( CLIENT ) then return end

    local basePitch = 100
    local deviation = ( math.random() * 2 - 1 ) * 12
    self:GetOwner():EmitSound( "weapons/schuuz/throw.wav", 75, basePitch + deviation )
    
    self:SendWeaponAnim( ACT_VM_SECONDARYATTACK )
    
    self:SetHavePlayedDrawAnim(false)
    
    self:ThrowShoe( true )
    
    self:SetNextPrimaryFire( CurTime() + 0.6 )
    self:SetNextSecondaryFire( CurTime() + 0.6 )
    
end

function SWEP:DrawHUD()
end

function SWEP:Reload()
end

function SWEP:Think()

    if ( ( CurTime() > self:GetNextPrimaryFire() ) and not self:GetHavePlayedDrawAnim() ) then
        
        self:SendWeaponAnim( ACT_VM_DRAW )
        self:SetHavePlayedDrawAnim(true)
        
    end

end

function SWEP:Holster()
    
    if CLIENT and IsValid(self.Owner) then
        local vm = self.Owner:GetViewModel()
        if IsValid(vm) then
            self:ResetBonePositions(vm)
        end
    end
    
    return true
end

function SWEP:OnRemove()
    self:Holster()
end

if CLIENT then

    SWEP.vRenderOrder = nil
    function SWEP:ViewModelDrawn()
        
        local vm = self.Owner:GetViewModel()
        if !IsValid(vm) then return end
        
        if (!self.VElements) then return end
        
        self:UpdateBonePositions(vm)

        if (!self.vRenderOrder) then
            
            // we build a render order because sprites need to be drawn after models
            self.vRenderOrder = {}

            for k, v in pairs( self.VElements ) do
                if (v.type == "Model") then
                    table.insert(self.vRenderOrder, 1, k)
                elseif (v.type == "Sprite" or v.type == "Quad") then
                    table.insert(self.vRenderOrder, k)
                end
            end
            
        end

        for k, name in ipairs( self.vRenderOrder ) do
        
            local v = self.VElements[name]
            if (!v) then self.vRenderOrder = nil break end
            if (v.hide) then continue end
            
            local model = v.modelEnt
            local sprite = v.spriteMaterial
            
            if (!v.bone) then continue end
            
            local pos, ang = self:GetBoneOrientation( self.VElements, v, vm )
            
            if (!pos) then continue end
            
            if (v.type == "Model" and IsValid(model)) then

                model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)

                model:SetAngles(ang)
                //model:SetModelScale(v.size)
                local matrix = Matrix()
                matrix:Scale(v.size)
                model:EnableMatrix( "RenderMultiply", matrix )
                
                if (v.material == "") then
                    model:SetMaterial("")
                elseif (model:GetMaterial() != v.material) then
                    model:SetMaterial( v.material )
                end
                
                if (v.skin and v.skin != model:GetSkin()) then
                    model:SetSkin(v.skin)
                end
                
                if (v.bodygroup) then
                    for k, v in pairs( v.bodygroup ) do
                        if (model:GetBodygroup(k) != v) then
                            model:SetBodygroup(k, v)
                        end
                    end
                end
                
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(true)
                end
                
                render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
                render.SetBlend(v.color.a/255)
                model:DrawModel()
                render.SetBlend(1)
                render.SetColorModulation(1, 1, 1)
                
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(false)
                end
                
            elseif (v.type == "Sprite" and sprite) then
                
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                render.SetMaterial(sprite)
                render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
                
            elseif (v.type == "Quad" and v.draw_func) then
                
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)
                
                cam.Start3D2D(drawpos, ang, v.size)
                    v.draw_func( self )
                cam.End3D2D()

            end
            
        end
        
    end

    SWEP.wRenderOrder = nil
    function SWEP:DrawWorldModel()
        
        if (self.ShowWorldModel == nil or self.ShowWorldModel) then
            self:DrawModel()
        end
        
        if (!self.WElements) then return end
        
        if (!self.wRenderOrder) then

            self.wRenderOrder = {}

            for k, v in pairs( self.WElements ) do
                if (v.type == "Model") then
                    table.insert(self.wRenderOrder, 1, k)
                elseif (v.type == "Sprite" or v.type == "Quad") then
                    table.insert(self.wRenderOrder, k)
                end
            end

        end
        
        if (IsValid(self.Owner)) then
            bone_ent = self.Owner
        else
            // when the weapon is dropped
            bone_ent = self
        end
        
        for k, name in pairs( self.wRenderOrder ) do
        
            local v = self.WElements[name]
            if (!v) then self.wRenderOrder = nil break end
            if (v.hide) then continue end
            
            local pos, ang
            
            if (v.bone) then
                pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent )
            else
                pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand" )
            end
            
            if (!pos) then continue end
            
            local model = v.modelEnt
            local sprite = v.spriteMaterial
            
            if (v.type == "Model" and IsValid(model)) then

                model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)

                model:SetAngles(ang)
                //model:SetModelScale(v.size)
                local matrix = Matrix()
                matrix:Scale(v.size)
                model:EnableMatrix( "RenderMultiply", matrix )
                
                if (v.material == "") then
                    model:SetMaterial("")
                elseif (model:GetMaterial() != v.material) then
                    model:SetMaterial( v.material )
                end
                
                if (v.skin and v.skin != model:GetSkin()) then
                    model:SetSkin(v.skin)
                end
                
                if (v.bodygroup) then
                    for k, v in pairs( v.bodygroup ) do
                        if (model:GetBodygroup(k) != v) then
                            model:SetBodygroup(k, v)
                        end
                    end
                end
                
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(true)
                end
                
                render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
                render.SetBlend(v.color.a/255)
                model:DrawModel()
                render.SetBlend(1)
                render.SetColorModulation(1, 1, 1)
                
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(false)
                end
                
            elseif (v.type == "Sprite" and sprite) then
                
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                render.SetMaterial(sprite)
                render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
                
            elseif (v.type == "Quad" and v.draw_func) then
                
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)
                
                cam.Start3D2D(drawpos, ang, v.size)
                    v.draw_func( self )
                cam.End3D2D()

            end
            
        end
        
    end

    function SWEP:GetBoneOrientation( basetab, tab, ent, bone_override )
        
        local bone, pos, ang
        if (tab.rel and tab.rel != "") then
            
            local v = basetab[tab.rel]
            
            if (!v) then return end
            
            // Technically, if there exists an element with the same name as a bone
            // you can get in an infinite loop. Let's just hope nobody's that stupid.
            pos, ang = self:GetBoneOrientation( basetab, v, ent )
            
            if (!pos) then return end
            
            pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
            ang:RotateAroundAxis(ang:Up(), v.angle.y)
            ang:RotateAroundAxis(ang:Right(), v.angle.p)
            ang:RotateAroundAxis(ang:Forward(), v.angle.r)
                
        else
        
            bone = ent:LookupBone(bone_override or tab.bone)

            if (!bone) then return end
            
            pos, ang = Vector(0,0,0), Angle(0,0,0)
            local m = ent:GetBoneMatrix(bone)
            if (m) then
                pos, ang = m:GetTranslation(), m:GetAngles()
            end
            
            if (IsValid(self.Owner) and self.Owner:IsPlayer() and 
                ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
                ang.r = -ang.r // Fixes mirrored models
            end
        
        end
        
        return pos, ang
    end

    function SWEP:CreateModels( tab )

        if (!tab) then return end

        // Create the clientside models here because Garry says we can't do it in the render hook
        for k, v in pairs( tab ) do
            if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and 
                    string.find(v.model, ".mdl") and file.Exists (v.model, "GAME") ) then
                
                v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE)
                if (IsValid(v.modelEnt)) then
                    v.modelEnt:SetPos(self:GetPos())
                    v.modelEnt:SetAngles(self:GetAngles())
                    v.modelEnt:SetParent(self)
                    v.modelEnt:SetNoDraw(true)
                    v.createdModel = v.model
                else
                    v.modelEnt = nil
                end
                
            elseif (v.type == "Sprite" and v.sprite and v.sprite != "" and (!v.spriteMaterial or v.createdSprite != v.sprite) 
                and file.Exists ("materials/"..v.sprite..".vmt", "GAME")) then
                
                local name = v.sprite.."-"
                local params = { ["$basetexture"] = v.sprite }
                // make sure we create a unique name based on the selected options
                local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
                for i, j in pairs( tocheck ) do
                    if (v[j]) then
                        params["$"..j] = 1
                        name = name.."1"
                    else
                        name = name.."0"
                    end
                end

                v.createdSprite = v.sprite
                v.spriteMaterial = CreateMaterial(name,"UnlitGeneric",params)
                
            end
        end
        
    end
    
    local allbones
    local hasGarryFixedBoneScalingYet = false

    function SWEP:UpdateBonePositions(vm)
        
        if self.ViewModelBoneMods then
            
            if (!vm:GetBoneCount()) then return end
            
            // !! WORKAROUND !! //
            // We need to check all model names :/
            local loopthrough = self.ViewModelBoneMods
            if (!hasGarryFixedBoneScalingYet) then
                allbones = {}
                for i=0, vm:GetBoneCount() do
                    local bonename = vm:GetBoneName(i)
                    if (self.ViewModelBoneMods[bonename]) then 
                        allbones[bonename] = self.ViewModelBoneMods[bonename]
                    else
                        allbones[bonename] = { 
                            scale = Vector(1,1,1),
                            pos = Vector(0,0,0),
                            angle = Angle(0,0,0)
                        }
                    end
                end
                
                loopthrough = allbones
            end
            // !! ----------- !! //
            
            for k, v in pairs( loopthrough ) do
                local bone = vm:LookupBone(k)
                if (!bone) then continue end
                
                // !! WORKAROUND !! //
                local s = Vector(v.scale.x,v.scale.y,v.scale.z)
                local p = Vector(v.pos.x,v.pos.y,v.pos.z)
                local ms = Vector(1,1,1)
                if (!hasGarryFixedBoneScalingYet) then
                    local cur = vm:GetBoneParent(bone)
                    while(cur >= 0) do
                        local pscale = loopthrough[vm:GetBoneName(cur)].scale
                        ms = ms * pscale
                        cur = vm:GetBoneParent(cur)
                    end
                end
                
                s = s * ms
                // !! ----------- !! //
                
                if vm:GetManipulateBoneScale(bone) != s then
                    vm:ManipulateBoneScale( bone, s )
                end
                if vm:GetManipulateBoneAngles(bone) != v.angle then
                    vm:ManipulateBoneAngles( bone, v.angle )
                end
                if vm:GetManipulateBonePosition(bone) != p then
                    vm:ManipulateBonePosition( bone, p )
                end
            end
        else
            self:ResetBonePositions(vm)
        end
           
    end
     
    function SWEP:ResetBonePositions(vm)
        
        if (!vm:GetBoneCount()) then return end
        for i=0, vm:GetBoneCount() do
            vm:ManipulateBoneScale( i, Vector(1, 1, 1) )
            vm:ManipulateBoneAngles( i, Angle(0, 0, 0) )
            vm:ManipulateBonePosition( i, Vector(0, 0, 0) )
        end
        
    end

    /**************************
        Global utility code
    **************************/

    // Fully copies the table, meaning all tables inside this table are copied too and so on (normal table.Copy copies only their reference).
    // Does not copy entities of course, only copies their reference.
    // WARNING: do not use on tables that contain themselves somewhere down the line or you'll get an infinite loop
    function table.FullCopy( tab )

        if (!tab) then return nil end
        
        local res = {}
        for k, v in pairs( tab ) do
            if (type(v) == "table") then
                res[k] = table.FullCopy(v) // recursion ho!
            elseif (type(v) == "Vector") then
                res[k] = Vector(v.x, v.y, v.z)
            elseif (type(v) == "Angle") then
                res[k] = Angle(v.p, v.y, v.r)
            else
                res[k] = v
            end
        end
        
        return res
        
    end
    
end

