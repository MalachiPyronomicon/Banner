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
// * 2013-05-16	-	0.1.6		-	add menu handling
// * 2013-05-16	-	0.1.7		-	fix array index out of bounds (line 236)
// * 2013-05-16	-	0.1.8		-	test new player join team func
//	------------------------------------------------------------------------------------


// INCLUDES
#include <sourcemod>
#include <donator>
#include <clientprefs>


#pragma semicolon 1


// DEFINES
#define PLUGIN_VERSION	"0.1.7"

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

// These define the text players see in the donator menu
#define MENUTEXT_DONATOR_TAG		"Intro Banner"
#define MENUTEXT_DONATOR_TAG_COLOR	"Intro Banner Color"


// GLOBALS
new g_bClientStatus[MAXPLAYERS + 1] = {false, ...};
new Handle:g_hTimerHandle[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:g_HudSync = INVALID_HANDLE;
new Handle:g_TagColorCookie = INVALID_HANDLE;
new g_iTagColor[MAXPLAYERS + 1][4];


enum _:tColors
{
	tColor_Black,
	tColor_White,
	tColor_Orange,
	tColor_Yellow,
	tColor_Green,
	tColor_Blue,
	tColor_Red,
	tColor_Lime,
	tColor_Aqua,
	tColor_Grey,
	tColor_Purple,
	tColor_Max
}


new const String:szColorValues[tColor_Max][11] =
{
	"0 0 0", "255 255 255", "255 102 0",
	"255 255 0", "0 128 0", "0 0 255",
	"255 0 0", "0 255 0", "0 255 255",
	"128 128 128", "128 0 128"
};


new const String:szColorNames[tColor_Max][11] =
{
	"Black", "White", "Orange",
	"Yellow", "Green", "Blue",
	"Red", "Lime", "Aqua",
	"Grey", "Purple"
};



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

	//	HookEvent("player_team", EventTeamChange, EventHookMode_Post);
	AddCommandListener(EventTeamChange, "joinclass");

	g_TagColorCookie = RegClientCookie("donator_tagcolor", "Chat color for donators.", CookieAccess_Private);

	AddCommandListener(SayCallback, "donator_tag");
	AddCommandListener(SayCallback, "donator_tagcolor");

}


public OnPluginEnd() 
{
    RemoveCommandListener(EventTeamChange, "joinclass");
    RemoveCommandListener(SayCallback, "donator_tag");
    RemoveCommandListener(SayCallback, "donator_tagcolor");
}


