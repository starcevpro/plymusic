#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Starcev"
#define PLUGIN_VERSION "1.0"

#define LOG_PREFIX "[PlyMusic]"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
//#include <sdkhooks>


#pragma newdecls required

Database pmDatabase;

public Plugin myinfo = 
{
	name = "PlyMusic", 
	author = PLUGIN_AUTHOR, 
	description = "Music at the entrance to the server for players", 
	version = PLUGIN_VERSION, 
	url = "https://vk.com/e_dev"
}

public void OnMapStart()
{
	
	Database.Connect(MysqlConnected, "plymusic");
	
}

public void OnClientPostAdminCheck(int iClient)
{
	if(!IsFakeClient(iClient))
	{
		int iAccountID = GetSteamAccountID(iClient);
		
		LogMessage("Проверка игрока %i", iAccountID);
		
		char szQuery[256];
		
		FormatEx(szQuery, sizeof(szQuery), "SELECT `account_id`, `music`, `expires` FROM `plymusic` WHERE `account_id` = %i;", iAccountID);
		pmDatabase.Query(MysqlPlayMusic, szQuery, iClient);
	}
}

public void MysqlConnected (Database hDB, const char[] pmError, any data)
{
	if (hDB == null)
	{
		LogError("Ошибка подключения к Mysql: %s", pmError);
		return;
	}
	
	LogMessage("Успешное подключение к Mysql");
	
	pmDatabase = hDB;
	
	SQL_LockDatabase(pmDatabase);
															
	pmDatabase.Query(MysqlCreateDataBase,	"CREATE TABLE IF NOT EXISTS `plymusic` (\
												  `account_id` int(11) NOT NULL PRIMARY KEY,\
												  `music` varchar(64) NOT NULL,\
												  `expires` int(10) UNSIGNED NOT NULL DEFAULT '0'\
												)ENGINE = InnoDB DEFAULT CHARSET = utf8; ");
															
	SQL_UnlockDatabase(pmDatabase);
	
	MysqlDeletePlayerMusic();
	
	pmDatabase.Query(MysqlGetMusics, "SELECT `music` FROM `plymusic`;", 0);
	
	pmDatabase.SetCharset("utf8");
}

public void MysqlGetMusics(Database hDatabase, DBResultSet pmResults, const char[] pmError, int Noll)
{
	
	if(pmError[0])
	{
		LogError("Ошибка получения музыки: %s", pmError);
	}
	
	if(pmResults.FetchRow())
	{
		LogMessage("В базе есть игроки с музыкой, загружаю музыку...");
		
		do {
			char pmMusic[64];
			pmResults.FetchString(0, pmMusic, sizeof(pmMusic));
			
			char pmMusicDir[100];
			FormatEx(pmMusicDir, sizeof(pmMusicDir), "sound/%s", pmMusic);
			
			LogMessage("Получаю песню: %s", pmMusicDir);
			
			if (FileExists(pmMusicDir)) {
				AddFileToDownloadsTable(pmMusicDir);
				PrecacheSound(pmMusic, true);
			} else {
				LogError("Не найден файл с музыкой");
			}
		} while (pmResults.FetchMoreResults());
		
		LogMessage("Все песни загружены и прекешированы!");
	} else {
		LogMessage("В базе нет игроков с музыкой");
	}
}

public void MysqlCreateDataBase(Database hDatabase, DBResultSet results, const char[] pmError, any data)
{
	if(pmError[0])
	{
		LogError("Ошибка создания базы данных: %s", pmError);
	}
}

public void MysqlPlayMusic(Database hDatabase, DBResultSet pmResults, const char[] pmError, int iClient)
{
	if(pmError[0])
	{
		LogError("Ошибка получения музыки игрока: %s", pmError);
		return;
	}
	
	char plyName[33];
	GetClientName(iClient, plyName, sizeof(plyName));
	
	if(iClient)
	{
		char szQuery[256], szName[MAX_NAME_LENGTH*2+1];
		GetClientName(iClient, szQuery, MAX_NAME_LENGTH);
		pmDatabase.Escape(szQuery, szName, sizeof(szName));

		if(pmResults.FetchRow())
		{
			LogMessage("У игрока %s есть запись с музыкой", plyName);
				
			char pmMusic[64];
			pmResults.FetchString(1, pmMusic, sizeof(pmMusic));
			
			LogMessage("Воспроизведение музыки: %s", pmMusic);
			
			PrecacheSound(pmMusic);
			EmitSoundToAll(pmMusic, SOUND_FROM_LOCAL_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_NOFLAGS, 0.4);
			
		} else {
			LogMessage("Игрок %s не найден в базе", plyName);
		}
	}
}

public void MysqlDeletePlayerMusic()
{
	
	char szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `plymusic` WHERE `expires` < %i AND `expires` <> 0;", GetTime());
	pmDatabase.Query(MysqlDeletePlayerMusic_callback, szQuery);

}

public void MysqlDeletePlayerMusic_callback(Database hOwner, DBResultSet hResult, const char[] pmError, DataPack hPack)
{
	
	if(pmError[0])
	{
		LogError("Ошибка при удалении пользователей: %s", pmError);
		return;
	} else {
		LogMessage("Удалены пользователи у которых истек срок музыки");
	}
	
}