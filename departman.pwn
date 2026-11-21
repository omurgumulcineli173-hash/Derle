/*
    ====================================================================
    SA-MP DEPARTMAN SISTEMI  (Filterscript)  v1.0
    Departmanlar: Belediye, FBI, Polis (LSPD), Hastane (EMS), Medya (NEWS)

    KURULUM:
      1) Bu dosyayi  pawno/  veya  filterscripts/  klasorune koy: departman.pwn
      2) Pawno ile derle -> departman.amx olusur, filterscripts/ icine koy
      3) server.cfg icindeki filterscripts satirinin sonuna  departman  ekle
      4) scriptfiles/ klasoru sunucuda olmali (departman.db oraya olusur)
      5) Dosyayi ANSI (Windows-1254) kaydet. Metinler Turkce karaktersiz yazildi.

    KOMUTLAR:
      /departman  /tablet  /gorev  /d  /haberler  /mekanlar  /yardim
      /ihbar  /acil  /sikayet
      /departmanver [id] [dep 0-4] [rutbe 1-5]   (sadece RCON admin)
    ====================================================================
*/

#include <a_samp>

#pragma dynamic 16384
#pragma tabsize 0

#define MAX_DEP          5
#define MAX_RANK         5
#define MAX_LOC          16
#define MAX_TABITEM      24
#define MAX_LISTITEM     30
#define YONETIM_RUTBE    4
#define RANK_MAAS        600
#define MAAS_SURE_DK     60
#define BASLANGIC_BUTCE  100000
#define DB_DOSYA         "departman.db"

#define C_ERR 0xFF6B6BFF
#define C_OK  0x6BFF8BFF
#define C_INF 0x6BC8FFFF

#define IsYonetici(%1) (PDep[%1] >= 0 && PRank[%1] >= YONETIM_RUTBE)

// Tablet islem kodlari
#define ACT_PERS     1
#define ACT_DUY      2
#define ACT_DUYNEW   3
#define ACT_MSG      4
#define ACT_BUTCE    5
#define ACT_YONET    6
#define ACT_SORGUK   7
#define ACT_SORGUP   8
#define ACT_RUHSAT   9
#define ACT_HNEW     10
#define ACT_HONAY    11
#define ACT_HGEC     12
#define ACT_DUTY     13
#define ACT_REC      100

enum
{
    D_NONE = 9100,
    D_BACK, D_DEPLIST, D_DEPINFO, D_MEKANLIST,
    D_TAB, D_DUYYAZ, D_MESAJ, D_BUTCE, D_BUTCEMIKTAR,
    D_YONET, D_YONETID, D_YONETRANK, D_YONETMAAS,
    D_RECSUB, D_RECHEDEF, D_RECMETIN,
    D_SORGUK, D_SORGUP, D_RUHSAT,
    D_HBASLIK, D_HMETIN, D_HTUR, D_HONAY, D_HONAYACT, D_HGECMIS, D_HGECACT, D_HEDIT
}

// ------------------------------------------------------------------
//  DEPARTMAN VERILERI
// ------------------------------------------------------------------
new DepName[MAX_DEP][24] = {"Belediye", "FBI", "Polis (LSPD)", "Hastane (EMS)", "Medya (NEWS)"};
new DepTablet[MAX_DEP][24] = {"Belediye Tableti", "FBI MDT", "Polis MDT", "EMS Tableti", "Haber Tableti"};
new DepColor[MAX_DEP] = {0xF1C40FFF, 0x95A5A6FF, 0x3498DBFF, 0xE74C3CFF, 0x9B59B6FF};
new DepEmbed[MAX_DEP][10] = {"{F1C40F}", "{95A5A6}", "{3498DB}", "{E74C3C}", "{9B59B6}"};
new DepSkin[MAX_DEP] = {147, 286, 280, 274, 59};
new DepIcon[MAX_DEP] = {36, 30, 30, 22, 55};
new DepDesc[MAX_DEP][200] =
{
    "Sehrin yonetimi, ruhsat, vergi ve vatandas islemlerinden sorumludur.",
    "Federal sorusturmalar, operasyonlar ve ozel vakalar ile ilgilenir.",
    "Sehirde asayisi saglar, ihbarlara mudahale eder, ceza ve tutanak tutar.",
    "Acil saglik hizmeti, ambulans ve hasta tedavisinden sorumludur.",
    "Haber, canli yayin ve etkinlik duyurulari ile halki bilgilendirir."
};
new RankName[MAX_DEP][MAX_RANK][24] =
{
    {"Memur", "Uzman Memur", "Sef", "Baskan Yrd.", "Belediye Baskani"},
    {"Stajyer Ajan", "Ajan", "Ozel Ajan", "Mudur Yrd.", "FBI Muduru"},
    {"Cadet", "Memur", "Komiser Yrd.", "Komiser", "Polis Muduru"},
    {"Stajyer", "Paramedik", "Doktor", "Basdoktor", "Hastane Muduru"},
    {"Muhabir", "Gazeteci", "Editor", "Yazi Isleri Md.", "Medya Muduru"}
};
new RecCount[MAX_DEP] = {5, 6, 5, 5, 1};
new RecType[MAX_DEP][6][28] =
{
    {"Is Yeri Ruhsati", "Vergi Kaydi", "Vatandas Sikayeti", "Basvuru", "Toplanti Kaydi", ""},
    {"Operasyon Kaydi", "Sorusturma Dosyasi", "Olay Kaydi", "Delil Kaydi", "Gorev Raporu", "Gorev Atamasi"},
    {"Olay Raporu", "Ihbar Kaydi", "Ceza Kaydi", "Resmi Tutanak", "Gorev Atamasi", ""},
    {"Hasta Kaydi", "Tedavi Kaydi", "Hastane Raporu", "Ambulans Cagrisi", "Acil Servis Cagrisi", ""},
    {"Yayin Notu", "", "", "", "", ""}
};

// ------------------------------------------------------------------
//  MEKANLAR
// ------------------------------------------------------------------
new LocCount;
new LocDep[MAX_LOC], LocPub[MAX_LOC], LocInt[MAX_LOC];
new LocName[MAX_LOC][32];
new Float:LocOut[MAX_LOC][4];
new Float:LocIn[MAX_LOC][4];
new LocPickO[MAX_LOC], LocPickI[MAX_LOC];

// ------------------------------------------------------------------
//  OYUNCU VERILERI
// ------------------------------------------------------------------
new DB:gDB;
new PDep[MAX_PLAYERS], PRank[MAX_PLAYERS], PMaas[MAX_PLAYERS];
new bool:PDuty[MAX_PLAYERS];
new PAct[MAX_PLAYERS], PTarget[MAX_PLAYERS], PTmp[MAX_PLAYERS];
new PTmpStr[MAX_PLAYERS][128], PTmpStr2[MAX_PLAYERS][128];
new PTab[MAX_PLAYERS][MAX_TABITEM];
new PList[MAX_PLAYERS][MAX_LISTITEM];
new PTeleTick[MAX_PLAYERS];
new PlayerText:PTD[MAX_PLAYERS][4];

forward MaasVer();
forward PanelYenile();

// ==================================================================
//  YARDIMCI FONKSIYONLAR
// ==================================================================
stock DbExec(q[])
{
    new DBResult:r = db_query(gDB, q);
    if(r) db_free_result(r);
}

stock DbGetInt(q[], def = 0)
{
    new DBResult:r = db_query(gDB, q), f[32];
    if(r)
    {
        if(db_num_rows(r))
        {
            db_get_field(r, 0, f, sizeof f);
            def = strval(f);
        }
        db_free_result(r);
    }
    return def;
}

stock DbGetStr(q[], dest[], size, def[] = "")
{
    format(dest, size, "%s", def);
    new DBResult:r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r)) db_get_field(r, 0, dest, size);
        db_free_result(r);
    }
}

stock Esc(s[])
{
    for(new i = 0; s[i]; i++)
    {
        if(s[i] == '\'' || s[i] == '"' || s[i] == '\\' || s[i] == '%') s[i] = ' ';
    }
}

stock TimeStr(dest[], size = 24)
{
    new y, mo, d, h, mi, sc;
    getdate(y, mo, d);
    gettime(h, mi, sc);
    format(dest, size, "%02d.%02d.%d %02d:%02d", d, mo, y, h, mi);
}

stock Token(str[], &idx, dest[], size = 32)
{
    new len = strlen(str), o = 0;
    while(idx < len && str[idx] == ' ') idx++;
    while(idx < len && str[idx] != ' ' && o < size - 1) dest[o++] = str[idx++];
    dest[o] = 0;
    return o;
}

stock GetPart(src[], idx, dest[], size = 32)
{
    new cur = 0, start = 0, len = strlen(src);
    dest[0] = 0;
    for(new i = 0; i <= len; i++)
    {
        if(src[i] == ',' || src[i] == 0)
        {
            if(cur == idx)
            {
                new n = i - start;
                if(n >= size) n = size - 1;
                strmid(dest, src, start, start + n, size);
                while(dest[0] == ' ') strdel(dest, 0, 1);
                return 1;
            }
            cur++;
            start = i + 1;
        }
    }
    return 0;
}

