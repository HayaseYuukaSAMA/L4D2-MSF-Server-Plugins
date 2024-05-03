#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <builtinvotes>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>

#define TEAM_SPECTATE		1
#define MATCHMODES_PATH		"configs/matchmodes.txt"

Handle
	g_hVote = null;

KeyValues
	g_hModesKV = null;

ConVar
	g_hEnabled = null,
	g_hCvarPlayerLimit = null,
	g_hMaxPlayers = null,
	g_hSvMaxPlayers = null;

char
	g_sCfg[32];

bool
	g_bIsConfoglAvailable = false,
	g_bOnSet = false,
	g_bCedaGame = false;

public Plugin myinfo =
{
	name = "Match Vote",
	author = "vintik, Sir, StarterX4",
	description = "!match !rmatch !chmatch - Change Hostname and Slots while you're at it!",
	version = "1.3",
	url = "https://github.com/L4D-Community/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	EngineVersion iEngine = GetEngineVersion();
	if (iEngine != Engine_Left4Dead2) {
		strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	char sBuffer[PLATFORM_MAX_PATH ];
	g_hModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);

	if (!g_hModesKV.ImportFromFile(sBuffer)) {
		SetFailState("Couldn't load matchmodes.txt!");
	}

	g_hEnabled = CreateConVar("sm_match_vote_enabled", "1", "Plugin enabled", _, true, 0.0, true, 1.0);
	g_hMaxPlayers = CreateConVar("mv_maxplayers", "30", "How many slots would you like the Server to be at Config Load/Unload?", _, true, 1.0, true, 32.0);
	g_hCvarPlayerLimit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", _, true, 1.0, true, 32.0);

	RegConsoleCmd("sm_match", MatchRequest);
	RegConsoleCmd("sm_chmatch", ChangeMatchRequest);
	RegConsoleCmd("sm_rmatch", MatchReset);

	g_hSvMaxPlayers = FindConVar("sv_maxplayers");
	g_bIsConfoglAvailable = LibraryExists("confogl");
}

public void OnConfigsExecuted()
{
	if (!g_bOnSet) {
		g_hSvMaxPlayers.SetInt(g_hMaxPlayers.IntValue);
		g_bOnSet = true;
	}
}

public void OnPluginEnd()
{
	g_hSvMaxPlayers.SetInt(g_hMaxPlayers.IntValue);
}

public void OnLibraryRemoved(const char[] sPluginName)
{
	if (strcmp(sPluginName, "confogl") == 0) {
		g_bIsConfoglAvailable = false;
	}
}

public void OnLibraryAdded(const char[] sPluginName)
{
	if (strcmp(sPluginName, "confogl") == 0) {
		g_bIsConfoglAvailable = true;
	}
}

public void OnCedapugStarted() {
	g_bCedaGame = true;
}

public void OnCedapugEnded() {
	g_bCedaGame = false;
}

public Action MatchRequest(int iClient, int iArgs)
{
	if (!g_hEnabled.BoolValue || iClient == 0 || !g_bIsConfoglAvailable) {
		return Plugin_Handled;
	}

	if (iArgs > 0) {
		//config specified
		char sCfg[64], sName[64];
		GetCmdArg(1, sCfg, sizeof(sCfg));

		if (FindConfigName(sCfg, sName, sizeof(sName))) {
			if (StartMatchVote(iClient, sName)) {
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);

				//caller is voting for
				FakeClientCommand(iClient, "Vote Yes"); 
			}

			return Plugin_Handled;
		}
	}

	//show main menu
	MatchModeMenu(iClient);
	return Plugin_Handled;
}

bool FindConfigName(const char[] sConfig, char[] sName, const int iMaxLength)
{
	g_hModesKV.Rewind();

	if (g_hModesKV.GotoFirstSubKey()) {
		do {
			if (g_hModesKV.JumpToKey(sConfig)) {
				g_hModesKV.GetString("name", sName, iMaxLength);
				return true;
			}
		} while (g_hModesKV.GotoNextKey(false));
	}

	return false;
}

