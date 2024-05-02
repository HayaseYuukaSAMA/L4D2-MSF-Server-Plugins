#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo =
{
    name = "控制大厅",
    author = "早濑优香",
    description = "从Anne插件包里cv下来的控制大厅功能,去除其他东西",
    version = "1.0",
    url = "https://github.com/HayaseYuukaSAMA/L4D2-MSF-Server-Plugins"
};

ConVar
	hCvarLobbyControl,
	hCvarSvAllowLobbyCo,
	hCvarEnableAutoRemoveLobby,
	hCvarGamemode,
	hCvarSteamgroupExclusive;

public void OnPluginStart()
{
    hCvarEnableAutoRemoveLobby = CreateConVar("join_enable_autoremovelobby", "1", "大厅满了是否自动删除大厅", _, true, 0.0, true, 1.0);
	hCvarLobbyControl = CreateConVar("join_enable_autolobbycontrol", "1", "是否开启自动大厅控制,战役模式开启好友大厅,对抗模式开启公共大厅(server.cfg中删去sv_steamgroup_exclusive)", _, true, 0.0, true, 1.0);
	hCvarSvAllowLobbyCo = FindConVar("sv_allow_lobby_connect_only");
	hCvarSteamgroupExclusive = FindConVar("sv_steamgroup_exclusive");
	hCvarGamemode = FindConVar("mp_gamemode");
	hCvarGamemode.AddChangeHook(GamemodeChange);
	hCvarLobbyControl.AddChangeHook(GamemodeChange);
	ChangeLobby();
}

public void GamemodeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ChangeLobby();
}
void ChangeLobby()
{
	if(hCvarLobbyControl.BoolValue)
	{
		char g_sCurrentGameMode[64];
		GetConVarString(hCvarGamemode, g_sCurrentGameMode, sizeof(g_sCurrentGameMode));
		if(StrContains(g_sCurrentGameMode, "versus", false) != -1)
		{
			SetConVarInt(hCvarSteamgroupExclusive, 0);
		}
		else
		{
			SetConVarInt(hCvarSteamgroupExclusive, 1);
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(IsServerLobbyFull() && hCvarEnableAutoRemoveLobby.IntValue)
	{
		if(L4D_LobbyIsReserved())
			L4D_LobbyUnreserve();
		SetAllowLobby(0);
	}

}

bool IsServerLobbyFull() {
	return GetConnectedPlayer() >= numSlots();
}

int numSlots() {
	return LoadFromAddress(L4D_GetPointer(POINTER_SERVER) + view_as<Address>(L4D_GetServerOS() ? 380 : 384), NumberType_Int32);
}

int GetConnectedPlayer() {
	int count = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}

void SetAllowLobby(int value) {
	hCvarSvAllowLobbyCo.IntValue = value;
}