stock IsNameOnline(name[])
{
    new n[MAX_PLAYER_NAME];
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if(!strcmp(n, name, true)) return 1;
    }
    return 0;
}

stock ResolveTarget(txt[])
{
    if(txt[0] >= '0' && txt[0] <= '9')
    {
        new id = strval(txt);
        if(id >= 0 && id < MAX_PLAYERS && IsPlayerConnected(id)) return id;
        return INVALID_PLAYER_ID;
    }
    new n[MAX_PLAYER_NAME];
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if(strfind(n, txt, true) != -1) return i;
    }
    return INVALID_PLAYER_ID;
}

stock CountOnline(dep)
{
    new c = 0;
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && PDep[i] == dep) c++;
    return c;
}

stock CountMembers(dep)
{
    new q[80];
    format(q, sizeof q, "SELECT COUNT(*) FROM uyeler WHERE dep=%d", dep);
    return DbGetInt(q);
}

stock GetMudur(dep, dest[], size)
{
    new q[100];
    format(q, sizeof q, "SELECT isim FROM uyeler WHERE dep=%d AND rutbe=%d LIMIT 1", dep, MAX_RANK);
    DbGetStr(q, dest, size, "Atanmadi");
}

stock SendDep(dep, color, msg[])
{
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && PDep[i] == dep) SendClientMessage(i, color, msg);
}

stock AddHistory(dep, name[], olay[])
{
    new q[320], t[24], n[32], o[100];
    format(n, sizeof n, "%s", name);
    format(o, sizeof o, "%s", olay);
    Esc(n); Esc(o);
    TimeStr(t);
    format(q, sizeof q, "INSERT INTO gecmis (dep,isim,olay,tarih) VALUES (%d,'%s','%s','%s')", dep, n, o, t);
    DbExec(q);
}

stock InsertRec(dep, tur, hedef[], yazar[], metin[])
{
    new q[600], t[24], h[64], y[32], m[160];
    format(h, sizeof h, "%s", hedef);
    format(y, sizeof y, "%s", yazar);
    format(m, sizeof m, "%s", metin);
    Esc(h); Esc(y); Esc(m);
    TimeStr(t);
    format(q, sizeof q, "INSERT INTO kayitlar (dep,tur,hedef,yazar,metin,tarih) VALUES (%d,%d,'%s','%s','%s','%s')", dep, tur, h, y, m, t);
    DbExec(q);
}

// ==================================================================
//  VERITABANI
// ==================================================================
stock DBInit()
{
    gDB = db_open(DB_DOSYA);
    if(!gDB)
    {
        print("[Departman] HATA: Veritabani acilamadi! scriptfiles klasorunu kontrol et.");
        return 0;
    }
    DbExec("CREATE TABLE IF NOT EXISTS uyeler (isim TEXT PRIMARY KEY, dep INTEGER, rutbe INTEGER, maas INTEGER, katilma TEXT)");
    DbExec("CREATE TABLE IF NOT EXISTS duyurular (id INTEGER PRIMARY KEY AUTOINCREMENT, dep INTEGER, yazar TEXT, metin TEXT, tarih TEXT)");
    DbExec("CREATE TABLE IF NOT EXISTS kayitlar (id INTEGER PRIMARY KEY AUTOINCREMENT, dep INTEGER, tur INTEGER, hedef TEXT, yazar TEXT, metin TEXT, tarih TEXT)");
    DbExec("CREATE TABLE IF NOT EXISTS gecmis (id INTEGER PRIMARY KEY AUTOINCREMENT, dep INTEGER, isim TEXT, olay TEXT, tarih TEXT)");
    DbExec("CREATE TABLE IF NOT EXISTS butce (dep INTEGER PRIMARY KEY, miktar INTEGER)");
    DbExec("CREATE TABLE IF NOT EXISTS haberler (id INTEGER PRIMARY KEY AUTOINCREMENT, baslik TEXT, metin TEXT, yazar TEXT, durum INTEGER, herkes INTEGER, tur INTEGER, tarih TEXT)");
    DbExec("CREATE TABLE IF NOT EXISTS araclar (plaka TEXT PRIMARY KEY, sahip TEXT, model TEXT, tarih TEXT)");
    new q[100];
    for(new d = 0; d < MAX_DEP; d++)
    {
        format(q, sizeof q, "INSERT OR IGNORE INTO butce (dep,miktar) VALUES (%d,%d)", d, BASLANGIC_BUTCE);
        DbExec(q);
    }
    return 1;
}

// ==================================================================
//  MEKANLAR
// ==================================================================
stock AddLoc(dep, name[], pub, Float:ox, Float:oy, Float:oz, Float:oa, Float:ix, Float:iy, Float:iz, Float:ia, interior)
{
    if(LocCount >= MAX_LOC) return -1;
    new i = LocCount++;
    LocDep[i] = dep;
    LocPub[i] = pub;
    LocInt[i] = interior;
    format(LocName[i], 32, "%s", name);
    LocOut[i][0] = ox; LocOut[i][1] = oy; LocOut[i][2] = oz; LocOut[i][3] = oa;
    LocIn[i][0] = ix; LocIn[i][1] = iy; LocIn[i][2] = iz; LocIn[i][3] = ia;
    LocPickO[i] = CreatePickup(1318, 1, ox, oy, oz, 0);
    LocPickI[i] = CreatePickup(1318, 1, ix, iy, iz, i + 1);
    new lbl[80];
    format(lbl, sizeof lbl, "%s\n%s", name, pub ? "Herkese Acik" : "Sadece Personel");
    Create3DTextLabel(lbl, DepColor[dep], ox, oy, oz + 0.8, 20.0, 0, 0);
    Create3DTextLabel("CIKIS", 0xFFFFFFFF, ix, iy, iz + 0.8, 10.0, i + 1, 0);
    return i;
}

stock DoTeleport(playerid, loc, bool:giris)
{
    new Float:x, Float:y, Float:z, Float:a;
    if(giris)
    {
        if(!LocPub[loc] && PDep[playerid] != LocDep[loc])
        {
            new s[96];
            format(s, sizeof s, "Bu mekana sadece %s personeli girebilir.", DepName[LocDep[loc]]);
            SendClientMessage(playerid, C_ERR, s);
            return 0;
        }
        a = LocIn[loc][3];
        x = LocIn[loc][0] - 2.0 * floatsin(a, degrees);
        y = LocIn[loc][1] + 2.0 * floatcos(a, degrees);
        z = LocIn[loc][2];
        SetPlayerInterior(playerid, LocInt[loc]);
        SetPlayerVirtualWorld(playerid, loc + 1);
    }
    else
    {
        a = LocOut[loc][3];
        x = LocOut[loc][0] - 2.0 * floatsin(a, degrees);
        y = LocOut[loc][1] + 2.0 * floatcos(a, degrees);
        z = LocOut[loc][2];
        SetPlayerInterior(playerid, 0);
        SetPlayerVirtualWorld(playerid, 0);
    }
    SetPlayerPos(playerid, x, y, z);
    SetPlayerFacingAngle(playerid, a);
    SetCameraBehindPlayer(playerid);
    PTeleTick[playerid] = GetTickCount();
    return 1;
}

stock SetMapIcons(playerid)
{
    for(new i = 0; i < LocCount; i++)
        SetPlayerMapIcon(playerid, i, LocOut[i][0], LocOut[i][1], LocOut[i][2], DepIcon[LocDep[i]], 0, MAPICON_GLOBAL);
}

// ==================================================================
//  SOL PANEL (MAVI)
// ==================================================================
stock CreatePanel(playerid)
{
    PTD[playerid][0] = CreatePlayerTextDraw(playerid, 10.0, 150.0, "_");
    PlayerTextDrawFont(playerid, PTD[playerid][0], 1);
    PlayerTextDrawLetterSize(playerid, PTD[playerid][0], 0.5, 11.6);
    PlayerTextDrawTextSize(playerid, PTD[playerid][0], 160.0, 0.0);
    PlayerTextDrawUseBox(playerid, PTD[playerid][0], 1);
    PlayerTextDrawBoxColor(playerid, PTD[playerid][0], 0x0A2A66AA);

    PTD[playerid][1] = CreatePlayerTextDraw(playerid, 16.0, 154.0, "DEPARTMAN");
    PlayerTextDrawFont(playerid, PTD[playerid][1], 2);
    PlayerTextDrawLetterSize(playerid, PTD[playerid][1], 0.28, 1.2);
    PlayerTextDrawColor(playerid, PTD[playerid][1], 0x6FB1FFFF);
    PlayerTextDrawSetOutline(playerid, PTD[playerid][1], 1);
    PlayerTextDrawSetProportional(playerid, PTD[playerid][1], 1);

    PTD[playerid][2] = CreatePlayerTextDraw(playerid, 16.0, 178.0, "_");
    PlayerTextDrawFont(playerid, PTD[playerid][2], 1);
    PlayerTextDrawLetterSize(playerid, PTD[playerid][2], 0.24, 1.0);
    PlayerTextDrawColor(playerid, PTD[playerid][2], 0xFFFFFFFF);
    PlayerTextDrawSetOutline(playerid, PTD[playerid][2], 1);
    PlayerTextDrawSetProportional(playerid, PTD[playerid][2], 1);

    PTD[playerid][3] = CreatePlayerTextDraw(playerid, 114.0, 152.0, "_");
    PlayerTextDrawFont(playerid, PTD[playerid][3], 5);
    PlayerTextDrawTextSize(playerid, PTD[playerid][3], 42.0, 50.0);
    PlayerTextDrawBackgroundColor(playerid, PTD[playerid][3], 0x00000000);
    PlayerTextDrawSetPreviewModel(playerid, PTD[playerid][3], 280);
}