void MatchModeMenu(int iClient)
{
	Menu hMenu = new Menu(MatchModeMenuHandler);
	hMenu.SetTitle("选择要玩的模式:");

	char sBuffer[64];
	g_hModesKV.Rewind();

	if (g_hModesKV.GotoFirstSubKey()) {
		do {
			g_hModesKV.GetSectionName(sBuffer, sizeof(sBuffer));
			hMenu.AddItem(sBuffer, sBuffer);
		} while (g_hModesKV.GotoNextKey(false));
	}

	hMenu.Display(iClient, 20);
}

public int MatchModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		g_hModesKV.Rewind();

		if (g_hModesKV.JumpToKey(sInfo) && g_hModesKV.GotoFirstSubKey()) {
			Menu hMenu = new Menu(ConfigsMenuHandler);

			FormatEx(sBuffer, sizeof(sBuffer), "选择 %s 配置:", sInfo);
			hMenu.SetTitle(sBuffer);

			do {
				g_hModesKV.GetSectionName(sInfo, sizeof(sInfo));
				g_hModesKV.GetString("name", sBuffer, sizeof(sBuffer));

				hMenu.AddItem(sInfo, sBuffer);
			} while (g_hModesKV.GotoNextKey());

			hMenu.Display(param1, 20);
		} else {
			CPrintToChat(param1, "{blue}[{default}Match{blue}] {default}没有找到这个模式.");
			MatchModeMenu(param1);
		}
	}

	return 0;
}

public int ConfigsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		MatchModeMenu(param1);
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));

		if (StartMatchVote(param1, sBuffer)) {
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		} else {
			MatchModeMenu(param1);
		}
	}

	return 0;
}

bool StartMatchVote(int iClient, const char[] sCfgName)
{
	if (GetClientTeam(iClient) <= TEAM_SPECTATE) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}旁观者不允许投票更改游戏模式.");
		return false;
	}

	if (LGO_IsMatchModeLoaded()) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}模式已经加载，请先使用!rmatch卸载配置");
		return false;
	}

	if (!IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0;
		int[] iPlayers = new int[MaxClients];

		//list of non-spectators players
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= TEAM_SPECTATE) {
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		if (iNumPlayers < g_hCvarPlayerLimit.IntValue) {
			CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}没有足够多的玩家来发起模式更改投票");
			return false;
		}

		char sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "加载 confogl '%s' 模式?", sCfgName);

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, MatchVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}模式更改投票暂不可用.");
	return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			delete vote;
			g_hVote = null;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void MatchVoteResultHandler(Handle vote, int num_votes, int num_clients, \
										const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "模式加载");
				//PrintToConsoleAll("%s", g_sCfg);
				for(int j = 0; j < strlen(g_sCfg); j++){
					g_sCfg[j] = CharToLower(g_sCfg[j]);
				}
				//PrintToConsoleAll("%s", g_sCfg);
				ServerCommand("sm_forcematch %s", g_sCfg);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action MatchReset(int iClient, int iArgs)
{
	if (!g_hEnabled.BoolValue || iClient == 0 || !g_bIsConfoglAvailable) {
		return Plugin_Handled;
	}

	if (g_bCedaGame) {
		return Plugin_Handled;
	}

	//voting for resetmatch
	StartResetMatchVote(iClient);
	return Plugin_Handled;
}

bool StartResetMatchVote(int iClient)
{
	if (GetClientTeam(iClient) <= TEAM_SPECTATE) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}旁观者不允许投票重赛.");
		return false;
	}

	if (!LGO_IsMatchModeLoaded()) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}当前无比赛模式加载.");
		return false;
	}

	if (IsNewBuiltinVoteAllowed()) {
		int iNumPlayers = 0, iConnectedCount = 0;
		int[] iPlayers = new int[MaxClients];

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i)) {
				if (IsClientConnected(i)) {
					iConnectedCount++;
				}
			} else {
				if (!IsFakeClient(i) && GetClientTeam(i) > TEAM_SPECTATE) {
					iPlayers[iNumPlayers++] = i;
				}
			}
		}

		if (iConnectedCount > 0) {
			CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}重赛投票暂不可用，有玩家正在连接");
			return false;
		}

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, "卸载配置文件?");
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, ResetMatchVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);

		FakeClientCommand(iClient, "Vote Yes");
		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}重赛投票暂不可用.");
	return false;
}