// Required: Basic donator interface
public OnAllPluginsLoaded()
{
	if(!LibraryExists("donator.core"))
		SetFailState("Unable to find plugin: Basic Donator Interface");
		
	Donator_RegisterMenuItem(MENUTEXT_DONATOR_TAG, ChangeTagCallback);
	Donator_RegisterMenuItem(MENUTEXT_DONATOR_TAG_COLOR, ChangeTagColorCallback);
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
//public Action:EventTeamChange(Handle:event, const String:name[], bool:dontBroadcast)
public Action:EventTeamChange(client, const String:command[], args)
{
//	new client = GetClientOfUserId(GetEventInt(event, "userid"));
//	new team = GetEventInt(event, "team");

	if (g_bClientStatus[client])
	{
//		PrintToServer("[Donator:Banner] Player Team - Status=TRUE, team=%d", team);
		PrintToServer("[Donator:Banner] Player Team - Status=TRUE");
		new String:szBuffer[256];
		GetDonatorMessage(client, szBuffer, sizeof(szBuffer));
		ShowDonatorMessage(client, szBuffer);
		
		// we only show the intro once
		g_bClientStatus[client]=false;
	}
	else
	{
//		PrintToServer("[Donator:Banner] Player Team - Status=FALSE, team=%d", team);
		PrintToServer("[Donator:Banner] Player Team - Status=FALSE");
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


public PanelHandlerBlank(Handle:menu, MenuAction:action, iClient, param2) {}

public DonatorMenu:ChangeTagCallback(iClient) Panel_ChangeTag(iClient);

public DonatorMenu:ChangeTagColorCallback(iClient) Panel_ChangeTagColor(iClient);


// Cleanup all timers on map end
public OnMapEnd()
{

	// Kill timers for all players
	for(new i = 0; i < (MAXPLAYERS + 1); i++)
	{
		if(g_hTimerHandle[i] != INVALID_HANDLE)
		{
			KillTimer(g_hTimerHandle[i]);
			g_hTimerHandle[i] = INVALID_HANDLE;
		}
	}

}



// Copied from donator.recognition.tf2.sp v0.5.16
public Action:Panel_ChangeTag(iClient)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "Donator: Change Banner:");
	
	new String:szBuffer[256];
	GetDonatorMessage(iClient, szBuffer, sizeof(szBuffer));
	DrawPanelItem(panel, "Your current donator banner is:", ITEMDRAW_DEFAULT);
	DrawPanelItem(panel, szBuffer, ITEMDRAW_RAWLINE);
	DrawPanelItem(panel, "space", ITEMDRAW_SPACER);
	DrawPanelItem(panel, "Type the following in the console to change your banner:", ITEMDRAW_CONTROL);
	DrawPanelItem(panel, "donator_tag \"YOUR BANNER GOES HERE\"", ITEMDRAW_RAWLINE);
	
	SendPanelToClient(panel, iClient, PanelHandlerBlank, 20);
	CloseHandle(panel);
}


// Copied from donator.recognition.tf2.sp v0.5.16
public Action:Panel_ChangeTagColor(iClient)
{
	new Handle:menu = CreateMenu(TagColorMenuSelected);
	SetMenuTitle(menu,"Donator: Change Banner Color:");
	
	decl String:szBuffer[256];
	FormatEx(szBuffer, sizeof(szBuffer), "%i %i %i", g_iTagColor[iClient][0], g_iTagColor[iClient][1], g_iTagColor[iClient][2]);

	decl String:szItem[4];
	for (new i = 0; i < tColor_Max; i++)
	{
		FormatEx(szItem, sizeof(szItem), "%i", i);
		if (StrEqual(szBuffer, szColorValues[i]))
			AddMenuItem(menu, szItem, szColorNames[i], ITEMDRAW_DISABLED);
		else
			AddMenuItem(menu, szItem, szColorNames[i], ITEMDRAW_DEFAULT);
	}
	DisplayMenu(menu, iClient, 20);
}


public Action:SayCallback(iClient, const String:command[], argc)
{
	if(!iClient) return Plugin_Continue;
	if (!IsPlayerDonator(iClient)) return Plugin_Continue;

	decl String:szArg[255];
	GetCmdArgString(szArg, sizeof(szArg));

	StripQuotes(szArg);
	TrimString(szArg);

	if (StrEqual(command, "donator_tag", true))
	{
		decl String:szTmp[256];
		if (strlen(szArg) < 1)
		{
			GetDonatorMessage(iClient, szTmp, sizeof(szTmp));
			ReplyToCommand(iClient, "[SM] Your current banner is: %s", szTmp);
		}
		else
		{
			PrintToChat(iClient, "\x01[SM] You have sucessfully changed your banner to: \x04%s\x01", szArg);
			SetDonatorMessage(iClient, szArg);
		}
	}
	else if (StrEqual(command, "donator_tagcolor", true))
	{
		decl String:szTmp[3][16];
		if (strlen(szArg) < 1)
		{
			GetClientCookie(iClient, g_TagColorCookie, szTmp[0], sizeof(szTmp[]));
			ReplyToCommand(iClient, "[SM] Your current banner color is: %s", szTmp[0]);
		}
		else
		{
			ExplodeString(szArg, " ", szTmp, 3, sizeof(szTmp[]));
			ReplyToCommand(iClient, "[SM] You have sucessfully changed your color to %s", szArg);
			SetClientCookie(iClient, g_TagColorCookie, szArg);
		}
	}
	return Plugin_Handled;
}


public TagColorMenuSelected(Handle:menu, MenuAction:action, param1, param2)
{
	decl String:tmp[32], iSelected;
	GetMenuItem(menu, param2, tmp, sizeof(tmp));
	iSelected = StringToInt(tmp);

	switch (action)
	{
		case MenuAction_Select:
		{
			decl String:szTmp[3][16], iColor[4];
			
			ExplodeString(szColorValues[iSelected], " ", szTmp, 3, sizeof(szTmp[]));
			iColor[0] = StringToInt(szTmp[0]); 
			iColor[1] = StringToInt(szTmp[1]);
			iColor[2] = StringToInt(szTmp[2]);
			iColor[3] = 255;
			
			g_iTagColor[param1] = iColor;
			
			SetHudTextParamsEx(-1.0, 0.22, 4.0, iColor, {0, 0, 0, 255}, 1, 5.0, 0.15, 0.15);
			ShowSyncHudText(param1, g_HudSync, "This is your new banner color.");
			SetClientCookie(param1, g_TagColorCookie, szColorValues[iSelected]);
		}
		case MenuAction_End: CloseHandle(menu);
	}
}

