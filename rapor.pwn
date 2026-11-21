/*
    DUKTUR RP - Gelismis Admin Rapor Yonetim Sistemi (filterscript)
    - /report  : oyuncu raporu (kategori, ID, sebep, aciklama, kanit) - 60 sn bekleme
    - /raporlarim : kendi raporlarinin durumunu takip
    - /reports : admin paneli (Bekleyen / Ustlendigim / Gecmis / Admin Sikayetleri[ust kademe])
    - /specoff : spectate'i bitirir
    - SQLite (duktur_rp.db), ek plugin gerekmez. Tum admin islemleri report_logs tablosuna yazilir.

    ADMIN YETKISI: Bu script admin sisteminden su public'i okur:
        public RP_GetAdminLevel(playerid) { return <senin admin seviyen>; }
    Bunu admin filterscriptine eklemelisin. Yoksa sadece RCON admini (/rcon login) panele girebilir.
    ADMIN_LEVEL: panel/islem icin gereken minimum seviye, SUPER_LEVEL: admin sikayetlerini gorebilen ust kademe.
    NOT: Dosyayi ANSI (Windows-1254) kaydet; metinler bilerek ASCII yazildi.
*/

#include <a_samp>

#pragma dynamic 32768

#define DB_FILE             "duktur_rp.db"
#define REPORT_COOLDOWN     60
#define ADMIN_LEVEL         1
#define SUPER_LEVEL         3
#define MAX_LIST            20

#define D_REP_CAT           7200
#define D_REP_TARGET        7201
#define D_REP_REASON        7202
#define D_REP_DETAIL        7203
#define D_REP_EVID          7204
#define D_MY_LIST           7205
#define D_MY_DETAIL         7206
#define D_PANEL             7210
#define D_LIST              7211
#define D_DETAIL            7212
#define D_ACTIONS           7213
#define D_BACKPANEL         7214
#define D_RESOLVE           7215
#define D_REJECT            7216
#define D_NOTE              7217
#define D_BACKACT           7218
#define D_TARGETHIST        7219

#define CAT_PLAYER          0
#define CAT_ADMIN           1
#define CAT_CHEAT           2
#define CAT_OTHER           3

#define ST_PENDING          0
#define ST_REVIEW           1
#define ST_DONE             2
#define ST_REJECT           3

#define COL_ERR             0xFF4444FF
#define COL_OK              0x33CC33FF
#define COL_INFO            0xFFCC00FF
#define COL_ADMIN           0xFFAA00FF

new DB:gDB;

new gCatNames[4][24] = {"Oyuncu Sikayeti", "Admin Sikayeti", "Hile / Bug Bildirimi", "Diger"};
new gStatusNames[4][28] = {"{FFAA00}Bekleyen", "{33AAFF}Inceleniyor", "{33CC33}Sonuclandirildi", "{FF4444}Reddedildi"};

enum E_REP
{
    rId,
    rCat,
    rStatus,
    rReporterID,
    rTargetID,
    rReporter[25],
    rTarget[25],
    rAdmin[25]
}
new pRep[MAX_PLAYERS][E_REP];

new pLastReport[MAX_PLAYERS];
new pCat[MAX_PLAYERS];
new pTargetID[MAX_PLAYERS];
new pReason[MAX_PLAYERS][128];
new pDetail[MAX_PLAYERS][128];
new pListType[MAX_PLAYERS];
new pListIds[MAX_PLAYERS][MAX_LIST];
new pCurReport[MAX_PLAYERS];
new pSpecOn[MAX_PLAYERS];
new pSpecTarget[MAX_PLAYERS];
new Float:pSpecPos[MAX_PLAYERS][4];
new pSpecInt[MAX_PLAYERS];
new pSpecVW[MAX_PLAYERS];
new pSpecReturn[MAX_PLAYERS];

forward RP_DoSpec(playerid, targetid);
forward RP_Restore(playerid);

// ---------------------------------------------------------------- yardimcilar

stock RP_Esc(const src[], dest[], size = sizeof dest)
{
    new j = 0;
    for (new i = 0; src[i] != 0 && j < size - 2; i++)
    {
        if (src[i] == '\'') dest[j++] = '\'';
        dest[j++] = src[i];
    }
    dest[j] = 0;
}

stock RP_Exec(const query[])
{
    new DBResult:r = db_query(gDB, query);
    if (r) { db_free_result(r); return 1; }
    return 0;
}

stock RP_Clean(str[])
{
    for (new i = 0; str[i]; i++)
    {
        if (str[i] == '{' || str[i] == '}' || str[i] == '%' || str[i] < ' ') str[i] = ' ';
    }
}

stock RP_IsNum(const s[])
{
    if (!s[0]) return 0;
    new i = 0;
    if (s[0] == '-') i = 1;
    if (!s[i]) return 0;
    for (; s[i]; i++) if (s[i] < '0' || s[i] > '9') return 0;
    return 1;
}

stock RP_AdminLevel(playerid)
{
    new lvl = CallRemoteFunction("RP_GetAdminLevel", "i", playerid);
    if (IsPlayerAdmin(playerid) && lvl < SUPER_LEVEL) lvl = SUPER_LEVEL;
    return lvl;
}

stock RP_IsAdmin(playerid) return (RP_AdminLevel(playerid) >= ADMIN_LEVEL);
stock RP_IsSuper(playerid) return (RP_AdminLevel(playerid) >= SUPER_LEVEL);

stock RP_FindByName(const name[])
{
    new pn[MAX_PLAYER_NAME + 1];
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        GetPlayerName(i, pn, sizeof pn);
        if (!strcmp(pn, name, true)) return i;
    }
    return INVALID_PLAYER_ID;
}

stock RP_NotifyAdmins(const msg[], minLevel)
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && RP_AdminLevel(i) >= minLevel) SendClientMessage(i, COL_ADMIN, msg);
    }
}

