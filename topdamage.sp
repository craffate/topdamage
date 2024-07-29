#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"

#define TOP_DAMAGE_COUNT 5
#define TOP_DAMAGE_LINE_LENGTH 64
#define TOP_DAMAGE_HEADER "* * * TOP DAMAGE * * *"
#define TOP_DAMAGE_HEADER_SIZE 22

#include <sourcemod>
#include <sorting>
#undef REQUIRE_PLUGIN
#include <DynamicChannels>

enum struct		Client
{
	int			iDamageDealt;
	char		szName[MAX_NAME_LENGTH + 1];
}

static bool		g_bUseDynamicChannels;
static Client	g_aeClients[MAXPLAYERS];
static int		g_aiTopClientIdx[MAXPLAYERS];

public Plugin	myinfo =
{
	name = "Top damage",
	author = "exha",
	description = "Displays a top damage summary at the end of the round.",
	version = PLUGIN_VERSION,
	url = ""
};

static void		ResetClient(const int client)
{
	g_aeClients[client].iDamageDealt = 0;
	g_aeClients[client].szName[0] = 0;
}

static int		SortByDamageDealt(int elem1, int elem2, const int[] array, Handle hndl)
{
	int			ret;
	
	ret = 1;
	if (g_aeClients[elem1].iDamageDealt > g_aeClients[elem2].iDamageDealt)
	{
		ret = -1;
	}
	else if (g_aeClients[elem1].iDamageDealt == g_aeClients[elem2].iDamageDealt)
	{
		ret = 0;
	}
	return (ret);
}

static Action	Event_PlayerHurt(Event event, char[] name, bool dontBroadcast)
{
	int			client;
	int			attacker;
	
	client = GetClientOfUserId(event.GetInt("userid"));
	attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker && IsClientInGame(attacker) && GetClientTeam(client) != GetClientTeam(attacker))
	{
		g_aeClients[attacker].iDamageDealt += event.GetInt("dmg_health");
	}
	return (Plugin_Continue);
}

static void		Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	int			idx;
	
	idx = MaxClients;
	while (--idx)
	{
		ResetClient(idx);
		if (IsClientInGame(idx))
		{
			GetClientName(idx, g_aeClients[idx].szName, MAX_NAME_LENGTH + 1);
		}
	}
}

static void		Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	int			idx;
	char		buf[TOP_DAMAGE_LINE_LENGTH];
	char		display[TOP_DAMAGE_HEADER_SIZE + sizeof(buf) * TOP_DAMAGE_COUNT];

	StrCat(display, sizeof(display), TOP_DAMAGE_HEADER);
	SortCustom1D(g_aiTopClientIdx, MAXPLAYERS, SortByDamageDealt);
	idx = -1;
	while (TOP_DAMAGE_COUNT > ++idx)
	{
		if (g_aeClients[g_aiTopClientIdx[idx]].iDamageDealt)
		{
			Format(
				buf,
				sizeof(buf),
				"\n%s — %d",
				g_aeClients[g_aiTopClientIdx[idx]].szName,
				g_aeClients[g_aiTopClientIdx[idx]].iDamageDealt
			);
			StrCat(display, sizeof(display), buf);
		}
		else
		{
			break;
		}
	}
	SetHudTextParams(0.025, 0.25, 5.0, 0, 255, 255, 0);
	idx = MaxClients;
	while (--idx)
	{
		if (IsClientInGame(idx) && !IsFakeClient(idx))
		{
			ShowHudText(
				idx,
				g_bUseDynamicChannels ? GetDynamicChannel(0) : -1,
				display
			);
		}
	}
}

public void		OnPluginStart()
{
	int			idx;

	idx = MAXPLAYERS;
	while (--idx)
	{
		g_aiTopClientIdx[idx] = idx;
	}
	g_bUseDynamicChannels = false;
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void		OnAllPluginsLoaded()
{
	g_bUseDynamicChannels = LibraryExists("DynamicChannels");
}

public void		OnClientPutInServer(int client)
{
	ResetClient(client);
	GetClientName(client, g_aeClients[client].szName, MAX_NAME_LENGTH + 1);
}