public void ResetMatchVoteResultHandler(Handle vote, int num_votes, int num_clients, \
										const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "Confogl is unloading...");
				ServerCommand("sm_resetmatch");

				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action ChangeMatchRequest(int iClient, int iArgs)
{
	if (!g_hEnabled.BoolValue || iClient == 0 || !g_bIsConfoglAvailable) {
		return Plugin_Handled;
	}

	if (iArgs > 0) {
		//config specified
		char sCfg[64], sName[64];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		if (FindConfigName(sCfg, sName, sizeof(sName))) {
			if (StartChMatchVote(iClient, sName)) {
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);

				//caller is voting for
				FakeClientCommand(iClient, "Vote Yes");
			}
			return Plugin_Handled;
		}
	}

	//show main menu
	ChMatchModeMenu(iClient);
	return Plugin_Handled;
}

void ChMatchModeMenu(int iClient)
{
	Menu hMenu = new Menu(ChMatchModeMenuHandler);
	hMenu.SetTitle("Select match mode:");

	char sBuffer[64];
	g_hModesKV.Rewind();

	if (g_hModesKV.GotoFirstSubKey()) {
		do {
			g_hModesKV.GetSectionName(sBuffer, sizeof(sBuffer));
			hMenu.AddItem(sBuffer, sBuffer);
		} while (g_hModesKV.GotoNextKey(false));
	}

	hMenu.Display(iClient, 20);
}

public int ChMatchModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		g_hModesKV.Rewind();

		if (g_hModesKV.JumpToKey(sInfo) && g_hModesKV.GotoFirstSubKey()) {
			Menu hMenu = new Menu(ChConfigsMenuHandler);

			FormatEx(sBuffer, sizeof(sBuffer), "Select %s config:", sInfo);
			hMenu.SetTitle(sBuffer);

			do {
				g_hModesKV.GetSectionName(sInfo, sizeof(sInfo));
				g_hModesKV.GetString("name", sBuffer, sizeof(sBuffer));

				hMenu.AddItem(sInfo, sBuffer);
			} while (g_hModesKV.GotoNextKey());

			hMenu.Display(param1, 20);
		} else {
			CPrintToChat(param1, "{blue}[{default}Match{blue}] {default}没有找到这个模式配置.");
			ChMatchModeMenu(param1);
		}
	}

	return 0;
}

public int ChConfigsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		ChMatchModeMenu(param1);
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));

		if (StartChMatchVote(param1, sBuffer)) {
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		} else {
			ChMatchModeMenu(param1);
		}
	}

	return 0;
}

bool StartChMatchVote(int iClient, const char[] sCfgName)
{
	if (GetClientTeam(iClient) <= TEAM_SPECTATE) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}旁观者不允许发起重赛投票.");
		return false;
	}

	if (!LGO_IsMatchModeLoaded()) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}比赛模式还没有载入，请使用!match载入比赛配置!");
		return false;
	}

	if (IsNewBuiltinVoteAllowed() || !IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0, iConnectedCount = 0;
		int[] iPlayers = new int[MaxClients];

		//list of non-spectators players
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= TEAM_SPECTATE) {
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		if (iNumPlayers < g_hCvarPlayerLimit.IntValue) {
			CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}比赛投票暂时没办法进行，因为没有足够的玩家.");
			return false;
		}

		if (iConnectedCount > 0) {
			CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}修改比赛配置投票暂时不能进行，因为还有玩家正在载入中.");
			return false;
		}

		char sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "将比赛配置更改为 '%s'?", sCfgName);

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, ChMatchVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}比赛投票暂时不能使用.");
	return false;
}

public void ChMatchVoteResultHandler(Handle vote, int num_votes, int num_clients, \
										const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "Matchmode Changed");
				for(int j = 0; j < strlen(g_sCfg); j++){
					g_sCfg[j] = CharToLower(g_sCfg[j]);
				}
				ServerCommand("sm_forcechangematch %s", g_sCfg);

				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}