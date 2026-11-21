/*
    DUKTUR RP - Kalici Kayit ve Giris Sistemi (filterscript)
    - SQLite (duktur_rp.db) - ek plugin GEREKMEZ
    - Ilk giris: kayit (sifre, karakter adi, yas) -> veritabanina kalici yazilir
    - Sonraki giris: sadece kullanici adi + sifre
    - Isim koruma: online + TUM kayitli hesaplar (kullanici adi ve karakter adi), buyuk/kucuk harf duyarsiz
    - Guvenlik: SHA256 + salt, 3 yanlis denemede 5 dk hesap kilidi
    Gereksinim: SA-MP 0.3.7 R2+ (SHA256_PassHash)
    NOT: Dosyayi ANSI (Windows-1254) kaydet; metinler bilerek ASCII yazildi.
*/

#include <a_samp>

#pragma dynamic 16384

#define DB_FILE         "duktur_rp.db"

#define DLG_USER        7100
#define DLG_LOGIN       7101
#define DLG_REGPASS     7102
#define DLG_REGPASS2    7103
#define DLG_REGCHAR     7104
#define DLG_REGAGE      7105

#define MAX_TRIES       3
#define LOCK_SECONDS    300
#define MIN_PASS        6
#define MIN_AGE         14
#define MAX_AGE         80

#define SPAWN_X         1759.0189
#define SPAWN_Y         -1898.1260
#define SPAWN_Z         13.5622
#define SPAWN_A         270.0
#define SPAWN_SKIN      29

#define COL_ERR         0xFF4444FF
#define COL_OK          0x33CC33FF
#define COL_INFO        0xFFCC00FF

new DB:gDB;
new pLogged[MAX_PLAYERS];
new pAccID[MAX_PLAYERS];
new pAge[MAX_PLAYERS];
new pTries[MAX_PLAYERS];
new pTmpUser[MAX_PLAYERS][25];
new pTmpPlain[MAX_PLAYERS][33];
new pTmpHash[MAX_PLAYERS][65];
new pTmpSalt[MAX_PLAYERS][17];
new pTmpChar[MAX_PLAYERS][25];

forward KG_Start(playerid);
forward KG_Kick(playerid);
forward KG_IsLogged(playerid);
forward KG_GetAccountID(playerid);
forward KG_GetAge(playerid);

// ---------------------------------------------------------------- yardimcilar

stock KG_Esc(const src[], dest[], size = sizeof dest)
{
    new j = 0;
    for (new i = 0; src[i] != 0 && j < size - 2; i++)
    {
        if (src[i] == '\'') dest[j++] = '\'';
        dest[j++] = src[i];
    }
    dest[j] = 0;
}

stock KG_Exec(const query[])
{
    new DBResult:r = db_query(gDB, query);
    if (r) { db_free_result(r); return 1; }
    return 0;
}

stock KG_ValidName(const name[])
{
    new len = strlen(name);
    if (len < 3 || len > 20) return 0;
    for (new i = 0; i < len; i++)
    {
        new c = name[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
            || c == '_' || c == '.' || c == '[' || c == ']' || c == '(' || c == ')'
            || c == '$' || c == '=' || c == '@')) return 0;
    }
    return 1;
}

// Isim online biri tarafindan VEYA kayitli herhangi bir hesap tarafindan kullaniliyor mu?
stock KG_NameTaken(const name[], exceptPlayer)
{
    new pn[MAX_PLAYER_NAME + 1];
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || i == exceptPlayer) continue;
        GetPlayerName(i, pn, sizeof pn);
        if (!strcmp(pn, name, true)) return 1;
    }
    new esc[64], q[256], taken = 0;
    KG_Esc(name, esc);
    format(q, sizeof q, "SELECT id FROM accounts WHERE username='%s' COLLATE NOCASE OR char_name='%s' COLLATE NOCASE LIMIT 1", esc, esc);
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        taken = (db_num_rows(r) > 0);
        db_free_result(r);
    }
    return taken;
}

