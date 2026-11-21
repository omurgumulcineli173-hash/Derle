/*
    DUKTUR RP - Ayarlar Menusu + Kalici Kayit/Giris (filterscript)
    - Buton yok. Menu sadece /ayarlar komutuyla acilir.
    - Oyuna girince ustte 12 sn hosgeldin yazisi + chat'te /yardim ve /ayarlar bilgisi cikar.
    - Rapor sistemi: /report, /raporlarim (oyuncu) ve /reports (sadece admin: Beklemede/Incelemede/Onaylandi/Reddedildi).
    - Menu icerigi:
        Giris Yap / Kayit Ol / Hesap Bilgilerim / Sifre Degistir /
        Admin Rapor Paneli (sadece admin) / Giris Yap / Kayit Ol / Rapor Gonder / Raporlarim / Yardim / Envanter / Telefon
    - SQLite (duktur_rp.db) - ek plugin gerekmez. SHA256 + salt. 3 yanlis sifre = 5 dk kilit.
    - Kullanici adi = oyuncunun SA-MP adi. Isim koruma: online + tum kayitli hesaplar, buyuk/kucuk harf duyarsiz.
    - ZORUNLU_GIRIS 1 yaparsan giris yapmayan oyuncu hareket edemez/yazamaz/komut kullanamaz.
    Gereksinim: SA-MP 0.3.7 R2+ (SHA256_PassHash, secilebilir textdraw)
*/

#include <a_samp>

#pragma dynamic 16384

#define DB_FILE         "duktur_rp.db"

// 0 = giris istege bagli (Ayarlar menusunden), 1 = zorunlu
#define ZORUNLU_GIRIS   0

#define DLG_LOGIN       7101
#define DLG_REGPASS     7102
#define DLG_REGPASS2    7103
#define DLG_MENU        7106
#define DLG_INFO        7107
#define DLG_CHP_OLD     7108
#define DLG_CHP_NEW     7109
#define DLG_CHP_NEW2    7110
#define DLG_REP_NEW     7120
#define DLG_REP_LIST    7121
#define DLG_REP_INFO    7122
#define DLG_AREP_LIST   7123
#define DLG_AREP_VIEW   7124
#define DLG_AREP_ACT    7125
#define DLG_AREP_NOTE   7126

#define REP_COOLDOWN    20
#define REP_MAXLIST     20

#define MAX_TRIES       3
#define LOCK_SECONDS    300
#define MIN_PASS        6

#define COL_ERR         0xFF4444FF
#define COL_OK          0x33CC33FF
#define COL_INFO        0xFFCC00FF

new DB:gDB;
new Text:gTD;
new pLogged[MAX_PLAYERS];
new pAccID[MAX_PLAYERS];
new pTries[MAX_PLAYERS];
new pMenuAct[MAX_PLAYERS][12];
new pTmpUser[MAX_PLAYERS][25];
new pTmpPlain[MAX_PLAYERS][33];
new pTmpHash[MAX_PLAYERS][65];
new pTmpSalt[MAX_PLAYERS][17];
new pRepMap[MAX_PLAYERS][REP_MAXLIST];
new pRepCount[MAX_PLAYERS];
new pRepSel[MAX_PLAYERS];
new pRepAct[MAX_PLAYERS];
new pRepLast[MAX_PLAYERS];

forward KG_Start(playerid);
forward KG_Kick(playerid);
forward KG_PromptTimer(playerid);
forward KG_HideWelcome(playerid);
forward KG_IsLogged(playerid);
forward KG_GetAccountID(playerid);

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

// Kullanici adi ile hesap bul; gercek kullanici adini dest'e yazar
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
#if ZORUNLU_GIRIS
    SetTimerEx("KG_Kick", 500, false, "i", playerid);
#else
    #pragma unused playerid
#endif
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
    pTries[playerid] = 0;
    pTmpUser[playerid][0] = 0;
    pTmpPlain[playerid][0] = 0;
    pTmpHash[playerid][0] = 0;
    pTmpSalt[playerid][0] = 0;
    pRepCount[playerid] = 0;
    pRepSel[playerid] = 0;
    pRepAct[playerid] = 0;
    pRepLast[playerid] = 0;
}

stock KG_IsAdmin(playerid)
{
    new lvl = CallRemoteFunction("RP_GetAdminLevel", "i", playerid);
    if (lvl >= 1 || IsPlayerAdmin(playerid)) return 1;
    return 0;
}

stock KG_RunCommand(playerid, const cmd[])
{
    CallRemoteFunction("OnPlayerCommandText", "is", playerid, cmd);
}

// ---------------------------------------------------------------- RAPOR SISTEMI
// Durumlar: 0 Beklemede, 1 Incelemede, 2 Onaylandi, 3 Reddedildi
// Oyuncu: /report, /raporlarim   |   Sadece admin: /reports (ayarlar menusunde en ustte "Admin Rapor Paneli")

