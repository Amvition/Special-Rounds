/*
	Hello guys! First time here just wondering if any of you are interested making a plugin for an awp server?

	Basically, the plugin will comeout randomly which players can vote what mode they will play next round:

	Modes in mind is:

	Noscope round
	Knife Round
	Drug Round
	Scout only Round
	0 gravity round
	Revolver round and so on.

	If you are interested and know more about the server drop me a pm or something ill gladly share you the details. Will pay if necessary.
*/

//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

#define MODE_NONE 0
#define MODE_NOSCOPE 1
#define MODE_KNIFE 2
#define MODE_DRUG 3
#define MODE_SCOUTONLY 4
#define MODE_ZEROGRAV 5
#define MODE_REVOLVER 6

#define DMG_HEADSHOT (1 << 30)

//Sourcemod Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colorvariables>

//ConVars
ConVar convar_Status;
ConVar convar_MinTime;
ConVar convar_MaxTime;
ConVar convar_VoteTime;

//Globals
int g_iCurrentMode = MODE_NONE;
int g_iQueuedMode = MODE_NONE;
Handle g_hTimer_VoteMenu;
bool g_bCantBuy;
int m_flNextSecondaryAttack = -1;

//throwing knives
bool g_bHasThrowingKnife[MAXPLAYERS + 1];
int g_iTrailSprite;
int g_iBloodDecal;
ArrayList g_hThrownKnives;
bool g_bHeadshot[MAXPLAYERS + 1];

//drugs timer
UserMsg g_FadeUserMsgId;
Handle g_hTimer_Drugs;
float g_DrugAngles[20] = {0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 20.0, 15.0, 10.0, 5.0, 0.0, -5.0, -10.0, -15.0, -20.0, -25.0, -20.0, -15.0, -10.0, -5.0};

public Plugin myinfo =
{
	name = "Special Rounds",
	author = "Keith Warren (Shaders Allen)",
	description = "Commissioned by Amb.",
	version = "1.0.0",
	url = "https://github.com/ShadersAllen"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_specialrounds_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_MinTime = CreateConVar("sm_specialrounds_mintime", "30.0", "Minimum amount of time to randomize the vote starting on round start.", FCVAR_NOTIFY, true, 0.0);
	convar_MaxTime = CreateConVar("sm_specialrounds_maxtime", "360.0", "Minimum amount of time to randomize the vote starting on round start.", FCVAR_NOTIFY, true, 0.0);
	convar_VoteTime = CreateConVar("sm_specialrounds_maxtime", "20", "Time in seconds for the vote to last.", FCVAR_NOTIFY, true, 0.0);
	AutoExecConfig();

	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("round_freeze_end", Event_OnRoundFreezeEnd);
	HookEvent("round_end", Event_OnRoundEnd);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);

	RegAdminCmd("sm_specialrounds", Command_SpecialRounds, ADMFLAG_ROOT, "Test special rounds.");

	m_flNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack");
	g_hThrownKnives = new ArrayList();
	g_FadeUserMsgId = GetUserMessageId("Fade");
}

public void OnMapStart()
{
	g_iTrailSprite = PrecacheModel("effects/blueblacklargebeam.vmt");
	g_iBloodDecal = PrecacheDecal("sprites/blood.vmt");
}

public void OnMapEnd()
{
	g_hTimer_VoteMenu = null;
	g_iCurrentMode = MODE_NONE;
	g_iQueuedMode = MODE_NONE;
	g_bCantBuy = false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	int dmgtype = DMG_SLASH | DMG_NEVERGIB;

	if (0 < inflictor <= MaxClients && inflictor == attacker && damagetype == dmgtype)
	{
		g_bHeadshot[attacker] = false;
	}
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hTimer_VoteMenu != null)
	{
		KillTimer(g_hTimer_VoteMenu);
		g_hTimer_VoteMenu = null;
	}

	if (!convar_Status.BoolValue)
	{
		return;
	}

	g_hTimer_VoteMenu = CreateTimer(GetRandomFloat(convar_MinTime.FloatValue, convar_MaxTime.FloatValue), Timer_DisplayVoteMenu, _, TIMER_FLAG_NO_MAPCHANGE);

	g_iCurrentMode = g_iQueuedMode;
	g_iQueuedMode = MODE_NONE;

	switch (g_iCurrentMode)
	{
		case MODE_NOSCOPE, MODE_KNIFE, MODE_SCOUTONLY, MODE_REVOLVER:
		{
			g_bCantBuy = true;
		}
	}
}

