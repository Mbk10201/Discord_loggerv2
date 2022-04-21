#include <sourcemod>
#include <smlib>
#include <geoip>
#include <steamworks>
#include <unixtime_sourcemod>
#include <discord>

#undef REQUIRE_PLUGIN
#include <sourcebanspp>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

KeyValues 
	gKv;
char
	g_sHostname[64],
	g_sTitleLink[128],
	g_sUsername[128];
bool
	g_bLogIP = false,
	g_bLogSteamID = false,
	g_bLogCountry = false,
	g_bLogConnectIP = false,
	g_bEmbed = false;
ArrayList
	g_aChannels;
float
	g_fTimerInfo = 0.0;
	
enum METHODS {
	MAP,
	CHANGEMAP,
	AUTH,
	BANS,
	KICK,
	UNBAN,
	CHAT,
	KILL,
	GAG,
	INFO,
	ENDPLAYERSALIVE
}

enum CHANNELDATA {
	COLOR,
	URL
}
	
enum struct MethodData {
	bool enabled;
	char channel[64];
	char tag[64];
}
MethodData g_sMethod[METHODS];

enum struct PlayerData {
	char IP[64];
	char SteamID[32];
	bool IsInDisconnectQueue;
}
PlayerData g_sPlayer[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Discord Logger!",
	author = "MbK",
	description = "Log server events",
	version = "v2",
	url = "https://forums.alliedmods.net/member.php?u=286665"
};