stock KG_RepStatus(st, dest[], size = sizeof dest)
{
    switch (st)
    {
        case 1: format(dest, size, "{33AAFF}Incelemede");
        case 2: format(dest, size, "{33CC33}Onaylandi");
        case 3: format(dest, size, "{FF4444}Reddedildi");
        default: format(dest, size, "{FFCC00}Beklemede");
    }
}

stock KG_RepClean(str[])
{
    for (new i = 0; str[i] != 0; i++)
    {
        if (str[i] == '{') str[i] = '(';
        else if (str[i] == '}') str[i] = ')';
        else if (str[i] == '\n' || str[i] == '\r') str[i] = ' ';
    }
}

stock KG_Cut(const src[], dest[], maxlen, size = sizeof dest)
{
    new i = 0;
    while (src[i] != 0 && i < maxlen && i < size - 4) { dest[i] = src[i]; i++; }
    dest[i] = 0;
    if (src[i] != 0) strcat(dest, "...", size);
}

stock KG_RepNow(dest[], size = sizeof dest)
{
    new y, mo, d, h, mi, s;
    getdate(y, mo, d);
    gettime(h, mi, s);
    format(dest, size, "%02d.%02d.%04d %02d:%02d", d, mo, y, h, mi);
}

stock KG_RepPendingCount()
{
    new c = 0, tmp[16];
    new DBResult:r = db_query(gDB, "SELECT COUNT(*) FROM rp_reports WHERE status<2");
    if (r)
    {
        db_get_field(r, 0, tmp, sizeof tmp);
        c = strval(tmp);
        db_free_result(r);
    }
    return c;
}

stock KG_RepNewDialog(playerid)
{
    ShowPlayerDialog(playerid, DLG_REP_NEW, DIALOG_STYLE_INPUT, "Rapor Gonder",
        "{FFFFFF}Raporunuzu yazin (kural ihlali, sorun, oyuncu sikayeti...).\n{AAAAAA}Raporu sadece adminler gorebilir.",
        "Gonder", "Iptal");
}

stock KG_RepSubmit(playerid, const text[])
{
    if (strlen(text) < 5)
    {
        SendClientMessage(playerid, COL_ERR, "Rapor en az 5 karakter olmali.");
        return 0;
    }
    if (pRepLast[playerid] && gettime() - pRepLast[playerid] < REP_COOLDOWN)
    {
        SendClientMessage(playerid, COL_ERR, "Cok hizli rapor gonderiyorsunuz, biraz bekleyin.");
        return 0;
    }
    new name[MAX_PLAYER_NAME + 1], clean[130], esc[270], escn[64], now[24], q[700];
    GetPlayerName(playerid, name, sizeof name);
    format(clean, sizeof clean, "%s", text);
    KG_RepClean(clean);
    KG_Esc(clean, esc);
    KG_Esc(name, escn);
    KG_RepNow(now);
    format(q, sizeof q, "INSERT INTO rp_reports (reporter, text, status, created_txt, updated_txt) VALUES ('%s','%s',0,'%s','%s')", escn, esc, now, now);
    if (!KG_Exec(q))
    {
        SendClientMessage(playerid, COL_ERR, "Rapor kaydedilemedi, tekrar deneyin.");
        return 0;
    }
    new id = 0, tmp[16];
    new DBResult:r = db_query(gDB, "SELECT last_insert_rowid()");
    if (r)
    {
        db_get_field(r, 0, tmp, sizeof tmp);
        id = strval(tmp);
        db_free_result(r);
    }
    pRepLast[playerid] = gettime();

    new msg[200], shortt[90];
    format(msg, sizeof msg, "Raporunuz alindi (#%d). Durumu /raporlarim ile gorebilirsiniz.", id);
    SendClientMessage(playerid, COL_OK, msg);

    KG_Cut(clean, shortt, 80);
    format(msg, sizeof msg, "[RAPOR #%d] %s: %s  (/reports)", id, name, shortt);
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && KG_IsAdmin(i)) SendClientMessage(i, 0xFF8800FF, msg);
    }
    return 1;
}