// Kullanici adi veya karakter adi ile hesap bul; gercek kullanici adini dest'e yazar
stock KG_FindUser(const name[], dest[], size = sizeof dest)
{
    new esc[64], q[256], found = 0;
    KG_Esc(name, esc);
    format(q, sizeof q, "SELECT username FROM accounts WHERE username='%s' COLLATE NOCASE OR char_name='%s' COLLATE NOCASE LIMIT 1", esc, esc);
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        if (db_num_rows(r) > 0)
        {
            db_get_field(r, 0, dest, size);
            found = 1;
        }
        db_free_result(r);
    }
    return found;
}

stock KG_MakeSalt(dest[])
{
    for (new i = 0; i < 16; i++)
    {
        if (random(2)) dest[i] = 'a' + random(26);
        else dest[i] = '0' + random(10);
    }
    dest[16] = 0;
}

stock KG_KickDelay(playerid)
{
    SetTimerEx("KG_Kick", 500, false, "i", playerid);
}

public KG_Kick(playerid)
{
    if (IsPlayerConnected(playerid)) Kick(playerid);
    return 1;
}

stock KG_ResetPlayer(playerid)
{
    pLogged[playerid] = 0;
    pAccID[playerid] = 0;
    pAge[playerid] = 0;
    pTries[playerid] = 0;
    pTmpUser[playerid][0] = 0;
    pTmpPlain[playerid][0] = 0;
    pTmpHash[playerid][0] = 0;
    pTmpSalt[playerid][0] = 0;
    pTmpChar[playerid][0] = 0;
}

// ---------------------------------------------------------------- dialoglar

stock KG_ShowUser(playerid)
{
    ShowPlayerDialog(playerid, DLG_USER, DIALOG_STYLE_INPUT, "DUKTUR RP - Giris / Kayit",
        "{FFFFFF}DUKTUR RP'ye hos geldiniz.\n\nKullanici adinizi yazin.\n{AAAAAA}Hesabiniz varsa giris, yoksa kayit ekrani acilir.",
        "Devam", "Cikis");
}

stock KG_ShowLogin(playerid)
{
    new esc[64], q[200], str[256], tmp[16], lock = 0;
    KG_Esc(pTmpUser[playerid], esc);
    format(q, sizeof q, "SELECT lock_until FROM accounts WHERE username='%s' COLLATE NOCASE", esc);
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        if (db_num_rows(r) > 0)
        {
            db_get_field(r, 0, tmp, sizeof tmp);
            lock = strval(tmp);
        }
        db_free_result(r);
    }
    if (lock > gettime())
    {
        format(str, sizeof str, "Bu hesap cok fazla hatali giris nedeniyle kilitli. Kalan sure: %d sn.", lock - gettime());
        SendClientMessage(playerid, COL_ERR, str);
        KG_KickDelay(playerid);
        return 1;
    }
    format(str, sizeof str, "{FFFFFF}Kullanici adi: {FFCC00}%s\n\n{FFFFFF}Sifrenizi girin.\n{AAAAAA}Kalan deneme hakki: %d", pTmpUser[playerid], MAX_TRIES - pTries[playerid]);
    ShowPlayerDialog(playerid, DLG_LOGIN, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Giris", str, "Giris", "Cikis");
    return 1;
}