stock HidePanel(playerid)
{
    for(new i = 0; i < 4; i++) PlayerTextDrawHide(playerid, PTD[playerid][i]);
}

stock ShowPanel(playerid)
{
    new d = PDep[playerid];
    if(d < 0 || !IsPlayerConnected(playerid)) { HidePanel(playerid); return; }
    new s[320];
    format(s, sizeof s, "~b~~h~%s", DepName[d]);
    PlayerTextDrawSetString(playerid, PTD[playerid][1], s);
    format(s, sizeof s, "~w~Rutbe: ~y~%s~n~~w~Gorev: %s~n~~w~Cevrimici: ~y~%d~n~~w~Maas: ~g~$%d~n~~n~~w~/tablet ~b~| ~w~/departman",
        RankName[d][PRank[playerid] - 1],
        PDuty[playerid] ? "~g~Aktif" : "~r~Pasif",
        CountOnline(d), PMaas[playerid]);
    PlayerTextDrawSetString(playerid, PTD[playerid][2], s);
    PlayerTextDrawSetPreviewModel(playerid, PTD[playerid][3], DepSkin[d]);
    for(new i = 0; i < 4; i++) PlayerTextDrawShow(playerid, PTD[playerid][i]);
}

public PanelYenile()
{
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && PDep[i] >= 0) ShowPanel(i);
}

// ==================================================================
//  UYELIK
// ==================================================================
stock UpdateMember(playerid)
{
    new q[200], n[MAX_PLAYER_NAME];
    GetPlayerName(playerid, n, sizeof n);
    Esc(n);
    format(q, sizeof q, "UPDATE uyeler SET rutbe=%d, maas=%d WHERE isim='%s'", PRank[playerid], PMaas[playerid], n);
    DbExec(q);
}

stock SetMember(playerid, dep, rank)
{
    new n[MAX_PLAYER_NAME], q[260], t[24], ev[100], old = PDep[playerid];
    GetPlayerName(playerid, n, sizeof n);
    Esc(n);
    if(old >= 0 && old != dep) AddHistory(old, n, "Baska departmana gecti");
    PDep[playerid] = dep;
    PRank[playerid] = rank;
    PMaas[playerid] = rank * RANK_MAAS;
    PDuty[playerid] = false;
    TimeStr(t);
    format(q, sizeof q, "INSERT OR REPLACE INTO uyeler (isim,dep,rutbe,maas,katilma) VALUES ('%s',%d,%d,%d,'%s')", n, dep, rank, PMaas[playerid], t);
    DbExec(q);
    format(ev, sizeof ev, "Katildi: %s", RankName[dep][rank - 1]);
    AddHistory(dep, n, ev);
    ShowPanel(playerid);
    format(q, sizeof q, "%s departmanina %s olarak katildin. Tablet icin /tablet yaz.", DepName[dep], RankName[dep][rank - 1]);
    SendClientMessage(playerid, DepColor[dep], q);
}

stock LeaveDept(playerid)
{
    new n[MAX_PLAYER_NAME], q[160], d = PDep[playerid];
    if(d < 0) return 0;
    GetPlayerName(playerid, n, sizeof n);
    Esc(n);
    AddHistory(d, n, "Departmandan ayrildi/cikarildi");
    format(q, sizeof q, "DELETE FROM uyeler WHERE isim='%s'", n);
    DbExec(q);
    PDep[playerid] = -1;
    PRank[playerid] = 0;
    PMaas[playerid] = 0;
    PDuty[playerid] = false;
    HidePanel(playerid);
    SendClientMessage(playerid, C_INF, "Departmandan ayrildin.");
    return 1;
}

stock SetRank(t, nr)
{
    new n[MAX_PLAYER_NAME], ev[100], d = PDep[t];
    GetPlayerName(t, n, sizeof n);
    PRank[t] = nr;
    PMaas[t] = nr * RANK_MAAS;
    UpdateMember(t);
    format(ev, sizeof ev, "Rutbe: %s", RankName[d][nr - 1]);
    AddHistory(d, n, ev);
    ShowPanel(t);
    format(ev, sizeof ev, "Yeni rutben: %s", RankName[d][nr - 1]);
    SendClientMessage(t, DepColor[d], ev);
}

// ==================================================================
//  DIALOG GOSTERIMLERI
// ==================================================================
stock ShowDepList(playerid)
{
    new s[700], l[140], mud[32];
    format(s, sizeof s, "Departman\tPersonel\tYonetici\n");
    for(new d = 0; d < MAX_DEP; d++)
    {
        GetMudur(d, mud, sizeof mud);
        format(l, sizeof l, "%s%s\t%d\t%s\n", DepEmbed[d], DepName[d], CountMembers(d), mud);
        strcat(s, l, sizeof s);
    }
    ShowPlayerDialog(playerid, D_DEPLIST, DIALOG_STYLE_TABLIST_HEADERS, "Departmanlar", s, "Sec", "Kapat");
}

stock ShowDepInfo(playerid, d)
{
    new s[1200], l[160], mud[32];
    GetMudur(d, mud, sizeof mud);
    format(s, sizeof s, "%s%s\n{FFFFFF}%s\n\n{AAAAAA}Yonetici: {FFFFFF}%s\n{AAAAAA}Personel: {FFFFFF}%d  (Cevrimici: %d)\n\n{AAAAAA}Rutbeler:\n{FFFFFF}",
        DepEmbed[d], DepName[d], DepDesc[d], mud, CountMembers(d), CountOnline(d));
    for(new r = 0; r < MAX_RANK; r++)
    {
        format(l, sizeof l, "%d) %s\n", r + 1, RankName[d][r]);
        strcat(s, l, sizeof s);
    }
    strcat(s, "\n{AAAAAA}Mekanlar:\n{FFFFFF}", sizeof s);
    for(new i = 0; i < LocCount; i++)
    {
        if(LocDep[i] != d) continue;
        format(l, sizeof l, "- %s (%s)\n", LocName[i], LocPub[i] ? "Herkese Acik" : "Sadece Personel");
        strcat(s, l, sizeof s);
    }
    new b1[12];
    if(PDep[playerid] == d) format(b1, sizeof b1, "Ayril");
    else format(b1, sizeof b1, "Katil");
    ShowPlayerDialog(playerid, D_DEPINFO, DIALOG_STYLE_MSGBOX, DepName[d], s, b1, "Geri");
}

stock ShowBack(playerid, style, cap[], info[])
{
    ShowPlayerDialog(playerid, D_BACK, style, cap, info, "Geri", "Kapat");
}

stock AddTab(playerid, &n, act, label[], list[], len)
{
    if(n >= MAX_TABITEM) return 0;
    PTab[playerid][n++] = act;
    strcat(list, label, len);
    strcat(list, "\n", len);
    return 1;
}

stock ActAllowed(playerid, act)
{
    new d = PDep[playerid];
    if(d < 0) return 0;
    switch(act)
    {
        case ACT_DUYNEW, ACT_YONET, ACT_HONAY: return IsYonetici(playerid);
        case ACT_SORGUK: return (d <= 3);
        case ACT_SORGUP: return (d == 1 || d == 2);
        case ACT_RUHSAT: return (d == 0);
        case ACT_HNEW, ACT_HGEC: return (d == 4);
    }
    return 1;
}

stock OpenTablet(playerid)
{
    new d = PDep[playerid];
    if(d < 0) return SendClientMessage(playerid, C_ERR, "Departman personeli degilsin. /departman ile bir departmana katil.");
    new list[1024], n = 0, cap[64], l[48];
    list[0] = 0;
    for(new i = 0; i < MAX_TABITEM; i++) PTab[playerid][i] = 0;
    AddTab(playerid, n, ACT_PERS, "Personel Listesi", list, sizeof list);
    AddTab(playerid, n, ACT_DUY, "Departman Duyurulari", list, sizeof list);
    AddTab(playerid, n, ACT_MSG, "Departman Mesaji Gonder", list, sizeof list);
    AddTab(playerid, n, ACT_BUTCE, "Departman Butcesi", list, sizeof list);
    AddTab(playerid, n, ACT_DUTY, "Gorev Durumu Degistir", list, sizeof list);
    if(ActAllowed(playerid, ACT_SORGUK)) AddTab(playerid, n, ACT_SORGUK, "Vatandas Sorgula", list, sizeof list);
    if(ActAllowed(playerid, ACT_SORGUP)) AddTab(playerid, n, ACT_SORGUP, "Plaka / Arac Sorgula", list, sizeof list);
    if(ActAllowed(playerid, ACT_RUHSAT)) AddTab(playerid, n, ACT_RUHSAT, "Arac Ruhsati Ver", list, sizeof list);
    if(ActAllowed(playerid, ACT_HNEW)) AddTab(playerid, n, ACT_HNEW, "Haber / Paylasim Olustur", list, sizeof list);
    if(ActAllowed(playerid, ACT_HGEC)) AddTab(playerid, n, ACT_HGEC, "Yayin Gecmisi", list, sizeof list);
    if(ActAllowed(playerid, ACT_HONAY)) AddTab(playerid, n, ACT_HONAY, "Haber Onay Listesi", list, sizeof list);
    for(new t = 0; t < RecCount[d]; t++)
    {
        format(l, sizeof l, "Kayit: %s", RecType[d][t]);
        AddTab(playerid, n, ACT_REC + t, l, list, sizeof list);
    }
    if(ActAllowed(playerid, ACT_DUYNEW)) AddTab(playerid, n, ACT_DUYNEW, "Duyuru Paylas", list, sizeof list);
    if(ActAllowed(playerid, ACT_YONET)) AddTab(playerid, n, ACT_YONET, "Yonetim Paneli", list, sizeof list);
    format(cap, sizeof cap, "%s%s", DepEmbed[d], DepTablet[d]);
    ShowPlayerDialog(playerid, D_TAB, DIALOG_STYLE_LIST, cap, list, "Sec", "Kapat");
    return 1;
}

