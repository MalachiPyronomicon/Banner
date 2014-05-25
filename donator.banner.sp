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
// * 2013-05-16	-	0.1.9		-	add timers to add brief delay before showing banner
// * 2013-08-03	-	0.1.10		-	also announce donator in chat
// * 2013-08-03	-	0.1.11		-	add debug msg, reorganize, fix commands
//	------------------------------------------------------------------------------------


// INCLUDES
#include <sourcemod>
#include <donator>
#include <clientprefs>


#pragma semicolon 1


// DEFINES
// Plugin Info
#define PLUGIN_INFO_VERSION					"0.1.11"
#define PLUGIN_INFO_NAME					"Donator Banner"
#define PLUGIN_INFO_AUTHOR					"Malachi"
#define PLUGIN_INFO_DESCRIPTION				"Displays the donator banner when they join the server"
#define PLUGIN_INFO_URL						"http://www.necrophix.com/"
#define PLUGIN_PRINT_NAME					"[Banner]"							// Used for self-identification in chat/logging

// for SetHudTextParamsEx()
#define HUDTEXT_X_COORDINATE				-1.0
#define HUDTEXT_Y_COORDINATE				0.22
#define HUDTEXT_HOLDTIME					8.0
#define HUDTEXT_WHITE						{255, 255, 255, 255}
#define HUDTEXT_BLACK						{0, 0, 0, 255}
#define HUDTEXT_EFFECT						1
#define HUDTEXT_FXTIME						9.0
#define HUDTEXT_FADEINTIME					0.15
#define HUDTEXT_FADEOUTTIME					0.15

// These define the text players see in the donator menu
#define MENUTEXT_DONATOR_TAG				"Intro Banner"
#define MENUTEXT_DONATOR_TAG_COLOR			"Intro Banner Color"

#define CONVAR_BANNER_TEXT 					"banner_text"
#define CONVAR_BANNER_COLOR		 			"banner_color"

#define COOKIENAME_BANNER					"donator_tagcolor"
#define COOKIENAME_BANNER_DESCRIPTION		"Chat color for donators."


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


// Info
public Plugin:myinfo = 
{
	name = PLUGIN_INFO_NAME,
	author = PLUGIN_INFO_AUTHOR,
	description = PLUGIN_INFO_DESCRIPTION,
	version = PLUGIN_INFO_VERSION,
	url = PLUGIN_INFO_URL
}


public OnPluginStart()
{
	// Advertise our presence...
	PrintToServer("%s v%s Plugin start...", PLUGIN_PRINT_NAME, PLUGIN_INFO_VERSION);

	g_HudSync = CreateHudSynchronizer();

	AddCommandListener(EventTeamChange, "joinclass");

	g_TagColorCookie = RegClientCookie(COOKIENAME_BANNER, COOKIENAME_BANNER_DESCRIPTION, CookieAccess_Private);

	AddCommandListener(ChangeBannerText, CONVAR_BANNER_TEXT);
	AddCommandListener(ChangeBannerColor, CONVAR_BANNER_COLOR);

}


public OnPluginEnd() 
{
    RemoveCommandListener(EventTeamChange, "joinclass");
    RemoveCommandListener(ChangeBannerText, CONVAR_BANNER_TEXT);
    RemoveCommandListener(ChangeBannerColor, CONVAR_BANNER_COLOR);
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
		g_bClientStatus[client]=false;
	}
	return;

}


// If client joins a team and status=true, show msg and set status=false
public Action:EventTeamChange(client, const String:command[], args)
{
	if (g_bClientStatus[client])
	{
		g_hTimerHandle[client] = CreateTimer(1.0, CallShowDonatorMessage, client);
		
		// we only show the intro once
		g_bClientStatus[client]=false;
	}
	
	return Plugin_Continue;
}


// func wrapper to deal w/timer handle
public Action:CallShowDonatorMessage(Handle:Timer, any:client)
{
	new String:szBuffer[256];
	decl String:sName[MAX_NAME_LENGTH];

	// Print a welcome msg to chat
	if (GetClientName(client, sName, sizeof(sName)))
	{
		PrintToChatAll("\x04%s: \x01Welcome back %s", PLUGIN_PRINT_NAME, sName);
	}

	GetDonatorMessage(client, szBuffer, sizeof(szBuffer));
	ShowDonatorMessage(client, szBuffer);
	
	g_hTimerHandle[client] = INVALID_HANDLE;

}


// Cleanup when player leaves
public OnClientDisconnect(client)
{
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
	PrintToServer("%s Show Banner", PLUGIN_PRINT_NAME);

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
	
	DrawPanelItem(panel, "Console command to change banner text:", ITEMDRAW_CONTROL);
	
	Format(szBuffer, sizeof(szBuffer), "%s \"YOUR BANNER GOES HERE\"", CONVAR_BANNER_TEXT);
	DrawPanelItem(panel, szBuffer, ITEMDRAW_RAWLINE);
	
	DrawPanelItem(panel, "Console command to change banner color (RGB):", ITEMDRAW_CONTROL);
	
	Format(szBuffer, sizeof(szBuffer), "%s 0-255 0-255 0-255", CONVAR_BANNER_COLOR);
	DrawPanelItem(panel, szBuffer, ITEMDRAW_RAWLINE);

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


public Action:ChangeBannerText(iClient, const String:command[], argc)
{
	if(!iClient) return Plugin_Continue;
	if (!IsPlayerDonator(iClient)) return Plugin_Continue;

	decl String:szArg[255];
	GetCmdArgString(szArg, sizeof(szArg));

	StripQuotes(szArg);
	TrimString(szArg);

	decl String:szTmp[256];
	if (strlen(szArg) < 1)
	{
		GetDonatorMessage(iClient, szTmp, sizeof(szTmp));
		ReplyToCommand(iClient, "[SM] Your current banner is: %s", szTmp);
	}
	else
	{
		PrintToChat(iClient, "\x01%s You have successfully changed your banner to: \x04%s\x01", PLUGIN_PRINT_NAME, szArg);
		LogMessage("%s You have successfully changed your banner to: %s", PLUGIN_PRINT_NAME, szArg);						// DEBUG
		SetDonatorMessage(iClient, szArg);
	}
	return Plugin_Handled;
}


public Action:ChangeBannerColor(iClient, const String:command[], argc)
{
	if(!iClient) return Plugin_Continue;
	if (!IsPlayerDonator(iClient)) return Plugin_Continue;

	decl String:szArg[255];
	GetCmdArgString(szArg, sizeof(szArg));

	StripQuotes(szArg);
	TrimString(szArg);

	decl String:szTmp[3][16];
	if (strlen(szArg) < 1)
	{
		GetClientCookie(iClient, g_TagColorCookie, szTmp[0], sizeof(szTmp[]));
		ReplyToCommand(iClient, "%s Your current banner color is: %s", PLUGIN_PRINT_NAME, szTmp[0]);
	}
	else
	{
		ExplodeString(szArg, " ", szTmp, 3, sizeof(szTmp[]));
		ReplyToCommand(iClient, "%s You have successfully changed your color to %s", PLUGIN_PRINT_NAME, szArg);
		SetClientCookie(iClient, g_TagColorCookie, szArg);
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

