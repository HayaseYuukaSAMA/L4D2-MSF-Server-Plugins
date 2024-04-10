/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.
	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define NUM_OF_SURVS 4

new incap_count[NUM_OF_SURVS];
new preheal_temp[NUM_OF_SURVS];
new preheal_perm[NUM_OF_SURVS];

new Handle:sdkRevive;

new Handle:hEnabled;
new Handle:hAmount;
new Handle:hIncap;
new Handle:hOver;
new bool:bEnabled;

public Plugin:myinfo =
{
	name = "Solid Health Medkits",
	author = "Air",
	description = "A plugin that replaced health gained by medkits with solid health",
	version = "0.1",
	url = "https://github.com/A1oneR/AirMod"
}

public OnPluginStart()
{
	hEnabled = CreateConVar("l4d2_solidhealthmedkits_enable", "1", "Enable temp health medkits");
	hAmount = CreateConVar("l4d2_solidhealthmedkits_amount", "50", "Solid health recover");
	hIncap = CreateConVar("l4d2_solidhealthmedkits_incap", "1", "Recover from incap states");
	hOver = CreateConVar("l4d2_solidhealthmedkits_over", "0", "Over 100 HP will be like(0 = None,1 = Perm,2 = Temp)");
	HookConVarChange(hEnabled, Enabled_Change);
	
	bEnabled = GetConVarBool(hEnabled);
	
	HookEvent("heal_success",	HealSuccess_Event);
	HookEvent("heal_end",		HealEnd_Event);
	
	new Handle:config = LoadGameConfigFile("left4dhooks.l4d2");
	if(config == INVALID_HANDLE)
	{
		SetFailState("Unable to find the gamedata file, check that it is installed correctly!");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTerrorPlayer::OnRevived");
	sdkRevive = EndPrepSDKCall();
	if(sdkRevive == INVALID_HANDLE)
	{
		SetFailState("Unable to find the \"CTerrorPlayer::OnRevived(void)\" signature, check the file version!");
	}
	CloseHandle(config);
}

public Enabled_Change(Handle:c, const String:n[], const String:o[]) bEnabled = GetConVarBool(hEnabled);

public HealEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bEnabled) return;
	
	new iSurvCount = 0;
	decl character;
	for (new client = 1; client <= MaxClients && iSurvCount < 4; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			character = GetSurvivorCharacter(client);
			
			preheal_temp[character] = GetSurvivorTempHealth(client);
			preheal_perm[character] = GetSurvivorPermanentHealth(client);
			incap_count[character] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
			
			iSurvCount++;
		}
	}
}

public HealSuccess_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bEnabled) return;
	
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	new character = GetSurvivorCharacter(client);
	new max_health = GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);
	new preheal_total = preheal_perm[character] + preheal_temp[character];
	new HealAmount = GetConVarInt(hAmount);
	
	new new_perm = preheal_perm[character] + HealAmount;
	new tempp = 0;
	if (new_perm >= 100) 
	{
		if (GetConVarInt(hOver) == 2)
		{
			tempp = new_perm - 100;
			new_perm = 100;
		}
		else if (GetConVarInt(hOver) == 0)
		{
			new_perm = 100;
		}
	}
	
	if (incap_count[character] == GetConVarInt(FindConVar("survivor_max_incapacitated_count")) && !GetConVarBool(hIncap))
	{
		SetBlackAndWhite(client, preheal_perm[character], new_perm);
	}
	else
	{
		if (GetConVarBool(hIncap))
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", incap_count[character]);
		}
		SetEntProp(client, Prop_Send, "m_iHealth", new_perm);
		//PrintToChat(client, "New Perm Should Be %i", new_perm);
		//PrintToChat(client, "HealAmount Should Be %i", HealAmount);
		new now_temp = GetSurvivorTempHealth(client);
		if (now_temp == 0 && preheal_temp[character] != 0)
		{
			SetSurvivorTempHealth(client, preheal_temp[character]);
		}
		if (new_perm + preheal_temp[character] > 100)
		{
			SetSurvivorTempHealth(client, 100 - new_perm + tempp);
		}
	}
}




stock GetSurvivorPermanentHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock GetSurvivorCharacter(client)
{
	return GetEntProp(client, Prop_Send, "m_survivorCharacter");
}

stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return temphp > 0 ? temphp : 0;
}

stock SetSurvivorTempHealth(client, hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	new Float:newOverheal = hp * 1.0;
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

stock SetBlackAndWhite(target, health, temp_health)
{
	if(target > 0 && IsValidEntity(target) && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) == 2)
	{
		SetEntProp(target, Prop_Send, "m_currentReviveCount", GetConVarInt(FindConVar("survivor_max_incapacitated_count"))-1);
		SetEntProp(target, Prop_Send, "m_isIncapacitated", 1);
		SDKCall(sdkRevive, target);
		SetEntityHealth(target, health);
		SetSurvivorTempHealth(target, temp_health);
	}
}