stock RP_Log(reportid, const admin[], const action[], const note[] = "")
{
    new ea[64], eac[40], en[300], q[600];
    RP_Esc(admin, ea);
    RP_Esc(action, eac);
    RP_Esc(note, en);
    format(q, sizeof q, "INSERT INTO report_logs (report_id, ts, admin, action, note) VALUES (%d,%d,'%s','%s','%s')",
        reportid, gettime(), ea, eac, en);
    RP_Exec(q);
}

// raporu cache'e yukler; yetki kontrolu yapar (admin sikayeti sadece ust kademe)
stock RP_Load(playerid, reportid)
{
    new q[300], tmp[16], ok = 0;
    format(q, sizeof q, "SELECT id, category, status, reporter, reporter_id, target, target_id, admin FROM reports WHERE id=%d", reportid);
    new DBResult:r = db_query(gDB, q);
    if (!r) return 0;
    if (db_num_rows(r) > 0)
    {
        db_get_field(r, 0, tmp, sizeof tmp); pRep[playerid][rId] = strval(tmp);
        db_get_field(r, 1, tmp, sizeof tmp); pRep[playerid][rCat] = strval(tmp);
        db_get_field(r, 2, tmp, sizeof tmp); pRep[playerid][rStatus] = strval(tmp);
        db_get_field(r, 3, pRep[playerid][rReporter], 25);
        db_get_field(r, 4, tmp, sizeof tmp); pRep[playerid][rReporterID] = strval(tmp);
        db_get_field(r, 5, pRep[playerid][rTarget], 25);
        db_get_field(r, 6, tmp, sizeof tmp); pRep[playerid][rTargetID] = strval(tmp);
        db_get_field(r, 7, pRep[playerid][rAdmin], 25);
        ok = 1;
    }
    db_free_result(r);
    if (ok && pRep[playerid][rCat] == CAT_ADMIN && !RP_IsSuper(playerid)) ok = 0;
    return ok;
}

stock RP_FindTarget(playerid)
{
    new t = pRep[playerid][rTargetID];
    new pn[MAX_PLAYER_NAME + 1];
    if (t >= 0 && t < MAX_PLAYERS && IsPlayerConnected(t))
    {
        GetPlayerName(t, pn, sizeof pn);
        if (!strcmp(pn, pRep[playerid][rTarget], true)) return t;
    }
    return RP_FindByName(pRep[playerid][rTarget]);
}

// ---------------------------------------------------------------- oyuncu tarafi

stock RP_ShowCategory(playerid)
{
    ShowPlayerDialog(playerid, D_REP_CAT, DIALOG_STYLE_LIST, "Rapor - Kategori",
        "Oyuncu Sikayeti\nAdmin Sikayeti\nHile / Bug Bildirimi\nDiger", "Sec", "Iptal");
}

stock RP_ShowTargetDlg(playerid)
{
    if (pCat[playerid] == CAT_CHEAT || pCat[playerid] == CAT_OTHER)
        ShowPlayerDialog(playerid, D_REP_TARGET, DIALOG_STYLE_INPUT, "Rapor - Oyuncu ID",
            "{FFFFFF}Ilgili oyuncunun ID'sini yazin.\n{AAAAAA}Belirli bir oyuncu yoksa -1 yazin.", "Ileri", "Iptal");
    else
        ShowPlayerDialog(playerid, D_REP_TARGET, DIALOG_STYLE_INPUT, "Rapor - Oyuncu ID",
            "{FFFFFF}Sikayet ettiginiz oyuncunun ID'sini yazin.", "Ileri", "Iptal");
}

stock RP_Submit(playerid, const evid[])
{
    new rn[MAX_PLAYER_NAME + 1], tn[MAX_PLAYER_NAME + 1] = "-";
    GetPlayerName(playerid, rn, sizeof rn);
    if (pTargetID[playerid] >= 0 && IsPlayerConnected(pTargetID[playerid]))
        GetPlayerName(pTargetID[playerid], tn, sizeof tn);

    new er[64], et[64], ere[260], ed[260], ev[260], q[1400];
    RP_Esc(rn, er);
    RP_Esc(tn, et);
    RP_Esc(pReason[playerid], ere);
    RP_Esc(pDetail[playerid], ed);
    RP_Esc(evid, ev);

    new prio = 0;
    if (pCat[playerid] == CAT_CHEAT) prio = 2;

    format(q, sizeof q, "INSERT INTO reports (ts, category, priority, reporter, reporter_id, target, target_id, reason, detail, evidence, status) VALUES (%d,%d,%d,'%s',%d,'%s',%d,'%s','%s','%s',0)",
        gettime(), pCat[playerid], prio, er, playerid, et, pTargetID[playerid], ere, ed, ev);
    if (!RP_Exec(q))
    {
        SendClientMessage(playerid, COL_ERR, "Rapor kaydedilemedi, tekrar deneyin.");
        return 0;
    }

    new id = 0, tmp[16];
    new DBResult:r = db_query(gDB, "SELECT last_insert_rowid()");
    if (r)
    {
        if (db_num_rows(r) > 0) { db_get_field(r, 0, tmp, sizeof tmp); id = strval(tmp); }
        db_free_result(r);
    }

    pLastReport[playerid] = gettime();
    RP_Log(id, rn, "OLUSTURULDU", "");

    new msg[144];
    format(msg, sizeof msg, "Raporunuz alindi. Rapor No: #%d - Durumu /raporlarim ile takip edebilirsiniz.", id);
    SendClientMessage(playerid, COL_OK, msg);

    if (pCat[playerid] == CAT_ADMIN)
    {
        format(msg, sizeof msg, "[RAPOR] Yeni ADMIN SIKAYETI #%d (sadece ust kademe goruyor).", id);
        RP_NotifyAdmins(msg, SUPER_LEVEL);
    }
    else if (pCat[playerid] == CAT_CHEAT)
    {
        format(msg, sizeof msg, "[RAPOR] {FF0000}[ONCELIKLI]{FFAA00} Yeni rapor #%d (%s) - /reports", id, gCatNames[CAT_CHEAT]);
        RP_NotifyAdmins(msg, ADMIN_LEVEL);
    }
    else
    {
        format(msg, sizeof msg, "[RAPOR] Yeni rapor #%d (%s) - /reports", id, gCatNames[pCat[playerid]]);
        RP_NotifyAdmins(msg, ADMIN_LEVEL);
    }
    return 1;
}