public void OnPluginStart()
{
	// Load translation file
	LoadTranslations("discord_logger.phrases");
	
	// Register Array
	g_aChannels = new ArrayList(64);
	
	// Hook Game Events
	HookEvent("player_death", Event_OnDeath, EventHookMode_Post);
	HookEvent("player_disconnect", Event_OnDisconnect, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	AddCommandListener(Listener_Say, "say");
	
	// Register Keyvalue
	char key_path[PLATFORM_MAX_PATH];
	gKv = new KeyValues("Discord_logger");
	BuildPath(Path_SM, key_path, sizeof(key_path), "configs/discord_logger.ini");
	
	if(!gKv.ImportFromFile(key_path))
	{
		SetFailState("File not found (%s)", key_path);
		delete gKv;
	}
	
	if(gKv.JumpToKey("settings"))
	{
		gKv.GetString("username", g_sUsername, sizeof(g_sUsername));
		gKv.GetString("title_link", g_sTitleLink, sizeof(g_sTitleLink));
		
		// Set fail state if there is no http or https protocol, if there is none of them the message will not be sent due to discord conditions.
		if(StrContains(g_sTitleLink, "http", false) == -1 && !StrEqual(g_sTitleLink, ""))
			SetFailState("Key 'title_link' in %s is missing http / https protocol", key_path);
		
		g_bLogIP = view_as<bool>(gKv.GetNum("log_ip"));
		g_bLogSteamID = view_as<bool>(gKv.GetNum("log_steamid"));
		g_bLogCountry = view_as<bool>(gKv.GetNum("log_country"));
		g_bLogConnectIP = view_as<bool>(gKv.GetNum("log_ipconnect"));
		g_bEmbed = view_as<bool>(gKv.GetNum("embed"));
		g_fTimerInfo = gKv.GetFloat("informations_timer");
		
		if(gKv.JumpToKey("auth"))
		{
			g_sMethod[AUTH].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[AUTH].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[AUTH].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("map"))
		{
			g_sMethod[MAP].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[MAP].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[MAP].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("bans"))
		{
			g_sMethod[BANS].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[BANS].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[BANS].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("kick"))
		{
			g_sMethod[KICK].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[KICK].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[KICK].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("chat"))
		{
			g_sMethod[CHAT].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[CHAT].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[CHAT].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("gag"))
		{
			g_sMethod[GAG].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[GAG].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[GAG].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("kill"))
		{
			g_sMethod[KILL].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[KILL].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[KILL].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("informations"))
		{
			g_sMethod[INFO].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[INFO].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[INFO].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		if(gKv.JumpToKey("roundend_playersalive"))
		{
			g_sMethod[ENDPLAYERSALIVE].enabled = view_as<bool>(gKv.GetNum("enabled"));
			gKv.GetString("channel", g_sMethod[ENDPLAYERSALIVE].channel, sizeof(g_sMethod[].channel));
			gKv.GetString("tag", g_sMethod[ENDPLAYERSALIVE].tag, sizeof(g_sMethod[].tag));
			
			gKv.GoBack();
		}
		
		gKv.GoBack();
	}
	
	if(gKv.JumpToKey("webhooks"))
	{
		if (!gKv.GotoFirstSubKey())
		{
			PrintToServer("ERROR FIRST KEY");
			delete gKv;
			return;
		}
		
		do
		{
			if(gKv.GetSectionName(key_path, sizeof(key_path)))
			{
				char sColor[16];
				gKv.GetString("color", sColor, sizeof(sColor));
				char sUrl[1024];
				gKv.GetString("url", sUrl, sizeof(sUrl));
				
				Format(key_path, sizeof(key_path), "%s|%s|%s", key_path, sColor, sUrl);
				
				g_aChannels.PushString(key_path);
			}
		} 
		while (gKv.GotoNextKey());
		
		gKv.GoBack();
	}
	
	gKv.Rewind();
}

public void OnMapStart()
{
	if(g_fTimerInfo > 0.0)
	{
		CreateTimer(g_fTimerInfo, Timer_Information, _, TIMER_REPEAT);
	}
	
	FindConVar("hostname").GetString(g_sHostname, sizeof(g_sHostname));
	if(g_sMethod[MAP].enabled)
	{
		char sMap[64];
		logger_GetMap(sMap, sizeof(sMap));
		
		char sUrl[1024];
		GetChannelData(g_sMethod[MAP].channel, URL, sUrl, sizeof(sUrl));
		
		DiscordWebHook hook = new DiscordWebHook(sUrl);
		
		if(g_bEmbed)
		{
			MessageEmbed Embed = new MessageEmbed();
			
			Embed.SetTitle(g_sHostname);
			
			if(!StrEqual(g_sTitleLink, ""))
				Embed.SetTitleLink(g_sTitleLink);
			
			char sColor[32];
			GetChannelData(g_sMethod[MAP].channel, COLOR, sColor, sizeof(sColor));
			Embed.SetColor(sColor);
			
			char sField[32];
			Format(sMap, sizeof(sMap), "```%s```", sMap);
			Format(sField, sizeof(sField), "%T", "field_map", LANG_SERVER);
			Embed.AddField(sField, sMap, true);
			logger_GetMap(sMap, sizeof(sMap));
			
			char sGame[64];
			GetGameFolderName(sGame, sizeof(sGame));
			
			char image_url[512];
			Format(image_url, sizeof(image_url), "https://image.gametracker.com/images/maps/160x120/%s/%s.jpg", sGame, sMap);
			Embed.SetImage(image_url);
			
			Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
		
			hook.Embed(Embed);
		}
		else
		{
			char sMessage[2048];
			Format(sMessage, sizeof(sMessage), "%T", "map_init", LANG_SERVER, sMap);
			hook.SetContent(sMessage);
		}
		
		SendEmbed(hook, MAP);
	}
}

public Action Event_OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	char weapon[64], killer_name[64], victim_name[64];
	event.GetString("weapon", weapon, sizeof(weapon));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	GetClientName(attacker, killer_name, sizeof(killer_name));
	GetClientName(victim, victim_name, sizeof(victim_name));

	if(attacker == victim)
	{
		killer_name = "World";
		weapon = "Suicide";
	}
	
	if(g_sMethod[KILL].enabled && !g_sPlayer[victim].IsInDisconnectQueue)
	{
		char sMap[64];
		logger_GetMap(sMap, sizeof(sMap));
		
		char sUrl[1024];
		GetChannelData(g_sMethod[KILL].channel, URL, sUrl, sizeof(sUrl));
		
		DiscordWebHook hook = new DiscordWebHook(sUrl);
		
		if(g_bEmbed)
		{
			MessageEmbed Embed = new MessageEmbed();
			
			Embed.SetTitle(g_sHostname);
			
			if(!StrEqual(g_sTitleLink, ""))
				Embed.SetTitleLink(g_sTitleLink);
			
			char sColor[32];
			GetChannelData(g_sMethod[KILL].channel, COLOR, sColor, sizeof(sColor));
			Embed.SetColor(sColor);
			
			char sField[32];
			Format(sField, sizeof(sField), "%T", "field_killer", LANG_SERVER);
			Format(killer_name, sizeof(killer_name), "```%s```", killer_name);
			Embed.AddField(sField, killer_name, true);
			Format(sField, sizeof(sField), "%T", "field_victim", LANG_SERVER);
			Format(victim_name, sizeof(victim_name), "```%s```", victim_name);
			Embed.AddField(sField, victim_name, true);
			Format(sField, sizeof(sField), "%T", "field_weapon", LANG_SERVER);
			Format(weapon, sizeof(weapon), "```%s```", weapon);
			Embed.AddField(sField, weapon, true);
			
			Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
		
			hook.Embed(Embed);
		}
		else
		{
			char sMessage[2048];
			Format(sMessage, sizeof(sMessage), "%T", "ondeath_no_embed", LANG_SERVER, attacker, victim, weapon);
			hook.SetContent(sMessage);
		}
		
		SendEmbed(hook, KILL);
	}
	
	return Plugin_Continue;
}

public Action Listener_Say(int client, char[] Cmd, int args)
{
	if(client > 0)
	{
		if(IsClientValid(client))
		{
			char arg[256];
			GetCmdArgString(arg, sizeof(arg));
			StripQuotes(arg);
			TrimString(arg);
	
			if (strcmp(arg, " ") == 0 || strcmp(arg, "") == 0 || strlen(arg) == 0 || StrContains(arg, "!") == 0 || StrContains(arg, "/") == 0 || StrContains(arg, "@") == 0)
			{
				return Plugin_Handled;
			}

			if(StrContains(arg, "@everyone", false) == -1 || StrContains(arg, "@here", false) != -1)
			{
				char name[64];
				GetClientName(client, name, sizeof(name));
				
				if(g_sMethod[CHAT].enabled)
				{
					char sMap[64];
					logger_GetMap(sMap, sizeof(sMap));
					
					char sUrl[1024];
					GetChannelData(g_sMethod[CHAT].channel, URL, sUrl, sizeof(sUrl));
					
					DiscordWebHook hook = new DiscordWebHook(sUrl);
					
					if(g_bEmbed)
					{
						MessageEmbed Embed = new MessageEmbed();
						
						Embed.SetTitle(g_sHostname);
						
						if(!StrEqual(g_sTitleLink, ""))
							Embed.SetTitleLink(g_sTitleLink);
						
						char sColor[32];
						GetChannelData(g_sMethod[CHAT].channel, COLOR, sColor, sizeof(sColor));
						Embed.SetColor(sColor);
						
						char sField[32];
						
						Format(sField, sizeof(sField), "%T", "field_player", LANG_SERVER);
						Format(name, sizeof(name), "```%s```", name);
						Embed.AddField(sField, name, true);
						Format(sField, sizeof(sField), "%T", "field_message", LANG_SERVER);
						Format(arg, sizeof(arg), "```%s```", arg);
						Embed.AddField(sField, arg, true);
						
						Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
					
						hook.Embed(Embed);
					}
					else
					{
						char sMessage[2048];
						Format(sMessage, sizeof(sMessage), "%T", "onsay_no_embed", LANG_SERVER, client, arg);
						hook.SetContent(sMessage);
					}
					
					SendEmbed(hook, CHAT);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_OnDisconnect(Event event, const char[] name, bool dontBroadcast) 
{
	if(g_sMethod[AUTH].enabled)
	{
		char sName[32];
		event.GetString("name", sName, sizeof(sName));
			
		int client = GetClientOfUserId(event.GetInt("userid"));
			
		if(client != 0 && !IsClientInKickQueue(client))
		{
			g_sPlayer[client].IsInDisconnectQueue = true;
			
			char country[64];
			GetCountryPrefix(client, country, sizeof(country));
			
			char sUrl[1024];
			GetChannelData(g_sMethod[AUTH].channel, URL, sUrl, sizeof(sUrl));
			
			DiscordWebHook hook = new DiscordWebHook(sUrl);
			
			if(g_bEmbed)
			{
				MessageEmbed Embed = new MessageEmbed();
				
				Embed.SetTitle(g_sHostname);
				
				if(!StrEqual(g_sTitleLink, ""))
					Embed.SetTitleLink(g_sTitleLink);
				
				char sColor[32];
				GetChannelData(g_sMethod[AUTH].channel, COLOR, sColor, sizeof(sColor));
				Embed.SetColor(sColor);
				
				char sField[32], sType[32];
				
				Format(sField, sizeof(sField), "%T", "field_player", LANG_SERVER);
				Format(sName, sizeof(sName), "```%s```", sName);
				Embed.AddField(sField, sName, true);
				
				Format(sField, sizeof(sField), "%T", "field_auth", LANG_SERVER);
				Format(sType, sizeof(sType), "%T", "auth_disconnect", LANG_SERVER);
				Format(sType, sizeof(sType), "```%s```", sType);
				Embed.AddField(sField, sType, true);
				
				Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
			
				hook.Embed(Embed);
			}
			else
			{
				char sMessage[2048];
				char l[1], r[1], params[128];
				Format(l, sizeof(l), "(");
				Format(r, sizeof(r), ")");
				
				if(g_bLogCountry)
				{
					char sEmoji[32];
					GetCountryEmoji(client, sEmoji, sizeof(sEmoji));
					Format(country, sizeof(country), "%s %s", country, sEmoji);
					Format(params, sizeof(params), "%s", country);
				}
				if(g_bLogSteamID)
					Format(params, sizeof(params), "%s | %s", params, g_sPlayer[client].SteamID);
				if(g_bLogIP)
					Format(params, sizeof(params), "%s | %s", params, g_sPlayer[client].IP);
				
				Format(sMessage, sizeof(sMessage), "%s%s%s", l, params, r);
				Format(sMessage, sizeof(sMessage), "%T", "player_left", LANG_SERVER, client, sMessage);
				hook.SetContent(sMessage);
			}
			
			SendEmbed(hook, AUTH);
		}
		
		if(IsClientInKickQueue(client))
		{
			char country[64];
			GetCountryPrefix(client, country, sizeof(country));
			
			char sUrl[1024];
			GetChannelData(g_sMethod[KICK].channel, URL, sUrl, sizeof(sUrl));
			
			DiscordWebHook hook = new DiscordWebHook(sUrl);
			
			if(g_bEmbed)
			{
				MessageEmbed Embed = new MessageEmbed();
				
				Embed.SetTitle(g_sHostname);
				
				if(!StrEqual(g_sTitleLink, ""))
					Embed.SetTitleLink(g_sTitleLink);
				
				char sColor[32];
				GetChannelData(g_sMethod[KICK].channel, COLOR, sColor, sizeof(sColor));
				Embed.SetColor(sColor);
				
				char sField[32], sType[32];
				
				Format(sField, sizeof(sField), "%T", "field_player", LANG_SERVER);
				Format(sName, sizeof(sName), "```%s```", sName);
				Embed.AddField(sField, sName, true);
				
				Format(sField, sizeof(sField), "%T", "field_event", LANG_SERVER);
				Format(sType, sizeof(sType), "%T", "field_kick", LANG_SERVER);
				Format(sType, sizeof(sType), "```%s```", sType);
				Embed.AddField(sField, sType, true);
				
				Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
			
				hook.Embed(Embed);
			}
			else
			{
				char sMessage[2048];
				Format(sMessage, sizeof(sMessage), "%T", "player_kicked", LANG_SERVER, client);
				hook.SetContent(sMessage);
			}
			
			SendEmbed(hook, KICK);
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(g_sMethod[ENDPLAYERSALIVE].enabled)
	{
		char sUrl[1024];
		GetChannelData(g_sMethod[ENDPLAYERSALIVE].channel, URL, sUrl, sizeof(sUrl));
		
		DiscordWebHook hook = new DiscordWebHook(sUrl);
		
		int maxplayers, aliveplayers;
		char sPlayers[512] = "";
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientValid(i))
			{
				maxplayers++;
				
				if(IsPlayerAlive(i))
				{
					aliveplayers++;
					Format(sPlayers, sizeof(sPlayers), "%s\n %i - %N", sPlayers, i, i);
				}
			}
		}
		
		if(g_bEmbed)
		{
			MessageEmbed Embed = new MessageEmbed();
			Embed.SetTitle(g_sHostname);
			
			if(!StrEqual(g_sTitleLink, ""))
				Embed.SetTitleLink(g_sTitleLink);
			
			char sColor[32];
			GetChannelData(g_sMethod[ENDPLAYERSALIVE].channel, COLOR, sColor, sizeof(sColor));
			Embed.SetColor(sColor);
			
			char sField[32], sEvent[64];
			Format(sEvent, sizeof(sField), "%T", "roundend", LANG_SERVER, aliveplayers, maxplayers);
			Embed.AddField("", sField, false);
			
			Format(sField, sizeof(sField), "%T", "field_event", LANG_SERVER);
			Format(sEvent, sizeof(sEvent), "%T", "field_roundend", LANG_SERVER);
			Format(sEvent, sizeof(sEvent), "```%s```", sEvent);
			Embed.AddField(sField, sEvent, true);
			
			Embed.AddField("", sPlayers, false);
			
			Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
		
			hook.Embed(Embed);
		}
		else
		{
			char sMessage[2048], sTmp[64];
			Format(sMessage, sizeof(sMessage), "%T", "field_roundend", LANG_SERVER);
			Format(sTmp, sizeof(sTmp), "%T", "roundend", LANG_SERVER, aliveplayers, maxplayers);
			Format(sMessage, sizeof(sMessage), "%s \n\n %t \n\n %s", sMessage, sTmp, sPlayers);
			hook.SetContent(sMessage);
		}
		
		SendEmbed(hook, BANS);
	}
	
	return Plugin_Continue;
}

public void OnClientAuthorized(int client, const char[] auth) 
{	
	strcopy(g_sPlayer[client].SteamID, sizeof(g_sPlayer[].SteamID), auth);
	GetClientIP(client, g_sPlayer[client].IP, sizeof(g_sPlayer[].IP));
	
	g_sPlayer[client].IsInDisconnectQueue = false;
	
	if(g_sMethod[AUTH].enabled)
	{
		char name[64];
		GetClientName(client, name, sizeof(name));
		
		char country[64];
		GetCountryPrefix(client, country, sizeof(country));
		
		char sUrl[1024];
		GetChannelData(g_sMethod[AUTH].channel, URL, sUrl, sizeof(sUrl));
		
		DiscordWebHook hook = new DiscordWebHook(sUrl);
		
		if(g_bEmbed)
		{
			MessageEmbed Embed = new MessageEmbed();
			Embed.SetTitle(g_sHostname);
			
			if(!StrEqual(g_sTitleLink, ""))
				Embed.SetTitleLink(g_sTitleLink);
			
			char sColor[32];
			GetChannelData(g_sMethod[AUTH].channel, COLOR, sColor, sizeof(sColor));
			Embed.SetColor(sColor);
			
			char sField[32], sType[32], sValue[64];
			
			Format(sField, sizeof(sField), "%T", "field_player", LANG_SERVER);
			Format(name, sizeof(name), "```%s```", name);
			Embed.AddField(sField, name, true);
			
			Format(sField, sizeof(sField), "%T", "field_auth", LANG_SERVER);
			Format(sType, sizeof(sType), "%T", "auth_connect", LANG_SERVER);
			Format(sType, sizeof(sType), "```%s```", sType);
			Embed.AddField(sField, sType, true);
			
			if(g_bLogCountry)
			{
				char sEmoji[32];
				GetCountryEmoji(client, sEmoji, sizeof(sEmoji));
				Format(country, sizeof(country), "%s %s", country, sEmoji);

				Format(sField, sizeof(sField), "%T", "field_country", LANG_SERVER);
				Embed.AddField(sField, country, true);
			}
			if(g_bLogSteamID)
			{
				Format(sField, sizeof(sField), "%T", "field_steamid", LANG_SERVER);
				Format(sValue, sizeof(sValue), "```%s```", g_sPlayer[client].SteamID);
				Embed.AddField(sField, sValue, true);
			}
			if(g_bLogIP)
			{
				Format(sField, sizeof(sField), "%T", "field_ip", LANG_SERVER);
				Format(sValue, sizeof(sValue), "```%s```", g_sPlayer[client].IP);
				Embed.AddField(sField, sValue, true);
			}
			
			Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
		
			hook.Embed(Embed);
		}
		else
		{
			char sMessage[2048];
			char l[1], r[1], params[128];
			Format(l, sizeof(l), "(");
			Format(r, sizeof(r), ")");
			
			if(g_bLogCountry)
			{
				char sEmoji[32];
				GetCountryEmoji(client, sEmoji, sizeof(sEmoji));
				Format(country, sizeof(country), "%s %s", country, sEmoji);
				Format(params, sizeof(params), "%s", country);
			}
			if(g_bLogSteamID)
				Format(params, sizeof(params), "%s | %s", params, g_sPlayer[client].SteamID);
			if(g_bLogIP)
				Format(params, sizeof(params), "%s | %s", params, g_sPlayer[client].IP);
			
			Format(sMessage, sizeof(sMessage), "%s%s%s", l, params, r);
			Format(sMessage, sizeof(sMessage), "%T", "player_join", LANG_SERVER, client, sMessage);
			hook.SetContent(sMessage);
		}
		
		SendEmbed(hook, AUTH);
	}
}

public void SBPP_OnBanPlayer(int iAdmin, int iTarget, int iTime, const char[] sReason)
{
	if(g_sMethod[BANS].enabled)
	{
		char tName[64];
		GetClientName(iTarget, tName, sizeof(tName));
		
		char aName[64];
		GetClientName(iAdmin, aName, sizeof(aName));
		
		char sUrl[1024];
		GetChannelData(g_sMethod[BANS].channel, URL, sUrl, sizeof(sUrl));
		
		DiscordWebHook hook = new DiscordWebHook(sUrl);
		
		if(g_bEmbed)
		{
			MessageEmbed Embed = new MessageEmbed();
			Embed.SetTitle(g_sHostname);
			
			if(!StrEqual(g_sTitleLink, ""))
				Embed.SetTitleLink(g_sTitleLink);
			
			char sColor[32];
			GetChannelData(g_sMethod[BANS].channel, COLOR, sColor, sizeof(sColor));
			Embed.SetColor(sColor);
			
			char sField[32], sEvent[64];
			
			Format(sField, sizeof(sField), "%T", "field_event", LANG_SERVER);
			Format(sEvent, sizeof(sEvent), "%T", "field_ban", LANG_SERVER);
			Format(sEvent, sizeof(sEvent), "```%s```", sEvent);
			Embed.AddField(sField, sEvent, true);
			
			Format(sField, sizeof(sField), "%T", "field_player", LANG_SERVER);
			Format(tName, sizeof(tName), "```%s```", tName);
			Embed.AddField(sField, tName, true);
			
			Format(sField, sizeof(sField), "%T", "field_admin", LANG_SERVER);
			Format(aName, sizeof(aName), "```%s```", aName);
			Embed.AddField(sField, aName, true);
			
			char reason[128];
			Format(sField, sizeof(sField), "%T", "field_raison", LANG_SERVER);
			Format(reason, sizeof(reason), "```%s```", sReason);
			Embed.AddField(sField, reason, true);
			
			char time[128];

			int iYear, iMonth, iDay, iHour, iMinute, iSecond;
			UnixToTime((GetTime() + (iTime)/60), iYear, iMonth, iDay, iHour, iMinute, iSecond, UT_TIMEZONE_CEST);
			
			Format(sField, sizeof(sField), "%T", "field_time", LANG_SERVER);
			Format(time, sizeof(time), "```%02d/%02d/%d - %02d:%02d:%02d```", iDay, iMonth, iYear, iHour, iMinute, iSecond);
			Embed.AddField(sField, time, true);
			
			Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
		
			hook.Embed(Embed);
		}
		else
		{
			char sMessage[2048];
			Format(sMessage, sizeof(sMessage), "%T", "player_banned", LANG_SERVER, iTarget, iAdmin, sReason);
			hook.SetContent(sMessage);
		}
		
		SendEmbed(hook, BANS);
	}
}

public void BaseComm_OnClientGag(int client, bool gagState)
{
	if(g_sMethod[GAG].enabled)
	{
		char sUrl[1024];
		GetChannelData(g_sMethod[GAG].channel, URL, sUrl, sizeof(sUrl));
		
		DiscordWebHook hook = new DiscordWebHook(sUrl);
		
		if(g_bEmbed)
		{
			MessageEmbed Embed = new MessageEmbed();
			Embed.SetTitle(g_sHostname);
			
			if(!StrEqual(g_sTitleLink, ""))
				Embed.SetTitleLink(g_sTitleLink);
			
			char sColor[32];
			GetChannelData(g_sMethod[GAG].channel, COLOR, sColor, sizeof(sColor));
			Embed.SetColor(sColor);
			
			char sField[32], sTmp[128];
			Format(sField, sizeof(sField), "%T", "field_player", LANG_SERVER);
			Format(sTmp, sizeof(sTmp), "```%N```", client);
			Embed.AddField(sField, sTmp, true);
			
			char sStatus[32];
			Format(sField, sizeof(sField), "%T", "field_status", LANG_SERVER);
			Format(sStatus, sizeof(sStatus), "```%t```", (gagState) ? "gag" : "ungag", LANG_SERVER);
			Embed.AddField(sField, sStatus, true);
			
			Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
		
			hook.Embed(Embed);
		}
		else
		{
			
		}
		
		SendEmbed(hook, GAG);
	}
}

void SendEmbed(DiscordWebHook hook, METHODS type)
{
	char sColor[32];
	GetChannelData(g_sMethod[type].channel, COLOR, sColor, sizeof(sColor));

	hook.SlackMode = g_bEmbed;
	
	if(!StrEqual(g_sMethod[type].tag, ""))
		hook.SetContent(g_sMethod[type].tag);
	
	hook.SetUsername(g_sUsername);
	
	hook.Send();
	delete hook;
}

public Action Timer_Information(Handle timer)
{
	char sUrl[1024];
	GetChannelData(g_sMethod[INFO].channel, URL, sUrl, sizeof(sUrl));
	
	DiscordWebHook hook = new DiscordWebHook(sUrl);
	
	if(g_bEmbed)
	{
		MessageEmbed Embed = new MessageEmbed();
		
		Embed.SetTitle(g_sHostname);
		
		char sLink[64];
		GetServerAdress(sLink, sizeof(sLink));
		
		if(!StrEqual(g_sTitleLink, ""))
			Embed.SetTitleLink(g_sTitleLink);
		
		char sColor[32];
		GetChannelData(g_sMethod[INFO].channel, COLOR, sColor, sizeof(sColor));
		Embed.SetColor(sColor);
		
		char sField[32], sTmp[64];
		
		Format(sField, sizeof(sField), "%T", "field_playerscount", LANG_SERVER);
		Format(sTmp, sizeof(sTmp), "```%i/%i```", GetRealClientCount(), GetMaxHumanPlayers());
		Embed.AddField(sField, sTmp, true);
	
		char sMap[64];
		logger_GetMap(sMap, sizeof(sMap));
		
		char sGame[64], image_url[512];
		GetGameFolderName(sGame, sizeof(sGame));
		Format(image_url, sizeof(image_url), "https://image.gametracker.com/images/maps/160x120/%s/%s.jpg", sGame, sMap);
		
		Format(sMap, sizeof(sMap), "```%s```", sMap);
		Format(sField, sizeof(sField), "%T", "field_map", LANG_SERVER);
		Embed.AddField(sField, sMap, true);
		
		if(g_bLogConnectIP)
		{
			Format(sField, sizeof(sField), "%T", "field_connect", LANG_SERVER);
			Embed.AddField(sField, sLink, false);
		}

		Embed.SetImage(image_url);
		
		Embed.SetFooter("SM Discord Logger V2 By Benito(MbK)");
	
		hook.Embed(Embed);
	}
	else
	{
		char sMessage[2048];
		Format(sMessage, sizeof(sMessage), "IN DEVELOPMENT");
		hook.SetContent(sMessage);
	}
	
	SendEmbed(hook, INFO);
	
	return Plugin_Handled;
}

void GetChannelData(char[] channel, CHANNELDATA type, char[] buffer, int maxlength)
{
	char sTmp[2048];
	for (int i = 0; i < g_aChannels.Length; i++) 
	{
		g_aChannels.GetString(i, sTmp, sizeof(sTmp));
		
		char sBuffer[3][512];
		ExplodeString(sTmp, "|", sBuffer, 3, 512);
		
		if(StrEqual(channel, sBuffer[0]))
		{
			switch(type)
			{
				case COLOR:strcopy(buffer, maxlength, sBuffer[1]);
				case URL:strcopy(buffer, maxlength, sBuffer[2]);
			}
		}			
	}
}

void logger_GetMap(char[] map, int maxlength)
{
	char tmp[128];
	GetCurrentMap(tmp, sizeof(tmp));
	if (StrContains(tmp, "workshop") != -1) {
		char mapPart[3][64];
		ExplodeString(tmp, "/", mapPart, 3, 64);
		strcopy(map, maxlength, mapPart[2]);
	}
	else
		strcopy(map, maxlength, tmp);
}

void GetServerAdress(char[] buffer, int maxlen)
{
	char sBuff[64];
	int ip[4];
	SteamWorks_GetPublicIP(ip);
	if(SteamWorks_GetPublicIP(ip)) 
	{
		Format(sBuff, sizeof(sBuff), "steam://connect/%d.%d.%d.%d:%d", ip[0], ip[1], ip[2], ip[3], FindConVar("hostport").IntValue);
		
	}
	else {
		int iIPB = FindConVar("hostip").IntValue;
		Format(sBuff, sizeof(sBuff), "steam://connect/%d.%d.%d.%d:%d", iIPB >> 24 & 0x000000FF, iIPB >> 16 & 0x000000FF, iIPB >> 8 & 0x000000FF, iIPB & 0x000000FF, FindConVar("hostport").IntValue);
	}
	
	strcopy(buffer, maxlen, sBuff);
}

bool IsClientValid(int client = -1, bool bAlive = false) 
{
	return MaxClients >= client > 0 && IsClientConnected(client) && !IsFakeClient(client) && IsClientInGame(client) && (!bAlive || IsPlayerAlive(client)) ? true : false;
}

int GetRealClientCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i)) count++;
	}

	return count;
}

void GetCountryPrefix(int client, char[] buffer, int maxlen)
{
	char ip[32];
	GetClientIP(client, ip, sizeof(ip));
	GeoipCountry(ip, buffer, maxlen);
}

void GetCountryEmoji(int client, char[] buffer, int maxlen)
{
	char sPrefix[3];
	GeoipCode2(g_sPlayer[client].IP, sPrefix);
	if(StrEqual(sPrefix, ""))
	{
		strcopy(buffer, maxlen, "Unknown :pirate_flag:");
	}
	else
	{
		char sEmoji[16];
		Format(sEmoji, sizeof(sEmoji), ":flag_%s:", sPrefix);
		StringToLowerCase(sEmoji);
		strcopy(buffer, maxlen, sEmoji);
	}
}

void StringToLowerCase(char[] input)
{
    for (int i = 0; i < strlen(input); i++)
    {
        input[i] = CharToLower(input[i]);
    }
}