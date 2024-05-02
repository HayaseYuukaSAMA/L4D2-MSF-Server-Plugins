#include <sourcemod>

public Plugin myinfo =
{
    name = "管理员重置地图",
    author = "早濑优香",
    description = "从Anne插件包里cv下来的重置地图,去除其他东西",
    version = "1.0",
    url = "https://github.com/HayaseYuukaSAMA/L4D2-MSF-Server-Plugins"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "restarts map");
}

public Action RestartMap(int client,int args)
{
	CrashMap();
	return Plugin_Handled;
}

void CrashMap()
{
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
}