stock ShowPersonel(playerid)
{
    new d = PDep[playerid], q[160], s[2048], l[120], a[32], b[16], c[16], DBResult:r;
    format(s, sizeof s, "Isim\tRutbe\tDurum\n");
    format(q, sizeof q, "SELECT isim,rutbe,maas FROM uyeler WHERE dep=%d ORDER BY rutbe DESC, isim ASC LIMIT 30", d);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            do
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                db_get_field(r, 2, c, sizeof c);
                new rk = strval(b);
                if(rk < 1) rk = 1;
                if(rk > MAX_RANK) rk = MAX_RANK;
                format(l, sizeof l, "%s\t%s\t%s\n", a, RankName[d][rk - 1], IsNameOnline(a) ? "{44FF44}Cevrimici" : "{AAAAAA}Cevrimdisi");
                strcat(s, l, sizeof s);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    ShowBack(playerid, DIALOG_STYLE_TABLIST_HEADERS, "Personel Listesi", s);
}

stock ShowDuyurular(playerid)
{
    new d = PDep[playerid], q[160], s[2048], l[256], a[32], b[130], c[24], DBResult:r;
    s[0] = 0;
    format(q, sizeof q, "SELECT yazar,metin,tarih FROM duyurular WHERE dep=%d ORDER BY id DESC LIMIT 8", d);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            do
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                db_get_field(r, 2, c, sizeof c);
                format(l, sizeof l, "{AAAAAA}[%s] {FFFFFF}%s: %s\n\n", c, a, b);
                strcat(s, l, sizeof s);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!s[0]) format(s, sizeof s, "Henuz duyuru yok.");
    ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Departman Duyurulari", s);
}

stock ShowKayitlar(playerid, tur)
{
    new d = PDep[playerid], q[200], s[2400], l[330], a[64], b[32], c[160], e[24], DBResult:r, cap[64];
    s[0] = 0;
    format(q, sizeof q, "SELECT hedef,yazar,metin,tarih FROM kayitlar WHERE dep=%d AND tur=%d ORDER BY id DESC LIMIT 10", d, tur);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            do
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                db_get_field(r, 2, c, sizeof c);
                db_get_field(r, 3, e, sizeof e);
                format(l, sizeof l, "{AAAAAA}[%s] {FFCC00}%s {FFFFFF}(%s)\n%s\n\n", e, a, b, c);
                strcat(s, l, sizeof s);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!s[0]) format(s, sizeof s, "Bu turde kayit yok.");
    format(cap, sizeof cap, "%s - Son Kayitlar", RecType[d][tur]);
    ShowBack(playerid, DIALOG_STYLE_MSGBOX, cap, s);
}

stock HaberDetay(id, dest[], size)
{
    new q[200], a[70], b[140], c[32], e[24], f[8], g[8], DBResult:r;
    format(dest, size, "Haber bulunamadi.");
    format(q, sizeof q, "SELECT baslik,metin,yazar,tarih,tur,durum FROM haberler WHERE id=%d", id);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            db_get_field(r, 0, a, sizeof a);
            db_get_field(r, 1, b, sizeof b);
            db_get_field(r, 2, c, sizeof c);
            db_get_field(r, 3, e, sizeof e);
            db_get_field(r, 4, f, sizeof f);
            db_get_field(r, 5, g, sizeof g);
            new durum[20];
            switch(strval(g))
            {
                case 0: format(durum, sizeof durum, "Onay Bekliyor");
                case 1: format(durum, sizeof durum, "Yayinda");
                default: format(durum, sizeof durum, "Kaldirildi");
            }
            format(dest, size, "{FFCC00}%s\n{FFFFFF}%s\n\n{AAAAAA}Yazar: {FFFFFF}%s\n{AAAAAA}Tarih: {FFFFFF}%s\n{AAAAAA}Durum: {FFFFFF}%s", a, b, c, e, durum);
        }
        db_free_result(r);
    }
}

stock SaveHaber(playerid)
{
    new q[600], t[24], n[MAX_PLAYER_NAME], bs[128], mt[128], durum, herkes, tur = PTmp[playerid];
    GetPlayerName(playerid, n, sizeof n);
    format(bs, sizeof bs, "%s", PTmpStr[playerid]);
    format(mt, sizeof mt, "%s", PTmpStr2[playerid]);
    Esc(bs); Esc(mt);
    TimeStr(t);
    durum = (PRank[playerid] >= YONETIM_RUTBE) ? 1 : 0;
    herkes = (tur == 1) ? 0 : 1;
    format(q, sizeof q, "INSERT INTO haberler (baslik,metin,yazar,durum,herkes,tur,tarih) VALUES ('%s','%s','%s',%d,%d,%d,'%s')", bs, mt, n, durum, herkes, tur, t);
    DbExec(q);
    if(durum == 1) BroadcastHaber(tur, bs);
    else SendClientMessage(playerid, C_INF, "Haberin onay icin medya yonetimine gonderildi.");
    if(durum == 1) SendClientMessage(playerid, C_OK, "Haber yayinlandi.");
}

stock BroadcastHaber(tur, baslik[])
{
    new s[160];
    if(tur == 2) format(s, sizeof s, "[SON DAKIKA] %s", baslik);
    else if(tur == 3) format(s, sizeof s, "[CANLI YAYIN] %s", baslik);
    else if(tur == 4) format(s, sizeof s, "[ETKINLIK] %s", baslik);
    else return 0;
    SendClientMessageToAll(0x9B59B6FF, s);
    return 1;
}

stock ShowHaberFeed(playerid)
{
    new q[260], s[3000], l[330], a[70], b[140], c[32], e[24], f[4], DBResult:r;
    s[0] = 0;
    if(PDep[playerid] == 4) format(q, sizeof q, "SELECT baslik,metin,yazar,tarih,herkes FROM haberler WHERE durum=1 ORDER BY id DESC LIMIT 10");
    else format(q, sizeof q, "SELECT baslik,metin,yazar,tarih,herkes FROM haberler WHERE durum=1 AND herkes=1 ORDER BY id DESC LIMIT 10");
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            do
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                db_get_field(r, 2, c, sizeof c);
                db_get_field(r, 3, e, sizeof e);
                db_get_field(r, 4, f, sizeof f);
                format(l, sizeof l, "{AAAAAA}[%s] {FFCC00}%s%s\n{FFFFFF}%s {AAAAAA}- %s\n\n", e, a, (strval(f) == 0) ? " {FF6666}(Departman)" : "", b, c);
                strcat(s, l, sizeof s);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!s[0]) format(s, sizeof s, "Yayinlanmis haber yok.");
    ShowPlayerDialog(playerid, D_NONE, DIALOG_STYLE_MSGBOX, "Haber Akisi (NEWS)", s, "Kapat", "");
}

// ==================================================================
//  CALLBACKLAR
// ==================================================================
public OnFilterScriptInit()
{
    if(!DBInit()) return 1;
    LocCount = 0;

    // AddLoc(dep, "isim", herkese_acik, giris_x,y,z,aci, ic_x,y,z,aci, interior_id)
    // NOT: Asagidakiler ORNEK koordinatlardir. Kendi mekanlarini buraya ekle/degistir.
    AddLoc(0, "Belediye Binasi", 1, 1481.0, -1768.3, 18.8, 0.0, 389.8, 173.8, 1008.4, 90.0, 3);
    AddLoc(1, "FBI Merkezi", 0, 1464.1, -1010.2, 26.8, 180.0, 246.4, 110.8, 1003.2, 0.0, 10);
    AddLoc(2, "LSPD Merkezi", 1, 1554.7, -1675.6, 16.2, 90.0, 246.7, 63.9, 1003.6, 0.0, 6);
    AddLoc(3, "All Saints Hastanesi", 1, 1177.9, -1323.9, 14.0, 270.0, 288.7, 169.3, 1007.2, 0.0, 3);
    AddLoc(4, "Medya Merkezi (NEWS)", 1, 1031.0, -1133.0, 23.9, 0.0, 288.7, 169.3, 1007.2, 0.0, 3);

    SetTimer("MaasVer", MAAS_SURE_DK * 60 * 1000, true);
    SetTimer("PanelYenile", 30000, true);
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) { OnPlayerConnect(i); SetMapIcons(i); ShowPanel(i); }
    print("[Departman] Sistem yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        for(new t = 0; t < 4; t++) PlayerTextDrawDestroy(i, PTD[i][t]);
    }
    if(gDB) db_close(gDB);
    return 1;
}