stock RP_ShowMyList(playerid)
{
    new rn[MAX_PLAYER_NAME + 1], er[64], q[400], str[1500], tmp[16], line[160], n = 0;
    GetPlayerName(playerid, rn, sizeof rn);
    RP_Esc(rn, er);
    format(q, sizeof q, "SELECT id, category, status, strftime('%%d.%%m.%%Y %%H:%%M', ts, 'unixepoch', 'localtime') FROM reports WHERE reporter='%s' COLLATE NOCASE ORDER BY id DESC LIMIT 15", er);
    new DBResult:r = db_query(gDB, q);
    str = "No\tKategori\tDurum\tTarih\n";
    if (r)
    {
        new rows = db_num_rows(r);
        for (new i = 0; i < rows && i < MAX_LIST; i++)
        {
            new id, cat, st, dt[24];
            db_get_field(r, 0, tmp, sizeof tmp); id = strval(tmp);
            db_get_field(r, 1, tmp, sizeof tmp); cat = strval(tmp);
            db_get_field(r, 2, tmp, sizeof tmp); st = strval(tmp);
            db_get_field(r, 3, dt, sizeof dt);
            if (cat < 0 || cat > 3) cat = 3;
            if (st < 0 || st > 3) st = 0;
            pListIds[playerid][n++] = id;
            format(line, sizeof line, "#%d\t%s\t%s\t%s\n", id, gCatNames[cat], gStatusNames[st], dt);
            strcat(str, line);
            db_next_row(r);
        }
        db_free_result(r);
    }
    if (!n)
    {
        SendClientMessage(playerid, COL_INFO, "Henuz bir rapor gondermediniz.");
        return 1;
    }
    ShowPlayerDialog(playerid, D_MY_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Raporlarim", str, "Detay", "Kapat");
    return 1;
}

stock RP_ShowMyDetail(playerid, reportid)
{
    new rn[MAX_PLAYER_NAME + 1], er[64], q[500], str[1200];
    GetPlayerName(playerid, rn, sizeof rn);
    RP_Esc(rn, er);
    format(q, sizeof q, "SELECT category, status, target, reason, admin, result_note, strftime('%%d.%%m.%%Y %%H:%%M', ts, 'unixepoch', 'localtime') FROM reports WHERE id=%d AND reporter='%s' COLLATE NOCASE", reportid, er);
    new DBResult:r = db_query(gDB, q);
    if (!r) return 0;
    if (db_num_rows(r) < 1) { db_free_result(r); return 0; }

    new tmp[16], cat, st, target[25], reason[128], admin[25], note[128], dt[24];
    db_get_field(r, 0, tmp, sizeof tmp); cat = strval(tmp);
    db_get_field(r, 1, tmp, sizeof tmp); st = strval(tmp);
    db_get_field(r, 2, target, sizeof target);
    db_get_field(r, 3, reason, sizeof reason);
    db_get_field(r, 4, admin, sizeof admin);
    db_get_field(r, 5, note, sizeof note);
    db_get_field(r, 6, dt, sizeof dt);
    db_free_result(r);
    if (cat < 0 || cat > 3) cat = 3;
    if (st < 0 || st > 3) st = 0;
    if (!admin[0]) admin = "-";
    if (!note[0]) note = "-";

    format(str, sizeof str, "{FFCC00}Rapor No: {FFFFFF}#%d\n{FFCC00}Kategori: {FFFFFF}%s\n{FFCC00}Durum: %s\n{FFCC00}Tarih: {FFFFFF}%s\n{FFCC00}Sikayet edilen: {FFFFFF}%s\n{FFCC00}Sebep: {FFFFFF}%s\n{FFCC00}Ilgilenen yetkili: {FFFFFF}%s\n{FFCC00}Sonuc / gerekce: {FFFFFF}%s",
        reportid, gCatNames[cat], gStatusNames[st], dt, target, reason, (cat == CAT_ADMIN) ? ("-") : (admin), note);
    ShowPlayerDialog(playerid, D_MY_DETAIL, DIALOG_STYLE_MSGBOX, "Rapor Durumu", str, "Geri", "Kapat");
    return 1;
}

// ---------------------------------------------------------------- admin paneli

stock RP_Count(const where[])
{
    new q[300], tmp[16], c = 0;
    format(q, sizeof q, "SELECT COUNT(*) FROM reports WHERE %s", where);
    new DBResult:r = db_query(gDB, q);
    if (r)
    {
        if (db_num_rows(r) > 0) { db_get_field(r, 0, tmp, sizeof tmp); c = strval(tmp); }
        db_free_result(r);
    }
    return c;
}

stock RP_ShowPanel(playerid)
{
    if (!RP_IsAdmin(playerid)) return 0;
    new an[MAX_PLAYER_NAME + 1], ea[64], w[160], str[400];
    GetPlayerName(playerid, an, sizeof an);
    RP_Esc(an, ea);

    new cPend = RP_Count("status=0 AND category<>1");
    format(w, sizeof w, "status=1 AND admin='%s' AND category<>1", ea);
    new cMine = RP_Count(w);
    new cHist = RP_Count("status IN (2,3) AND category<>1");

    format(str, sizeof str, "Bekleyen Raporlar\t{FFAA00}%d\nUstlendigim Raporlar\t{33AAFF}%d\nGecmis Raporlar\t{AAAAAA}%d", cPend, cMine, cHist);
    if (RP_IsSuper(playerid))
    {
        new cAdm = RP_Count("category=1 AND status IN (0,1)"), extra[80];
        format(extra, sizeof extra, "\n{FF4444}Admin Sikayetleri\t{FF4444}%d", cAdm);
        strcat(str, extra);
    }
    ShowPlayerDialog(playerid, D_PANEL, DIALOG_STYLE_TABLIST, "DUKTUR RP - Admin Rapor Paneli", str, "Ac", "Kapat");
    return 1;
}

stock RP_ShowList(playerid, type)
{
    if (!RP_IsAdmin(playerid)) return 0;
    if (type == 3 && !RP_IsSuper(playerid)) return 0;

    new an[MAX_PLAYER_NAME + 1], ea[64], where[160], order[40];
    GetPlayerName(playerid, an, sizeof an);
    RP_Esc(an, ea);
    order = "priority DESC, id ASC";
    switch (type)
    {
        case 0: where = "status=0 AND category<>1";
        case 1: format(where, sizeof where, "status=1 AND admin='%s' AND category<>1", ea);
        case 2: { where = "status IN (2,3) AND category<>1"; order = "id DESC"; }
        case 3: where = "category=1 AND status IN (0,1)";
        default: return 0;
    }
    pListType[playerid] = type;

    new q[400], str[2200], line[200], tmp[16], n = 0;
    format(q, sizeof q, "SELECT id, reporter, target, category, status, priority FROM reports WHERE %s ORDER BY %s LIMIT %d", where, order, MAX_LIST);
    new DBResult:r = db_query(gDB, q);
    str = "No\tGonderen\tSikayet Edilen\tKategori\tDurum\n";
    if (r)
    {
        new rows = db_num_rows(r);
        for (new i = 0; i < rows && n < MAX_LIST; i++)
        {
            new id, cat, st, prio, rep[25], tar[25];
            db_get_field(r, 0, tmp, sizeof tmp); id = strval(tmp);
            db_get_field(r, 1, rep, sizeof rep);
            db_get_field(r, 2, tar, sizeof tar);
            db_get_field(r, 3, tmp, sizeof tmp); cat = strval(tmp);
            db_get_field(r, 4, tmp, sizeof tmp); st = strval(tmp);
            db_get_field(r, 5, tmp, sizeof tmp); prio = strval(tmp);
            if (cat < 0 || cat > 3) cat = 3;
            if (st < 0 || st > 3) st = 0;
            pListIds[playerid][n++] = id;
            format(line, sizeof line, "%s#%d\t%s\t%s\t%s\t%s\n", (prio >= 2) ? ("{FF0000}[!] {FFFFFF}") : (""), id, rep, tar, gCatNames[cat], gStatusNames[st]);
            strcat(str, line);
            db_next_row(r);
        }
        db_free_result(r);
    }
    if (!n)
    {
        ShowPlayerDialog(playerid, D_BACKPANEL, DIALOG_STYLE_MSGBOX, "Rapor Listesi", "{FFFFFF}Bu bolumde rapor bulunmuyor.", "Geri", "Kapat");
        return 1;
    }
    ShowPlayerDialog(playerid, D_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Rapor Listesi", str, "Ac", "Geri");
    return 1;
}

stock RP_ShowDetail(playerid, reportid)
{
    if (!RP_IsAdmin(playerid)) return 0;
    if (!RP_Load(playerid, reportid))
    {
        SendClientMessage(playerid, COL_ERR, "Rapor bulunamadi veya erisim yetkiniz yok.");
        return 0;
    }
    pCurReport[playerid] = reportid;

    new q[500], str[1800];
    format(q, sizeof q, "SELECT strftime('%%d.%%m.%%Y %%H:%%M', ts, 'unixepoch', 'localtime'), reason, detail, evidence, result_note FROM reports WHERE id=%d", reportid);
    new DBResult:r = db_query(gDB, q);
    if (!r) return 0;
    if (db_num_rows(r) < 1) { db_free_result(r); return 0; }

    new dt[24], reason[128], detail[128], evid[128], note[128];
    db_get_field(r, 0, dt, sizeof dt);
    db_get_field(r, 1, reason, sizeof reason);
    db_get_field(r, 2, detail, sizeof detail);
    db_get_field(r, 3, evid, sizeof evid);
    db_get_field(r, 4, note, sizeof note);
    db_free_result(r);

    new cat = pRep[playerid][rCat], st = pRep[playerid][rStatus];
    if (cat < 0 || cat > 3) cat = 3;
    if (st < 0 || st > 3) st = 0;
    new adm[25];
    format(adm, sizeof adm, "%s", pRep[playerid][rAdmin]);
    if (!adm[0]) adm = "-";
    if (!evid[0]) evid = "-";
    if (!note[0]) note = "-";

    format(str, sizeof str,
        "{FFCC00}Rapor No: {FFFFFF}#%d\n{FFCC00}Kategori: {FFFFFF}%s\n{FFCC00}Durum: %s\n{FFCC00}Tarih: {FFFFFF}%s\n\n{FFCC00}Gonderen: {FFFFFF}%s (ID: %d)\n{FFCC00}Sikayet edilen: {FFFFFF}%s (ID: %d)\n{FFCC00}Ilgilenen admin: {FFFFFF}%s\n\n{FFCC00}Sebep: {FFFFFF}%s\n{FFCC00}Aciklama: {FFFFFF}%s\n{FFCC00}Kanit: {FFFFFF}%s\n{FFCC00}Sonuc notu: {FFFFFF}%s",
        reportid, gCatNames[cat], gStatusNames[st], dt,
        pRep[playerid][rReporter], pRep[playerid][rReporterID],
        pRep[playerid][rTarget], pRep[playerid][rTargetID],
        adm, reason, detail, evid, note);
    ShowPlayerDialog(playerid, D_DETAIL, DIALOG_STYLE_MSGBOX, "Rapor Detayi", str, "Islemler", "Geri");
    return 1;
}

stock RP_ShowActions(playerid)
{
    ShowPlayerDialog(playerid, D_ACTIONS, DIALOG_STYLE_LIST, "Rapor Islemleri",
        "Oyuncuyu Incele\nOyuncuya Git\nSpectate\nRaporu Ustlen\nRaporu Coz\nRaporu Reddet\nNot Birak\nNotlar ve Islem Kaydi\nSikayet Edilenin Gecmis Raporlari",
        "Sec", "Geri");
}

stock RP_Info(playerid, dialogid, const caption[], const text[])
{
    ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, caption, text, "Geri", "Kapat");
}

stock RP_NotifyReporter(playerid, const text[])
{
    new rp = RP_FindByName(pRep[playerid][rReporter]);
    if (rp != INVALID_PLAYER_ID) SendClientMessage(rp, COL_INFO, text);
}

stock RP_DoAction(playerid, action)
{
    if (!RP_IsAdmin(playerid)) return 0;
    if (!RP_Load(playerid, pCurReport[playerid]))
    {
        SendClientMessage(playerid, COL_ERR, "Rapor bulunamadi veya erisim yetkiniz yok.");
        return 0;
    }
    new an[MAX_PLAYER_NAME + 1], msg[200], rid = pRep[playerid][rId];
    GetPlayerName(playerid, an, sizeof an);
    new st = pRep[playerid][rStatus];
    new mine = (!strcmp(pRep[playerid][rAdmin], an, true));

    switch (action)
    {
        case 0: // incele
        {
            new t = RP_FindTarget(playerid);
            if (t == INVALID_PLAYER_ID)
            {
                RP_Info(playerid, D_BACKACT, "Oyuncuyu Incele", "{FFFFFF}Sikayet edilen oyuncu su an cevrimdisi.");
                return 1;
            }
            new Float:hp, Float:ar, tn[MAX_PLAYER_NAME + 1], ip[20] = "gizli", str[500];
            GetPlayerName(t, tn, sizeof tn);
            GetPlayerHealth(t, hp);
            GetPlayerArmour(t, ar);
            if (RP_IsSuper(playerid)) GetPlayerIp(t, ip, sizeof ip);
            format(str, sizeof str, "{FFCC00}Oyuncu: {FFFFFF}%s (ID: %d)\n{FFCC00}Can / Zirh: {FFFFFF}%.0f / %.0f\n{FFCC00}Para: {FFFFFF}$%d\n{FFCC00}Skor: {FFFFFF}%d\n{FFCC00}Ping: {FFFFFF}%d\n{FFCC00}Skin: {FFFFFF}%d\n{FFCC00}Interior / VW: {FFFFFF}%d / %d\n{FFCC00}IP: {FFFFFF}%s",
                tn, t, hp, ar, GetPlayerMoney(t), GetPlayerScore(t), GetPlayerPing(t), GetPlayerSkin(t), GetPlayerInterior(t), GetPlayerVirtualWorld(t), ip);
            RP_Info(playerid, D_BACKACT, "Oyuncuyu Incele", str);
            RP_Log(rid, an, "INCELEDI", "");
        }
        case 1: // git
        {
            new t = RP_FindTarget(playerid);
            if (t == INVALID_PLAYER_ID)
            {
                RP_Info(playerid, D_BACKACT, "Oyuncuya Git", "{FFFFFF}Sikayet edilen oyuncu su an cevrimdisi.");
                return 1;
            }
            new Float:x, Float:y, Float:z;
            GetPlayerPos(t, x, y, z);
            SetPlayerInterior(playerid, GetPlayerInterior(t));
            SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(t));
            SetPlayerPos(playerid, x + 1.0, y, z);
            SendClientMessage(playerid, COL_OK, "Oyuncunun konumuna isinlandiniz.");
            RP_Log(rid, an, "ISINLANDI", "");
        }
        case 2: // spectate
        {
            new t = RP_FindTarget(playerid);
            if (t == INVALID_PLAYER_ID || t == playerid)
            {
                RP_Info(playerid, D_BACKACT, "Spectate", "{FFFFFF}Oyuncu cevrimdisi veya gecersiz.");
                return 1;
            }
            if (!pSpecOn[playerid])
            {
                GetPlayerPos(playerid, pSpecPos[playerid][0], pSpecPos[playerid][1], pSpecPos[playerid][2]);
                GetPlayerFacingAngle(playerid, pSpecPos[playerid][3]);
                pSpecInt[playerid] = GetPlayerInterior(playerid);
                pSpecVW[playerid] = GetPlayerVirtualWorld(playerid);
                TogglePlayerSpectating(playerid, 1);
            }
            pSpecOn[playerid] = 1;
            pSpecTarget[playerid] = t;
            SetTimerEx("RP_DoSpec", 300, false, "ii", playerid, t);
            SendClientMessage(playerid, COL_OK, "Spectate basladi. Bitirmek icin /specoff");
            RP_Log(rid, an, "SPECTATE", "");
        }
        case 3: // ustlen
        {
            if (st != ST_PENDING)
            {
                SendClientMessage(playerid, COL_ERR, (st == ST_REVIEW) ? ("Bu rapor zaten baska bir admin tarafindan ustlenilmis.") : ("Bu rapor kapatilmis."));
                return 1;
            }
            new ea[64], q[300];
            RP_Esc(an, ea);
            format(q, sizeof q, "UPDATE reports SET status=1, admin='%s' WHERE id=%d AND status=0", ea, rid);
            RP_Exec(q);
            RP_Load(playerid, rid);
            if (pRep[playerid][rStatus] == ST_REVIEW && !strcmp(pRep[playerid][rAdmin], an, true))
            {
                RP_Log(rid, an, "USTLENDI", "");
                format(msg, sizeof msg, "[RAPOR #%d] %s tarafindan ustlenildi.", rid, an);
                RP_NotifyAdmins(msg, ADMIN_LEVEL);
                format(msg, sizeof msg, "[RAPOR #%d] Raporunuz incelenmeye alindi.", rid);
                RP_NotifyReporter(playerid, msg);
            }
            else SendClientMessage(playerid, COL_ERR, "Rapor ustlenilemedi (baska admin almis olabilir).");
        }
        case 4: // coz
        {
            if (st == ST_DONE || st == ST_REJECT) { SendClientMessage(playerid, COL_ERR, "Bu rapor zaten kapatilmis."); return 1; }
            if (st == ST_PENDING) { SendClientMessage(playerid, COL_ERR, "Once raporu ustlenmelisiniz."); return 1; }
            if (!mine && !RP_IsSuper(playerid)) { SendClientMessage(playerid, COL_ERR, "Bu raporu baska bir admin ustlenmis."); return 1; }
            ShowPlayerDialog(playerid, D_RESOLVE, DIALOG_STYLE_INPUT, "Raporu Coz", "{FFFFFF}Sonuc notunu yazin (oyuncuya iletilir):", "Coz", "Iptal");
        }
        case 5: // reddet
        {
            if (st == ST_DONE || st == ST_REJECT) { SendClientMessage(playerid, COL_ERR, "Bu rapor zaten kapatilmis."); return 1; }
            if (st == ST_REVIEW && !mine && !RP_IsSuper(playerid)) { SendClientMessage(playerid, COL_ERR, "Bu raporu baska bir admin ustlenmis."); return 1; }
            ShowPlayerDialog(playerid, D_REJECT, DIALOG_STYLE_INPUT, "Raporu Reddet", "{FFFFFF}Red gerekcesini yazin (zorunlu):", "Reddet", "Iptal");
        }
        case 6: // not
        {
            ShowPlayerDialog(playerid, D_NOTE, DIALOG_STYLE_INPUT, "Not Birak", "{FFFFFF}Diger yetkililerin gorecegi notu yazin:", "Kaydet", "Iptal");
        }
        case 7: // notlar ve islem kaydi
        {
            new q[300], str[1800], line[260], dt[24], adm[25], act[40], note[128];
            format(q, sizeof q, "SELECT strftime('%%d.%%m.%%Y %%H:%%M', ts, 'unixepoch', 'localtime'), admin, action, note FROM report_logs WHERE report_id=%d ORDER BY id DESC LIMIT 12", rid);
            new DBResult:r = db_query(gDB, q);
            str = "";
            if (r)
            {
                new rows = db_num_rows(r);
                for (new i = 0; i < rows; i++)
                {
                    db_get_field(r, 0, dt, sizeof dt);
                    db_get_field(r, 1, adm, sizeof adm);
                    db_get_field(r, 2, act, sizeof act);
                    db_get_field(r, 3, note, sizeof note);
                    format(line, sizeof line, "{AAAAAA}[%s] {FFCC00}%s {FFFFFF}- %s %s\n", dt, act, adm, note);
                    strcat(str, line);
                    db_next_row(r);
                }
                db_free_result(r);
            }
            if (!str[0]) str = "{FFFFFF}Kayit bulunamadi.";
            RP_Info(playerid, D_BACKACT, "Notlar ve Islem Kaydi", str);
        }
        case 8: // hedefin gecmis raporlari
        {
            new et[64], q[500], str[1800], line[260], tmp[16];
            RP_Esc(pRep[playerid][rTarget], et);
            format(q, sizeof q, "SELECT id, category, status, reason FROM reports WHERE target='%s' COLLATE NOCASE AND id<>%d AND (category<>1 OR %d=1) ORDER BY id DESC LIMIT 10", et, rid, RP_IsSuper(playerid) ? 1 : 0);
            new DBResult:r = db_query(gDB, q);
            str = "No\tKategori\tDurum\tSebep\n";
            new n = 0;
            if (r)
            {
                new rows = db_num_rows(r);
                for (new i = 0; i < rows; i++)
                {
                    new id, cat, s, reason[128];
                    db_get_field(r, 0, tmp, sizeof tmp); id = strval(tmp);
                    db_get_field(r, 1, tmp, sizeof tmp); cat = strval(tmp);
                    db_get_field(r, 2, tmp, sizeof tmp); s = strval(tmp);
                    db_get_field(r, 3, reason, sizeof reason);
                    if (cat < 0 || cat > 3) cat = 3;
                    if (s < 0 || s > 3) s = 0;
                    format(line, sizeof line, "#%d\t%s\t%s\t%s\n", id, gCatNames[cat], gStatusNames[s], reason);
                    strcat(str, line);
                    n++;
                    db_next_row(r);
                }
                db_free_result(r);
            }
            if (!n) { RP_Info(playerid, D_BACKACT, "Gecmis Raporlar", "{FFFFFF}Bu oyuncu hakkinda baska rapor yok."); return 1; }
            ShowPlayerDialog(playerid, D_TARGETHIST, DIALOG_STYLE_TABLIST_HEADERS, "Sikayet Edilenin Gecmis Raporlari", str, "Geri", "Kapat");
        }
    }
    return 1;
}

