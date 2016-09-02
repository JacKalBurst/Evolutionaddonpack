--[[
	Ship Railgun
	Copyright (C) 2010 Madman07
]]--

if (Lib!=nil and Lib.Wire!=nil) then Lib.Wiremod(ENT); end
if (Lib!=nil and Lib.RD!=nil) then Lib.LifeSupport(ENT); end

ENT.Type = "anim"
ENT.Base = "turret_base"
ENT.PrintName = "Ship Railgun"
ENT.Author = "Madman07, Boba Fett"
ENT.Instructions= ""
ENT.Contact = "madman097@gmail.com"
ENT.Category = Lib.Language.GetMessage("cat_weapons");
ENT.WireDebugName = ENT.PrintName
ENT.Spawnable = true
ENT.AdminSpawnable = true

list.Set("EAP", ENT.PrintName, ENT);

if SERVER then

AddCSLuaFile()

ENT.Sounds={
	Shoot=Sound("weapons/railgun_shoot.wav"),
	Move=Sound("weapons/turret_move_loop.wav"),
}
ENT.SoundDur = 0.2;

ENT.BaseModel = "models/Madman07/ship_rail/ship_stand.mdl";
ENT.TurnModel = "models/Madman07/ship_rail/ship_turn.mdl";
ENT.BarrelModel = "models/Madman07/ship_rail/ship_cann.mdl";
ENT.TurnPos = Vector(0,0,22.75);
ENT.BarrelPos = Vector(0,0,16.5);

ENT.DownClamp = -50;
ENT.UpClamp = -5;
ENT.Speed = 0.5;

ENT.energy_drain = 400;
ENT.energy_setup = 800;

ENT.Pitch = -25;

-----------------------------------SPAWN----------------------------------

function ENT:SpawnFunction( ply, tr )
	if ( !tr.HitPos ) then return end

	if (IsValid(ply)) then
		local PropLimit = GetConVar("EAP_shiprail_max"):GetInt()
		if(ply:GetCount("EAP_shiprail")+1 > PropLimit) then
			ply:SendLua("GAMEMODE:AddNotify(Lib.Language.GetMessage(\"entity_limit_ship_rail\"), NOTIFY_ERROR, 5); surface.PlaySound( \"buttons/button2.wav\" )");
			return
		end
	end

	local ang = ply:GetAimVector():Angle(); ang.p = 0; ang.r = 0; ang.y = ang.y % 360

	local ent = ents.Create("turret_shiprail");
	ent:SetPos(tr.HitPos);
	ent:SetAngles(ang);
	ent:Spawn();
	ent:Activate();

	if (IsValid(ply)) then
		ply:AddCount("EAP_shiprail", ent)
	end
	ent:SpawnRest(ply);
	ent.Duped = true;
	return ent
end

function ENT:PreEntityCopy()
	local dupeInfo = {}

	if IsValid(self.Entity) then
		dupeInfo.EntID = self.Entity:EntIndex();
	end

	if IsValid(self.Turn) then
		dupeInfo.Turn = self.Turn:EntIndex();
	end

	if IsValid(self.Cann) then
		dupeInfo.Cann = self.Cann:EntIndex();
	end

	duplicator.StoreEntityModifier(self, "SGTurrBaseDupe", dupeInfo)
	Lib.Wire.PreEntityCopy(self,ply,Ent,CreatedEntities)
	Lib.RD.PreEntityCopy(self,ply,Ent,CreatedEntities)
end