// Rapor detayi (dialogid DLG_REP_INFO = oyuncu, DLG_AREP_VIEW = admin)
stock KG_RepDetail(playerid, id, dialogid)
{
    new q[300], str[1100], part[300], rep[MAX_PLAYER_NAME + 1], txt[130], adm[MAX_PLAYER_NAME + 1];
    new note[110], cr[24], up[24], tmp[16], st = 0, stn[32], found = 0;
    format(q, sizeof q, "SELECT reporter, text, status, admin, note, created_txt, updated_txt FROM rp_reports WHERE id=%d", id);
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        if (db_num_rows(r) > 0)
        {
            db_get_field(r, 0, rep, sizeof rep);
            db_get_field(r, 1, txt, sizeof txt);
            db_get_field(r, 2, tmp, sizeof tmp);
            st = strval(tmp);
            db_get_field(r, 3, adm, sizeof adm);
            db_get_field(r, 4, note, sizeof note);
            db_get_field(r, 5, cr, sizeof cr);
            db_get_field(r, 6, up, sizeof up);
            found = 1;
        }
        db_free_result(r);
    }
    if (!found)
    {
        SendClientMessage(playerid, COL_ERR, "Rapor bulunamadi.");
        return 0;
    }
    KG_RepStatus(st, stn);
    format(str, sizeof str, "{FFFFFF}Rapor No: {FFCC00}#%d\n{FFFFFF}Gonderen: {AAAAAA}%s\n{FFFFFF}Tarih: {AAAAAA}%s\n{FFFFFF}Durum: %s\n\n{FFFFFF}Rapor:\n{AAAAAA}%s\n", id, rep, cr, stn, txt);
    if (adm[0])
    {
        format(part, sizeof part, "\n{FFFFFF}Isleyen Admin: {AAAAAA}%s\n{FFFFFF}Son Islem: {AAAAAA}%s\n", adm, up);
        strcat(str, part, sizeof str);
        if (note[0])
        {
            format(part, sizeof part, "{FFFFFF}Admin Notu: {AAAAAA}%s\n", note);
            strcat(str, part, sizeof str);
        }
    }
    if (dialogid == DLG_AREP_VIEW)
        ShowPlayerDialog(playerid, DLG_AREP_VIEW, DIALOG_STYLE_MSGBOX, "Admin - Rapor Incele", str, "Islem", "Geri");
    else
        ShowPlayerDialog(playerid, DLG_REP_INFO, DIALOG_STYLE_MSGBOX, "Raporum", str, "Geri", "Kapat");
    return 1;
}

// Oyuncunun kendi raporlari (/raporlarim)
stock KG_RepMyList(playerid)
{
    new name[MAX_PLAYER_NAME + 1], esc[64], q[300], str[2500], line[200], tmp[16], stn[32], txt[130], shortt[48];
    GetPlayerName(playerid, name, sizeof name);
    KG_Esc(name, esc);
    format(q, sizeof q, "SELECT id, status, text FROM rp_reports WHERE reporter='%s' COLLATE NOCASE ORDER BY id DESC LIMIT %d", esc, REP_MAXLIST);
    pRepCount[playerid] = 0;
    str[0] = 0;
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        if (db_num_rows(r) > 0)
        {
            do
            {
                if (pRepCount[playerid] >= REP_MAXLIST) break;
                db_get_field(r, 0, tmp, sizeof tmp);
                pRepMap[playerid][pRepCount[playerid]] = strval(tmp);
                db_get_field(r, 1, tmp, sizeof tmp);
                KG_RepStatus(strval(tmp), stn);
                db_get_field(r, 2, txt, sizeof txt);
                KG_Cut(txt, shortt, 40);
                format(line, sizeof line, "{FFFFFF}#%d  %s{FFFFFF}  %s\n", pRepMap[playerid][pRepCount[playerid]], stn, shortt);
                strcat(str, line, sizeof str);
                pRepCount[playerid]++;
            }
            while (db_next_row(r));
        }
        db_free_result(r);
    }
    if (pRepCount[playerid] == 0)
    {
        ShowPlayerDialog(playerid, DLG_INFO, DIALOG_STYLE_MSGBOX, "Raporlarim", "{FFFFFF}Henuz rapor gondermediniz.\n{AAAAAA}Rapor icin: /ayarlar > Rapor Gonder veya /report", "Tamam", "");
        return 1;
    }
    ShowPlayerDialog(playerid, DLG_REP_LIST, DIALOG_STYLE_LIST, "Raporlarim", str, "Incele", "Kapat");
    return 1;
}

// Admin rapor paneli (/reports) - acik raporlar uste gelir
stock KG_RepAdminList(playerid)
{
    if (!KG_IsAdmin(playerid))
    {
        SendClientMessage(playerid, COL_ERR, "Bu bolum sadece adminler icindir.");
        return 0;
    }
    new str[3200], line[220], tmp[16], stn[32], rep[MAX_PLAYER_NAME + 1], txt[130], shortt[40], cap[64];
    pRepCount[playerid] = 0;
    str[0] = 0;
    new DBResult:r = db_query(gDB, "SELECT id, status, reporter, text FROM rp_reports ORDER BY CASE WHEN status<2 THEN 0 ELSE 1 END, id DESC LIMIT 20");
    if (r)
    {
        if (db_num_rows(r) > 0)
        {
            do
            {
                if (pRepCount[playerid] >= REP_MAXLIST) break;
                db_get_field(r, 0, tmp, sizeof tmp);
                pRepMap[playerid][pRepCount[playerid]] = strval(tmp);
                db_get_field(r, 1, tmp, sizeof tmp);
                KG_RepStatus(strval(tmp), stn);
                db_get_field(r, 2, rep, sizeof rep);
                db_get_field(r, 3, txt, sizeof txt);
                KG_Cut(txt, shortt, 28);
                format(line, sizeof line, "{FFFFFF}#%d  %s{FFFFFF}  %s: {AAAAAA}%s\n", pRepMap[playerid][pRepCount[playerid]], stn, rep, shortt);
                strcat(str, line, sizeof str);
                pRepCount[playerid]++;
            }
            while (db_next_row(r));
        }
        db_free_result(r);
    }
    if (pRepCount[playerid] == 0)
    {
        ShowPlayerDialog(playerid, DLG_INFO, DIALOG_STYLE_MSGBOX, "Admin - Rapor Kontrol", "{FFFFFF}Hic rapor yok.", "Tamam", "");
        return 1;
    }
    format(cap, sizeof cap, "Rapor Kontrol - %d acik rapor", KG_RepPendingCount());
    ShowPlayerDialog(playerid, DLG_AREP_LIST, DIALOG_STYLE_LIST, cap, str, "Sec", "Kapat");
    return 1;
}