public Action Timer_DrugPlayers(Handle timer)
{
	float angs[3]; Handle message; int clients[2]; int duration; int holdtime; int flags; int color[4] = { 0, 0, 0, 128 };
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i))
		{
			continue;
		}

		GetClientEyeAngles(i, angs);

		angs[2] = g_DrugAngles[GetRandomInt(0,100) % 20];

		TeleportEntity(i, NULL_VECTOR, angs, NULL_VECTOR);

		clients[0] = i;

		duration = 255;
		holdtime = 255;
		flags = 0x0002;
		color[0] = GetRandomInt(0,255); color[1] = GetRandomInt(0,255); color[2] = GetRandomInt(0,255);

		message = StartMessageEx(g_FadeUserMsgId, clients, 1);
		if (GetUserMessageType() == UM_Protobuf)
		{
			Protobuf pb = UserMessageToProtobuf(message);
			pb.SetInt("duration", duration);
			pb.SetInt("hold_time", holdtime);
			pb.SetInt("flags", flags);
			pb.SetColor("clr", color);
		}
		else
		{
			BfWriteShort(message, duration);
			BfWriteShort(message, holdtime);
			BfWriteShort(message, flags);
			BfWriteByte(message, color[0]);
			BfWriteByte(message, color[1]);
			BfWriteByte(message, color[2]);
			BfWriteByte(message, color[3]);
		}

		EndMessage();
	}
}

public void Event_OnRoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
	{
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
		{
			continue;
		}

		switch (g_iCurrentMode)
		{
			case MODE_NOSCOPE:
			{
				CSGO_ReplaceWeapon(i, 0, "weapon_awp");
				SDKHook(i, SDKHook_PreThink, NoScope_DisableScope);
				SDKHook(i, SDKHook_WeaponCanSwitchTo, NoScope_WeaponLimiter);
			}

			case MODE_KNIFE:
			{
				CSGO_StripToKnife(i);
				SDKHook(i, SDKHook_WeaponCanSwitchTo, Knife_WeaponLimiter);
				g_bHasThrowingKnife[i] = true;
			}

			case MODE_DRUG:
			{
				if (g_hTimer_Drugs != null)
				{
					KillTimer(g_hTimer_Drugs);
					g_hTimer_Drugs = null;
				}

				g_hTimer_Drugs = CreateTimer(1.0, Timer_DrugPlayers, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}

			case MODE_SCOUTONLY:
			{
				CSGO_ReplaceWeapon(i, 0, "weapon_ssg08");
				SDKHook(i, SDKHook_WeaponCanSwitchTo, ScoutOnly_WeaponLimiter);
			}

			case MODE_ZEROGRAV:
			{
				SetEntityGravity(i, 0.1);
			}

			case MODE_REVOLVER:
			{
				CSGO_ReplaceWeapon(i, 1, "weapon_revolver");
				SDKHook(i, SDKHook_WeaponCanSwitchTo, Revolver_WeaponLimiter);
			}
		}
	}
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hTimer_VoteMenu != null)
	{
		KillTimer(g_hTimer_VoteMenu);
		g_hTimer_VoteMenu = null;
	}

	if (g_hTimer_Drugs != null)
	{
		KillTimer(g_hTimer_Drugs);
		g_hTimer_Drugs = null;
	}

	float angs[3]; Handle message; int clients[2]; int duration = 1536; int holdtime = 1536; int flags; int color[4] = { 0, 0, 0, 0 };
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKUnhook(i, SDKHook_PreThink, NoScope_DisableScope);
			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, NoScope_WeaponLimiter);
			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, Knife_WeaponLimiter);
			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, ScoutOnly_WeaponLimiter);
			SDKUnhook(i, SDKHook_WeaponCanSwitchTo, Revolver_WeaponLimiter);

			GetClientEyeAngles(i, angs);

			angs[2] = 0.0;

			TeleportEntity(i, NULL_VECTOR, angs, NULL_VECTOR);

			clients[0] = i;
			flags = (0x0001 | 0x0010);

			message = StartMessageEx(g_FadeUserMsgId, clients, 1);
			if (GetUserMessageType() == UM_Protobuf)
			{
				Protobuf pb = UserMessageToProtobuf(message);
				pb.SetInt("duration", duration);
				pb.SetInt("hold_time", holdtime);
				pb.SetInt("flags", flags);
				pb.SetColor("clr", color);
			}
			else
			{
				BfWrite bf = UserMessageToBfWrite(message);
				bf.WriteShort(duration);
				bf.WriteShort(holdtime);
				bf.WriteShort(flags);
				bf.WriteByte(color[0]);
				bf.WriteByte(color[1]);
				bf.WriteByte(color[2]);
				bf.WriteByte(color[3]);
			}

			EndMessage();

			SetEntityGravity(i, 1.0);
		}
	}

	g_iCurrentMode = MODE_NONE;

	g_bCantBuy = false;
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (g_bHasThrowingKnife[client])
	{
		char sWeapon[32];
		GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));

		if (StrContains(sWeapon, "knife", false) != -1 || strcmp(sWeapon, "bayonet") == 0)
		{
			SetEventBool(event, "headshot", g_bHeadshot[client]);
			g_bHeadshot[client] = false;
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_iCurrentMode == MODE_KNIFE && client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && buttons & IN_ATTACK && g_bHasThrowingKnife[client])
	{
		int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

		if (IsValidEntity(active))
		{
			char sWeapon[32];
			GetEntityClassname(active, sWeapon, sizeof(sWeapon));

			if (StrContains(sWeapon[7], "knife", false) != -1 || strcmp(sWeapon[7], "bayonet") == 0)
			{
				RequestFrame(CreateThrowingKnife, GetClientUserId(client));
			}
		}
	}
}