function ENT:PostEntityPaste(ply, Ent, CreatedEntities)
	local dupeInfo = Ent.EntityMods["SGTurrBaseDupe"] or {}

	if dupeInfo.Turn then
		self.Turn = CreatedEntities[ dupeInfo.Turn ]
		self.Turn.Parent = self.Entity;
	end

	if dupeInfo.Cann then
		self.Cann = CreatedEntities[ dupeInfo.Cann ]
		self.Cann.Parent = self.Entity;
	end

	if dupeInfo.EntID then
		self.Entity = CreatedEntities[ dupeInfo.EntID ]
	end

	self.Stand = self.Entity;
	if (Lib.NotSpawnable(Ent:GetClass(),ply)) then self.Entity:Remove(); return end
	if (IsValid(ply)) then
		local PropLimit = GetConVar("EAP_shiprail_max"):GetInt()
		if(ply:GetCount("EAP_shiprail")+1 > PropLimit) then
			ply:SendLua("GAMEMODE:AddNotify(Lib.Language.GetMessage(\"entity_limit_ship_rail\"), NOTIFY_ERROR, 5); surface.PlaySound( \"buttons/button2.wav\" )");
			self.Entity:Remove();
			return
		end
		ply:AddCount("EAP_shiprail", self.Entity)
	end
	self.Duped = true;
	Lib.Wire.PostEntityPaste(self,ply,Ent,CreatedEntities)
	Lib.RD.PostEntityPaste(self,ply,Ent,CreatedEntities)
end

if (Lib and Lib.EAP_GmodDuplicator) then
	duplicator.RegisterEntityClass( "turret_shiprail", Lib.EAP_GmodDuplicator, "Data" )
end

function ENT:OnRemove()
	if IsValid(self.Stand) then self.Stand:Remove(); end
	if IsValid(self.Turn) then self.Turn:Remove(); end
	if IsValid(self.Cann) then self.Cann:Remove() end
end

-----------------------------------SHOOT----------------------------------

function ENT:Shoot()

	local energy = self:GetResource("energy",self.energy_drain);

	if(energy > self.energy_drain or !self.HasResourceDistribution) then

		self:ConsumeResource("energy",self.energy_drain);

		self.CanFire = false;

		local seq = self.Cann:LookupSequence("Fire");
		self.Cann:ResetSequence(seq);

		local data = self.Cann:GetAttachment(self.Cann:LookupAttachment("Fire"))
		if(not (data and data.Pos)) then return end

		self.StargateTrace = Lib.Trace:New(data.Pos+self.Cann:GetForward()*100,self.Cann:GetPos()+self.Cann:GetForward() * 10^14);

		local mat = self.StargateTrace.MatType;
		local smoke = 1;
		if (self.StargateTrace.HitSky or (mat == MAT_FLESH) or (mat == MAT_METAL) or (mat == MAT_GLASS)) then smoke = 0 end

		local fx = EffectData();
			fx:SetStart(data.Pos);
			fx:SetOrigin(self.StargateTrace.HitPos);
			fx:SetMagnitude(smoke);
			fx:SetAngles(Angle(235, 215, 130));
			fx:SetRadius(1);
		util.Effect("Bullettracer",fx);

		local effectdata = EffectData()
			effectdata:SetOrigin(data.Pos)
			effectdata:SetAngles(self.Cann:GetAngles())
			effectdata:SetScale( 2 )
		util.Effect( "MuzzleEffect", effectdata )

		local damage = Lib.CFG:Get("ship_railgun","damage",10);

		bullet = {}
		bullet.Src		= data.Pos;
		bullet.Attacker = self.Entity;
		bullet.Dir		= self.Cann:GetForward();
		bullet.Spread	= Vector(0.01,0.01,0);
		bullet.Num		= 1;
		bullet.Damage	= damage;
		bullet.Force	= damage;
		bullet.Tracer	= 0;
		self.Cann:FireBullets(bullet);

		self:EmitSound(self.Sounds.Shoot,100,math.random(98,102));
		util.ScreenShake(data.Pos,1,2.5,0.5,500)

		local rand = math.random(2,3)/100;
		timer.Simple(rand, function() self.CanFire = true; end);

	end

end

end

if CLIENT then

if (Lib.Language!=nil and Lib.Language.GetMessage!=nil) then
	ENT.Category = Lib.Language.GetMessage("cat_weapons");
	ENT.PrintName = Lib.Language.GetMessage("entity_shiprail");
end

end