public OnPlayerConnect(playerid)
{
    PDep[playerid] = -1; PRank[playerid] = 0; PMaas[playerid] = 0; PDuty[playerid] = false;
    PTeleTick[playerid] = 0;
    CreatePanel(playerid);
    new q[160], n[MAX_PLAYER_NAME], f[16], DBResult:r;
    GetPlayerName(playerid, n, sizeof n);
    Esc(n);
    format(q, sizeof q, "SELECT dep,rutbe,maas FROM uyeler WHERE isim='%s'", n);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            db_get_field(r, 0, f, sizeof f); PDep[playerid] = strval(f);
            db_get_field(r, 1, f, sizeof f); PRank[playerid] = strval(f);
            db_get_field(r, 2, f, sizeof f); PMaas[playerid] = strval(f);
            if(PDep[playerid] < 0 || PDep[playerid] >= MAX_DEP || PRank[playerid] < 1 || PRank[playerid] > MAX_RANK)
            { PDep[playerid] = -1; PRank[playerid] = 0; }
        }
        db_free_result(r);
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    PDep[playerid] = -1;
    return 1;
}

public OnPlayerSpawn(playerid)
{
    SetMapIcons(playerid);
    ShowPanel(playerid);
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(GetTickCount() - PTeleTick[playerid] < 1500) return 1;
    for(new i = 0; i < LocCount; i++)
    {
        if(pickupid == LocPickO[i]) { DoTeleport(playerid, i, true); return 1; }
        if(pickupid == LocPickI[i]) { DoTeleport(playerid, i, false); return 1; }
    }
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    DisablePlayerCheckpoint(playerid);
    SendClientMessage(playerid, C_OK, "Mekana ulastin.");
    return 1;
}

public MaasVer()
{
    new s[100], q[120];
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PDep[i] < 0 || PMaas[i] <= 0) continue;
        new d = PDep[i];
        format(q, sizeof q, "SELECT miktar FROM butce WHERE dep=%d", d);
        if(DbGetInt(q) >= PMaas[i])
        {
            format(q, sizeof q, "UPDATE butce SET miktar=miktar-%d WHERE dep=%d", PMaas[i], d);
            DbExec(q);
            GivePlayerMoney(i, PMaas[i]);
            format(s, sizeof s, "Departman maasin yatirildi: $%d", PMaas[i]);
            SendClientMessage(i, C_OK, s);
        }
        else SendClientMessage(i, C_ERR, "Departman butcesi yetersiz, maas odenemedi.");
    }
}

// ==================================================================
//  KOMUTLAR
// ==================================================================
public OnPlayerCommandText(playerid, cmdtext[])
{
    new n[MAX_PLAYER_NAME], s[200];
    GetPlayerName(playerid, n, sizeof n);

    if(!strcmp(cmdtext, "/departman", true)) { ShowDepList(playerid); return 1; }

    if(!strcmp(cmdtext, "/tablet", true)) { OpenTablet(playerid); return 1; }

    if(!strcmp(cmdtext, "/yardim", true) || !strcmp(cmdtext, "/komutlar", true))
    {
        ShowPlayerDialog(playerid, D_NONE, DIALOG_STYLE_MSGBOX, "Yardim - Komutlar",
            "{FFFFFF}/departman  {AAAAAA}- Departman menusunu acar (herkes)\n"
            "{FFFFFF}/yardim  {AAAAAA}- Bu menuyu acar\n"
            "{FFFFFF}/tablet  {AAAAAA}- Yetkili oldugun departmanin tabletini acar\n"
            "{FFFFFF}/gorev  {AAAAAA}- Gorev durumunu degistirir\n"
            "{FFFFFF}/d [mesaj]  {AAAAAA}- Departman telsizi\n"
            "{FFFFFF}/mekanlar  {AAAAAA}- Departman mekanlari, haritada isaretler\n"
            "{FFFFFF}/haberler  {AAAAAA}- Medya haber akisi\n"
            "{FFFFFF}/ihbar [mesaj]  {AAAAAA}- Polise ihbar\n"
            "{FFFFFF}/acil [mesaj]  {AAAAAA}- Hastaneye acil cagri\n"
            "{FFFFFF}/sikayet [mesaj]  {AAAAAA}- Belediyeye sikayet",
            "Kapat", "");
        return 1;
    }

    if(!strcmp(cmdtext, "/gorev", true))
    {
        if(PDep[playerid] < 0) return SendClientMessage(playerid, C_ERR, "Departman personeli degilsin."), 1;
        PDuty[playerid] = !PDuty[playerid];
        format(s, sizeof s, "Gorev durumu: %s", PDuty[playerid] ? "AKTIF" : "PASIF");
        SendClientMessage(playerid, PDuty[playerid] ? C_OK : C_INF, s);
        ShowPanel(playerid);
        return 1;
    }

    if(!strcmp(cmdtext, "/d ", true, 3))
    {
        if(PDep[playerid] < 0) return SendClientMessage(playerid, C_ERR, "Departman personeli degilsin."), 1;
        if(!cmdtext[3]) return SendClientMessage(playerid, C_INF, "Kullanim: /d [mesaj]"), 1;
        format(s, sizeof s, "[%s] %s %s: %s", DepName[PDep[playerid]], RankName[PDep[playerid]][PRank[playerid] - 1], n, cmdtext[3]);
        SendDep(PDep[playerid], DepColor[PDep[playerid]], s);
        return 1;
    }

    if(!strcmp(cmdtext, "/mekanlar", true))
    {
        new l[2000], t[96];
        l[0] = 0;
        for(new i = 0; i < LocCount; i++)
        {
            format(t, sizeof t, "%s%s {FFFFFF}- %s\n", DepEmbed[LocDep[i]], DepName[LocDep[i]], LocName[i]);
            strcat(l, t, sizeof l);
        }
        ShowPlayerDialog(playerid, D_MEKANLIST, DIALOG_STYLE_LIST, "Mekanlar (sec: haritada isaretle)", l, "Isaretle", "Kapat");
        return 1;
    }

    if(!strcmp(cmdtext, "/haberler", true)) { ShowHaberFeed(playerid); return 1; }

    if(!strcmp(cmdtext, "/ihbar ", true, 7))
    {
        if(!cmdtext[7]) return SendClientMessage(playerid, C_INF, "Kullanim: /ihbar [mesaj]"), 1;
        InsertRec(2, 1, n, n, cmdtext[7]);
        format(s, sizeof s, "[IHBAR] %s (ID:%d): %s", n, playerid, cmdtext[7]);
        SendDep(2, 0x3498DBFF, s);
        SendClientMessage(playerid, C_OK, "Ihbarin polise iletildi.");
        return 1;
    }

    if(!strcmp(cmdtext, "/acil ", true, 6))
    {
        if(!cmdtext[6]) return SendClientMessage(playerid, C_INF, "Kullanim: /acil [mesaj]"), 1;
        InsertRec(3, 3, n, n, cmdtext[6]);
        format(s, sizeof s, "[ACIL CAGRI] %s (ID:%d): %s", n, playerid, cmdtext[6]);
        SendDep(3, 0xE74C3CFF, s);
        SendClientMessage(playerid, C_OK, "Acil cagrin hastaneye iletildi.");
        return 1;
    }

    if(!strcmp(cmdtext, "/sikayet ", true, 9))
    {
        if(!cmdtext[9]) return SendClientMessage(playerid, C_INF, "Kullanim: /sikayet [mesaj]"), 1;
        InsertRec(0, 2, n, n, cmdtext[9]);
        SendClientMessage(playerid, C_OK, "Sikayetin belediyeye iletildi.");
        return 1;
    }

    if(!strcmp(cmdtext, "/departmanver", true, 13))
    {
        if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, C_ERR, "Bu komut sadece RCON admin icindir."), 1;
        new idx = 13, a[16], b[16], c[16];
        Token(cmdtext, idx, a); Token(cmdtext, idx, b); Token(cmdtext, idx, c);
        if(!a[0] || !b[0] || !c[0]) return SendClientMessage(playerid, C_INF, "Kullanim: /departmanver [id] [dep 0-4] [rutbe 1-5]  (0 Belediye,1 FBI,2 Polis,3 EMS,4 Medya)"), 1;
        new t = strval(a), d = strval(b), r = strval(c);
        if(t < 0 || t >= MAX_PLAYERS || !IsPlayerConnected(t)) return SendClientMessage(playerid, C_ERR, "Oyuncu bulunamadi."), 1;
        if(d < 0 || d >= MAX_DEP || r < 1 || r > MAX_RANK) return SendClientMessage(playerid, C_ERR, "Gecersiz departman/rutbe."), 1;
        SetMember(t, d, r);
        SendClientMessage(playerid, C_OK, "Islem tamamlandi.");
        return 1;
    }
    return 0;
}

