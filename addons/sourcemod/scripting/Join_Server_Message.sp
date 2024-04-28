
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

public Plugin myinfo =
{
    name = "玩家连接服务器时的信息提示",
    author = "早濑优香",
    description = "从Anne插件包里cv下来的连接提示,去除其他东西",
    version = "1.0",
    url = "https://github.com/HayaseYuukaSAMA/L4D2-MSF-Server-Plugins"
}

public void OnPluginStart()
{
    HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);
}

public void OnClientConnected(int client)
{
	if(!IsFakeClient(client))
	{
		PrintToChatAll("\x03 %N \x05正在进入牢房",client);
	}
}

public Action PlayerDisconnect_Event(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event,"userid"));

    if (!(1 <= client <= MaxClients))
        return Plugin_Handled;

    if (!IsClientInGame(client))
        return Plugin_Handled;

    if (IsFakeClient(client))
        return Plugin_Handled;

    char reason[64], message[64];
    GetEventString(event, "reason", reason, sizeof(reason));

    if(StrContains(reason, "connection rejected", false) != -1)
    {
        Format(message,sizeof(message),"连接被拒绝");
    }
    else if(StrContains(reason, "timed out", false) != -1)
    {
        Format(message,sizeof(message),"超时");
    }
    else if(StrContains(reason, "by console", false) != -1)
    {
        Format(message,sizeof(message),"服务器踢出");
    }
    else if(StrContains(reason, "by user", false) != -1)
    {
        Format(message,sizeof(message),"自己选择跑路");
    }
    else if(StrContains(reason, "ping is too high", false) != -1)
    {
        Format(message,sizeof(message),"ping 太高了");
    }
    else if(StrContains(reason, "No Steam logon", false) != -1)
    {
        Format(message,sizeof(message),"steam验证失败");
    }
    else if(StrContains(reason, "Steam account is being used in another", false) != -1)
    {
        Format(message,sizeof(message),"steam账号被顶");
    }
    else if(StrContains(reason, "Steam Connection lost", false) != -1)
    {
        Format(message,sizeof(message),"steam断线");
    }
    else if(StrContains(reason, "This Steam account does not own this game", false) != -1)
    {
        Format(message,sizeof(message),"没有这款游戏");
    }
    else if(StrContains(reason, "Validation Rejected", false) != -1)
    {
        Format(message,sizeof(message),"验证失败");
    }
    else if(StrContains(reason, "Certificate Length", false) != -1)
    {
        Format(message,sizeof(message),"certificate length");
    }
    else if(StrContains(reason, "Pure server", false) != -1)
    {
        Format(message,sizeof(message),"纯净服务器");
    }
    else
    {
        message = reason;
    }

    CPrintToChatAll("{blue}%N {green}离开了游戏 - 理由: [{blue}%s{green}]", client, message);
    return Plugin_Handled;
} 