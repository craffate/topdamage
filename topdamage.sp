#pragma semicolon 1
#pragma newdecls required

#if !defined TOP_DAMAGE_LINE_MAX_SIZE
	#define TOP_DAMAGE_LINE_MAX_SIZE 256
#endif

#define TOP_DAMAGE_CONFIG_DEFAULT_X 0.025
#define TOP_DAMAGE_CONFIG_DEFAULT_Y 0.25
#define TOP_DAMAGE_CONFIG_DEFAULT_HOLDTIME 5.0
#define TOP_DAMAGE_CONFIG_DEFAULT_R 0
#define TOP_DAMAGE_CONFIG_DEFAULT_G 255
#define TOP_DAMAGE_CONFIG_DEFAULT_B 255
#define TOP_DAMAGE_CONFIG_DEFAULT_A 0
#define TOP_DAMAGE_CONFIG_DEFAULT_EFFECT 0
#define TOP_DAMAGE_CONFIG_DEFAULT_FXTIME 6.0
#define TOP_DAMAGE_CONFIG_DEFAULT_FADEIN 0.1
#define TOP_DAMAGE_CONFIG_DEFAULT_FADEOUT 0.2
#define TOP_DAMAGE_CONFIG_DEFAULT_HEADER "* * * TOP DAMAGE * * *"
#define TOP_DAMAGE_CONFIG_DEFAULT_COUNT 5 

#define PLUGIN_VERSION "1.1.0"

#include <sourcemod>
#include <sorting>
#undef REQUIRE_PLUGIN
#include <DynamicChannels>

enum struct		Client
{
	int			iDamageDealt;
	char		szName[MAX_NAME_LENGTH + 1];
}

enum struct		Config
{
	float		x;
	float		y;
	float		holdTime;
	int			r;
	int			g;
	int			b;
	int			a;
	int			effect;
	float		fxTime;
	float		fadeIn;
	float		fadeOut;
	char		header[TOP_DAMAGE_LINE_MAX_SIZE];
	int			count;
}

static bool		g_bUseDynamicChannels;
static Client	g_aeClients[MAXPLAYERS];
static int		g_aiTopClientIdx[MAXPLAYERS];
static Config	g_eConfig;

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
	char		buf[TOP_DAMAGE_LINE_MAX_SIZE];
	char[]		display = new char[(TOP_DAMAGE_LINE_MAX_SIZE * 2) * g_eConfig.count];

	StrCat(display, (TOP_DAMAGE_LINE_MAX_SIZE * 2) * g_eConfig.count, g_eConfig.header);
	SortCustom1D(g_aiTopClientIdx, MAXPLAYERS, SortByDamageDealt);
	idx = -1;
	while (g_eConfig.count > ++idx)
	{
		if (g_aeClients[g_aiTopClientIdx[idx]].iDamageDealt)
		{
			Format(
				buf,
				TOP_DAMAGE_LINE_MAX_SIZE,
				"\n%s — %d",
				g_aeClients[g_aiTopClientIdx[idx]].szName,
				g_aeClients[g_aiTopClientIdx[idx]].iDamageDealt
			);
			StrCat(display, (TOP_DAMAGE_LINE_MAX_SIZE * 2) * g_eConfig.count, buf);
		}
		else
		{
			break;
		}
	}
	SetHudTextParams(
		g_eConfig.x,
		g_eConfig.y,
		g_eConfig.holdTime,
		g_eConfig.r,
		g_eConfig.g,
		g_eConfig.b,
		g_eConfig.a,
		g_eConfig.effect,
		g_eConfig.fxTime,
		g_eConfig.fadeIn,
		g_eConfig.fadeOut
	);
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

static void		LoadConfig()
{
	char		config_path[PLATFORM_MAX_PATH];
	KeyValues	kv;

	BuildPath(Path_SM, config_path, sizeof(config_path), "configs/topdamage.cfg");
	kv = new KeyValues("Top damage");
	if (INVALID_HANDLE == kv || false == kv.ImportFromFile(config_path))
	{
		g_eConfig.x = TOP_DAMAGE_CONFIG_DEFAULT_X;
		g_eConfig.y = TOP_DAMAGE_CONFIG_DEFAULT_Y;
		g_eConfig.holdTime = TOP_DAMAGE_CONFIG_DEFAULT_HOLDTIME;
		g_eConfig.r = TOP_DAMAGE_CONFIG_DEFAULT_R;
		g_eConfig.g = TOP_DAMAGE_CONFIG_DEFAULT_G;
		g_eConfig.b = TOP_DAMAGE_CONFIG_DEFAULT_B;
		g_eConfig.a = TOP_DAMAGE_CONFIG_DEFAULT_A;
		g_eConfig.effect = TOP_DAMAGE_CONFIG_DEFAULT_EFFECT;
		g_eConfig.fxTime = TOP_DAMAGE_CONFIG_DEFAULT_FXTIME;
		g_eConfig.fadeIn = TOP_DAMAGE_CONFIG_DEFAULT_FADEIN;
		g_eConfig.fadeOut = TOP_DAMAGE_CONFIG_DEFAULT_FADEOUT;
		g_eConfig.header = TOP_DAMAGE_CONFIG_DEFAULT_HEADER;
		g_eConfig.count = TOP_DAMAGE_CONFIG_DEFAULT_COUNT;
	}
	else
	{
		g_eConfig.x = kv.GetFloat("x", TOP_DAMAGE_CONFIG_DEFAULT_X);
		g_eConfig.y = kv.GetFloat("y", TOP_DAMAGE_CONFIG_DEFAULT_Y);
		g_eConfig.holdTime = kv.GetFloat("holdTime", TOP_DAMAGE_CONFIG_DEFAULT_HOLDTIME);
		g_eConfig.r = kv.GetNum("r", TOP_DAMAGE_CONFIG_DEFAULT_R);
		g_eConfig.g = kv.GetNum("g", TOP_DAMAGE_CONFIG_DEFAULT_G);
		g_eConfig.b = kv.GetNum("b", TOP_DAMAGE_CONFIG_DEFAULT_B);
		g_eConfig.a = kv.GetNum("a", TOP_DAMAGE_CONFIG_DEFAULT_A);
		g_eConfig.effect = kv.GetNum("effect", TOP_DAMAGE_CONFIG_DEFAULT_EFFECT);
		g_eConfig.fxTime = kv.GetFloat("fxTime", TOP_DAMAGE_CONFIG_DEFAULT_FXTIME);
		g_eConfig.fadeIn = kv.GetFloat("fadeIn", TOP_DAMAGE_CONFIG_DEFAULT_FADEIN);
		g_eConfig.fadeOut = kv.GetFloat("fadeOut", TOP_DAMAGE_CONFIG_DEFAULT_FADEOUT);
		kv.GetString("header", g_eConfig.header, TOP_DAMAGE_LINE_MAX_SIZE, TOP_DAMAGE_CONFIG_DEFAULT_HEADER);
		g_eConfig.count = kv.GetNum("count", TOP_DAMAGE_CONFIG_DEFAULT_COUNT);
	}
	if (null != kv)
	{
		CloseHandle(kv);
		kv = null;
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
	LoadConfig();
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