public Action Command_SpecialRounds(int client, int args)
{
	if (!convar_Status.BoolValue)
	{
		return Plugin_Handled;
	}

	StartVoteForMode();
	return Plugin_Handled;
}

public Action Timer_DisplayVoteMenu(Handle timer)
{
	if (!convar_Status.BoolValue)
	{
		return Plugin_Stop;
	}

	StartVoteForMode();
	return Plugin_Stop;
}

void StartVoteForMode()
{
	if (!convar_Status.BoolValue)
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_VoteForMode);
	menu.SetTitle("Vote for a gamemode:");
	menu.AddItem("1", "Noscope Round");
	menu.AddItem("2", "Knife Round");
	menu.AddItem("3", "Drug Round");
	menu.AddItem("4", "Scout only Round");
	menu.AddItem("5", "0 gravity Round");
	menu.AddItem("6", "Revolver Round");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(convar_VoteTime.IntValue);
}

public int MenuHandler_VoteForMode(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_VoteEnd:
		{
			if (!convar_Status.BoolValue)
			{
				return;
			}

			char sItem[12]; char sName[32];
			menu.GetItem(param1, sItem, sizeof(sItem), _, sName, sizeof(sName));

			int votes; int totalvotes;
			GetMenuVoteInfo(param2, votes, totalvotes);

			g_iQueuedMode = StringToInt(sItem);
			CPrintToChatAll("Gamemode '%s' has won with %i votes with a total of %i votes.", sName, votes, totalvotes);
		}

		case MenuAction_VoteCancel, VoteCancel_NoVotes:
		{
			CPrintToChatAll("Vote has failed, no votes casted.");
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if (g_bCantBuy)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

stock int CSGO_ReplaceWeapon(int client, int slot, const char[] weapon_string)
{
	int old_weapon = GetPlayerWeaponSlot(client, slot);

	if (IsValidEntity(old_weapon))
	{
		if (GetEntPropEnt(old_weapon, Prop_Send, "m_hOwnerEntity") != client)
		{
			SetEntPropEnt(old_weapon, Prop_Send, "m_hOwnerEntity", client);
		}

		CS_DropWeapon(client, old_weapon, false, true);
		AcceptEntityInput(old_weapon, "Kill");
	}

	int new_weapon = GivePlayerItem(client, weapon_string);

	if (IsValidEntity(new_weapon))
	{
		EquipPlayerWeapon(client, new_weapon);
	}

	return new_weapon;
}

stock void CSGO_StripToKnife(int client)
{
	int weapon;
	for (int i = 0; i < 4; i++)
	{
		if (i == CS_SLOT_KNIFE)
		{
			EquipWeaponSlot(client, i);
			continue;
		}

		if ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != client)
			{
				SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
			}

			SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(weapon, "Kill");
		}
	}
}

