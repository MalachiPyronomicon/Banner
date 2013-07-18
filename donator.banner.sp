//	------------------------------------------------------------------------------------
//	Filename:		donator.banner.sp
//	Author:			Malachi
//	Version:		(see PLUGIN_VERSION)
//	Description:
//					Plugin displays the donator message when they first join the server.
//
// * Changelog (date/version/description):
// * 2013-05-16	-	0.1.1		-	initial test version
// * 2013-05-16	-	0.1.2		-	jointeam doesnt work for initial team selection
// * 2013-05-16	-	0.1.3		-	add timer stuff
// * 2013-05-16	-	0.1.4		-	add support for color
// * 2013-05-16	-	0.1.5		-	fix defines for banner
//	------------------------------------------------------------------------------------


// INCLUDES
#include <sourcemod>
#include <donator>
#include <clientprefs>


#pragma semicolon 1


// DEFINES
#define PLUGIN_VERSION	"0.1.5"

// for SetHudTextParamsEx()
#define HUDTEXT_X_COORDINATE	-1.0
#define HUDTEXT_Y_COORDINATE	0.22
#define HUDTEXT_HOLDTIME	8.0
#define HUDTEXT_WHITE	{255, 255, 255, 255}
#define HUDTEXT_BLACK	{0, 0, 0, 255}
#define HUDTEXT_EFFECT	1
#define HUDTEXT_FXTIME	9.0
#define HUDTEXT_FADEINTIME	0.15
#define HUDTEXT_FADEOUTTIME	0.15


// GLOBALS
new g_bClientStatus[MAXPLAYERS + 1] = {false, ...};
new Handle:g_hTimerHandle[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:g_HudSync = INVALID_HANDLE;
new Handle:g_TagColorCookie = INVALID_HANDLE;
new g_iTagColor[MAXPLAYERS + 1][4];


public Plugin:myinfo = 
{
	name = "Donator Banner",
	author = "Malachi",
	description = "displays the donator banner when they join the server",
	version = PLUGIN_VERSION,
	url = "www.necrophix.com"
}


public OnPluginStart()
{
	PrintToServer("[Donator:Banner] Plugin start...");
	g_HudSync = CreateHudSynchronizer();
	HookEvent("player_team", EventTeamChange, EventHookMode_Post);
	g_TagColorCookie = RegClientCookie("donator_tagcolor", "Chat color for donators.", CookieAccess_Private);

}


// Required: Basic donator interface
public OnAllPluginsLoaded()
{
	if(!LibraryExists("donator.core")) SetFailState("Unable to find plugin: Basic Donator Interface");
}


// If client passes donator check, set status=true, otherwise false
// We assume this will happen before jointeam, otherwise nothing will show
public OnPostDonatorCheck(client)
{
	if (IsPlayerDonator(client)) 
	{
		PrintToServer("[Donator:Banner] Post Donator Check = TRUE");
		g_bClientStatus[client]=true;

		// Grab the banner color from the cookie
		g_iTagColor[client] = HUDTEXT_WHITE;
		
		new String:szBuffer[256];
		if (AreClientCookiesCached(client))
		{
			GetClientCookie(client, g_TagColorCookie, szBuffer, sizeof(szBuffer));
			if (strlen(szBuffer) > 0)
			{
				decl String:szTmp[3][16];
				ExplodeString(szBuffer, " ", szTmp, 3, sizeof(szTmp[]));
				g_iTagColor[client][0] = StringToInt(szTmp[0]); 
				g_iTagColor[client][1] = StringToInt(szTmp[1]);
				g_iTagColor[client][2] = StringToInt(szTmp[2]);
			}
		}
		
	}
	else
	{
		PrintToServer("[Donator:Banner] Post Donator Check = FALSE");
		g_bClientStatus[client]=false;
	}
	return;

}


// If client joins a team and status=true, show msg and set status=false
public Action:EventTeamChange(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetEventInt(event, "team");

	if (g_bClientStatus[client])
	{
		PrintToServer("[Donator:Banner] Player Team - Status=TRUE, team=%d", team);
		new String:szBuffer[256];
		GetDonatorMessage(client, szBuffer, sizeof(szBuffer));
		ShowDonatorMessage(client, szBuffer);
		
		// we only show the intro once
		g_bClientStatus[client]=false;
	}
	else
	{
		PrintToServer("[Donator:Banner] Player Team - Status=FALSE, team=%d", team);
	}
	
	return Plugin_Continue;
}


// Cleanup when player leaves
public OnClientDisconnect(client)
{
	PrintToServer("[Donator:Banner] Disconnect - reset status");

	// kill timer if we quickly disconnect
	if(g_hTimerHandle[client] != INVALID_HANDLE)
	{
		KillTimer(g_hTimerHandle[client]);
		g_hTimerHandle[client] = INVALID_HANDLE;
	}
	
	g_bClientStatus[client]=false;
}


// Copied from donator.recognition.tf2.sp v0.5.15
public ShowDonatorMessage(iClient, String:message[])
{
	PrintToServer("[Donator:Banner] Show Banner");

	// Set up text location/params
	SetHudTextParamsEx(HUDTEXT_X_COORDINATE, HUDTEXT_Y_COORDINATE, HUDTEXT_HOLDTIME, g_iTagColor[iClient], HUDTEXT_BLACK, HUDTEXT_EFFECT, HUDTEXT_FXTIME, HUDTEXT_FADEINTIME, HUDTEXT_FADEOUTTIME);

	// Display to all players
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowSyncHudText(i, g_HudSync, message);
		}
	}
	
}




// Cleanup all timers on map end
public OnMapEnd()
{

	// Kill timers for all players
	for(new i = 0; i <= (MAXPLAYERS + 1); i++)
	{
		if(g_hTimerHandle[i] != INVALID_HANDLE)
		{
			KillTimer(g_hTimerHandle[i]);
			g_hTimerHandle[i] = INVALID_HANDLE;
		}
	}

}