// Admin durum degistirir: 1 Incelemede, 2 Onaylandi, 3 Reddedildi
stock KG_RepSetStatus(playerid, id, st, const note[])
{
    if (!KG_IsAdmin(playerid))
    {
        SendClientMessage(playerid, COL_ERR, "Bu islem sadece adminler icindir.");
        return 0;
    }
    new q[700], an[MAX_PLAYER_NAME + 1], ean[64], cn[110], en[240], now[24];
    new rep[MAX_PLAYER_NAME + 1], stn[32], msg[200], found = 0;
    GetPlayerName(playerid, an, sizeof an);
    KG_Esc(an, ean);
    KG_RepNow(now);

    format(q, sizeof q, "SELECT reporter FROM rp_reports WHERE id=%d", id);
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        if (db_num_rows(r) > 0)
        {
            db_get_field(r, 0, rep, sizeof rep);
            found = 1;
        }
        db_free_result(r);
    }
    if (!found)
    {
        SendClientMessage(playerid, COL_ERR, "Rapor bulunamadi.");
        return 0;
    }

    if (st == 1)
    {
        format(q, sizeof q, "UPDATE rp_reports SET status=1, admin='%s', updated_txt='%s' WHERE id=%d", ean, now, id);
    }
    else
    {
        format(cn, sizeof cn, "%s", note);
        KG_RepClean(cn);
        KG_Esc(cn, en);
        format(q, sizeof q, "UPDATE rp_reports SET status=%d, admin='%s', note='%s', updated_txt='%s' WHERE id=%d", st, ean, en, now, id);
    }
    if (!KG_Exec(q))
    {
        SendClientMessage(playerid, COL_ERR, "Islem kaydedilemedi.");
        return 0;
    }

    KG_RepStatus(st, stn);
    format(msg, sizeof msg, "[RAPOR] #%d (%s) durumu: %s", id, rep, stn);
    SendClientMessage(playerid, COL_INFO, msg);

    // raporu gonderen online ise haber ver
    new pn[MAX_PLAYER_NAME + 1];
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        GetPlayerName(i, pn, sizeof pn);
        if (strcmp(pn, rep, true) != 0) continue;
        format(msg, sizeof msg, "[RAPOR] #%d numarali raporunuz: %s", id, stn);
        SendClientMessage(i, COL_INFO, msg);
        if (st != 1 && cn[0])
        {
            format(msg, sizeof msg, "[RAPOR] Admin notu: %s", cn);
            SendClientMessage(i, COL_INFO, msg);
        }
        SendClientMessage(i, COL_INFO, "Detay icin /raporlarim yazin.");
    }
    return 1;
}

// Rapor dialoglari; ilgili dialog ise 1 doner
stock KG_RepDialog(playerid, dialogid, response, listitem, const inputtext[])
{
    switch (dialogid)
    {
        case DLG_REP_NEW:
        {
            if (!response) return 1;
            KG_RepSubmit(playerid, inputtext);
            return 1;
        }
        case DLG_REP_LIST:
        {
            if (!response) return 1;
            if (listitem < 0 || listitem >= pRepCount[playerid]) return 1;
            KG_RepDetail(playerid, pRepMap[playerid][listitem], DLG_REP_INFO);
            return 1;
        }
        case DLG_REP_INFO:
        {
            if (response) KG_RepMyList(playerid);
            return 1;
        }
        case DLG_AREP_LIST:
        {
            if (!response) return 1;
            if (!KG_IsAdmin(playerid)) return 1;
            if (listitem < 0 || listitem >= pRepCount[playerid]) return 1;
            pRepSel[playerid] = pRepMap[playerid][listitem];
            KG_RepDetail(playerid, pRepSel[playerid], DLG_AREP_VIEW);
            return 1;
        }
        case DLG_AREP_VIEW:
        {
            if (!KG_IsAdmin(playerid)) return 1;
            if (response)
                ShowPlayerDialog(playerid, DLG_AREP_ACT, DIALOG_STYLE_LIST, "Rapor Islemi",
                    "{33AAFF}Incelemeye Al\n{33CC33}Onayla\n{FF4444}Reddet", "Sec", "Geri");
            else
                KG_RepAdminList(playerid);
            return 1;
        }
        case DLG_AREP_ACT:
        {
            if (!KG_IsAdmin(playerid)) return 1;
            if (!response)
            {
                KG_RepDetail(playerid, pRepSel[playerid], DLG_AREP_VIEW);
                return 1;
            }
            if (listitem == 0)
            {
                KG_RepSetStatus(playerid, pRepSel[playerid], 1, "");
                KG_RepAdminList(playerid);
                return 1;
            }
            if (listitem == 1 || listitem == 2)
            {
                pRepAct[playerid] = listitem;
                if (listitem == 1)
                    ShowPlayerDialog(playerid, DLG_AREP_NOTE, DIALOG_STYLE_INPUT, "Raporu Onayla",
                        "{FFFFFF}Oyuncuya gorunecek not yazin (bos birakabilirsiniz).", "Uygula", "Geri");
                else
                    ShowPlayerDialog(playerid, DLG_AREP_NOTE, DIALOG_STYLE_INPUT, "Raporu Reddet",
                        "{FFFFFF}Oyuncuya gorunecek not yazin (bos birakabilirsiniz).", "Uygula", "Geri");
            }
            return 1;
        }
        case DLG_AREP_NOTE:
        {
            if (!KG_IsAdmin(playerid)) return 1;
            if (!response)
            {
                KG_RepDetail(playerid, pRepSel[playerid], DLG_AREP_VIEW);
                return 1;
            }
            new nst = 3;
            if (pRepAct[playerid] == 1) nst = 2;
            KG_RepSetStatus(playerid, pRepSel[playerid], nst, inputtext);
            KG_RepAdminList(playerid);
            return 1;
        }
    }
    return 0;
}