// ---------------------------------------------------------------- spectate

public RP_DoSpec(playerid, targetid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerConnected(targetid) || !pSpecOn[playerid]) return 0;
    SetPlayerInterior(playerid, GetPlayerInterior(targetid));
    SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
    PlayerSpectatePlayer(playerid, targetid);
    return 1;
}

stock RP_StopSpec(playerid)
{
    if (!pSpecOn[playerid]) return 0;
    pSpecOn[playerid] = 0;
    pSpecTarget[playerid] = INVALID_PLAYER_ID;
    pSpecReturn[playerid] = 1;
    TogglePlayerSpectating(playerid, 0);
    return 1;
}

public RP_Restore(playerid)
{
    if (!IsPlayerConnected(playerid) || !pSpecReturn[playerid]) return 0;
    pSpecReturn[playerid] = 0;
    SetPlayerInterior(playerid, pSpecInt[playerid]);
    SetPlayerVirtualWorld(playerid, pSpecVW[playerid]);
    SetPlayerPos(playerid, pSpecPos[playerid][0], pSpecPos[playerid][1], pSpecPos[playerid][2]);
    SetPlayerFacingAngle(playerid, pSpecPos[playerid][3]);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if (pSpecReturn[playerid]) SetTimerEx("RP_Restore", 400, false, "i", playerid);
    return 1;
}

