#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "R3TROATTACK"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>

#pragma newdecls required

int g_BanTargetUserId[MAXPLAYERS + 1] =  { -1, ... };

public Plugin myinfo = 
{
	name = "Informative Disconnect Reason",
	author = PLUGIN_AUTHOR,
	description = "Makes a useful disconnect menu",
	version = PLUGIN_VERSION,
	url = "www.memerland.com"
};

char g_sName[128];
ConVar g_cName;

public void OnPluginStart()
{
	g_cName = CreateConVar("sm_server_name", "Memerland", "Name of your server/community");
	g_cName.AddChangeHook(NameChanged);
	AutoExecConfig();
	LoadTranslations("common.phrases");
	LoadTranslations("plugin.basecommands");
	AddCommandListener(Listener_Kick, "sm_kick");
	AddCommandListener(Listener_Ban, "sm_ban");
}

public void OnConfigsExecuted()
{
	g_cName.GetString(g_sName, sizeof(g_sName));
}

public void NameChanged(ConVar convar, const char[] newVal, const char[] oldVal)
{
	OnConfigsExecuted();
}

public Action Listener_Kick(int client, const char[] cmd, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_kick <#userid|name> [reason]");
		return Plugin_Handled;
	}

	char Arguments[256];
	GetCmdArgString(Arguments, sizeof(Arguments));

	char arg[65];
	int len = BreakString(Arguments, arg, sizeof(arg));
	
	if (len == -1)
	{
		/* Safely null terminate */
		len = 0;
		Arguments[0] = '\0';
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		char reason[64];
		Format(reason, sizeof(reason), Arguments[len]);

		if (tn_is_ml)
		{
			if (reason[0] == '\0')
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target", target_name);
			}
			else
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target reason", target_name, reason);
			}
		}
		else
		{
			if (reason[0] == '\0')
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target", "_s", target_name);            
			}
			else
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target reason", "_s", target_name, reason);
			}
		}
		
		int kick_self = 0;
		
		for (int i = 0; i < target_count; i++)
		{
			/* Kick everyone else first */
			if (target_list[i] == client)
			{
				kick_self = client;
			}
			else
			{
				PerformKick(client, target_list[i], reason);
			}
		}
		
		if (kick_self)
		{
			PerformKick(client, client, reason);
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}

	return Plugin_Handled;
}

public Action Listener_Ban(int client, const char[] cmd, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_ban <#userid|name> <minutes|0> [reason]");
		return Plugin_Handled;
	}

	int len, next_len;
	char Arguments[256];
	GetCmdArgString(Arguments, sizeof(Arguments));

	char arg[65];
	len = BreakString(Arguments, arg, sizeof(arg));

	int target = FindTarget(client, arg, true);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	char s_time[12];
	if ((next_len = BreakString(Arguments[len], s_time, sizeof(s_time))) != -1)
	{
		len += next_len;
	}
	else
	{
		len = 0;
		Arguments[0] = '\0';
	}

	int time = StringToInt(s_time);

	g_BanTargetUserId[client] = GetClientUserId(target);

	PrepareBan(client, target, time, Arguments[len]);

	return Plugin_Handled;
}

void PrepareBan(int client, int target, int time, const char[] reason)
{
	int originalTarget = GetClientOfUserId(g_BanTargetUserId[client]);

	if (originalTarget != target)
	{
		if (client == 0)
		{
			PrintToServer("[SM] %t", "Player no longer available");
		}
		else
		{
			PrintToChat(client, "[SM] %t", "Player no longer available");
		}

		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));

	if (!time)
	{
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Permabanned player", name);
		} else {
			ShowActivity(client, "%t", "Permabanned player reason", name, reason);
		}
	} else {
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Banned player", name, time);
		} else {
			ShowActivity(client, "%t", "Banned player reason", name, time, reason);
		}
	}

	LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);

	char sReason[512],adminName[MAX_NAME_LENGTH], sTime[128];
	GetClientName(client, adminName, sizeof(adminName));
	GetBanTime(time, sTime, sizeof(sTime));
	Format(sReason, sizeof(sReason), "<font color=\"#FF0000\">====%s====</font>\nAdmin: %s\nTime: %s\nReason: %s", g_sName, adminName, sTime, reason[0] == '\0' ? "No reason specified" : reason);

	if (reason[0] == '\0')
	{
		BanClient(target, time, BANFLAG_AUTO, "No Reason Specified", sReason, "sm_ban", client);
	}
	else
	{
		BanClient(target, time, BANFLAG_AUTO, reason, sReason, "sm_ban", client);
	}
}

void PerformKick(int client, int target, const char[] reason)
{
	LogAction(client, target, "\"%L\" kicked \"%L\" (reason \"%s\")", client, target, reason);
	char sReason[512], adminName[MAX_NAME_LENGTH];
	GetClientName(client, adminName, sizeof(adminName));
	Format(sReason, sizeof(sReason), "<font color=\"#FF0000\">====%s====</font>\nAdmin: %s\nReason: %s", g_sName, adminName, reason[0] == '\0' ? "No reason specified" : reason);
	KickClient(target, sReason);
}

public void GetBanTime(int time, char[] buffer, int len)
{
	if(time == 0)
	{
		Format(buffer, len, "Permanent");
		return;
	}
	int years = 0, months = 0, weeks = 0, days = 0, hours = 0, minutes = 0;
	int timeLeft = time;
	if(timeLeft >= 518400)
	{
		years = timeLeft / 518400;
		timeLeft = timeLeft % 518400;
	}
	if(timeLeft >= 43200)
	{
		months = timeLeft / 43200;
		timeLeft = timeLeft % 43200;
	}
	if(timeLeft >= 10080)
	{
		weeks = timeLeft / 10080;
		timeLeft = timeLeft % 10080;
	}
	if(timeLeft >= 1440)
	{
		days = timeLeft / 1440;
		timeLeft = timeLeft % 1440;
	}
	if(timeLeft >= 60)
	{
		hours = timeLeft / 60;
		timeLeft = timeLeft % 60;
	}
	minutes = timeLeft;
	char sYear[16], sMonth[16], sWeek[16], sDay[16], sHour[16], sMinute[16];
	if(years != 0)
		Format(sYear, sizeof(sYear), "%iy", years);
	if(months != 0)
		Format(sMonth, sizeof(sMonth), "%im", months);
	if(weeks != 0)
		Format(sWeek, sizeof(sWeek), "%iw", weeks);
	if(days != 0)
		Format(sDay, sizeof(sDay), "%id", days);
	if(hours != 0)
		Format(sHour, sizeof(sHour), "%ih", hours);
	if(minutes != 0)
		Format(sMinute, sizeof(sMinute), "%imin", minutes);
	Format(buffer, len, "%s %s %s %s %s %s", sYear, sMonth, sWeek, sDay, sHour, sMinute);
}