// ---------------------------------------------------------------- dialoglar

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
    ShowPlayerDialog(playerid, DLG_LOGIN, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Giris", str, "Giris", "Iptal");
    return 1;
}

stock KG_ShowRegPass(playerid)
{
    new str[256];
    format(str, sizeof str, "{FFFFFF}Yeni hesap: {FFCC00}%s\n\n{FFFFFF}Bir sifre belirleyin ({FFCC00}%d-32{FFFFFF} karakter).", pTmpUser[playerid], MIN_PASS);
    ShowPlayerDialog(playerid, DLG_REGPASS, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Kayit", str, "Ileri", "Iptal");
}

stock KG_ShowRegPass2(playerid)
{
    ShowPlayerDialog(playerid, DLG_REGPASS2, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Kayit",
        "{FFFFFF}Sifrenizi tekrar girin.", "Kaydol", "Geri");
}

// Hesap varsa giris, yoksa kayit ekrani (zorunlu mod icin)
stock KG_Prompt(playerid)
{
    new name[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, name, sizeof name);
    if (KG_FindUser(name, pTmpUser[playerid], 25)) KG_ShowLogin(playerid);
    else
    {
        format(pTmpUser[playerid], 25, "%s", name);
        KG_ShowRegPass(playerid);
    }
    return 1;
}

stock KG_ShowMenu(playerid)
{
    new str[600], n = 0;
    str = "";
    if (KG_IsAdmin(playerid))
    {
        new apn[48];
        format(apn, sizeof apn, "{FF8800}Admin Rapor Paneli {FFFFFF}(%d acik)\n", KG_RepPendingCount());
        strcat(str, apn);                           pMenuAct[playerid][n++] = 10;
    }
    if (!pLogged[playerid])
    {
        strcat(str, "{33CC33}Giris Yap\n");        pMenuAct[playerid][n++] = 1;
        strcat(str, "{FFCC00}Kayit Ol\n");         pMenuAct[playerid][n++] = 2;
    }
    else
    {
        strcat(str, "{FFFFFF}Hesap Bilgilerim\n");  pMenuAct[playerid][n++] = 3;
        strcat(str, "{FFFFFF}Sifre Degistir\n");    pMenuAct[playerid][n++] = 4;
    }
    strcat(str, "{FFFFFF}Rapor Gonder\n");         pMenuAct[playerid][n++] = 5;
    strcat(str, "{FFFFFF}Raporlarim\n");           pMenuAct[playerid][n++] = 6;
    strcat(str, "{FFFFFF}Yardim\n");               pMenuAct[playerid][n++] = 7;
    strcat(str, "{FFFFFF}Envanter\n");             pMenuAct[playerid][n++] = 8;
    strcat(str, "{FFFFFF}Telefon\n");              pMenuAct[playerid][n++] = 9;
    ShowPlayerDialog(playerid, DLG_MENU, DIALOG_STYLE_LIST, "DUKTUR RP - Ayarlar", str, "Sec", "Kapat");
}

// ---------------------------------------------------------------- giris tamamlama

stock KG_Complete(playerid, accid, const charname[])
{
    pLogged[playerid] = 1;
    pAccID[playerid] = accid;
    pTries[playerid] = 0;

    new ip[20], q[200];
    GetPlayerIp(playerid, ip, sizeof ip);
    format(q, sizeof q, "UPDATE accounts SET last_login=%d, last_ip='%s', lock_until=0 WHERE id=%d", gettime(), ip, accid);
    KG_Exec(q);

    new msg[128];
    format(msg, sizeof msg, "Hos geldin, %s! Basariyla giris yaptin.", charname);
    SendClientMessage(playerid, COL_OK, msg);

#if ZORUNLU_GIRIS
    TogglePlayerControllable(playerid, 1);
#endif
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
    tq = "CREATE TABLE IF NOT EXISTS rp_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, reporter TEXT NOT NULL, text TEXT NOT NULL, ";
    strcat(tq, "status INTEGER DEFAULT 0, admin TEXT DEFAULT '', note TEXT DEFAULT '', created_txt TEXT DEFAULT '', updated_txt TEXT DEFAULT '')");
    KG_Exec(tq);

    // Ust ortada gecici hosgeldin yazisi (buton YOK; menu sadece /ayarlar ile acilir)
    gTD = TextDrawCreate(320.0, 8.0, "~y~DUKTUR RP'ye Hosgeldin!~n~~w~Yardim icin ~g~/yardim~w~  -  Giris / Kayit icin ~g~/ayarlar");
    TextDrawAlignment(gTD, 2);
    TextDrawFont(gTD, 1);
    TextDrawLetterSize(gTD, 0.32, 1.4);
    TextDrawColor(gTD, 0xFFFFFFFF);
    TextDrawSetOutline(gTD, 1);
    TextDrawSetProportional(gTD, 1);

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        KG_ResetPlayer(i);
        if (IsPlayerConnected(i))
        {
#if ZORUNLU_GIRIS
            SetTimerEx("KG_PromptTimer", 500, false, "i", i);
#endif
        }
    }
    print("[KAYIT] DUKTUR RP ayarlar/kayit/giris sistemi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    TextDrawDestroy(gTD);
    if (_:gDB) db_close(gDB);
    return 1;
}

public OnPlayerConnect(playerid)
{
    KG_ResetPlayer(playerid);
#if ZORUNLU_GIRIS
    SetTimerEx("KG_PromptTimer", 1500, false, "i", playerid);
#endif
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    KG_ResetPlayer(playerid);
    return 1;
}

public KG_PromptTimer(playerid)
{
    if (IsPlayerConnected(playerid) && !pLogged[playerid]) KG_Prompt(playerid);
    return 1;
}

public KG_Start(playerid)
{
    return 1;
}

public OnPlayerSpawn(playerid)
{
    // Hosgeldin yazisi (ust) + chat mesaji, 12 sn sonra yazi kaybolur
    TextDrawShowForPlayer(playerid, gTD);
    SetTimerEx("KG_HideWelcome", 12000, false, "i", playerid);
    SendClientMessage(playerid, COL_INFO, "DUKTUR RP'ye hosgeldin! Yardim icin /yardim yaz.");
    if (!pLogged[playerid])
        SendClientMessage(playerid, COL_INFO, "Giris yapmak / kayit olmak icin /ayarlar yaz.");
    if (KG_IsAdmin(playerid))
    {
        new pc = KG_RepPendingCount();
        if (pc > 0)
        {
            new pm[80];
            format(pm, sizeof pm, "[ADMIN] %d acik rapor var. Incelemek icin /reports", pc);
            SendClientMessage(playerid, 0xFF8800FF, pm);
        }
    }
#if ZORUNLU_GIRIS
    if (!pLogged[playerid])
    {
        TogglePlayerControllable(playerid, 0);
        SetTimerEx("KG_PromptTimer", 800, false, "i", playerid);
    }
#endif
    return 1;
}

public KG_HideWelcome(playerid)
{
    if (IsPlayerConnected(playerid)) TextDrawHideForPlayer(playerid, gTD);
    return 1;
}

public OnPlayerText(playerid, text[])
{
#if ZORUNLU_GIRIS
    if (!pLogged[playerid]) return 0;
#else
    #pragma unused playerid, text
#endif
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!strcmp(cmdtext, "/ayarlar", true))
    {
        KG_ShowMenu(playerid);
        return 1;
    }
#if ZORUNLU_GIRIS
    if (!pLogged[playerid])
    {
        SendClientMessage(playerid, COL_ERR, "Once giris yapmalisiniz. (/ayarlar)");
        return 1;
    }
#endif
    if (!strcmp(cmdtext, "/raporlarim", true))
    {
        KG_RepMyList(playerid);
        return 1;
    }
    if (!strcmp(cmdtext, "/reports", true))
    {
        KG_RepAdminList(playerid);
        return 1;
    }
    if (!strcmp(cmdtext, "/report", true, 7) && (cmdtext[7] == 0 || cmdtext[7] == ' '))
    {
        if (cmdtext[7] == ' ' && strlen(cmdtext) > 8) KG_RepSubmit(playerid, cmdtext[8]);
        else KG_RepNewDialog(playerid);
        return 1;
    }
    return 0;
}