// ---------------------------------------------------------------- callbackler

public OnFilterScriptInit()
{
    gDB = db_open(DB_FILE);
    if (!_:gDB)
    {
        print("[RAPOR] HATA: veritabani acilamadi!");
        return 1;
    }
    new tq[700];
    tq = "CREATE TABLE IF NOT EXISTS reports (id INTEGER PRIMARY KEY AUTOINCREMENT, ";
    strcat(tq, "ts INTEGER, category INTEGER, priority INTEGER DEFAULT 0, ");
    strcat(tq, "reporter TEXT, reporter_id INTEGER, target TEXT, target_id INTEGER, ");
    strcat(tq, "reason TEXT, detail TEXT, evidence TEXT, ");
    strcat(tq, "status INTEGER DEFAULT 0, admin TEXT DEFAULT '', result_note TEXT DEFAULT '', ");
    strcat(tq, "closed_ts INTEGER DEFAULT 0)");
    RP_Exec(tq);
    tq = "CREATE TABLE IF NOT EXISTS report_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, ";
    strcat(tq, "report_id INTEGER, ts INTEGER, admin TEXT, action TEXT, note TEXT)");
    RP_Exec(tq);
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        pLastReport[i] = 0;
        pSpecOn[i] = 0;
        pSpecReturn[i] = 0;
        pSpecTarget[i] = INVALID_PLAYER_ID;
    }
    print("[RAPOR] DUKTUR RP rapor sistemi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    if (_:gDB) db_close(gDB);
    return 1;
}

