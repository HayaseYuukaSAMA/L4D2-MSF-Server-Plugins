#if defined _readyup_panel_included
 #endinput
#endif
#define _readyup_panel_included

static Footer
	cmdFooter;
	
static int
	curCmd;

static const char 
	hintPhrase[2][] = {"HintUnready", "HintReady"},
	readySymbol[2][] = {"☐", "☑"},
	teamReadySymbol[2][] = {" [X]", " [√]"};

void InitPanel()
{
	if (cmdFooter == null)
	{
		cmdFooter = new Footer();
		cmdFooter.Add("->1. !slots 12 (更改人数)");
		cmdFooter.Add("->2. !chmatch (更换插件)");
		cmdFooter.Add("->3. !return (准备阶段回安全屋)");
		cmdFooter.Add("->4. !mix (分队选人)");
		cmdFooter.Add("->5. !mixmap (随机地图)");
		cmdFooter.Add("->6. !tank (查看坦克路程)");
		cmdFooter.Add("->7. !mixmap fo/so (随机一代/二代地图)");
		cmdFooter.Add("->8. !health (分数)");
		cmdFooter.Add("->9. !voteboss <Tank> <Witch> (设置BOSS路程)");
	}
	
	curCmd = 0;
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(4.0, MenuCmd_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { return 1; }

Action MenuRefresh_Timer(Handle timer)
{
	if (inReadyUp)
	{
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

Action MenuCmd_Timer(Handle timer)
{
	if (inReadyUp)
	{
		if (cmdFooter.Length)
		{
			curCmd = (curCmd + 1) % cmdFooter.Length;
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void UpdatePanel()
{
	char survivorBuffer[400] = "";
	char infectedBuffer[400] = "";
	char casterBuffer[300] = "";
	char specBuffer[200] = "";
	int playerCount = 0;
	int casterCount = 0;
	int specCount = 0;

	Panel menuPanel = new Panel();

	char ServerBuffer[128];
	char ServerName[32];
	char cfgName[32];

	int iPassTime = RoundToFloor(GetGameTime() - fStartTimestamp);
	
	bool isTeamReadyMode = readyUpMode == ReadyMode_TeamReady;
	int survivorReady = IsTeamReady(L4D2Team_Survivor);
	int infectedReady = IsTeamReady(L4D2Team_Infected);

	g_cvServerNamer.GetString(ServerName, sizeof(ServerName));
	
	l4d_ready_cfg_name.GetString(cfgName, sizeof(cfgName));
	Format(ServerBuffer, sizeof(ServerBuffer), "▸ 服务器: %s \n▸ 人数: %d/%d\n▸ 比赛插件: %s", ServerName, GetSeriousClientCount(), FindConVar("sv_maxplayers").IntValue, cfgName);
	menuPanel.DrawText(ServerBuffer);
	
	FormatTime(ServerBuffer, sizeof(ServerBuffer), "▸ %m/%d/%Y - %I:%M%p");
	Format(ServerBuffer, sizeof(ServerBuffer), "%s (%02d:%02d)", ServerBuffer, iPassTime / 60, iPassTime % 60);
	menuPanel.DrawText(ServerBuffer);
	
	menuPanel.DrawText(" ");
	menuPanel.DrawText("▸ 可用指令:");
	menuPanel.DrawText(FooterGet(cmdFooter, curCmd));
	menuPanel.DrawText(" ");
	
	char nameBuf[64];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			++playerCount;
			GetClientFixedName(client, nameBuf, sizeof(nameBuf));
			
			if (IsPlayer(client))
			{
				bool type = (GetClientTeam(client) == L4D2Team_Survivor);
				int isReady = view_as<int>(IsPlayerReady(client));
				
				switch (readyUpMode)
				{
					case ReadyMode_PlayerReady:
					{
						if (!inLiveCountdown) PrintHintText(client, "%t", hintPhrase[isReady]);
						Format(nameBuf, sizeof(nameBuf), "%s %s%s\n", readySymbol[isReady], nameBuf, IsPlayerAfk(client) ? " [挂机]" : "");
					}
					case ReadyMode_AutoStart:
					{
						Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
					}
					case ReadyMode_TeamReady:
					{
						if (!inLiveCountdown) PrintHintText(client, "%t", hintPhrase[type ? survivorReady : infectedReady]);
						Format(nameBuf, sizeof(nameBuf), "%s%s\n", nameBuf, IsPlayerAfk(client) ? " [挂机]" : "");
					}
				}
				type ? StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf) : StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
			}
			else
			{
				++specCount;
				if (casterSystemAvailable && IsClientCaster(client))
				{
					++casterCount;
					Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
					StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
				}
				else
				{
					if (playerCount <= l4d_ready_max_players.IntValue)
					{
						Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
						StrCat(specBuffer, sizeof(specBuffer), nameBuf);
					}
				}
			}
		}
	}
	
	int textCount = 0;
	int bufLen = strlen(survivorBuffer);
	if (bufLen != 0)
	{
		survivorBuffer[bufLen] = '\0';
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->%d. 生还%s", ++textCount, isTeamReadyMode ? teamReadySymbol[survivorReady] : "");
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(survivorBuffer);
	}

	bufLen = strlen(infectedBuffer);
	if (bufLen != 0)
	{
		infectedBuffer[bufLen] = '\0';
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->%d. 特感%s", ++textCount, isTeamReadyMode ? teamReadySymbol[infectedReady] : "");
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(infectedBuffer);
	}
	
	if (specCount && textCount) menuPanel.DrawText(" ");

	if (casterSystemAvailable)
	{
		bufLen = strlen(casterBuffer);
		if (bufLen != 0)
		{
			casterBuffer[bufLen] = '\0';
			Format(nameBuf, sizeof(nameBuf), "->%d. 解说%s", ++textCount, casterCount > 1 ? "s" : "");
			menuPanel.DrawText(nameBuf);
			ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_", true);
			menuPanel.DrawText(casterBuffer);
		}
	}
	
	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "->%d. 旁观%s", ++textCount, specCount > 1 ? "" : "");
		menuPanel.DrawText(nameBuf);
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (playerCount > l4d_ready_max_players.IntValue && specCount - casterCount > 1)
			FormatEx(specBuffer, sizeof(specBuffer), "**吃瓜群众** (%d)", specCount - casterCount);
		menuPanel.DrawText(specBuffer);
	}

	if (nativeFooter.Length)
	{
		menuPanel.DrawText(" ");
		for (int i = 0; i < nativeFooter.Length; i++)
		{
			menuPanel.DrawText(FooterGet(nativeFooter, i));
		}
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsPlayerHiddenPanel(client)) 
		{
			if (BuiltinVote_IsVoteInProgress() && IsClientInBuiltinVotePool(client))
			{
				continue;
			}
			
			if (Game_IsVoteInProgress())
			{
				int voteteam = Game_GetVoteTeam();
				if (voteteam == -1 || voteteam == GetClientTeam(client))
				{
					continue;
				}
			}
			
			switch (GetClientMenu(client))
			{
				case MenuSource_External, MenuSource_Normal: continue;
			}
			
			menuPanel.Send(client, DummyHandler, 1);
		}
	}
	
	delete menuPanel;
}