stock void EquipWeaponSlot(int client, int slot)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);
	if(IsValidEntity(iWeapon))
		EquipWeapon(client, iWeapon);
}

stock void EquipWeapon(int client, int weapon)
{
	char class[64];
	GetEntityClassname(weapon, class, sizeof(class));

	FakeClientCommand(client, "use %s", class);
}

public Action NoScope_DisableScope(int client)
{
	int primary = GetPlayerWeaponSlot(client, 0);

	if (IsValidEntity(primary))
	{
		char sClassname[32];
		GetEntityClassname(primary, sClassname, sizeof(sClassname));

		if (StrEqual(sClassname, "weapon_awp"))
		{
			SetEntDataFloat(primary, m_flNextSecondaryAttack, GetGameTime() + 1.0);
		}
	}
}

public Action NoScope_WeaponLimiter(int client, int weapon)
{
	char sClassname[32];
	GetEntityClassname(weapon, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "weapon_awp") || StrEqual(sClassname, "weapon_ssg08") || StrContains(sClassname, "weapon_knife") != -1)
	{
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public Action Knife_WeaponLimiter(int client, int weapon)
{
	char sClassname[32];
	GetEntityClassname(weapon, sClassname, sizeof(sClassname));

	if (StrContains(sClassname, "weapon_knife") != -1)
	{
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public Action ScoutOnly_WeaponLimiter(int client, int weapon)
{
	char sClassname[32];
	GetEntityClassname(weapon, sClassname, sizeof(sClassname));

	if (StrContains(sClassname, "weapon_ssg08") != -1)
	{
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public Action Revolver_WeaponLimiter(int client, int weapon)
{
	char sClassname[32];
	GetEntityClassname(weapon, sClassname, sizeof(sClassname));

	if (StrContains(sClassname, "weapon_revolver") != -1)
	{
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public void CreateThrowingKnife(any data)
{
	int client = GetClientOfUserId(data);

	if (g_iCurrentMode == MODE_KNIFE && client > 0 && IsClientInGame(client) && g_bHasThrowingKnife[client])
	{
		g_bHasThrowingKnife[client] = false;

		int slot_knife = GetPlayerWeaponSlot(client, 2);
		int knife = CreateEntityByName("smokegrenade_projectile");
		DispatchKeyValue(knife, "classname", "throwing_knife");

		if (DispatchSpawn(knife))
		{
			int iTeam = GetClientTeam(client);
			SetEntPropEnt(knife, Prop_Send, "m_hOwnerEntity", client);
			SetEntPropEnt(knife, Prop_Send, "m_hThrower", client);
			SetEntProp(knife, Prop_Send, "m_iTeamNum", iTeam);

			char sBuffer[PLATFORM_MAX_PATH];
			if (slot_knife != -1)
			{
				GetEntPropString(slot_knife, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));

				if (ReplaceString(sBuffer, sizeof(sBuffer), ".mdl", "_dropped.mdl", true) != 1)
				{
					sBuffer[0] = '\0';
				}
			}

			if (!FileExists(sBuffer, true))
			{
				switch (iTeam)
				{
					case 2:	strcopy(sBuffer, sizeof(sBuffer), "models/weapons/w_knife_default_t_dropped.mdl");
					case 3:	strcopy(sBuffer, sizeof(sBuffer), "models/weapons/w_knife_default_ct_dropped.mdl");
				}
			}

			SetEntProp(knife, Prop_Send, "m_nModelIndex", PrecacheModel(sBuffer));
			SetEntPropFloat(knife, Prop_Send, "m_flModelScale", 1.0);
			SetEntPropFloat(knife, Prop_Send, "m_flElasticity", 0.2);
			SetEntPropFloat(knife, Prop_Data, "m_flGravity", 1.0);

			float fOrigin[3]; float fAngles[3]; float sPos[3]; float fPlayerVelocity[3]; float fVelocity[3];
			GetClientEyePosition(client, fOrigin);
			GetClientEyeAngles(client, fAngles);

			GetAngleVectors(fAngles, sPos, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(sPos, 50.0);
			AddVectors(sPos, fOrigin, sPos);

			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fPlayerVelocity);
			GetAngleVectors(fAngles, fVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(fVelocity, 1900.0);
			AddVectors(fVelocity, fPlayerVelocity, fVelocity);

			SetEntPropVector(knife, Prop_Data, "m_vecAngVelocity", view_as<float>({4000.0, 0.0, 0.0}));

			SetEntProp(knife, Prop_Data, "m_nNextThinkTick", -1);
			Format(sBuffer, sizeof(sBuffer), "!self,Kill,,%0.1f,-1", 1.5);
			DispatchKeyValue(knife, "OnUser1", sBuffer);
			AcceptEntityInput(knife, "FireUser1");

			TE_SetupBeamFollow(knife, g_iTrailSprite, 0, 0.5, 1.0, 0.1, 0, {255, 255, 255, 255});
			TE_SendToAll();

			TeleportEntity(knife, sPos, fAngles, fVelocity);
			SDKHookEx(knife, SDKHook_Touch, KnifeHit);

			PushArrayCell(g_hThrownKnives, EntIndexToEntRef(knife));

			CS_DropWeapon(client, slot_knife, false, true);
			AcceptEntityInput(slot_knife, "Kill");
		}
	}
}

public Action KnifeHit(int knife, int victim)
{
	if (0 < victim <= MaxClients)
	{
		SetVariantString("csblood");
		AcceptEntityInput(knife, "DispatchEffect");
		AcceptEntityInput(knife, "Kill");

		int attacker = GetEntPropEnt(knife, Prop_Send, "m_hThrower");
		int inflictor = GetPlayerWeaponSlot(attacker, 2);

		if (inflictor == -1)
		{
			inflictor = attacker;
		}

		float fVictimEye[3]; float fDamagePosition[3]; float fDamageForce[3];
		GetClientEyePosition(victim, fVictimEye);

		GetEntPropVector(knife, Prop_Data, "m_vecOrigin", fDamagePosition);
		GetEntPropVector(knife, Prop_Data, "m_vecVelocity", fDamageForce);

		if (GetVectorLength(fDamageForce) != 0.0)
		{
			float distance = GetVectorDistance(fDamagePosition, fVictimEye);
			g_bHeadshot[attacker] = distance <= 20.0;

			int dmgtype = DMG_SLASH|DMG_NEVERGIB;

			if (g_bHeadshot[attacker])
			{
				dmgtype |= DMG_HEADSHOT;
			}

			SDKHooks_TakeDamage(victim, inflictor, attacker, g_bHeadshot[attacker] ? 80.0 : 20.0, dmgtype, knife, fDamageForce, fDamagePosition);

			TE_SetupBloodSprite(fDamagePosition, view_as<float>({0.0, 0.0, 0.0}), view_as<int>({255, 0, 0, 255}), 1, g_iBloodDecal, g_iBloodDecal);
			TE_SendToAll(0.0);

			int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");

			if (ragdoll != -1)
			{
				ScaleVector(fDamageForce, 50.0);
				fDamageForce[2] = FloatAbs(fDamageForce[2]);
				SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", fDamageForce);
				SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", fDamageForce);
			}
		}
	}
	else if (FindValueInArray(g_hThrownKnives, EntIndexToEntRef(victim)) != -1)
	{
		SDKUnhook(knife, SDKHook_Touch, KnifeHit);

		float sPos[3]; float dir[3];
		GetEntPropVector(knife, Prop_Data, "m_vecOrigin", sPos);
		TE_SetupArmorRicochet(sPos, dir);
		TE_SendToAll(0.0);

		DispatchKeyValue(knife, "OnUser1", "!self,Kill,,1.0,-1");
		AcceptEntityInput(knife, "FireUser1");
	}
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEdict(entity))
	{
		int index = FindValueInArray(g_hThrownKnives, EntIndexToEntRef(entity));

		if (index != -1)
		{
			RemoveFromArray(g_hThrownKnives, index);
		}
	}
}
