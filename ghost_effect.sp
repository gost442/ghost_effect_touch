/*  SM CS:GO Ghost on Death
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' Garc�a
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// NO THIS TIME LOL
//
//#include <SpanishPawn.inc>
//

#pragma newdecls required

#define VERSION "1.1.1"

// Boolean per client for disable his ghost
bool g_bGhost[MAXPLAYERS+1];

// Boolean for disable ghosts in general
bool g_bGhostsEnabled = true;

// Declare convar variables
ConVar g_cvGhostTime, g_cvGhostWarmup, g_cvGhostWarmupTime, g_cvGhostColor;
ConVar g_cvGhostAbsorb, g_cvGhostAbsorbHealth;

bool g_bGhostWarmup, g_bGhostColor;
float g_fGhostWarmupTime, g_fGhostTime;


bool g_bGhostAbsorb;
int g_iGhostAbsorbHealth;

public Plugin myinfo = {
	name = "SM CS:GO Ghost on Death",
	author = "Franc1sco franug",
	description = "",
	version = VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	
	g_cvGhostTime = CreateConVar("sm_ghost_time", "5", "Ghost appear time, 0.0 = Disappear in next round start.", 0, true);
	g_cvGhostWarmup = CreateConVar("sm_ghost_warmup", "0", "Ghost appear in warmup? 1 = yes, 0 = no", 0, true, 0.0, true, 1.0);
	g_cvGhostWarmupTime = CreateConVar("sm_ghost_warmup_time", "10.0", "Ghost appear time in warmup. 0.0 = Forever.", 0, true, 0.0, true, 1.0);
	g_cvGhostColor = CreateConVar("sm_ghost_team_color", "0", "Set ghost color depending on client team? 1 = yes, 0 = no, use random color.", 0, true, 0.0, true, 1.0);
	g_cvGhostAbsorb = CreateConVar("sm_ghost_absorb", "1", "People can absorb ghost? 1 = yes, 0 = no.", 0, true, 0.0, true, 1.0);
	g_cvGhostAbsorbHealth = CreateConVar("sm_ghost_absorb_health", "10", "How much health people gain for absorb a ghost");
	
	g_fGhostTime = GetConVarFloat(g_cvGhostTime);
	g_bGhostWarmup = GetConVarBool(g_cvGhostWarmup);
	g_fGhostWarmupTime = GetConVarFloat(g_cvGhostWarmupTime);
	g_bGhostColor = GetConVarBool(g_cvGhostColor);
	g_bGhostAbsorb = GetConVarBool(g_cvGhostAbsorb);
	g_iGhostAbsorbHealth = GetConVarInt(g_cvGhostAbsorbHealth);
	
	// Command for ROOT admins to disable ghosts in general
	RegAdminCmd("sm_ghosts", Command_ToggleForAll, ADMFLAG_ROOT);
	
	// Command for normal users to disable ghost on himself
	RegConsoleCmd("sm_ghost", Command_TogglePerClient);
	
	//Hook Death event where the ghost will appear
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	// Hook convar changes
	HookConVarChange(g_cvGhostTime, OnSettingChanged);
	HookConVarChange(g_cvGhostWarmup, OnSettingChanged);
	HookConVarChange(g_cvGhostWarmupTime, OnSettingChanged);
	HookConVarChange(g_cvGhostColor, OnSettingChanged);
	HookConVarChange(g_cvGhostAbsorb, OnSettingChanged);
	HookConVarChange(g_cvGhostAbsorbHealth, OnSettingChanged);
	
	// Enable ghost for clients on late load by default
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			g_bGhost[i] = true;		
}

public int OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvGhostTime)
	{
		g_fGhostTime = StringToFloat(newValue);
	}
	else if (convar == g_cvGhostWarmup)
	{
		g_bGhostWarmup = view_as<bool>(StringToInt(newValue));
	}
	else if (convar == g_cvGhostWarmupTime)
	{
		g_fGhostWarmupTime = StringToFloat(newValue);
	}
	else if (convar == g_cvGhostColor)
	{
		g_bGhostColor = view_as<bool>(StringToInt(newValue));
	}
	
	else if (convar == g_cvGhostAbsorb)
	{
		g_bGhostAbsorb = view_as<bool>(StringToInt(newValue));
	}
	else if (convar == g_cvGhostAbsorbHealth)
	{
		g_iGhostAbsorbHealth = StringToInt(newValue);
	}
}

public void OnMapStart()
{
	// Download materials/particles and prechache for prevent client crashes
	AddFileToDownloadsTable("particles/ghosts.pcf");
	
	AddFileToDownloadsTable("materials/effects/largesmoke.vmt");
	PrecacheModel("materials/effects/largesmoke.vmt");
	
	AddFileToDownloadsTable("materials/effects/largesmoke.vtf");
	AddFileToDownloadsTable("materials/effects/animatedeyes/animated_eyes.vmt");
	
	PrecacheModel("materials/effects/animatedeyes/animated_eyes.vmt");
	AddFileToDownloadsTable("materials/effects/animatedeyes/animated_eyes.vtf");
	
	AddFileToDownloadsTable("materials/effects/softglow_translucent_fog.vmt");
	PrecacheModel("materials/effects/softglow_translucent_fog.vmt");
	
	AddFileToDownloadsTable("materials/effects/outline_translucent.vtf");
	
	// Prechache the particle correcly for prevent client crashes
	PrecacheGeneric("particles/ghosts.pcf", true);
	PrecacheEffect("ParticleEffect");
	PrecacheParticleEffect("Ghost_Cyan");
	PrecacheParticleEffect("Ghost_Green");
	PrecacheParticleEffect("Ghost_Red");
	PrecacheParticleEffect("Ghost_Orange");
}

public Action Command_TogglePerClient(int iClient, int iArgs)
{

	g_bGhost[iClient] = !g_bGhost[iClient];
	
	PrintToChat(iClient, "[Ghosts] Your Ghost has been %s.", g_bGhost[iClient]?"enabled":"disabled");

	return Plugin_Handled;
}

public Action Command_ToggleForAll(int iClient, int iArgs)
{

	g_bGhostsEnabled = !g_bGhostsEnabled;
	
	PrintToChat(iClient, "[Ghosts] Ghosts %s for everyone.", g_bGhostsEnabled?"enabled":"disabled");
	
	return Plugin_Handled;
}

public void OnClientPutInServer(int iClient)
{

	g_bGhost[iClient] = true;
}

public Action Event_PlayerDeath(Handle hEvent, char[] sName, bool bDontBroadcast)
{
	//int entity;
	if (!g_bGhostsEnabled) return;
	
	bool bWarmup = GameRules_GetProp("m_bWarmupPeriod") == 1; 
	
	if (bWarmup && !g_bGhostWarmup)return;
	

	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	

	if (!g_bGhost[iClient])return;
	
	float fPos[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fPos); 


	fPos[2] += -50.0;
			

	char sGhostColor[32];
	Format(sGhostColor, sizeof(sGhostColor), "%s", GetClientTeam(iClient) == 2 ? "Ghost_Red":"Ghost_Cyan");


	int iGhost = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iGhost, "start_active", "0");
	
	if(g_bGhostColor)
		DispatchKeyValue(iGhost, "effect_name", sGhostColor); 
	else {
		switch(GetRandomInt(1, 4))
		{
			case 1:
			{
				DispatchKeyValue(iGhost, "effect_name", "Ghost_Cyan");
			}
			case 2:
			{
				DispatchKeyValue(iGhost, "effect_name", "Ghost_Green");
			}
			case 3:
			{
				DispatchKeyValue(iGhost, "effect_name", "Ghost_Red");
			}
			case 4:
			{
				DispatchKeyValue(iGhost, "effect_name", "Ghost_Orange");
			}
		}
	}
	
	DispatchSpawn(iGhost);

	TeleportEntity(iGhost, fPos, NULL_VECTOR, NULL_VECTOR); 

	ActivateEntity(iGhost);
	AcceptEntityInput(iGhost, "Start");
	
	SetEntPropEnt(iGhost, Prop_Send, "m_hOwnerEntity", iClient);
	
	//if(g_bGhostAbsorb) SDKHook(iGhost, SDKHook_TouchPost, SDKHookCB_Touch);
	SDKHook(iGhost, SDKHook_TouchPost, StartTouchPost);
	//SDKHook(entity, SDKHook_TouchPost, StartTouchPost);
	
	if(!bWarmup){
		if(g_fGhostTime > 0.0)
			CreateTimer(g_fGhostTime, Timer_KillGhost, EntIndexToEntRef(iGhost));
	}
	else if(g_fGhostWarmupTime > 0.0)
		CreateTimer(g_fGhostWarmupTime, Timer_KillGhost,EntIndexToEntRef(iGhost));
}

public Action Timer_KillGhost(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	
	if(iEntity == INVALID_ENT_REFERENCE || !IsValidEntity(iEntity))	return;
		
	AcceptEntityInput(iEntity, "DestroyImmediately");
	CreateTimer(0.1, Timer_KillGhostParticle, iRef); 
}

public Action Timer_KillGhostParticle(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	
	if(iEntity == INVALID_ENT_REFERENCE || !IsValidEntity(iEntity))	return;
	
	AcceptEntityInput(iEntity, "kill");
}

public Action StartTouchPost(int entity, int other) // oh, you touch my tralala, mmm... my ding ding dong
{
	switch(GetRandomInt(1, 4))
	{
		case 1:
		{
			GivePlayerItem(entity, "weapon_taser");
			AcceptEntityInput(entity, "kill");
			AcceptEntityInput(entity, "DestroyImmediately");
			SDKUnhook(entity, SDKHook_TouchPost, StartTouchPost);
			PrintToChat(other, "teste funcoes %N teste vida %s .");
		}
		case 2:
		{
			GivePlayerItem(entity, "weapon_tagrenade");
			AcceptEntityInput(entity, "kill");
			AcceptEntityInput(entity, "DestroyImmediately");
			SDKUnhook(entity, SDKHook_TouchPost, StartTouchPost);
			PrintToChat(other, "teste funcoes %N teste vida %s .");
		}
		case 3:
		{
			SetEntProp(entity, Prop_Send, "m_ArmorValue", 100);
			SetEntProp(entity, Prop_Send, "m_bHasHelmet", 1);
			AcceptEntityInput(entity, "kill");
			AcceptEntityInput(entity, "DestroyImmediately");
			SDKUnhook(entity, SDKHook_TouchPost, StartTouchPost);
			PrintToChat(other, "teste funcoes %N teste vida %s .");
		}
		case 4:
		{
			GivePlayerItem(entity, "weapon_healthshot");
			AcceptEntityInput(entity, "kill");
			AcceptEntityInput(entity, "DestroyImmediately");
			SDKUnhook(entity, SDKHook_TouchPost, StartTouchPost);
			PrintToChat(other, "teste funcoes %N teste vida %s .");
		}
		}
	}
	
	//PrintToChat(entity, "teste funcoes %N teste vida %s .",GetEntPropEnt(client, Prop_Send, "m_hOwnerEntity"), g_iGhostAbsorbHealth);
//}
		
/*public void SDKHookCB_Touch(int ghost, int client)
{
	if (client < 1 || client > MaxClients) return;
	
	//SDKUnhook(ghost, SDKHook_TouchPost, SDKHookCB_Touch);
	
	CreateTimer(0.0, Timer_KillGhost, EntIndexToEntRef(ghost));
	
	SetEntityHealth(client, GetClientHealth(client) + g_iGhostAbsorbHealth);
	
	switch(GetRandomInt(1, 4))
	{
		case 1:
		{
			GivePlayerItem(client, "weapon_taser");
		}
		case 2:
		{
			GivePlayerItem(client, "weapon_tagrenade");
		}
		case 3:
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
		}
		case 4:
		{
			GivePlayerItem(client, "weapon_healthshot");
		}
	}
	
	PrintToChat(client, "teste funcoes %N teste vida %s .",GetEntPropEnt(client, Prop_Send, "m_hOwnerEntity"), g_iGhostAbsorbHealth);
}*/

stock void PrecacheEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    
    if (table == INVALID_STRING_TABLE)
    {
        table = FindStringTable("EffectDispatch");
    }
    bool save = LockStringTables(false);
    AddToStringTable(table, sEffectName);
    LockStringTables(save);
}

stock void PrecacheParticleEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    
    if (table == INVALID_STRING_TABLE)
    {
        table = FindStringTable("ParticleEffectNames");
    }
    bool save = LockStringTables(false);
    AddToStringTable(table, sEffectName);
    LockStringTables(save);
}  

