//	------------------------------------------------------------------------------------
//	Filename:		donator.banner.sp
//	Author:			Malachi
//	Version:		(see PLUGIN_VERSION)
//	Description:
//					Plugin displays the donator message when they first join the server.
//
// * Changelog (date/version/description):
// * 2013-05-16	-	0.1.1		-	initial test version
//	------------------------------------------------------------------------------------


// INCLUDES
#include <sourcemod>
//#include <sdktools>
//#include <tf2>
#include <donator>
//#include <clientprefs>


#pragma semicolon 1


// DEFINES
#define PLUGIN_VERSION	"0.1.1"

// for SetHudTextParamsEx()
#define HUDTEXT_X_COORDINATE	-1.0
#define HUDTEXT_Y_COORDINATE	0.22
#define HUDTEXT_HOLDTIME	8
#define HUDTEXT_COLOR1	{255, 255, 255, 255}
#define HUDTEXT_COLOR2	{0, 0, 0, 255}
#define HUDTEXT_EFFECT	1
#define HUDTEXT_FXTIME	9.0
#define HUDTEXT_FADEINTIME	0.15
#define HUDTEXT_FADEOUTTIME	0.15


// GLOBALS
new g_bClientStatus[MAXPLAYERS + 1] = {false, ...};
new Handle:g_HudSync = INVALID_HANDLE;


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
	RegConsoleCmd("jointeam", Command_Jointeam, "Jointeam");
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
	}
	else
	{
		PrintToServer("[Donator:Banner] Post Donator Check = FALSE");
		g_bClientStatus[client]=false;
	}
	return;

}


// If client joins a team and status=true, show msg and set status=false
// Do we prefer jointeam or selectclass...
public Action:Command_Jointeam(client, args) 
{
	if (g_bClientStatus[client])
	{
		PrintToServer("[Donator:Banner] Join Team - Status=TRUE");
		new String:szBuffer[256];
		GetDonatorMessage(client, szBuffer, sizeof(szBuffer));
		ShowDonatorMessage(client, szBuffer);
		g_bClientStatus[client]=false;
	}
	return Plugin_Continue;
}


// We prolly dont really need this, but included to be safe
public OnClientDisconnect(client)
{
	PrintToServer("[Donator:Banner] Disconnect - reset status");
	g_bClientStatus[client]=false;
}


// Copied from donator.recognition.tf2.sp
public ShowDonatorMessage(iClient, String:message[])
{
	PrintToServer("[Donator:Banner] Show Banner");

	// Set up text location/params
//	SetHudTextParamsEx(HUDTEXT_X_COORDINATE, HUDTEXT_Y_COORDINATE, HUDTEXT_HOLDTIME, {255, 255, 255, 255}, {0, 0, 0, 255}, HUDTEXT_EFFECT, HUDTEXT_FXTIME, HUDTEXT_FADEINTIME, HUDTEXT_FADEOUTTIME);
	SetHudTextParamsEx(-1.0, 0.22, 4.0, {255, 255, 255, 255}, {0, 0, 0, 255}, 1, 5.0, 0.15, 0.15);

	// Display to all players
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowSyncHudText(i, g_HudSync, message);
		}
	}
	
}



