public KG_IsLogged(playerid) return pLogged[playerid];
public KG_GetAccountID(playerid) return pAccID[playerid];

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (KG_RepDialog(playerid, dialogid, response, listitem, inputtext)) return 1;
    switch (dialogid)
    {
        case DLG_MENU:
        {
            if (!response) return 1;
            if (listitem < 0 || listitem >= 12) return 1;
            new name[MAX_PLAYER_NAME + 1];
            GetPlayerName(playerid, name, sizeof name);
            switch (pMenuAct[playerid][listitem])
            {
                case 1: // giris yap
                {
                    if (pLogged[playerid]) { SendClientMessage(playerid, COL_INFO, "Zaten giris yaptiniz."); return 1; }
                    if (!KG_FindUser(name, pTmpUser[playerid], 25))
                    {
                        SendClientMessage(playerid, COL_ERR, "Bu isimle kayitli hesap yok. Once Kayit Ol'u kullanin.");
                        return 1;
                    }
                    pTries[playerid] = 0;
                    KG_ShowLogin(playerid);
                }
                case 2: // kayit ol
                {
                    if (pLogged[playerid]) { SendClientMessage(playerid, COL_INFO, "Zaten giris yaptiniz."); return 1; }
                    if (KG_FindUser(name, pTmpUser[playerid], 25))
                    {
                        SendClientMessage(playerid, COL_ERR, "Bu isim zaten kayitli. Giris Yap'i kullanin.");
                        return 1;
                    }
                    format(pTmpUser[playerid], 25, "%s", name);
                    KG_ShowRegPass(playerid);
                }
                case 3: // hesap bilgilerim
                {
                    new q[300], str[300], u[25], rd[24], ld[24];
                    format(q, sizeof q, "SELECT username, strftime('%%d.%%m.%%Y %%H:%%M', reg_date, 'unixepoch', 'localtime'), strftime('%%d.%%m.%%Y %%H:%%M', last_login, 'unixepoch', 'localtime') FROM accounts WHERE id=%d", pAccID[playerid]);
                    new DBResult:r = db_query(gDB, q);
                    if (r)
                    {
                        if (db_num_rows(r) > 0)
                        {
                            db_get_field(r, 0, u, sizeof u);
                            db_get_field(r, 1, rd, sizeof rd);
                            db_get_field(r, 2, ld, sizeof ld);
                        }
                        db_free_result(r);
                    }
                    format(str, sizeof str, "{FFCC00}Kullanici adi: {FFFFFF}%s\n{FFCC00}Hesap No: {FFFFFF}%d\n{FFCC00}Kayit tarihi: {FFFFFF}%s\n{FFCC00}Son giris: {FFFFFF}%s", u, pAccID[playerid], rd, ld);
                    ShowPlayerDialog(playerid, DLG_INFO, DIALOG_STYLE_MSGBOX, "Hesap Bilgilerim", str, "Tamam", "");
                }
                case 4: // sifre degistir
                {
                    if (!pLogged[playerid]) return 1;
                    ShowPlayerDialog(playerid, DLG_CHP_OLD, DIALOG_STYLE_PASSWORD, "Sifre Degistir", "{FFFFFF}Mevcut sifrenizi girin.", "Ileri", "Iptal");
                }
                case 5: KG_RepNewDialog(playerid);
                case 6: KG_RepMyList(playerid);
                case 7: KG_RunCommand(playerid, "/yardim");
                case 8: KG_RunCommand(playerid, "/envanter");
                case 9: KG_RunCommand(playerid, "/telefon");
                case 10: KG_RepAdminList(playerid);
            }
            return 1;
        }

        case DLG_INFO: return 1;

        case DLG_LOGIN:
        {
            if (!response) { KG_KickDelay(playerid); return 1; }
            if (!strlen(inputtext)) { KG_ShowLogin(playerid); return 1; }

            new esc[64], q[300], tmp[16];
            KG_Esc(pTmpUser[playerid], esc);
            format(q, sizeof q, "SELECT id, pass_hash, salt, char_name, lock_until FROM accounts WHERE username='%s' COLLATE NOCASE", esc);
            new DBResult:r = db_query(gDB, q);
            if (!r || db_num_rows(r) < 1)
            {
                if (r) db_free_result(r);
                SendClientMessage(playerid, COL_ERR, "Hesap bulunamadi.");
                return 1;
            }

            new accid, lock, dbhash[65], salt[17], charname[25], hash[65];
            db_get_field(r, 0, tmp, sizeof tmp); accid = strval(tmp);
            db_get_field(r, 1, dbhash, sizeof dbhash);
            db_get_field(r, 2, salt, sizeof salt);
            db_get_field(r, 3, charname, sizeof charname);
            db_get_field(r, 4, tmp, sizeof tmp); lock = strval(tmp);
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
                KG_Complete(playerid, accid, charname);
            }
            else
            {
                pTries[playerid]++;
                if (pTries[playerid] >= MAX_TRIES)
                {
                    format(q, sizeof q, "UPDATE accounts SET lock_until=%d WHERE id=%d", gettime() + LOCK_SECONDS, accid);
                    KG_Exec(q);
                    pTries[playerid] = 0;
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
            if (!response) { KG_KickDelay(playerid); return 1; }
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

            // son kontrol: isim baskasi tarafindan alinmis mi?
            if (KG_NameTaken(pTmpUser[playerid], playerid))
            {
                SendClientMessage(playerid, COL_ERR, "Bu isim kayitli veya kullanimda. Kayit yapilamadi.");
                return 1;
            }

            new eu[64], ip[20], q[600];
            KG_Esc(pTmpUser[playerid], eu);
            GetPlayerIp(playerid, ip, sizeof ip);
            format(q, sizeof q, "INSERT INTO accounts (username, char_name, pass_hash, salt, age, reg_date, last_login, last_ip) VALUES ('%s','%s','%s','%s',0,%d,%d,'%s')",
                eu, eu, pTmpHash[playerid], pTmpSalt[playerid], gettime(), gettime(), ip);
            if (!KG_Exec(q))
            {
                SendClientMessage(playerid, COL_ERR, "Kayit basarisiz oldu. Tekrar deneyin.");
                return 1;
            }
            format(q, sizeof q, "SELECT id FROM accounts WHERE username='%s' COLLATE NOCASE", eu);
            new DBResult:r = db_query(gDB, q), accid = 0, tmp[16];
            if (r)
            {
                if (db_num_rows(r) > 0) { db_get_field(r, 0, tmp, sizeof tmp); accid = strval(tmp); }
                db_free_result(r);
            }
            pTmpHash[playerid][0] = 0;
            if (!accid)
            {
                SendClientMessage(playerid, COL_ERR, "Kayit dogrulanamadi. Yoneticiye bildirin.");
                return 1;
            }
            SendClientMessage(playerid, COL_OK, "Kayit tamamlandi! Hesabiniz kalici olarak kaydedildi.");
            KG_Complete(playerid, accid, pTmpUser[playerid]);
            return 1;
        }

        case DLG_CHP_OLD:
        {
            if (!response || !pLogged[playerid]) return 1;
            new q[200], dbhash[65], salt[17], hash[65];
            format(q, sizeof q, "SELECT pass_hash, salt FROM accounts WHERE id=%d", pAccID[playerid]);
            new DBResult:r = db_query(gDB, q);
            if (!r) return 1;
            if (db_num_rows(r) < 1) { db_free_result(r); return 1; }
            db_get_field(r, 0, dbhash, sizeof dbhash);
            db_get_field(r, 1, salt, sizeof salt);
            db_free_result(r);
            SHA256_PassHash(inputtext, salt, hash, sizeof hash);
            if (strcmp(hash, dbhash, false) != 0)
            {
                SendClientMessage(playerid, COL_ERR, "Mevcut sifre hatali.");
                return 1;
            }
            ShowPlayerDialog(playerid, DLG_CHP_NEW, DIALOG_STYLE_PASSWORD, "Sifre Degistir", "{FFFFFF}Yeni sifrenizi girin (6-32 karakter).", "Ileri", "Iptal");
            return 1;
        }

        case DLG_CHP_NEW:
        {
            if (!response || !pLogged[playerid]) return 1;
            new len = strlen(inputtext);
            if (len < MIN_PASS || len > 32)
            {
                SendClientMessage(playerid, COL_ERR, "Sifre 6-32 karakter arasinda olmali.");
                ShowPlayerDialog(playerid, DLG_CHP_NEW, DIALOG_STYLE_PASSWORD, "Sifre Degistir", "{FFFFFF}Yeni sifrenizi girin (6-32 karakter).", "Ileri", "Iptal");
                return 1;
            }
            format(pTmpPlain[playerid], 33, "%s", inputtext);
            ShowPlayerDialog(playerid, DLG_CHP_NEW2, DIALOG_STYLE_PASSWORD, "Sifre Degistir", "{FFFFFF}Yeni sifrenizi tekrar girin.", "Degistir", "Iptal");
            return 1;
        }

        case DLG_CHP_NEW2:
        {
            if (!response || !pLogged[playerid]) { pTmpPlain[playerid][0] = 0; return 1; }
            if (strcmp(inputtext, pTmpPlain[playerid], false) != 0)
            {
                pTmpPlain[playerid][0] = 0;
                SendClientMessage(playerid, COL_ERR, "Sifreler eslesmiyor, sifre degistirilmedi.");
                return 1;
            }
            new q[300], salt[17], hash[65];
            KG_MakeSalt(salt);
            SHA256_PassHash(pTmpPlain[playerid], salt, hash, sizeof hash);
            pTmpPlain[playerid][0] = 0;
            format(q, sizeof q, "UPDATE accounts SET pass_hash='%s', salt='%s' WHERE id=%d", hash, salt, pAccID[playerid]);
            if (KG_Exec(q)) SendClientMessage(playerid, COL_OK, "Sifreniz degistirildi.");
            else SendClientMessage(playerid, COL_ERR, "Sifre degistirilemedi.");
            return 1;
        }
    }
    return 0;
}