public OnPlayerConnect(playerid)
{
    pLastReport[playerid] = 0;
    pSpecOn[playerid] = 0;
    pSpecReturn[playerid] = 0;
    pSpecTarget[playerid] = INVALID_PLAYER_ID;
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    pSpecOn[playerid] = 0;
    pSpecReturn[playerid] = 0;
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && pSpecOn[i] && pSpecTarget[i] == playerid)
        {
            RP_StopSpec(i);
            SendClientMessage(i, COL_INFO, "Izlediginiz oyuncu oyundan ayrildi, spectate sona erdi.");
        }
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!strcmp(cmdtext, "/report", true))
    {
        new left = REPORT_COOLDOWN - (gettime() - pLastReport[playerid]);
        if (left > 0)
        {
            new msg[96];
            format(msg, sizeof msg, "Yeni rapor gondermek icin %d saniye beklemelisiniz.", left);
            SendClientMessage(playerid, COL_ERR, msg);
            return 1;
        }
        RP_ShowCategory(playerid);
        return 1;
    }
    if (!strcmp(cmdtext, "/raporlarim", true))
    {
        RP_ShowMyList(playerid);
        return 1;
    }
    if (!strcmp(cmdtext, "/reports", true))
    {
        if (!RP_IsAdmin(playerid)) { SendClientMessage(playerid, COL_ERR, "Bu komutu kullanma yetkiniz yok."); return 1; }
        RP_ShowPanel(playerid);
        return 1;
    }
    if (!strcmp(cmdtext, "/specoff", true))
    {
        if (!RP_IsAdmin(playerid)) { SendClientMessage(playerid, COL_ERR, "Bu komutu kullanma yetkiniz yok."); return 1; }
        if (!RP_StopSpec(playerid)) SendClientMessage(playerid, COL_ERR, "Su an spectate modunda degilsiniz.");
        else SendClientMessage(playerid, COL_OK, "Spectate sona erdi.");
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        // ------------- oyuncu raporu
        case D_REP_CAT:
        {
            if (!response) return 1;
            if (listitem < 0 || listitem > 3) return 1;
            pCat[playerid] = listitem;
            RP_ShowTargetDlg(playerid);
            return 1;
        }
        case D_REP_TARGET:
        {
            if (!response) return 1;
            if (!RP_IsNum(inputtext)) { SendClientMessage(playerid, COL_ERR, "Gecerli bir ID girin."); RP_ShowTargetDlg(playerid); return 1; }
            new id = strval(inputtext);
            if (id == -1 && (pCat[playerid] == CAT_CHEAT || pCat[playerid] == CAT_OTHER))
            {
                pTargetID[playerid] = -1;
            }
            else
            {
                if (id < 0 || id >= MAX_PLAYERS || !IsPlayerConnected(id)) { SendClientMessage(playerid, COL_ERR, "Bu ID'de bir oyuncu yok."); RP_ShowTargetDlg(playerid); return 1; }
                if (id == playerid) { SendClientMessage(playerid, COL_ERR, "Kendinizi sikayet edemezsiniz."); RP_ShowTargetDlg(playerid); return 1; }
                pTargetID[playerid] = id;
            }
            ShowPlayerDialog(playerid, D_REP_REASON, DIALOG_STYLE_INPUT, "Rapor - Sebep", "{FFFFFF}Sikayet sebebini kisaca yazin:", "Ileri", "Iptal");
            return 1;
        }
        case D_REP_REASON:
        {
            if (!response) return 1;
            if (strlen(inputtext) < 3) { SendClientMessage(playerid, COL_ERR, "Sebep cok kisa."); ShowPlayerDialog(playerid, D_REP_REASON, DIALOG_STYLE_INPUT, "Rapor - Sebep", "{FFFFFF}Sikayet sebebini kisaca yazin:", "Ileri", "Iptal"); return 1; }
            format(pReason[playerid], 128, "%s", inputtext);
            RP_Clean(pReason[playerid]);
            ShowPlayerDialog(playerid, D_REP_DETAIL, DIALOG_STYLE_INPUT, "Rapor - Aciklama", "{FFFFFF}Olayi detayli aciklayin:", "Ileri", "Iptal");
            return 1;
        }
        case D_REP_DETAIL:
        {
            if (!response) return 1;
            if (strlen(inputtext) < 5) { SendClientMessage(playerid, COL_ERR, "Aciklama cok kisa."); ShowPlayerDialog(playerid, D_REP_DETAIL, DIALOG_STYLE_INPUT, "Rapor - Aciklama", "{FFFFFF}Olayi detayli aciklayin:", "Ileri", "Iptal"); return 1; }
            format(pDetail[playerid], 128, "%s", inputtext);
            RP_Clean(pDetail[playerid]);
            ShowPlayerDialog(playerid, D_REP_EVID, DIALOG_STYLE_INPUT, "Rapor - Kanit", "{FFFFFF}Kanit baglantisi (video/resim linki).\n{AAAAAA}Yoksa - yazin.", "Gonder", "Iptal");
            return 1;
        }
        case D_REP_EVID:
        {
            if (!response) return 1;
            new left = REPORT_COOLDOWN - (gettime() - pLastReport[playerid]);
            if (left > 0) { SendClientMessage(playerid, COL_ERR, "Cok hizli rapor gonderiyorsunuz."); return 1; }
            new evid[128];
            format(evid, sizeof evid, "%s", inputtext);
            RP_Clean(evid);
            if (!evid[0]) evid = "-";
            RP_Submit(playerid, evid);
            return 1;
        }
        case D_MY_LIST:
        {
            if (!response) return 1;
            if (listitem < 0 || listitem >= MAX_LIST) return 1;
            new id = pListIds[playerid][listitem];
            if (id > 0) RP_ShowMyDetail(playerid, id);
            return 1;
        }
        case D_MY_DETAIL:
        {
            if (response) RP_ShowMyList(playerid);
            return 1;
        }

        // ------------- admin paneli
        case D_PANEL:
        {
            if (!response) return 1;
            if (!RP_IsAdmin(playerid)) return 1;
            RP_ShowList(playerid, listitem);
            return 1;
        }
        case D_BACKPANEL:
        {
            if (response) RP_ShowPanel(playerid);
            return 1;
        }
        case D_LIST:
        {
            if (!response) { RP_ShowPanel(playerid); return 1; }
            if (!RP_IsAdmin(playerid)) return 1;
            if (listitem < 0 || listitem >= MAX_LIST) return 1;
            new id = pListIds[playerid][listitem];
            if (id > 0) RP_ShowDetail(playerid, id);
            return 1;
        }
        case D_DETAIL:
        {
            if (!RP_IsAdmin(playerid)) return 1;
            if (response) RP_ShowActions(playerid);
            else RP_ShowList(playerid, pListType[playerid]);
            return 1;
        }
        case D_ACTIONS:
        {
            if (!RP_IsAdmin(playerid)) return 1;
            if (!response) { RP_ShowDetail(playerid, pCurReport[playerid]); return 1; }
            RP_DoAction(playerid, listitem);
            // anlik islemlerden sonra detay ekranina don (diyalog acan islemler kendi dialogunu acar)
            if (listitem == 1 || listitem == 2 || listitem == 3) RP_ShowDetail(playerid, pCurReport[playerid]);
            return 1;
        }
        case D_BACKACT:
        {
            if (!RP_IsAdmin(playerid)) return 1;
            if (response) RP_ShowActions(playerid);
            return 1;
        }
        case D_TARGETHIST:
        {
            if (response && RP_IsAdmin(playerid)) RP_ShowActions(playerid);
            return 1;
        }
        case D_RESOLVE, D_REJECT:
        {
            if (!RP_IsAdmin(playerid)) return 1;
            if (!response) { RP_ShowActions(playerid); return 1; }
            if (!RP_Load(playerid, pCurReport[playerid])) { SendClientMessage(playerid, COL_ERR, "Rapor bulunamadi."); return 1; }

            new an[MAX_PLAYER_NAME + 1], st = pRep[playerid][rStatus], rid = pRep[playerid][rId];
            GetPlayerName(playerid, an, sizeof an);
            new mine = (!strcmp(pRep[playerid][rAdmin], an, true));
            if (st == ST_DONE || st == ST_REJECT) { SendClientMessage(playerid, COL_ERR, "Bu rapor zaten kapatilmis."); return 1; }
            if (st == ST_REVIEW && !mine && !RP_IsSuper(playerid)) { SendClientMessage(playerid, COL_ERR, "Bu raporu baska bir admin ustlenmis."); return 1; }
            if (dialogid == D_RESOLVE && st == ST_PENDING) { SendClientMessage(playerid, COL_ERR, "Once raporu ustlenmelisiniz."); return 1; }

            new note[128];
            format(note, sizeof note, "%s", inputtext);
            RP_Clean(note);
            if (strlen(note) < 3)
            {
                SendClientMessage(playerid, COL_ERR, "Not/gerekce en az 3 karakter olmali.");
                RP_DoAction(playerid, (dialogid == D_RESOLVE) ? 4 : 5);
                return 1;
            }

            new en[300], ea[64], q[700], newst = (dialogid == D_RESOLVE) ? ST_DONE : ST_REJECT;
            RP_Esc(note, en);
            RP_Esc(an, ea);
            format(q, sizeof q, "UPDATE reports SET status=%d, result_note='%s', closed_ts=%d, admin='%s' WHERE id=%d AND status IN (0,1)", newst, en, gettime(), ea, rid);
            RP_Exec(q);
            RP_Log(rid, an, (newst == ST_DONE) ? ("COZDU") : ("REDDETTI"), note);

            new msg[200], shortnote[70];
            strmid(shortnote, note, 0, 69, sizeof shortnote);
            if (newst == ST_DONE) format(msg, sizeof msg, "[RAPOR #%d] Raporunuz sonuclandirildi: %s", rid, shortnote);
            else format(msg, sizeof msg, "[RAPOR #%d] Raporunuz reddedildi: %s", rid, shortnote);
            RP_NotifyReporter(playerid, msg);

            format(msg, sizeof msg, "Rapor #%d %s.", rid, (newst == ST_DONE) ? ("sonuclandirildi") : ("reddedildi"));
            SendClientMessage(playerid, COL_OK, msg);
            RP_ShowList(playerid, pListType[playerid]);
            return 1;
        }
        case D_NOTE:
        {
            if (!RP_IsAdmin(playerid)) return 1;
            if (!response) { RP_ShowActions(playerid); return 1; }
            if (!RP_Load(playerid, pCurReport[playerid])) { SendClientMessage(playerid, COL_ERR, "Rapor bulunamadi."); return 1; }
            new note[128], an[MAX_PLAYER_NAME + 1];
            format(note, sizeof note, "%s", inputtext);
            RP_Clean(note);
            if (strlen(note) < 2) { SendClientMessage(playerid, COL_ERR, "Not cok kisa."); return 1; }
            GetPlayerName(playerid, an, sizeof an);
            RP_Log(pRep[playerid][rId], an, "NOT", note);
            SendClientMessage(playerid, COL_OK, "Not kaydedildi.");
            RP_ShowActions(playerid);
            return 1;
        }
    }
    return 0;
}