stock KG_ShowRegPass(playerid)
{
    new str[256];
    format(str, sizeof str, "{FFFFFF}Yeni hesap olusturuluyor: {FFCC00}%s\n\n{FFFFFF}Bir sifre belirleyin ({FFCC00}%d-32{FFFFFF} karakter).", pTmpUser[playerid], MIN_PASS);
    ShowPlayerDialog(playerid, DLG_REGPASS, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Kayit (1/3)", str, "Ileri", "Geri");
}

stock KG_ShowRegPass2(playerid)
{
    ShowPlayerDialog(playerid, DLG_REGPASS2, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Kayit (1/3)",
        "{FFFFFF}Sifrenizi tekrar girin.", "Ileri", "Geri");
}

stock KG_ShowRegChar(playerid)
{
    ShowPlayerDialog(playerid, DLG_REGCHAR, DIALOG_STYLE_INPUT, "DUKTUR RP - Kayit (2/3)",
        "{FFFFFF}Karakter adinizi yazin.\n{AAAAAA}Ornek: Ahmet_Yilmaz (3-20 karakter, harf/rakam/_ )",
        "Ileri", "Geri");
}

stock KG_ShowRegAge(playerid)
{
    new str[160];
    format(str, sizeof str, "{FFFFFF}Karakterinizin yasini girin ({FFCC00}%d-%d{FFFFFF}).", MIN_AGE, MAX_AGE);
    ShowPlayerDialog(playerid, DLG_REGAGE, DIALOG_STYLE_INPUT, "DUKTUR RP - Kayit (3/3)", str, "Kaydol", "Geri");
}

// ---------------------------------------------------------------- giris tamamlama

stock KG_Complete(playerid, accid, const charname[], age)
{
    new cur[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, cur, sizeof cur);

    if (strcmp(cur, charname, false))
    {
        if (SetPlayerName(playerid, charname) == -1)
        {
            SendClientMessage(playerid, COL_ERR, "Karakter adiniz su an baska bir oyuncu tarafindan kullaniliyor. Lutfen tekrar deneyin.");
            KG_KickDelay(playerid);
            return 0;
        }
    }

    pLogged[playerid] = 1;
    pAccID[playerid] = accid;
    pAge[playerid] = age;
    pTries[playerid] = 0;

    new ip[20], q[200];
    GetPlayerIp(playerid, ip, sizeof ip);
    format(q, sizeof q, "UPDATE accounts SET last_login=%d, last_ip='%s', lock_until=0 WHERE id=%d", gettime(), ip, accid);
    KG_Exec(q);

    new msg[128];
    format(msg, sizeof msg, "Hos geldin, %s! Basariyla giris yaptin.", charname);
    SendClientMessage(playerid, COL_OK, msg);

    SetSpawnInfo(playerid, NO_TEAM, SPAWN_SKIN, SPAWN_X, SPAWN_Y, SPAWN_Z, SPAWN_A, 0, 0, 0, 0, 0, 0);
    TogglePlayerSpectating(playerid, 0);

    CallRemoteFunction("OnPlayerAccountLogin", "i", playerid);
    return 1;
}

// ---------------------------------------------------------------- callbackler

public OnFilterScriptInit()
{
    gDB = db_open(DB_FILE);
    if (!_:gDB)
    {
        print("[KAYIT] HATA: veritabani acilamadi!");
        return 1;
    }
    new tq[700];
    tq = "CREATE TABLE IF NOT EXISTS accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, ";
    strcat(tq, "username TEXT NOT NULL UNIQUE COLLATE NOCASE, ");
    strcat(tq, "char_name TEXT NOT NULL UNIQUE COLLATE NOCASE, ");
    strcat(tq, "pass_hash TEXT NOT NULL, salt TEXT NOT NULL, age INTEGER NOT NULL, ");
    strcat(tq, "reg_date INTEGER DEFAULT 0, last_login INTEGER DEFAULT 0, ");
    strcat(tq, "last_ip TEXT DEFAULT '', lock_until INTEGER DEFAULT 0)");
    KG_Exec(tq);

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        KG_ResetPlayer(i);
        if (IsPlayerConnected(i)) SetTimerEx("KG_Start", 500, false, "i", i);
    }
    print("[KAYIT] DUKTUR RP kayit/giris sistemi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    if (_:gDB) db_close(gDB);
    return 1;
}

public OnPlayerConnect(playerid)
{
    KG_ResetPlayer(playerid);
    SetTimerEx("KG_Start", 800, false, "i", playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    KG_ResetPlayer(playerid);
    return 1;
}

public KG_Start(playerid)
{
    if (!IsPlayerConnected(playerid) || pLogged[playerid]) return 0;
    TogglePlayerSpectating(playerid, 1);

    new name[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, name, sizeof name);
    if (KG_FindUser(name, pTmpUser[playerid], 25))
    {
        KG_ShowLogin(playerid);   // kayitli oyuncu: yalnizca sifre
    }
    else
    {
        KG_ShowUser(playerid);
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    if (!pLogged[playerid]) return 0;
    return 1;
}

public OnPlayerText(playerid, text[])
{
    if (!pLogged[playerid]) return 0;
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!pLogged[playerid])
    {
        SendClientMessage(playerid, COL_ERR, "Once giris yapmalisiniz.");
        return 1;
    }
    return 0;
}

public KG_IsLogged(playerid) return pLogged[playerid];
public KG_GetAccountID(playerid) return pAccID[playerid];
public KG_GetAge(playerid) return pAge[playerid];

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DLG_USER:
        {
            if (!response) { KG_KickDelay(playerid); return 1; }
            new name[32];
            strmid(name, inputtext, 0, 31, sizeof name);
            if (!KG_ValidName(name))
            {
                SendClientMessage(playerid, COL_ERR, "Gecersiz kullanici adi (3-20 karakter; harf, rakam ve _ kullanin).");
                KG_ShowUser(playerid);
                return 1;
            }
            if (KG_FindUser(name, pTmpUser[playerid], 25))
            {
                pTries[playerid] = 0;
                KG_ShowLogin(playerid);
                return 1;
            }
            if (KG_NameTaken(name, playerid))
            {
                SendClientMessage(playerid, COL_ERR, "Bu isim su an baska bir oyuncu tarafindan kullaniliyor.");
                KG_ShowUser(playerid);
                return 1;
            }
            format(pTmpUser[playerid], 25, "%s", name);
            KG_ShowRegPass(playerid);
            return 1;
        }

        case DLG_LOGIN:
        {
            if (!response) { KG_KickDelay(playerid); return 1; }
            if (!strlen(inputtext)) { KG_ShowLogin(playerid); return 1; }

            new esc[64], q[300], tmp[16];
            KG_Esc(pTmpUser[playerid], esc);
            format(q, sizeof q, "SELECT id, pass_hash, salt, char_name, age, lock_until FROM accounts WHERE username='%s' COLLATE NOCASE", esc);
            new DBResult:r = db_query(gDB, q);
            if (!r || db_num_rows(r) < 1)
            {
                if (r) db_free_result(r);
                SendClientMessage(playerid, COL_ERR, "Hesap bulunamadi.");
                KG_ShowUser(playerid);
                return 1;
            }

            new accid, age, lock, dbhash[65], salt[17], charname[25], hash[65];
            db_get_field(r, 0, tmp, sizeof tmp); accid = strval(tmp);
            db_get_field(r, 1, dbhash, sizeof dbhash);
            db_get_field(r, 2, salt, sizeof salt);
            db_get_field(r, 3, charname, sizeof charname);
            db_get_field(r, 4, tmp, sizeof tmp); age = strval(tmp);
            db_get_field(r, 5, tmp, sizeof tmp); lock = strval(tmp);
            db_free_result(r);

            if (lock > gettime())
            {
                SendClientMessage(playerid, COL_ERR, "Bu hesap gecici olarak kilitli.");
                KG_KickDelay(playerid);
                return 1;
            }

            for (new i = 0; i < MAX_PLAYERS; i++)
            {
                if (i != playerid && IsPlayerConnected(i) && pLogged[i] && pAccID[i] == accid)
                {
                    SendClientMessage(playerid, COL_ERR, "Bu hesap su an baska bir oyuncu tarafindan kullaniliyor.");
                    KG_KickDelay(playerid);
                    return 1;
                }
            }

            SHA256_PassHash(inputtext, salt, hash, sizeof hash);
            if (!strcmp(hash, dbhash, false) && strlen(dbhash) > 0)
            {
                KG_Complete(playerid, accid, charname, age);
            }
            else
            {
                pTries[playerid]++;
                if (pTries[playerid] >= MAX_TRIES)
                {
                    format(q, sizeof q, "UPDATE accounts SET lock_until=%d WHERE id=%d", gettime() + LOCK_SECONDS, accid);
                    KG_Exec(q);
                    SendClientMessage(playerid, COL_ERR, "Cok fazla hatali sifre! Hesap 5 dakika kilitlendi.");
                    KG_KickDelay(playerid);
                }
                else
                {
                    SendClientMessage(playerid, COL_ERR, "Hatali sifre!");
                    KG_ShowLogin(playerid);
                }
            }
            return 1;
        }

        case DLG_REGPASS:
        {
            if (!response) { KG_ShowUser(playerid); return 1; }
            new len = strlen(inputtext);
            if (len < MIN_PASS || len > 32)
            {
                SendClientMessage(playerid, COL_ERR, "Sifre 6-32 karakter arasinda olmali.");
                KG_ShowRegPass(playerid);
                return 1;
            }
            format(pTmpPlain[playerid], 33, "%s", inputtext);
            KG_ShowRegPass2(playerid);
            return 1;
        }

        case DLG_REGPASS2:
        {
            if (!response) { KG_ShowRegPass(playerid); return 1; }
            if (strcmp(inputtext, pTmpPlain[playerid], false) != 0)
            {
                SendClientMessage(playerid, COL_ERR, "Sifreler eslesmiyor.");
                KG_ShowRegPass(playerid);
                return 1;
            }
            KG_MakeSalt(pTmpSalt[playerid]);
            SHA256_PassHash(pTmpPlain[playerid], pTmpSalt[playerid], pTmpHash[playerid], 65);
            pTmpPlain[playerid][0] = 0;
            KG_ShowRegChar(playerid);
            return 1;
        }

        case DLG_REGCHAR:
        {
            if (!response) { KG_ShowRegPass(playerid); return 1; }
            new name[32];
            strmid(name, inputtext, 0, 31, sizeof name);
            if (!KG_ValidName(name))
            {
                SendClientMessage(playerid, COL_ERR, "Gecersiz karakter adi (3-20 karakter; harf, rakam ve _ kullanin).");
                KG_ShowRegChar(playerid);
                return 1;
            }
            if (KG_NameTaken(name, playerid))
            {
                SendClientMessage(playerid, COL_ERR, "Bu isim daha once alinmis veya su an kullaniliyor. Baska bir isim secin.");
                KG_ShowRegChar(playerid);
                return 1;
            }
            format(pTmpChar[playerid], 25, "%s", name);
            KG_ShowRegAge(playerid);
            return 1;
        }

        case DLG_REGAGE:
        {
            if (!response) { KG_ShowRegChar(playerid); return 1; }
            new age = strval(inputtext);
            if (age < MIN_AGE || age > MAX_AGE)
            {
                SendClientMessage(playerid, COL_ERR, "Gecersiz yas.");
                KG_ShowRegAge(playerid);
                return 1;
            }

            // son kontrol (yaris durumu): isim hala bos mu?
            if (KG_NameTaken(pTmpChar[playerid], playerid) || KG_NameTaken(pTmpUser[playerid], playerid))
            {
                SendClientMessage(playerid, COL_ERR, "Bu isim bu sirada baskasi tarafindan alindi. Yeniden deneyin.");
                KG_ShowUser(playerid);
                return 1;
            }

            new eu[64], ec[64], ip[20], q[600];
            KG_Esc(pTmpUser[playerid], eu);
            KG_Esc(pTmpChar[playerid], ec);
            GetPlayerIp(playerid, ip, sizeof ip);
            format(q, sizeof q, "INSERT INTO accounts (username, char_name, pass_hash, salt, age, reg_date, last_login, last_ip) VALUES ('%s','%s','%s','%s',%d,%d,%d,'%s')",
                eu, ec, pTmpHash[playerid], pTmpSalt[playerid], age, gettime(), gettime(), ip);
            if (!KG_Exec(q))
            {
                SendClientMessage(playerid, COL_ERR, "Kayit basarisiz oldu (isim kullanimda olabilir). Tekrar deneyin.");
                KG_ShowUser(playerid);
                return 1;
            }

            format(q, sizeof q, "SELECT id FROM accounts WHERE username='%s' COLLATE NOCASE", eu);
            new DBResult:r = db_query(gDB, q), accid = 0, tmp[16];
            if (r)
            {
                if (db_num_rows(r) > 0) { db_get_field(r, 0, tmp, sizeof tmp); accid = strval(tmp); }
                db_free_result(r);
            }
            if (!accid)
            {
                SendClientMessage(playerid, COL_ERR, "Kayit dogrulanamadi. Yoneticiye bildirin.");
                KG_KickDelay(playerid);
                return 1;
            }

            SendClientMessage(playerid, COL_OK, "Kayit tamamlandi! Hesabiniz kalici olarak kaydedildi.");
            new charname[25];
            format(charname, sizeof charname, "%s", pTmpChar[playerid]);
            pTmpHash[playerid][0] = 0;
            KG_Complete(playerid, accid, charname, age);
            return 1;
        }
    }
    return 0;
}