// ==================================================================
//  DIALOG CEVAPLARI
// ==================================================================
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid < D_NONE || dialogid > D_HEDIT) return 0;

    new d = PDep[playerid], n[MAX_PLAYER_NAME], s[600], q[400], buf[130];
    GetPlayerName(playerid, n, sizeof n);
    format(buf, sizeof buf, "%s", inputtext);
    Esc(buf);

    if(dialogid == D_NONE) return 1;

    if(dialogid == D_BACK)
    {
        if(response) OpenTablet(playerid);
        return 1;
    }

    // ---------------- Departman menusu ----------------
    if(dialogid == D_DEPLIST)
    {
        if(!response) return 1;
        PTmp[playerid] = listitem;
        ShowDepInfo(playerid, listitem);
        return 1;
    }
    if(dialogid == D_DEPINFO)
    {
        new dd = PTmp[playerid];
        if(!response) { ShowDepList(playerid); return 1; }
        if(dd < 0 || dd >= MAX_DEP) return 1;
        if(PDep[playerid] == dd) LeaveDept(playerid);
        else SetMember(playerid, dd, 1);
        return 1;
    }
    if(dialogid == D_MEKANLIST)
    {
        if(!response || listitem < 0 || listitem >= LocCount) return 1;
        SetPlayerCheckpoint(playerid, LocOut[listitem][0], LocOut[listitem][1], LocOut[listitem][2], 4.0);
        format(s, sizeof s, "%s haritada isaretlendi.", LocName[listitem]);
        SendClientMessage(playerid, C_INF, s);
        return 1;
    }

    // Bundan sonrasi sadece personel icin
    if(d < 0) return 1;

    // ---------------- Ana tablet ----------------
    if(dialogid == D_TAB)
    {
        if(!response || listitem < 0 || listitem >= MAX_TABITEM) return 1;
        new act = PTab[playerid][listitem];
        if(act == 0 || !ActAllowed(playerid, act)) return 1;

        if(act >= ACT_REC && act < ACT_REC + 6)
        {
            new t = act - ACT_REC;
            if(t >= RecCount[d]) return 1;
            PTmp[playerid] = t;
            format(s, sizeof s, "Kayitlari Goruntule\nYeni Kayit Olustur");
            ShowPlayerDialog(playerid, D_RECSUB, DIALOG_STYLE_LIST, RecType[d][t], s, "Sec", "Geri");
            return 1;
        }
        switch(act)
        {
            case ACT_PERS: ShowPersonel(playerid);
            case ACT_DUY: ShowDuyurular(playerid);
            case ACT_DUYNEW: ShowPlayerDialog(playerid, D_DUYYAZ, DIALOG_STYLE_INPUT, "Duyuru Paylas", "Duyuru metnini yaz:", "Paylas", "Geri");
            case ACT_MSG: ShowPlayerDialog(playerid, D_MESAJ, DIALOG_STYLE_INPUT, "Departman Mesaji", "Departman personeline mesaj yaz:", "Gonder", "Geri");
            case ACT_DUTY:
            {
                PDuty[playerid] = !PDuty[playerid];
                format(s, sizeof s, "Gorev durumu: %s", PDuty[playerid] ? "AKTIF" : "PASIF");
                SendClientMessage(playerid, PDuty[playerid] ? C_OK : C_INF, s);
                ShowPanel(playerid);
                OpenTablet(playerid);
            }
            case ACT_BUTCE:
            {
                format(q, sizeof q, "SELECT miktar FROM butce WHERE dep=%d", d);
                new b = DbGetInt(q);
                if(IsYonetici(playerid))
                {
                    format(s, sizeof s, "Butce Bakiyesi: $%d\nPara Yatir\nPara Cek (Sadece Mudur)", b);
                    ShowPlayerDialog(playerid, D_BUTCE, DIALOG_STYLE_LIST, "Departman Butcesi", s, "Sec", "Geri");
                }
                else
                {
                    format(s, sizeof s, "Departman butcesi: {44FF44}$%d", b);
                    ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Departman Butcesi", s);
                }
            }
            case ACT_YONET:
                ShowPlayerDialog(playerid, D_YONET, DIALOG_STYLE_LIST, "Yonetim Paneli",
                    "Personel Ise Al\nPersonel Isten Cikar\nRutbe Ver\nTerfi Ettir\nGorevden Al (Rutbe 1)\nMaas Belirle\nPersonel Gecmisini Goruntule",
                    "Sec", "Geri");
            case ACT_SORGUK: ShowPlayerDialog(playerid, D_SORGUK, DIALOG_STYLE_INPUT, "Vatandas Sorgula", "Oyuncu ID, isim veya kayitli isim yaz:", "Sorgula", "Geri");
            case ACT_SORGUP: ShowPlayerDialog(playerid, D_SORGUP, DIALOG_STYLE_INPUT, "Plaka Sorgula", "Plakayi yaz:", "Sorgula", "Geri");
            case ACT_RUHSAT: ShowPlayerDialog(playerid, D_RUHSAT, DIALOG_STYLE_INPUT, "Arac Ruhsati", "Su formatta yaz:  PLAKA, SAHIP ADI, MODEL", "Kaydet", "Geri");
            case ACT_HNEW: ShowPlayerDialog(playerid, D_HBASLIK, DIALOG_STYLE_INPUT, "Haber Basligi", "Haber basligini yaz:", "Ileri", "Geri");
            case ACT_HONAY:
            {
                new DBResult:r, a[8], b[70], c[32], l[120], list[1800];
                list[0] = 0;
                for(new i = 0; i < MAX_LISTITEM; i++) PList[playerid][i] = 0;
                r = db_query(gDB, "SELECT id,baslik,yazar FROM haberler WHERE durum=0 ORDER BY id ASC LIMIT 20");
                new k = 0;
                if(r)
                {
                    if(db_num_rows(r))
                    {
                        do
                        {
                            db_get_field(r, 0, a, sizeof a);
                            db_get_field(r, 1, b, sizeof b);
                            db_get_field(r, 2, c, sizeof c);
                            PList[playerid][k++] = strval(a);
                            format(l, sizeof l, "#%s - %s (%s)\n", a, b, c);
                            strcat(list, l, sizeof list);
                        }
                        while(db_next_row(r) && k < MAX_LISTITEM);
                    }
                    db_free_result(r);
                }
                if(!k) ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Haber Onay Listesi", "Onay bekleyen haber yok.");
                else ShowPlayerDialog(playerid, D_HONAY, DIALOG_STYLE_LIST, "Onay Bekleyen Haberler", list, "Incele", "Geri");
            }
            case ACT_HGEC:
            {
                new DBResult:r, a[8], b[70], c[8], e[24], l[170], list[2400];
                format(list, sizeof list, "ID\tBaslik\tDurum\tTarih\n");
                for(new i = 0; i < MAX_LISTITEM; i++) PList[playerid][i] = 0;
                r = db_query(gDB, "SELECT id,baslik,durum,tarih FROM haberler ORDER BY id DESC LIMIT 20");
                new k = 0;
                if(r)
                {
                    if(db_num_rows(r))
                    {
                        do
                        {
                            db_get_field(r, 0, a, sizeof a);
                            db_get_field(r, 1, b, sizeof b);
                            db_get_field(r, 2, c, sizeof c);
                            db_get_field(r, 3, e, sizeof e);
                            PList[playerid][k++] = strval(a);
                            format(l, sizeof l, "%s\t%s\t%s\t%s\n", a, b, (strval(c) == 0) ? "Bekliyor" : ((strval(c) == 1) ? "Yayinda" : "Kaldirildi"), e);
                            strcat(list, l, sizeof list);
                        }
                        while(db_next_row(r) && k < MAX_LISTITEM);
                    }
                    db_free_result(r);
                }
                if(!k) ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Yayin Gecmisi", "Henuz haber yok.");
                else ShowPlayerDialog(playerid, D_HGECMIS, DIALOG_STYLE_TABLIST_HEADERS, "Yayin Gecmisi", list, "Sec", "Geri");
            }
        }
        return 1;
    }

    // ---------------- Duyuru / Mesaj ----------------
    if(dialogid == D_DUYYAZ)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid) || !buf[0]) return 1;
        new t[24];
        TimeStr(t);
        format(q, sizeof q, "INSERT INTO duyurular (dep,yazar,metin,tarih) VALUES (%d,'%s','%s','%s')", d, n, buf, t);
        DbExec(q);
        format(s, sizeof s, "[%s DUYURU] %s: %s", DepName[d], n, buf);
        SendDep(d, DepColor[d], s);
        return 1;
    }
    if(dialogid == D_MESAJ)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!buf[0]) return 1;
        format(s, sizeof s, "[%s MESAJ] %s %s: %s", DepName[d], RankName[d][PRank[playerid] - 1], n, buf);
        SendDep(d, DepColor[d], s);
        return 1;
    }

    // ---------------- Butce ----------------
    if(dialogid == D_BUTCE)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid)) return 1;
        if(listitem == 1)
        {
            PAct[playerid] = 1;
            ShowPlayerDialog(playerid, D_BUTCEMIKTAR, DIALOG_STYLE_INPUT, "Para Yatir", "Yatirilacak miktar:", "Onayla", "Geri");
        }
        else if(listitem == 2)
        {
            if(PRank[playerid] < MAX_RANK) return SendClientMessage(playerid, C_ERR, "Butceden para cekmek sadece mudur yetkisindedir."), 1;
            PAct[playerid] = 2;
            ShowPlayerDialog(playerid, D_BUTCEMIKTAR, DIALOG_STYLE_INPUT, "Para Cek", "Cekilecek miktar:", "Onayla", "Geri");
        }
        else OpenTablet(playerid);
        return 1;
    }
    if(dialogid == D_BUTCEMIKTAR)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid)) return 1;
        new amt = strval(buf);
        if(amt <= 0 || amt > 10000000) return SendClientMessage(playerid, C_ERR, "Gecersiz miktar."), 1;
        if(PAct[playerid] == 1)
        {
            if(GetPlayerMoney(playerid) < amt) return SendClientMessage(playerid, C_ERR, "Yeterli paran yok."), 1;
            GivePlayerMoney(playerid, -amt);
            format(q, sizeof q, "UPDATE butce SET miktar=miktar+%d WHERE dep=%d", amt, d);
            DbExec(q);
            format(s, sizeof s, "Butceye $%d yatirdin.", amt);
            SendClientMessage(playerid, C_OK, s);
        }
        else
        {
            if(PRank[playerid] < MAX_RANK) return 1;
            format(q, sizeof q, "SELECT miktar FROM butce WHERE dep=%d", d);
            if(DbGetInt(q) < amt) return SendClientMessage(playerid, C_ERR, "Butcede yeterli para yok."), 1;
            format(q, sizeof q, "UPDATE butce SET miktar=miktar-%d WHERE dep=%d", amt, d);
            DbExec(q);
            GivePlayerMoney(playerid, amt);
            format(s, sizeof s, "Butceden $%d cektin.", amt);
            SendClientMessage(playerid, C_OK, s);
        }
        return 1;
    }

    // ---------------- Yonetim paneli ----------------
    if(dialogid == D_YONET)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid)) return 1;
        PAct[playerid] = listitem + 1;
        if(listitem == 6) ShowPlayerDialog(playerid, D_YONETID, DIALOG_STYLE_INPUT, "Personel Gecmisi", "Oyuncu ID'si veya tam ismi:", "Goster", "Geri");
        else ShowPlayerDialog(playerid, D_YONETID, DIALOG_STYLE_INPUT, "Yonetim", "Hedef oyuncunun ID'si veya ismi (cevrimici olmali):", "Devam", "Geri");
        return 1;
    }
    if(dialogid == D_YONETID)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid) || !buf[0]) return 1;
        new act = PAct[playerid], t;
        if(act == 7)
        {
            new nm[32], DBResult:r, a[100], b[24], list[2000], l[160];
            t = ResolveTarget(inputtext);
            if(t != INVALID_PLAYER_ID) GetPlayerName(t, nm, sizeof nm);
            else format(nm, sizeof nm, "%s", buf);
            Esc(nm);
            list[0] = 0;
            format(q, sizeof q, "SELECT olay,tarih FROM gecmis WHERE dep=%d AND isim='%s' ORDER BY id DESC LIMIT 15", d, nm);
            r = db_query(gDB, q);
            if(r)
            {
                if(db_num_rows(r))
                {
                    do
                    {
                        db_get_field(r, 0, a, sizeof a);
                        db_get_field(r, 1, b, sizeof b);
                        format(l, sizeof l, "{AAAAAA}[%s] {FFFFFF}%s\n", b, a);
                        strcat(list, l, sizeof list);
                    }
                    while(db_next_row(r));
                }
                db_free_result(r);
            }
            if(!list[0]) format(list, sizeof list, "Kayit bulunamadi.");
            format(s, sizeof s, "Personel Gecmisi: %s", nm);
            ShowBack(playerid, DIALOG_STYLE_MSGBOX, s, list);
            return 1;
        }
        t = ResolveTarget(inputtext);
        if(t == INVALID_PLAYER_ID) return SendClientMessage(playerid, C_ERR, "Oyuncu bulunamadi."), 1;
        if(act == 1)
        {
            if(PDep[t] >= 0) return SendClientMessage(playerid, C_ERR, "Oyuncu zaten bir departmanda."), 1;
            SetMember(t, d, 1);
            SendClientMessage(playerid, C_OK, "Oyuncu departmana alindi.");
            return 1;
        }
        if(PDep[t] != d) return SendClientMessage(playerid, C_ERR, "Oyuncu senin departmanindan degil."), 1;
        if(t == playerid || PRank[t] >= PRank[playerid]) return SendClientMessage(playerid, C_ERR, "Kendi rutbenle esit veya ustu birine islem yapamazsin."), 1;
        PTarget[playerid] = t;
        switch(act)
        {
            case 2:
            {
                LeaveDept(t);
                SendClientMessage(playerid, C_OK, "Oyuncu departmandan cikarildi.");
            }
            case 3:
            {
                new l[160], mx = PRank[playerid] - 1;
                if(mx > MAX_RANK - 1) mx = MAX_RANK - 1;
                l[0] = 0;
                for(new r = 0; r < mx; r++)
                {
                    format(s, sizeof s, "%d) %s\n", r + 1, RankName[d][r]);
                    strcat(l, s, sizeof l);
                }
                ShowPlayerDialog(playerid, D_YONETRANK, DIALOG_STYLE_LIST, "Rutbe Sec", l, "Ver", "Iptal");
            }
            case 4:
            {
                if(PRank[t] + 1 >= PRank[playerid]) return SendClientMessage(playerid, C_ERR, "Bu oyuncuyu daha fazla terfi ettiremezsin."), 1;
                SetRank(t, PRank[t] + 1);
                SendClientMessage(playerid, C_OK, "Oyuncu terfi ettirildi.");
            }
            case 5:
            {
                SetRank(t, 1);
                SendClientMessage(playerid, C_OK, "Oyuncu gorevden alindi (Rutbe 1).");
            }
            case 6: ShowPlayerDialog(playerid, D_YONETMAAS, DIALOG_STYLE_INPUT, "Maas Belirle", "Yeni maas miktari (0 - 50000):", "Kaydet", "Iptal");
        }
        return 1;
    }
    if(dialogid == D_YONETRANK)
    {
        if(!response || !IsYonetici(playerid)) return 1;
        new t = PTarget[playerid], nr = listitem + 1;
        if(!IsPlayerConnected(t) || PDep[t] != d || PRank[t] >= PRank[playerid] || nr >= PRank[playerid] || nr > MAX_RANK - 1) return 1;
        SetRank(t, nr);
        SendClientMessage(playerid, C_OK, "Rutbe verildi.");
        return 1;
    }
    if(dialogid == D_YONETMAAS)
    {
        if(!response || !IsYonetici(playerid)) return 1;
        new t = PTarget[playerid], m = strval(buf);
        if(!IsPlayerConnected(t) || PDep[t] != d || PRank[t] >= PRank[playerid]) return 1;
        if(m < 0 || m > 50000) return SendClientMessage(playerid, C_ERR, "Maas 0 ile 50000 arasinda olmali."), 1;
        PMaas[t] = m;
        UpdateMember(t);
        GetPlayerName(t, n, sizeof n);
        format(s, sizeof s, "Maas belirlendi: $%d", m);
        AddHistory(d, n, s);
        ShowPanel(t);
        SendClientMessage(playerid, C_OK, "Maas guncellendi.");
        SendClientMessage(t, C_INF, "Maasin guncellendi.");
        return 1;
    }

    // ---------------- Kayitlar ----------------
    if(dialogid == D_RECSUB)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        new t = PTmp[playerid];
        if(t < 0 || t >= RecCount[d]) return 1;
        if(listitem == 0) ShowKayitlar(playerid, t);
        else ShowPlayerDialog(playerid, D_RECHEDEF, DIALOG_STYLE_INPUT, RecType[d][t], "Hedef / Konu (isim, plaka, baslik vb.):", "Ileri", "Iptal");
        return 1;
    }
    if(dialogid == D_RECHEDEF)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!buf[0]) return 1;
        format(PTmpStr[playerid], 128, "%s", buf);
        ShowPlayerDialog(playerid, D_RECMETIN, DIALOG_STYLE_INPUT, RecType[d][PTmp[playerid]], "Aciklama / Detay:", "Kaydet", "Iptal");
        return 1;
    }
    if(dialogid == D_RECMETIN)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        new t = PTmp[playerid];
        if(!buf[0] || t < 0 || t >= RecCount[d]) return 1;
        InsertRec(d, t, PTmpStr[playerid], n, buf);
        SendClientMessage(playerid, C_OK, "Kayit olusturuldu.");
        ShowKayitlar(playerid, t);
        return 1;
    }

    // ---------------- Sorgular ----------------
    if(dialogid == D_SORGUK)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!ActAllowed(playerid, ACT_SORGUK) || !buf[0]) return 1;
        new t = ResolveTarget(inputtext), nm[32], l[300], list[2400], DBResult:r, a[28], b[160], e[24], c[8];
        list[0] = 0;
        if(t != INVALID_PLAYER_ID)
        {
            GetPlayerName(t, nm, sizeof nm);
            format(l, sizeof l, "{FFCC00}%s {AAAAAA}(ID:%d)\n{FFFFFF}Skor: %d | Ping: %d | Durum: Cevrimici\nDepartman: %s\n\n", nm, t, GetPlayerScore(t), GetPlayerPing(t), (PDep[t] >= 0) ? DepName[PDep[t]] : "Yok (Vatandas)");
            strcat(list, l, sizeof list);
        }
        else
        {
            format(nm, sizeof nm, "%s", buf);
            format(l, sizeof l, "{FFCC00}%s {AAAAAA}(cevrimdisi / kayitli isim)\n\n", nm);
            strcat(list, l, sizeof list);
        }
        Esc(nm);
        if(d == 1) format(q, sizeof q, "SELECT dep,tur,metin,tarih FROM kayitlar WHERE hedef='%s' ORDER BY id DESC LIMIT 8", nm);
        else format(q, sizeof q, "SELECT dep,tur,metin,tarih FROM kayitlar WHERE hedef='%s' AND dep=%d ORDER BY id DESC LIMIT 8", nm, d);
        r = db_query(gDB, q);
        new cnt = 0;
        if(r)
        {
            if(db_num_rows(r))
            {
                do
                {
                    db_get_field(r, 0, c, sizeof c);
                    new rd = strval(c);
                    db_get_field(r, 1, c, sizeof c);
                    new rt = strval(c);
                    db_get_field(r, 2, b, sizeof b);
                    db_get_field(r, 3, e, sizeof e);
                    if(rd < 0 || rd >= MAX_DEP || rt < 0 || rt >= 6) continue;
                    format(a, sizeof a, "%s", RecType[rd][rt]);
                    format(l, sizeof l, "{AAAAAA}[%s] {FF8888}%s: {FFFFFF}%s\n", e, a, b);
                    strcat(list, l, sizeof list);
                    cnt++;
                }
                while(db_next_row(r));
            }
            db_free_result(r);
        }
        if(!cnt) strcat(list, "{AAAAAA}Kayit bulunamadi.", sizeof list);
        ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Vatandas Sorgu Sonucu", list);
        return 1;
    }
    if(dialogid == D_SORGUP)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!ActAllowed(playerid, ACT_SORGUP) || !buf[0]) return 1;
        new a[32], b[32], c[32], list[1500], l[300], e[160], DBResult:r;
        list[0] = 0;
        format(q, sizeof q, "SELECT plaka,sahip,model FROM araclar WHERE UPPER(plaka)=UPPER('%s')", buf);
        r = db_query(gDB, q);
        new found = 0;
        if(r)
        {
            if(db_num_rows(r))
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                db_get_field(r, 2, c, sizeof c);
                found = 1;
            }
            db_free_result(r);
        }
        if(found) format(list, sizeof list, "{FFCC00}Plaka: {FFFFFF}%s\n{FFCC00}Sahip: {FFFFFF}%s\n{FFCC00}Model: {FFFFFF}%s\n\n{AAAAAA}Arac Raporlari:\n", a, b, c);
        else format(list, sizeof list, "{FF6666}Bu plaka ruhsat kayitlarinda yok.\n\n{AAAAAA}Arac Raporlari:\n");
        format(q, sizeof q, "SELECT metin,tarih FROM kayitlar WHERE UPPER(hedef)=UPPER('%s') ORDER BY id DESC LIMIT 6", buf);
        r = db_query(gDB, q);
        new cnt = 0;
        if(r)
        {
            if(db_num_rows(r))
            {
                do
                {
                    db_get_field(r, 0, e, sizeof e);
                    db_get_field(r, 1, a, sizeof a);
                    format(l, sizeof l, "{AAAAAA}[%s] {FFFFFF}%s\n", a, e);
                    strcat(list, l, sizeof list);
                    cnt++;
                }
                while(db_next_row(r));
            }
            db_free_result(r);
        }
        if(!cnt) strcat(list, "{AAAAAA}Rapor yok.", sizeof list);
        ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Plaka Sorgu Sonucu", list);
        return 1;
    }
    if(dialogid == D_RUHSAT)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!ActAllowed(playerid, ACT_RUHSAT)) return 1;
        new pl[20], sh[32], md[32], t[24];
        GetPart(buf, 0, pl, sizeof pl);
        GetPart(buf, 1, sh, sizeof sh);
        GetPart(buf, 2, md, sizeof md);
        if(!pl[0] || !sh[0]) return SendClientMessage(playerid, C_ERR, "Format: PLAKA, SAHIP ADI, MODEL"), 1;
        TimeStr(t);
        format(q, sizeof q, "INSERT OR REPLACE INTO araclar (plaka,sahip,model,tarih) VALUES ('%s','%s','%s','%s')", pl, sh, md, t);
        DbExec(q);
        format(s, sizeof s, "Arac ruhsati islendi: %s - %s", pl, sh);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }

    // ---------------- Medya / Haber ----------------
    if(dialogid == D_HBASLIK)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(d != 4 || !buf[0]) return 1;
        format(PTmpStr[playerid], 128, "%s", buf);
        ShowPlayerDialog(playerid, D_HMETIN, DIALOG_STYLE_INPUT, "Haber Metni", "Haber aciklamasini yaz:", "Ileri", "Iptal");
        return 1;
    }
    if(dialogid == D_HMETIN)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(d != 4 || !buf[0]) return 1;
        format(PTmpStr2[playerid], 128, "%s", buf);
        ShowPlayerDialog(playerid, D_HTUR, DIALOG_STYLE_LIST, "Paylasim Turu",
            "Haber (Herkese Acik)\nHaber (Sadece Departman)\nSon Dakika Haberi\nCanli Yayin Duyurusu\nEtkinlik Duyurusu", "Paylas", "Iptal");
        return 1;
    }
    if(dialogid == D_HTUR)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(d != 4) return 1;
        PTmp[playerid] = listitem;
        SaveHaber(playerid);
        return 1;
    }
    if(dialogid == D_HONAY)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid) || d != 4 || listitem < 0 || listitem >= MAX_LISTITEM) return 1;
        new id = PList[playerid][listitem];
        if(id <= 0) return 1;
        PTmp[playerid] = id;
        HaberDetay(id, s, sizeof s);
        ShowPlayerDialog(playerid, D_HONAYACT, DIALOG_STYLE_MSGBOX, "Haber Onayi", s, "Onayla", "Reddet");
        return 1;
    }
    if(dialogid == D_HONAYACT)
    {
        if(!IsYonetici(playerid) || d != 4) return 1;
        new id = PTmp[playerid], DBResult:r, bs[70], tf[8];
        if(response)
        {
            format(q, sizeof q, "UPDATE haberler SET durum=1 WHERE id=%d AND durum=0", id);
            DbExec(q);
            format(q, sizeof q, "SELECT baslik,tur FROM haberler WHERE id=%d", id);
            r = db_query(gDB, q);
            if(r)
            {
                if(db_num_rows(r))
                {
                    db_get_field(r, 0, bs, sizeof bs);
                    db_get_field(r, 1, tf, sizeof tf);
                    BroadcastHaber(strval(tf), bs);
                }
                db_free_result(r);
            }
            SendClientMessage(playerid, C_OK, "Haber onaylandi ve yayinlandi.");
        }
        else
        {
            format(q, sizeof q, "UPDATE haberler SET durum=2 WHERE id=%d AND durum=0", id);
            DbExec(q);
            SendClientMessage(playerid, C_INF, "Haber reddedildi.");
        }
        return 1;
    }
    if(dialogid == D_HGECMIS)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(d != 4 || listitem < 0 || listitem >= MAX_LISTITEM) return 1;
        new id = PList[playerid][listitem];
        if(id <= 0) return 1;
        PTmp[playerid] = id;
        if(IsYonetici(playerid))
            ShowPlayerDialog(playerid, D_HGECACT, DIALOG_STYLE_LIST, "Haber Islemleri", "Haberi Goruntule\nBasligi Duzenle\nHaberi Kaldir", "Sec", "Geri");
        else
        {
            HaberDetay(id, s, sizeof s);
            ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Haber Detayi", s);
        }
        return 1;
    }
    if(dialogid == D_HGECACT)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid) || d != 4) return 1;
        new id = PTmp[playerid];
        if(listitem == 0)
        {
            HaberDetay(id, s, sizeof s);
            ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Haber Detayi", s);
        }
        else if(listitem == 1)
            ShowPlayerDialog(playerid, D_HEDIT, DIALOG_STYLE_INPUT, "Baslik Duzenle", "Yeni basligi yaz:", "Kaydet", "Iptal");
        else
        {
            format(q, sizeof q, "UPDATE haberler SET durum=2 WHERE id=%d", id);
            DbExec(q);
            SendClientMessage(playerid, C_OK, "Haber kaldirildi.");
        }
        return 1;
    }
    if(dialogid == D_HEDIT)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsYonetici(playerid) || d != 4 || !buf[0]) return 1;
        format(q, sizeof q, "UPDATE haberler SET baslik='%s' WHERE id=%d", buf, PTmp[playerid]);
        DbExec(q);
        SendClientMessage(playerid, C_OK, "Baslik guncellendi.");
        return 1;
    }
    return 1;
}
