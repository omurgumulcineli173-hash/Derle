/*
    ====================================================================
    SA-MP DEPARTMAN SISTEMI  (Filterscript)  v1.0
    Departmanlar: Belediye, FBI, Polis (LSPD), Hastane (EMS), Medya (NEWS)
    Ceteler: Los Namados (sari), Liberty (mavi), Inferno (kirmizi), Vipers (yesil)

    KURULUM:
      1) Bu dosyayi  pawno/  veya  filterscripts/  klasorune koy: departman.pwn
      2) Pawno ile derle -> departman.amx olusur, filterscripts/ icine koy
      3) server.cfg icindeki filterscripts satirinin sonuna  departman  ekle
      4) scriptfiles/ klasoru sunucuda olmali (departman.db oraya olusur)
      5) Dosyayi ANSI (Windows-1254) kaydet. Metinler Turkce karaktersiz yazildi.

    KOMUTLAR:
      /departman  /tablet  /gorev  /d  /haberler  /mekanlar  /yardim
      /ihbar  /acil  /sikayet
      /departmanver [id] [dep 0-8] [rutbe 1-10]   (sadece admin)
      /ayril  /seviye  /siralama  /telsiz  /t  /r   ADMIN: /seviyever [id] [seviye]
      ADMIN: /tablet [0-8] (her departmanda tam yetki)  /mekangit [0-8]  /mekanyer [0-8]  /kiyafetyer [0-8]
    ====================================================================
*/

#include <a_samp>

#pragma dynamic 16384
#pragma tabsize 0

#define MAX_DEP          9
#define GANG_BASLA       5      // 5,6,7,8 = cete (maas yok)
#define MAX_RANK         10     // bir kurumda en fazla rutbe
#define DEF_RANKS        5      // varsayilan rutbe sayisi
#define MAX_LOC          16
#define MAX_TABITEM      32
#define MAX_LISTITEM     30
#define MIN_LEVEL_DEF    5      // alimlar icin varsayilan minimum seviye
#define MAX_ADMIN_LEVEL  1000   // adminlerin seviyesi
#define RANK_MAAS        600
#define MAAS_SURE_DK     60
#define BASLANGIC_BUTCE  100000
#define DB_DOSYA         "departman.db"

// Ana sistemden admin seviyesi okunamazsa bu oyuncu adi admin sayilir
#define YEDEK_ADMIN      "Lebron_B"

#define C_ERR 0xFF6B6BFF
#define C_OK  0x6BFF8BFF
#define C_INF 0x6BC8FFFF

// Yetkiler (Discord rolleri gibi). Admin tabletten her rutbe icin acilip kapatilir.
#define PERM_COUNT   9
#define P_ALIM       1      // alimlari ac/kapat
#define P_ISEAL      2      // personel ise al
#define P_CIKAR      4      // personel isten cikar
#define P_RUTBE      8      // rutbe ver / terfi
#define P_MAAS       16     // maas belirle
#define P_DUYURU     32     // duyuru paylas
#define P_BUTCE      64     // butce yonetimi
#define P_MEDYA      128    // haber onay / yonetim (medya)
#define P_YONETICI   256    // YONETICI: tum yetkiler

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
#define ACT_ALIM     14
#define ACT_AYRIL    15
#define ACT_SIRALAMA 16
#define ACT_ROLLER   17
#define ACT_TELSIZ   18
#define ACT_PROFIL   19
#define ACT_REC      100

enum
{
    D_NONE = 9100,
    D_BACK, D_DEPLIST, D_DEPINFO, D_MEKANLIST,
    D_TAB, D_DUYYAZ, D_MESAJ, D_BUTCE, D_BUTCEMIKTAR,
    D_YONET, D_YONETID, D_YONETRANK, D_YONETMAAS,
    D_RECSUB, D_RECHEDEF, D_RECMETIN,
    D_SORGUK, D_SORGUP, D_RUHSAT,
    D_HBASLIK, D_HMETIN, D_HTUR, D_HONAY, D_HONAYACT, D_HGECMIS, D_HGECACT, D_HEDIT, D_ADMDEP, D_KATIL, D_KIYAFET,
    D_AYRIL, D_PLIST, D_PACT, D_ALIM, D_ALIMLVL, D_ROLES, D_ROLEACT, D_ROLENAME, D_ROLEPERM, D_ROLENEW
}

// ------------------------------------------------------------------
//  GECIKMELI DIALOG (mobil/SAMP Unity: OnDialogResponse icinde hemen
//  acilan yeni dialog gorunmuyor -> kisa gecikmeyle ac)
// ------------------------------------------------------------------
#define DEBUG_DEP 1   // sorun cozulunce 0 yap
new bool:gInDlg[MAX_PLAYERS];

forward DlgGoster(playerid, dialogid, style, cap[], info[], b1[], b2[]);
public DlgGoster(playerid, dialogid, style, cap[], info[], b1[], b2[])
{
    if(!IsPlayerConnected(playerid)) return 0;
    return ShowPlayerDialog(playerid, dialogid, style, cap, info, b1, b2);
}

stock SafeDialog(playerid, dialogid, style, cap[], info[], b1[], b2[])
{
    if(!gInDlg[playerid]) return ShowPlayerDialog(playerid, dialogid, style, cap, info, b1, b2);
    SetTimerEx("DlgGoster", 150, false, "iiissss", playerid, dialogid, style, cap, info, b1, b2);
    return 1;
}
#define ShowPlayerDialog SafeDialog

// ------------------------------------------------------------------
//  DEPARTMAN VERILERI
// ------------------------------------------------------------------
new DepName[MAX_DEP][24] = {"Belediye", "FBI", "Polis (LSPD)", "Hastane (EMS)", "Medya (NEWS)", "Los Namados", "Liberty", "Inferno", "Vipers"};
new DepTablet[MAX_DEP][24] = {"Belediye Tableti", "FBI MDT", "Polis MDT", "EMS Tableti", "Haber Tableti", "Los Namados Paneli", "Liberty Paneli", "Inferno Paneli", "Vipers Paneli"};
new DepColor[MAX_DEP] = {0xF1C40FFF, 0x95A5A6FF, 0x3498DBFF, 0xE74C3CFF, 0x9B59B6FF, 0xFFFF00FF, 0x1E40FFFF, 0xFF0000FF, 0x00C800FF};
new DepEmbed[MAX_DEP][10] = {"{F1C40F}", "{95A5A6}", "{3498DB}", "{E74C3C}", "{9B59B6}", "{FFFF00}", "{1E40FF}", "{FF0000}", "{00C800}"};
new DepRadio[MAX_DEP][24] = {"Belediye Telsizi", "FBI Telsizi", "LSPD Telsizi", "EMS Telsizi", "NEWS Telsizi", "Los Namados Telsizi", "Liberty Telsizi", "Inferno Telsizi", "Vipers Telsizi"};
new DepFrek[MAX_DEP][12] = {"100.1", "101.5", "911.0", "112.0", "103.7", "666.1", "666.2", "666.3", "666.4"};
new DepSkin[MAX_DEP] = {147, 286, 280, 274, 59, 108, 114, 121, 105};
new DepIcon[MAX_DEP] = {36, 30, 30, 22, 55, 0, 0, 0, 0};
new DepDesc[MAX_DEP][200] =
{
    "Sehrin yonetimi, ruhsat, vergi ve vatandas islemlerinden sorumludur.",
    "Federal sorusturmalar, operasyonlar ve ozel vakalar ile ilgilenir.",
    "Sehirde asayisi saglar, ihbarlara mudahale eder, ceza ve tutanak tutar.",
    "Acil saglik hizmeti, ambulans ve hasta tedavisinden sorumludur.",
    "Haber, canli yayin ve etkinlik duyurulari ile halki bilgilendirir.",
    "Los Namados cetesi. Sokaklarin sarilar sahibidir.",
    "Liberty cetesi. Mavi renkleriyle bolgesini korur.",
    "Inferno cetesi. Kirmizilar ates gibi yayilir.",
    "Vipers cetesi. Yesil yilanlar sessiz ve olumcul."
};
new DefRank[MAX_DEP][DEF_RANKS][24] =
{
    {"Memur", "Uzman Memur", "Sef", "Baskan Yrd.", "Belediye Baskani"},
    {"Stajyer Ajan", "Ajan", "Ozel Ajan", "Mudur Yrd.", "FBI Muduru"},
    {"Cadet", "Memur", "Komiser Yrd.", "Komiser", "Polis Muduru"},
    {"Stajyer", "Paramedik", "Doktor", "Basdoktor", "Hastane Muduru"},
    {"Muhabir", "Gazeteci", "Editor", "Yazi Isleri Md.", "Medya Muduru"},
    {"Acemi", "Uye", "Usta", "Sag Kol", "Lider"},
    {"Acemi", "Uye", "Usta", "Sag Kol", "Lider"},
    {"Acemi", "Uye", "Usta", "Sag Kol", "Lider"},
    {"Acemi", "Uye", "Usta", "Sag Kol", "Lider"}
};
new RecCount[MAX_DEP] = {5, 6, 5, 5, 1, 2, 2, 2, 2};
new RecType[MAX_DEP][6][28] =
{
    {"Is Yeri Ruhsati", "Vergi Kaydi", "Vatandas Sikayeti", "Basvuru", "Toplanti Kaydi", ""},
    {"Operasyon Kaydi", "Sorusturma Dosyasi", "Olay Kaydi", "Delil Kaydi", "Gorev Raporu", "Gorev Atamasi"},
    {"Olay Raporu", "Ihbar Kaydi", "Ceza Kaydi", "Resmi Tutanak", "Gorev Atamasi", ""},
    {"Hasta Kaydi", "Tedavi Kaydi", "Hastane Raporu", "Ambulans Cagrisi", "Acil Servis Cagrisi", ""},
    {"Yayin Notu", "", "", "", "", ""},
    {"Uye Kaydi", "Operasyon Notu", "", "", "", ""},
    {"Uye Kaydi", "Operasyon Notu", "", "", "", ""},
    {"Uye Kaydi", "Operasyon Notu", "", "", "", ""},
    {"Uye Kaydi", "Operasyon Notu", "", "", "", ""}
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
new Text3D:LocLblO[MAX_LOC];
new LocJoinP[MAX_LOC];            // girisin yanindaki KATIL pickup
new Text3D:LocJoinL[MAX_LOC];
new Float:LocClo[MAX_LOC][3];     // ic mekandaki kiyafet yeri
new LocCloP[MAX_LOC];
new Text3D:LocCloL[MAX_LOC];

// ------------------------------------------------------------------
//  OYUNCU VERILERI
// ------------------------------------------------------------------
new DB:gDB;
new PDep[MAX_PLAYERS], PRank[MAX_PLAYERS], PMaas[MAX_PLAYERS];
new bool:PDuty[MAX_PLAYERS];
new bool:PAdm[MAX_PLAYERS];   // admin gecici tam yetki modu (DB'ye yazilmaz)
new PAct[MAX_PLAYERS], PTarget[MAX_PLAYERS], PTmp[MAX_PLAYERS];
new PTmpStr[MAX_PLAYERS][128], PTmpStr2[MAX_PLAYERS][128];
new PTab[MAX_PLAYERS][MAX_TABITEM];
new PList[MAX_PLAYERS][MAX_LISTITEM];
new PTeleTick[MAX_PLAYERS];
new PSkinOld[MAX_PLAYERS];
new PLevel[MAX_PLAYERS], PXP[MAX_PLAYERS];

// Rutbeler ve yetkiler (admin tabletten degistirilir, DB'de saklanir)
new RankName[MAX_DEP][MAX_RANK][24];
new RankPerm[MAX_DEP][MAX_RANK];
new RankCnt[MAX_DEP];
new PermName[PERM_COUNT][32] = {"Alim Ac / Kapat", "Personel Ise Al", "Personel Isten Cikar", "Rutbe Ver / Terfi", "Maas Belirle", "Duyuru Paylas", "Butce Yonetimi", "Haber Onay (Medya)", "YONETICI (Tum Yetkiler)"};

// Alim ayarlari
new DepAlim[MAX_DEP];
new DepMinLvl[MAX_DEP];
new Text:TDAlim;
new gAlimTimer;
new bool:PTelsiz[MAX_PLAYERS];   // telsiz modu: acikken normal yazi telsize gider
new PlayerText:PTD[MAX_PLAYERS][4];

forward MaasVer();
forward PanelYenile();
forward LevelTick();
forward HideAlim();

// ==================================================================
//  YARDIMCI FONKSIYONLAR
// ==================================================================
stock IsAdm(playerid)
{
    if(IsPlayerAdmin(playerid)) return 1;
    if(CallRemoteFunction("RP_GetAdminLevel", "i", playerid) >= 1) return 1;
    new nm[MAX_PLAYER_NAME];
    GetPlayerName(playerid, nm, sizeof nm);
    if(!strcmp(nm, YEDEK_ADMIN, true)) return 1;
    return 0;
}

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
    format(q, sizeof q, "SELECT isim FROM uyeler WHERE dep=%d AND rutbe=%d LIMIT 1", dep, RankCnt[dep]);
    DbGetStr(q, dest, size, "Atanmadi");
}

// SA-MP 144 karakterden uzun mesaji HIC gostermez: uzun mesaji parcalara bol
stock SendLong(playerid, color, msg[])
{
    new len = strlen(msg);
    if(len <= 140)
    {
        SendClientMessage(playerid, color, msg);
        return 1;
    }
    new part[144], pos = 0, cut, k;
    while(pos < len)
    {
        cut = 130;
        if(len - pos <= 140) cut = len - pos;
        else
        {
            k = pos + 130;
            while(k > pos + 60 && msg[k] != ' ') k--;
            if(msg[k] == ' ') cut = k - pos;
        }
        strmid(part, msg, pos, pos + cut, sizeof part);
        SendClientMessage(playerid, color, part);
        pos += cut;
        while(msg[pos] == ' ') pos++;
    }
    return 1;
}

stock SendDep(dep, color, msg[])
{
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && PDep[i] == dep) SendLong(i, color, msg);
}

// Rutbe yetkisi kontrolu (admin modundaki oyuncu her yetkiye sahiptir)
stock HasPerm(playerid, mask)
{
    new d = PDep[playerid];
    if(d < 0) return 0;
    if(PAdm[playerid]) return 1;
    new r = PRank[playerid] - 1;
    if(r < 0 || r >= MAX_RANK) return 0;
    return ((RankPerm[d][r] & (mask | P_YONETICI)) != 0);
}

// ---------------- Seviye sistemi ----------------
stock LevelNeed(lv)
{
    return lv * 15;     // sonraki seviye icin gereken dakika
}

stock GetLevel(playerid)
{
    if(IsAdm(playerid)) return MAX_ADMIN_LEVEL;
    return PLevel[playerid];
}

stock SaveLevel(playerid)
{
    new n[MAX_PLAYER_NAME], q[200];
    GetPlayerName(playerid, n, sizeof n);
    Esc(n);
    format(q, sizeof q, "INSERT OR REPLACE INTO seviye (isim,seviye,xp,admin) VALUES ('%s',%d,%d,%d)", n, PLevel[playerid], PXP[playerid], IsAdm(playerid) ? 1 : 0);
    DbExec(q);
}

// Telsiz: SADECE ayni departman/cete uyelerine gider (baskasi duymaz)
stock SendRadio(playerid, text[])
{
    new d = PDep[playerid];
    if(d < 0) return 0;
    new n[MAX_PLAYER_NAME], s2[260], rk = PRank[playerid];
    if(rk < 1) rk = 1;
    if(rk > RankCnt[d]) rk = RankCnt[d];
    GetPlayerName(playerid, n, sizeof n);
    format(s2, sizeof s2, "%s[%s %s] %s %s: {FFFFFF}%s", DepEmbed[d], DepRadio[d], DepFrek[d], RankName[d][rk - 1], n, text);
    SendDep(d, DepColor[d], s2);
    return 1;
}

stock ToggleTelsiz(playerid)
{
    new d = PDep[playerid], tm[200];
    if(d < 0)
    {
        SendClientMessage(playerid, C_ERR, "Telsizin yok. Bir departman/cete uyesi olmalisin.");
        return 0;
    }
    PTelsiz[playerid] = !PTelsiz[playerid];
    if(PTelsiz[playerid])
        format(tm, sizeof tm, "%s%s (%s) ACIK{FFFFFF}: yazdiklarin sadece %s uyelerine gider. Kapatmak icin tekrar /telsiz yaz.", DepEmbed[d], DepRadio[d], DepFrek[d], DepName[d]);
    else
        format(tm, sizeof tm, "%s%s KAPALI{FFFFFF}: normal sohbete donuldu.", DepEmbed[d], DepRadio[d]);
    SendLong(playerid, PTelsiz[playerid] ? C_OK : C_INF, tm);
    return 1;
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
    DbExec("CREATE TABLE IF NOT EXISTS mekanyer (dep INTEGER PRIMARY KEY, x REAL, y REAL, z REAL, a REAL)");
    DbExec("CREATE TABLE IF NOT EXISTS seviye (isim TEXT PRIMARY KEY, seviye INTEGER, xp INTEGER, admin INTEGER)");
    DbExec("CREATE TABLE IF NOT EXISTS roller (dep INTEGER, rutbe INTEGER, isim TEXT, yetki INTEGER, PRIMARY KEY(dep,rutbe))");
    DbExec("CREATE TABLE IF NOT EXISTS depayar (dep INTEGER PRIMARY KEY, alim INTEGER, minlvl INTEGER)");
    DbExec("CREATE TABLE IF NOT EXISTS kiyafetyer (dep INTEGER PRIMARY KEY, x REAL, y REAL, z REAL)");
    DbExec("CREATE TABLE IF NOT EXISTS araclar (plaka TEXT PRIMARY KEY, sahip TEXT, model TEXT, tarih TEXT)");
    new q[100];
    for(new d = 0; d < MAX_DEP; d++)
    {
        format(q, sizeof q, "INSERT OR IGNORE INTO butce (dep,miktar) VALUES (%d,%d)", d, BASLANGIC_BUTCE);
        DbExec(q);
        format(q, sizeof q, "INSERT OR IGNORE INTO depayar (dep,alim,minlvl) VALUES (%d,0,%d)", d, MIN_LEVEL_DEF);
        DbExec(q);
    }
    return 1;
}

// ==================================================================
//  MEKANLAR
// ==================================================================
// Giris noktasinin yaninda (sag tarafta) "KATIL" noktasi olustur / yenile
stock MakeJoinSpot(i)
{
    if(LocJoinP[i]) DestroyPickup(LocJoinP[i]);
    if(LocJoinL[i] != Text3D:0) Delete3DTextLabel(LocJoinL[i]);
    new Float:a = LocOut[i][3];
    new Float:x = LocOut[i][0] + 2.5 * floatcos(a, degrees);
    new Float:y = LocOut[i][1] + 2.5 * floatsin(a, degrees);
    new lbl[80];
    format(lbl, sizeof lbl, "%s'e KATIL\n{FFFFFF}(Uzerine bas)", DepName[LocDep[i]]);
    LocJoinP[i] = CreatePickup(1239, 1, x, y, LocOut[i][2], 0);
    LocJoinL[i] = Create3DTextLabel(lbl, DepColor[LocDep[i]], x, y, LocOut[i][2] + 0.8, 15.0, 0, 0);
}

// Ic mekanda kiyafet yeri olustur / yenile (rengi departman/cete rengidir)
stock MakeCloSpot(i)
{
    if(LocCloP[i]) DestroyPickup(LocCloP[i]);
    if(LocCloL[i] != Text3D:0) Delete3DTextLabel(LocCloL[i]);
    new lbl[80];
    format(lbl, sizeof lbl, "KIYAFET\n%s", DepName[LocDep[i]]);
    LocCloP[i] = CreatePickup(1275, 1, LocClo[i][0], LocClo[i][1], LocClo[i][2], i + 1);
    LocCloL[i] = Create3DTextLabel(lbl, DepColor[LocDep[i]], LocClo[i][0], LocClo[i][1], LocClo[i][2] + 0.8, 12.0, i + 1, 0);
}

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
    LocLblO[i] = Create3DTextLabel(lbl, DepColor[dep], ox, oy, oz + 0.8, 20.0, 0, 0);
    Create3DTextLabel("CIKIS", 0xFFFFFFFF, ix, iy, iz + 0.8, 10.0, i + 1, 0);
    LocJoinP[i] = 0; LocJoinL[i] = Text3D:0; LocCloP[i] = 0; LocCloL[i] = Text3D:0;
    MakeJoinSpot(i);
    // kiyafet yeri: cikisin 3 birim ilerisi, 2.5 birim sagi (ornek; /kiyafetyer ile degistirilir)
    LocClo[i][0] = ix - 3.0 * floatsin(ia, degrees) + 2.5 * floatcos(ia, degrees);
    LocClo[i][1] = iy + 3.0 * floatcos(ia, degrees) + 2.5 * floatsin(ia, degrees);
    LocClo[i][2] = iz;
    MakeCloSpot(i);
    return i;
}

stock DoTeleport(playerid, loc, bool:giris)
{
    new Float:x, Float:y, Float:z, Float:a;
    if(giris)
    {
        if(!LocPub[loc] && PDep[playerid] != LocDep[loc] && !IsAdm(playerid))
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
    {
        if(LocDep[i] >= GANG_BASLA) continue;   // cete mekanlari haritada gorunmez
        SetPlayerMapIcon(playerid, i, LocOut[i][0], LocOut[i][1], LocOut[i][2], DepIcon[LocDep[i]], 0, MAPICON_GLOBAL);
    }
}

// Mekan giris noktasini tasi (pickup + yazi + harita ikonu yenilenir)
stock MoveLocOut(i, Float:x, Float:y, Float:z, Float:ang)
{
    DestroyPickup(LocPickO[i]);
    Delete3DTextLabel(LocLblO[i]);
    LocOut[i][0] = x; LocOut[i][1] = y; LocOut[i][2] = z; LocOut[i][3] = ang;
    LocPickO[i] = CreatePickup(1318, 1, x, y, z, 0);
    new lbl[80];
    format(lbl, sizeof lbl, "%s\n%s", LocName[i], LocPub[i] ? "Herkese Acik" : "Sadece Personel");
    LocLblO[i] = Create3DTextLabel(lbl, DepColor[LocDep[i]], x, y, z + 0.8, 20.0, 0, 0);
    MakeJoinSpot(i);
    for(new p = 0; p < MAX_PLAYERS; p++) if(IsPlayerConnected(p)) SetMapIcons(p);
}

stock FindLocByDep(dep)
{
    for(new i = 0; i < LocCount; i++) if(LocDep[i] == dep) return i;
    return -1;
}

// /mekanyer ile kaydedilmis giris noktalarini yukle
stock LoadLocOverrides()
{
    new DBResult:r = db_query(gDB, "SELECT dep,x,y,z,a FROM mekanyer");
    if(!r) return;
    if(db_num_rows(r))
    {
        do
        {
            new f[32], dep, Float:x, Float:y, Float:z, Float:ang;
            db_get_field(r, 0, f, sizeof f); dep = strval(f);
            db_get_field(r, 1, f, sizeof f); x = floatstr(f);
            db_get_field(r, 2, f, sizeof f); y = floatstr(f);
            db_get_field(r, 3, f, sizeof f); z = floatstr(f);
            db_get_field(r, 4, f, sizeof f); ang = floatstr(f);
            new li = FindLocByDep(dep);
            if(li >= 0) MoveLocOut(li, x, y, z, ang);
        }
        while(db_next_row(r));
    }
    db_free_result(r);
}

// /kiyafetyer ile kaydedilmis kiyafet yerlerini yukle
stock LoadCloOverrides()
{
    new DBResult:r = db_query(gDB, "SELECT dep,x,y,z FROM kiyafetyer");
    if(!r) return;
    if(db_num_rows(r))
    {
        do
        {
            new f[32], dep, li;
            db_get_field(r, 0, f, sizeof f); dep = strval(f);
            li = FindLocByDep(dep);
            if(li < 0) continue;
            db_get_field(r, 1, f, sizeof f); LocClo[li][0] = floatstr(f);
            db_get_field(r, 2, f, sizeof f); LocClo[li][1] = floatstr(f);
            db_get_field(r, 3, f, sizeof f); LocClo[li][2] = floatstr(f);
            MakeCloSpot(li);
        }
        while(db_next_row(r));
    }
    db_free_result(r);
}

// ==================================================================
//  SOL PANEL (MAVI)
// ==================================================================
stock CreatePanel(playerid)
{
    PTD[playerid][0] = CreatePlayerTextDraw(playerid, 10.0, 150.0, "_");
    PlayerTextDrawFont(playerid, PTD[playerid][0], 1);
    PlayerTextDrawLetterSize(playerid, PTD[playerid][0], 0.5, 13.0);
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
    format(s, sizeof s, "~w~Rutbe: ~y~%s~n~~w~Seviye: ~y~%d~n~~w~Gorev: %s~n~~w~Cevrimici: ~y~%d~n~~w~Maas: ~g~$%d~n~~n~~w~/tablet ~b~| ~w~/departman",
        RankName[d][PRank[playerid] - 1], GetLevel(playerid),
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

// Admin: istedigi departmanda gecici Mudur yetkisiyle calisir (DB'ye yazilmaz, maas almaz)
stock AdminAsDep(playerid, dep)
{
    PDep[playerid] = dep;
    PRank[playerid] = RankCnt[dep];
    PMaas[playerid] = 0;
    PDuty[playerid] = true;
    PAdm[playerid] = true;
    ShowPanel(playerid);
    new s[100];
    format(s, sizeof s, "[ADMIN] %s icin tam yetki (Mudur) modundasin.", DepName[dep]);
    SendClientMessage(playerid, DepColor[dep], s);
}

stock ShowAdmDepList(playerid)
{
    new s[400];
    s[0] = 0;
    for(new d = 0; d < MAX_DEP; d++)
    {
        strcat(s, DepEmbed[d], sizeof s);
        strcat(s, DepName[d], sizeof s);
        strcat(s, "\n", sizeof s);
    }
    ShowPlayerDialog(playerid, D_ADMDEP, DIALOG_STYLE_LIST, "Admin - Hangi tableti acmak istiyorsun?", s, "Ac", "Kapat");
}

// ==================================================================
//  UYELIK
// ==================================================================
stock UpdateMember(playerid)
{
    if(PAdm[playerid]) return;
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
    PAdm[playerid] = false;
    PDep[playerid] = dep;
    PRank[playerid] = rank;
    PMaas[playerid] = (dep >= GANG_BASLA) ? 0 : rank * RANK_MAAS;
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
    if(PAdm[playerid])
    {
        PAdm[playerid] = false;
        PDep[playerid] = -1; PRank[playerid] = 0; PMaas[playerid] = 0; PDuty[playerid] = false; PTelsiz[playerid] = false;
        HidePanel(playerid);
        SendClientMessage(playerid, C_INF, "Admin yetki modundan cikildi.");
        return 1;
    }
    GetPlayerName(playerid, n, sizeof n);
    Esc(n);
    AddHistory(d, n, "Departmandan ayrildi/cikarildi");
    format(q, sizeof q, "DELETE FROM uyeler WHERE isim='%s'", n);
    DbExec(q);
    // personel kiyafetini giyiyorsa eski kiyafetine don
    if(PSkinOld[playerid] >= 0 && GetPlayerSkin(playerid) == DepSkin[d]) SetPlayerSkin(playerid, PSkinOld[playerid]);
    PDep[playerid] = -1;
    PRank[playerid] = 0;
    PMaas[playerid] = 0;
    PDuty[playerid] = false;
    PTelsiz[playerid] = false;
    HidePanel(playerid);
    SendClientMessage(playerid, C_INF, "Departmandan ayrildin.");
    return 1;
}

stock SetRank(t, nr)
{
    new n[MAX_PLAYER_NAME], ev[100], d = PDep[t];
    GetPlayerName(t, n, sizeof n);
    PRank[t] = nr;
    PMaas[t] = (d >= GANG_BASLA) ? 0 : nr * RANK_MAAS;
    UpdateMember(t);
    format(ev, sizeof ev, "Rutbe: %s", RankName[d][nr - 1]);
    AddHistory(d, n, ev);
    ShowPanel(t);
    format(ev, sizeof ev, "Yeni rutben: %s", RankName[d][nr - 1]);
    SendClientMessage(t, DepColor[d], ev);
}

// ==================================================================
//  RUTBE / YETKI SISTEMI
// ==================================================================
stock DefaultPerm(rank, cnt)
{
    if(rank >= cnt) return P_YONETICI;
    if(rank == cnt - 1) return (P_ALIM | P_ISEAL | P_CIKAR | P_RUTBE | P_MAAS | P_DUYURU | P_BUTCE | P_MEDYA);
    return 0;
}

stock SetupRanks()
{
    for(new d = 0; d < MAX_DEP; d++)
    {
        RankCnt[d] = DEF_RANKS;
        for(new r = 0; r < MAX_RANK; r++)
        {
            RankName[d][r][0] = 0;
            RankPerm[d][r] = 0;
        }
        for(new r = 0; r < DEF_RANKS; r++)
        {
            format(RankName[d][r], 24, "%s", DefRank[d][r]);
            RankPerm[d][r] = DefaultPerm(r + 1, DEF_RANKS);
        }
    }
}

stock SaveRoles(dep)
{
    new q[200], nm[24];
    format(q, sizeof q, "DELETE FROM roller WHERE dep=%d", dep);
    DbExec(q);
    for(new r = 0; r < RankCnt[dep]; r++)
    {
        format(nm, sizeof nm, "%s", RankName[dep][r]);
        Esc(nm);
        format(q, sizeof q, "INSERT INTO roller (dep,rutbe,isim,yetki) VALUES (%d,%d,'%s',%d)", dep, r + 1, nm, RankPerm[dep][r]);
        DbExec(q);
    }
}

stock LoadRoles()
{
    new q[140];
    for(new d = 0; d < MAX_DEP; d++)
    {
        format(q, sizeof q, "SELECT COUNT(*) FROM roller WHERE dep=%d", d);
        new cnt = DbGetInt(q);
        if(cnt < 2 || cnt > MAX_RANK) continue;
        format(q, sizeof q, "SELECT rutbe,isim,yetki FROM roller WHERE dep=%d ORDER BY rutbe ASC", d);
        new DBResult:r = db_query(gDB, q);
        if(!r) continue;
        new f[32], idx = 0;
        if(db_num_rows(r))
        {
            do
            {
                if(idx >= MAX_RANK) break;
                db_get_field(r, 1, f, sizeof f);
                format(RankName[d][idx], 24, "%s", f);
                db_get_field(r, 2, f, sizeof f);
                RankPerm[d][idx] = strval(f);
                idx++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
        if(idx >= 2)
        {
            RankCnt[d] = idx;
            for(new k = idx; k < MAX_RANK; k++)
            {
                RankName[d][k][0] = 0;
                RankPerm[d][k] = 0;
            }
        }
    }
}

stock LoadDepAyar()
{
    new q[100];
    for(new d = 0; d < MAX_DEP; d++)
    {
        format(q, sizeof q, "SELECT alim FROM depayar WHERE dep=%d", d);
        DepAlim[d] = DbGetInt(q, 0);
        format(q, sizeof q, "SELECT minlvl FROM depayar WHERE dep=%d", d);
        DepMinLvl[d] = DbGetInt(q, MIN_LEVEL_DEF);
    }
}

// En alta (rutbe 1'in altina) yeni rutbe ekler, mevcut uyeler ayni rutbede kalir
stock RankAddBottom(dep, name[])
{
    if(RankCnt[dep] >= MAX_RANK) return 0;
    for(new r = RankCnt[dep]; r > 0; r--)
    {
        format(RankName[dep][r], 24, "%s", RankName[dep][r - 1]);
        RankPerm[dep][r] = RankPerm[dep][r - 1];
    }
    format(RankName[dep][0], 24, "%s", name);
    RankPerm[dep][0] = 0;
    RankCnt[dep]++;
    new q[100];
    format(q, sizeof q, "UPDATE uyeler SET rutbe=rutbe+1 WHERE dep=%d", dep);
    DbExec(q);
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PDep[i] != dep) continue;
        if(PAdm[i]) PRank[i] = RankCnt[dep];
        else PRank[i]++;
        ShowPanel(i);
    }
    SaveRoles(dep);
    return 1;
}

// Lider rutbesi silinemez. Silinen rutbenin uyeleri bir alt rutbeye gecer.
stock RankDelete(dep, idx)
{
    new cnt = RankCnt[dep], rk = idx + 1, q[120];
    if(cnt <= 2 || idx < 0 || idx >= cnt - 1) return 0;
    if(rk > 1)
    {
        format(q, sizeof q, "UPDATE uyeler SET rutbe=%d WHERE dep=%d AND rutbe=%d", rk - 1, dep, rk);
        DbExec(q);
    }
    format(q, sizeof q, "UPDATE uyeler SET rutbe=rutbe-1 WHERE dep=%d AND rutbe>%d", dep, rk);
    DbExec(q);
    for(new r = idx; r < cnt - 1; r++)
    {
        format(RankName[dep][r], 24, "%s", RankName[dep][r + 1]);
        RankPerm[dep][r] = RankPerm[dep][r + 1];
    }
    RankName[dep][cnt - 1][0] = 0;
    RankPerm[dep][cnt - 1] = 0;
    RankCnt[dep] = cnt - 1;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PDep[i] != dep) continue;
        if(PAdm[i]) PRank[i] = RankCnt[dep];
        else if(PRank[i] == rk) { if(rk > 1) PRank[i] = rk - 1; }
        else if(PRank[i] > rk) PRank[i]--;
        if(PRank[i] > RankCnt[dep]) PRank[i] = RankCnt[dep];
        ShowPanel(i);
    }
    SaveRoles(dep);
    return 1;
}

// ==================================================================
//  ISIM TABANLI PERSONEL ISLEMLERI (cevrimdisi personel icin de calisir)
// ==================================================================
stock FindOnlineByName(name[])
{
    new n[MAX_PLAYER_NAME];
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if(!strcmp(n, name, true)) return i;
    }
    return INVALID_PLAYER_ID;
}

stock GetMemberRank(name[], dep)
{
    new q[160], nm[32];
    format(nm, sizeof nm, "%s", name);
    Esc(nm);
    format(q, sizeof q, "SELECT rutbe FROM uyeler WHERE isim='%s' AND dep=%d", nm, dep);
    return DbGetInt(q, 0);
}

stock GetMemberByIndex(dep, idx, dest[], size)
{
    new q[200];
    dest[0] = 0;
    format(q, sizeof q, "SELECT isim FROM uyeler WHERE dep=%d ORDER BY rutbe DESC, isim ASC LIMIT 1 OFFSET %d", dep, idx);
    DbGetStr(q, dest, size, "");
    return (dest[0] != 0);
}

stock CanManage(playerid, tr, name[])
{
    new me[MAX_PLAYER_NAME];
    if(PAdm[playerid]) return 1;
    GetPlayerName(playerid, me, sizeof me);
    if(!strcmp(me, name, true)) return 0;
    return (tr < PRank[playerid]);
}

stock MaxAssignable(playerid)
{
    if(PAdm[playerid]) return RankCnt[PDep[playerid]];
    return PRank[playerid] - 1;
}

stock SetRankByName(name[], dep, nr)
{
    new nm[32], q[220], ev[100], t = FindOnlineByName(name);
    if(nr < 1) nr = 1;
    if(nr > RankCnt[dep]) nr = RankCnt[dep];
    if(t != INVALID_PLAYER_ID && PDep[t] == dep && !PAdm[t])
    {
        SetRank(t, nr);
        return 1;
    }
    format(nm, sizeof nm, "%s", name);
    Esc(nm);
    format(q, sizeof q, "UPDATE uyeler SET rutbe=%d, maas=%d WHERE isim='%s' AND dep=%d", nr, (dep >= GANG_BASLA) ? 0 : nr * RANK_MAAS, nm, dep);
    DbExec(q);
    format(ev, sizeof ev, "Rutbe: %s", RankName[dep][nr - 1]);
    AddHistory(dep, nm, ev);
    return 1;
}

stock RemoveByName(name[], dep)
{
    new nm[32], q[160], t = FindOnlineByName(name);
    if(t != INVALID_PLAYER_ID && PDep[t] == dep && !PAdm[t])
    {
        LeaveDept(t);
        return 1;
    }
    format(nm, sizeof nm, "%s", name);
    Esc(nm);
    AddHistory(dep, nm, "Departmandan cikarildi");
    format(q, sizeof q, "DELETE FROM uyeler WHERE isim='%s' AND dep=%d", nm, dep);
    DbExec(q);
    return 1;
}

stock SetMaasByName(name[], dep, m)
{
    new nm[32], q[160], ev[60], t = FindOnlineByName(name);
    format(nm, sizeof nm, "%s", name);
    Esc(nm);
    format(ev, sizeof ev, "Maas belirlendi: $%d", m);
    if(t != INVALID_PLAYER_ID && PDep[t] == dep && !PAdm[t])
    {
        PMaas[t] = m;
        UpdateMember(t);
        ShowPanel(t);
        SendClientMessage(t, C_INF, "Maasin guncellendi.");
    }
    else
    {
        format(q, sizeof q, "UPDATE uyeler SET maas=%d WHERE isim='%s' AND dep=%d", m, nm, dep);
        DbExec(q);
    }
    AddHistory(dep, nm, ev);
    return 1;
}

// ==================================================================
//  KATILMA (1 kisi = en fazla 1 departman/cete), ALIM, SEVIYE
// ==================================================================
// doit = false: sadece kontrol eder (mesaj verir), true: katilir
stock TryJoin(playerid, dep, bool:doit)
{
    new s[180];
    if(dep < 0 || dep >= MAX_DEP) return 0;
    if(PDep[playerid] == dep)
    {
        format(s, sizeof s, "Zaten %s uyesisin.", DepName[dep]);
        SendClientMessage(playerid, C_INF, s);
        return 0;
    }
    if(PDep[playerid] >= 0)
    {
        format(s, sizeof s, "Zaten %s icindesin. Ayni anda en fazla 1 departman/cetede olabilirsin, once /ayril yaz.", DepName[PDep[playerid]]);
        SendLong(playerid, C_ERR, s);
        return 0;
    }
    if(!IsAdm(playerid))
    {
        if(!DepAlim[dep])
        {
            format(s, sizeof s, "%s alimlari su an KAPALI.", DepName[dep]);
            SendClientMessage(playerid, C_ERR, s);
            return 0;
        }
        if(GetLevel(playerid) < DepMinLvl[dep])
        {
            format(s, sizeof s, "%s icin en az %d. seviye gerekli. (Senin seviyen: %d)", DepName[dep], DepMinLvl[dep], GetLevel(playerid));
            SendLong(playerid, C_ERR, s);
            return 0;
        }
    }
    if(doit) SetMember(playerid, dep, 1);
    return 1;
}

stock MakeAlimTD()
{
    TDAlim = TextDrawCreate(320.0, 22.0, "_");
    TextDrawAlignment(TDAlim, 2);
    TextDrawFont(TDAlim, 2);
    TextDrawLetterSize(TDAlim, 0.38, 1.6);
    TextDrawSetOutline(TDAlim, 1);
    TextDrawSetProportional(TDAlim, 1);
    TextDrawColor(TDAlim, 0xFFFFFFFF);
}

public HideAlim()
{
    TextDrawHideForAll(TDAlim);
    gAlimTimer = 0;
}

stock SetAlim(dep, acik)
{
    new q[100], s[180];
    DepAlim[dep] = acik ? 1 : 0;
    format(q, sizeof q, "UPDATE depayar SET alim=%d WHERE dep=%d", DepAlim[dep], dep);
    DbExec(q);
    if(acik)
    {
        format(s, sizeof s, "%s ALIMLARI ACILDI~n~Seviye %d ve uzeri katilabilir", DepName[dep], DepMinLvl[dep]);
        TextDrawSetString(TDAlim, s);
        TextDrawColor(TDAlim, DepColor[dep]);
        TextDrawShowForAll(TDAlim);
        if(gAlimTimer) KillTimer(gAlimTimer);
        gAlimTimer = SetTimer("HideAlim", 10000, false);
        format(s, sizeof s, "[ALIM] %s alimlari ACILDI! Seviye %d ve uzeri katilabilir. Giristeki KATIL noktasina git.", DepName[dep], DepMinLvl[dep]);
        SendClientMessageToAll(DepColor[dep], s);
    }
    else
    {
        format(s, sizeof s, "[ALIM] %s alimlari KAPANDI.", DepName[dep]);
        SendClientMessageToAll(DepColor[dep], s);
    }
}

public LevelTick()
{
    new s[100], st;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        st = GetPlayerState(i);
        if(st == PLAYER_STATE_NONE || st == PLAYER_STATE_SPECTATING) continue;
        if(!IsAdm(i))
        {
            PXP[i]++;
            if(PXP[i] >= LevelNeed(PLevel[i]) && PLevel[i] < 999)
            {
                PXP[i] -= LevelNeed(PLevel[i]);
                PLevel[i]++;
                format(s, sizeof s, "SEVIYE ATLADIN! Yeni seviyen: %d", PLevel[i]);
                SendClientMessage(i, C_OK, s);
                ShowPanel(i);
            }
        }
        SaveLevel(i);
    }
}

// ==================================================================
//  DIALOG GOSTERIMLERI
// ==================================================================
stock ShowDepList(playerid)
{
    new s[1400], l[160], mud[32];
    format(s, sizeof s, "Departman\tPersonel\tYonetici\tAlim\n");
    for(new d = 0; d < MAX_DEP; d++)
    {
        GetMudur(d, mud, sizeof mud);
        format(l, sizeof l, "%s%s\t%d\t%s\t%s\n", DepEmbed[d], DepName[d], CountMembers(d), mud, DepAlim[d] ? "{44FF44}Acik" : "{FF4444}Kapali");
        strcat(s, l, sizeof s);
    }
    ShowPlayerDialog(playerid, D_DEPLIST, DIALOG_STYLE_TABLIST_HEADERS, "Departmanlar", s, "Sec", "Kapat");
}

stock ShowDepInfo(playerid, d)
{
    new s[1700], l[160], mud[32];
    GetMudur(d, mud, sizeof mud);
    format(s, sizeof s, "%s%s\n{FFFFFF}%s\n\n{AAAAAA}Yonetici: {FFFFFF}%s\n{AAAAAA}Personel: {FFFFFF}%d  (Cevrimici: %d)\n{AAAAAA}Alimlar: %s  {AAAAAA}Min. seviye: {FFFF00}%d\n\n{AAAAAA}Rutbeler:\n{FFFFFF}",
        DepEmbed[d], DepName[d], DepDesc[d], mud, CountMembers(d), CountOnline(d), DepAlim[d] ? "{44FF44}ACIK" : "{FF4444}KAPALI", DepMinLvl[d]);
    for(new r = 0; r < RankCnt[d]; r++)
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
        case ACT_DUYNEW: return HasPerm(playerid, P_DUYURU);
        case ACT_YONET: return HasPerm(playerid, P_ISEAL | P_CIKAR | P_RUTBE | P_MAAS);
        case ACT_HONAY: return HasPerm(playerid, P_MEDYA);
        case ACT_ALIM: return HasPerm(playerid, P_ALIM);
        case ACT_ROLLER: return IsAdm(playerid);
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
    new list[1500], n = 0, cap[64], l[48];
    list[0] = 0;
    for(new i = 0; i < MAX_TABITEM; i++) PTab[playerid][i] = 0;
    AddTab(playerid, n, ACT_PROFIL, "Profilim / Yetkilerim", list, sizeof list);
    AddTab(playerid, n, ACT_PERS, "Personel Listesi", list, sizeof list);
    AddTab(playerid, n, ACT_DUY, "Departman Duyurulari", list, sizeof list);
    AddTab(playerid, n, ACT_MSG, "Departman Mesaji Gonder", list, sizeof list);
    AddTab(playerid, n, ACT_TELSIZ, "Telsizi Ac / Kapat", list, sizeof list);
    AddTab(playerid, n, ACT_BUTCE, "Departman Butcesi", list, sizeof list);
    AddTab(playerid, n, ACT_DUTY, "Gorev Durumu Degistir", list, sizeof list);
    AddTab(playerid, n, ACT_SIRALAMA, "Seviye Siralamasi", list, sizeof list);
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
    if(ActAllowed(playerid, ACT_ALIM)) AddTab(playerid, n, ACT_ALIM, "Alim Yonetimi (Ac / Kapat)", list, sizeof list);
    if(ActAllowed(playerid, ACT_YONET)) AddTab(playerid, n, ACT_YONET, "Yonetim Paneli", list, sizeof list);
    if(ActAllowed(playerid, ACT_ROLLER)) AddTab(playerid, n, ACT_ROLLER, "Rutbe & Yetki Ayarlari (Admin)", list, sizeof list);
    AddTab(playerid, n, ACT_AYRIL, "Departmandan / Cetedan Ayril", list, sizeof list);
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
                if(rk > RankCnt[d]) rk = RankCnt[d];
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

stock SaveHaber(playerid)
{
    new q[600], t[24], n[MAX_PLAYER_NAME], bs[128], mt[128], durum, herkes, tur = PTmp[playerid];
    GetPlayerName(playerid, n, sizeof n);
    format(bs, sizeof bs, "%s", PTmpStr[playerid]);
    format(mt, sizeof mt, "%s", PTmpStr2[playerid]);
    Esc(bs); Esc(mt);
    TimeStr(t);
    durum = HasPerm(playerid, P_MEDYA) ? 1 : 0;
    herkes = (tur == 1) ? 0 : 1;
    format(q, sizeof q, "INSERT INTO haberler (baslik,metin,yazar,durum,herkes,tur,tarih) VALUES ('%s','%s','%s',%d,%d,%d,'%s')", bs, mt, n, durum, herkes, tur, t);
    DbExec(q);
    if(durum == 1) BroadcastHaber(tur, bs);
    else SendClientMessage(playerid, C_INF, "Haberin onay icin medya yonetimine gonderildi.");
    if(durum == 1) SendClientMessage(playerid, C_OK, "Haber yayinlandi.");
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

stock ShowHistory(playerid, name[])
{
    new d = PDep[playerid], nm[32], DBResult:r, a[100], b[24], list[2000], l[160], q[200], cap[64];
    format(nm, sizeof nm, "%s", name);
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
    format(cap, sizeof cap, "Personel Gecmisi: %s", nm);
    ShowBack(playerid, DIALOG_STYLE_MSGBOX, cap, list);
}

stock ShowYonet(playerid)
{
    new s[300], k = 0;
    s[0] = 0;
    for(new i = 0; i < MAX_LISTITEM; i++) PList[playerid][i] = 0;
    if(HasPerm(playerid, P_RUTBE | P_CIKAR | P_MAAS)) { strcat(s, "Personel Listesi / Yonet\n", sizeof s); PList[playerid][k++] = 1; }
    if(HasPerm(playerid, P_ISEAL)) { strcat(s, "Oyuncuyu Ise Al (ID / Isim)\n", sizeof s); PList[playerid][k++] = 2; }
    strcat(s, "Personel Gecmisini Goruntule\n", sizeof s);
    PList[playerid][k++] = 3;
    ShowPlayerDialog(playerid, D_YONET, DIALOG_STYLE_LIST, "Yonetim Paneli", s, "Sec", "Geri");
}

stock ShowPlist(playerid)
{
    new d = PDep[playerid], q[200], s[2600], l[120], a[32], b[16], DBResult:r, k = 0;
    format(s, sizeof s, "Isim\tRutbe\tDurum\n");
    format(q, sizeof q, "SELECT isim,rutbe FROM uyeler WHERE dep=%d ORDER BY rutbe DESC, isim ASC LIMIT %d", d, MAX_LISTITEM);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            do
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                new rk = strval(b);
                if(rk < 1) rk = 1;
                if(rk > RankCnt[d]) rk = RankCnt[d];
                format(l, sizeof l, "%s\t%s\t%s\n", a, RankName[d][rk - 1], IsNameOnline(a) ? "{44FF44}Cevrimici" : "{AAAAAA}Cevrimdisi");
                strcat(s, l, sizeof s);
                k++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k)
    {
        ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Personel Yonetimi", "Departmanda personel yok.");
        return 0;
    }
    ShowPlayerDialog(playerid, D_PLIST, DIALOG_STYLE_TABLIST_HEADERS, "Personel Yonetimi (kisiyi sec)", s, "Sec", "Geri");
    return 1;
}

stock ShowPact(playerid)
{
    new d = PDep[playerid], nm[32], tr, s[300], cap[64], k = 0, mg;
    format(nm, sizeof nm, "%s", PTmpStr[playerid]);
    tr = GetMemberRank(nm, d);
    if(tr < 1)
    {
        SendClientMessage(playerid, C_ERR, "Personel bulunamadi.");
        ShowYonet(playerid);
        return 0;
    }
    if(tr > RankCnt[d]) tr = RankCnt[d];
    mg = CanManage(playerid, tr, nm);
    s[0] = 0;
    for(new i = 0; i < MAX_LISTITEM; i++) PList[playerid][i] = 0;
    if(mg && HasPerm(playerid, P_RUTBE))
    {
        strcat(s, "Rutbe Ver\nTerfi Ettir\nRutbe Dusur\n", sizeof s);
        PList[playerid][k++] = 1;
        PList[playerid][k++] = 2;
        PList[playerid][k++] = 3;
    }
    if(mg && HasPerm(playerid, P_MAAS)) { strcat(s, "Maas Belirle\n", sizeof s); PList[playerid][k++] = 4; }
    if(mg && HasPerm(playerid, P_CIKAR)) { strcat(s, "Isten Cikar\n", sizeof s); PList[playerid][k++] = 5; }
    strcat(s, "Gecmisi Goster\n", sizeof s);
    PList[playerid][k++] = 6;
    if(!mg) SendClientMessage(playerid, C_INF, "Bu kisi senden ust veya esit rutbede: sadece gecmisini gorebilirsin.");
    format(cap, sizeof cap, "%s - %s", nm, RankName[d][tr - 1]);
    ShowPlayerDialog(playerid, D_PACT, DIALOG_STYLE_LIST, cap, s, "Sec", "Geri");
    return 1;
}

stock ShowAlim(playerid)
{
    new d = PDep[playerid], s[260];
    format(s, sizeof s, "Alimlar: %s\nMinimum seviye: {FFFF00}%d{FFFFFF} (degistirmek icin sec)",
        DepAlim[d] ? "{44FF44}ACIK{FFFFFF} (kapatmak icin sec)" : "{FF4444}KAPALI{FFFFFF} (acmak icin sec)", DepMinLvl[d]);
    ShowPlayerDialog(playerid, D_ALIM, DIALOG_STYLE_LIST, "Alim Yonetimi", s, "Sec", "Geri");
}

stock ShowAyril(playerid)
{
    new d = PDep[playerid], s[200];
    if(d < 0) return 0;
    format(s, sizeof s, "%s%s{FFFFFF}\n\nBu kurumdan/cetedan ayrilmak istedigine emin misin?\nRutben ve maasin silinecek.", DepEmbed[d], DepName[d]);
    ShowPlayerDialog(playerid, D_AYRIL, DIALOG_STYLE_MSGBOX, "Ayril", s, "Ayril", "Vazgec");
    return 1;
}

stock ShowProfil(playerid)
{
    new d = PDep[playerid], n[MAX_PLAYER_NAME], s[1000], l[96], rk = PRank[playerid], c = 0;
    if(rk < 1) rk = 1;
    if(rk > RankCnt[d]) rk = RankCnt[d];
    GetPlayerName(playerid, n, sizeof n);
    format(s, sizeof s, "{FFCC00}%s\n{AAAAAA}Kurum: %s%s\n{AAAAAA}Rutbe: {FFFFFF}%s  {AAAAAA}(%d/%d)\n{AAAAAA}Maas: {44FF44}$%d\n", n, DepEmbed[d], DepName[d], RankName[d][rk - 1], rk, RankCnt[d], PMaas[playerid]);
    if(IsAdm(playerid)) format(l, sizeof l, "{AAAAAA}Seviye: {FF8800}%d (ADMIN)\n", MAX_ADMIN_LEVEL);
    else format(l, sizeof l, "{AAAAAA}Seviye: {FFFFFF}%d  {AAAAAA}(XP: %d/%d dk)\n", PLevel[playerid], PXP[playerid], LevelNeed(PLevel[playerid]));
    strcat(s, l, sizeof s);
    strcat(s, "\n{AAAAAA}Yetkilerin:\n{FFFFFF}", sizeof s);
    for(new p = 0; p < PERM_COUNT; p++)
    {
        if(HasPerm(playerid, (1 << p)))
        {
            format(l, sizeof l, "- %s\n", PermName[p]);
            strcat(s, l, sizeof s);
            c++;
        }
    }
    if(!c) strcat(s, "- Yok\n", sizeof s);
    ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Profilim", s);
}

stock ShowSeviye(playerid)
{
    new s[240];
    if(IsAdm(playerid)) format(s, sizeof s, "{FFCC00}Seviyen: {FF8800}%d (ADMIN)", MAX_ADMIN_LEVEL);
    else format(s, sizeof s, "{FFCC00}Seviyen: {FFFFFF}%d\n{AAAAAA}XP: {FFFFFF}%d / %d dakika\n\n{AAAAAA}Her dakika oyunda kalarak XP kazanirsin.\n/siralama ile en yuksek seviyeleri gor.", PLevel[playerid], PXP[playerid], LevelNeed(PLevel[playerid]));
    ShowPlayerDialog(playerid, D_NONE, DIALOG_STYLE_MSGBOX, "Seviye", s, "Kapat", "");
}

stock ShowSiralama(playerid, bool:back)
{
    new s[1800], l[140], a[32], b[12], e[12], DBResult:r, k = 0;
    format(s, sizeof s, "#\tOyuncu\tSeviye\tKurum\n");
    r = db_query(gDB, "SELECT s.isim, CASE WHEN s.admin=1 THEN 1000 ELSE s.seviye END AS lv, s.xp, u.dep FROM seviye s LEFT JOIN uyeler u ON u.isim=s.isim ORDER BY lv DESC, s.xp DESC LIMIT 15");
    if(r)
    {
        if(db_num_rows(r))
        {
            do
            {
                db_get_field(r, 0, a, sizeof a);
                db_get_field(r, 1, b, sizeof b);
                db_get_field(r, 3, e, sizeof e);
                k++;
                new dn = -1;
                if(e[0]) dn = strval(e);
                format(l, sizeof l, "%d\t%s\t%s\t%s\n", k, a, b, (dn >= 0 && dn < MAX_DEP) ? DepName[dn] : "-");
                strcat(s, l, sizeof s);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k)
    {
        if(back) ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Seviye Siralamasi", "Henuz kayit yok.");
        else ShowPlayerDialog(playerid, D_NONE, DIALOG_STYLE_MSGBOX, "Seviye Siralamasi", "Henuz kayit yok.", "Kapat", "");
        return 0;
    }
    if(back) ShowBack(playerid, DIALOG_STYLE_TABLIST_HEADERS, "Seviye Siralamasi (Top 15)", s);
    else ShowPlayerDialog(playerid, D_NONE, DIALOG_STYLE_TABLIST_HEADERS, "Seviye Siralamasi (Top 15)", s, "Kapat", "");
    return 1;
}

stock ShowRoller(playerid)
{
    new d = PDep[playerid], s[1300], l[140];
    if(d < 0) return 0;
    format(s, sizeof s, "Sira\tRutbe\tYetki\n");
    for(new r = 0; r < RankCnt[d]; r++)
    {
        format(l, sizeof l, "%d%s\t%s\t%s\n", r + 1, (r == RankCnt[d] - 1) ? " (Lider)" : "", RankName[d][r],
            (RankPerm[d][r] & P_YONETICI) ? "{FFCC00}YONETICI" : ((RankPerm[d][r] != 0) ? "{44FF44}Ozel yetkiler" : "{AAAAAA}Yok"));
        strcat(s, l, sizeof s);
    }
    strcat(s, "{FFFF00}+ Yeni Rutbe Ekle\t\t\n", sizeof s);
    ShowPlayerDialog(playerid, D_ROLES, DIALOG_STYLE_TABLIST_HEADERS, "Rutbe & Yetki Ayarlari (Admin)", s, "Sec", "Geri");
    return 1;
}

stock ShowRoleAct(playerid)
{
    new d = PDep[playerid], ri = PTmp[playerid], cap[64];
    if(d < 0 || ri < 0 || ri >= RankCnt[d]) return 0;
    format(cap, sizeof cap, "%s%s", DepEmbed[d], RankName[d][ri]);
    ShowPlayerDialog(playerid, D_ROLEACT, DIALOG_STYLE_LIST, cap, "Ismi Degistir\nYetkileri Duzenle\nRutbeyi Sil", "Sec", "Geri");
    return 1;
}

stock ShowRolePerm(playerid)
{
    new d = PDep[playerid], ri = PTmp[playerid], s[900], l[110], cap[64];
    if(d < 0 || ri < 0 || ri >= RankCnt[d]) return 0;
    format(s, sizeof s, "Yetki\tDurum\n");
    for(new p = 0; p < PERM_COUNT; p++)
    {
        format(l, sizeof l, "%s\t%s\n", PermName[p], (RankPerm[d][ri] & (1 << p)) ? "{44FF44}ACIK" : "{FF4444}KAPALI");
        strcat(s, l, sizeof s);
    }
    format(cap, sizeof cap, "Yetkiler: %s (sec = ac/kapat)", RankName[d][ri]);
    ShowPlayerDialog(playerid, D_ROLEPERM, DIALOG_STYLE_TABLIST_HEADERS, cap, s, "Degistir", "Geri");
    return 1;
}

// Giristeki KATIL noktasi
stock OpenJoin(playerid, li)
{
    new d = LocDep[li], s[200];
    PTmp[playerid] = d;
    if(!TryJoin(playerid, d, false)) return 1;
    format(s, sizeof s, "%s%s{FFFFFF}\n\nBu kuruma/ceteye katilmak istiyor musun?\nBaslangic rutben: %s\nMinimum seviye: %d", DepEmbed[d], DepName[d], RankName[d][0], DepMinLvl[d]);
    ShowPlayerDialog(playerid, D_KATIL, DIALOG_STYLE_MSGBOX, DepName[d], s, "Katil", "Vazgec");
    return 1;
}

// Ic mekandaki KIYAFET noktasi
stock OpenCloset(playerid, li)
{
    new d = LocDep[li], s[120];
    if(PDep[playerid] != d && !IsAdm(playerid))
    {
        format(s, sizeof s, "Bu kiyafet yeri sadece %s uyeleri icindir.", DepName[d]);
        SendClientMessage(playerid, C_ERR, s);
        return 1;
    }
    PTmp[playerid] = d;
    format(s, sizeof s, "%s%s Kiyafeti\n{FFFFFF}Eski Kiyafetime Don", DepEmbed[d], DepName[d]);
    ShowPlayerDialog(playerid, D_KIYAFET, DIALOG_STYLE_LIST, "Kiyafet Dolabi", s, "Sec", "Kapat");
    return 1;
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
    AddLoc(1, "FBI Merkezi", 0, 1476.0, -1696.0, 14.0, 180.0, 246.4, 110.8, 1003.2, 0.0, 10);
    AddLoc(2, "LSPD Merkezi", 1, 1554.7, -1675.6, 16.2, 90.0, 246.7, 63.9, 1003.6, 0.0, 6);
    AddLoc(3, "All Saints Hastanesi", 1, 1177.9, -1323.9, 14.0, 270.0, 288.7, 169.3, 1007.2, 0.0, 3);
    AddLoc(4, "Medya Merkezi (NEWS)", 1, 1486.0, -1696.0, 14.0, 180.0, 288.7, 169.3, 1007.2, 0.0, 3);

    // CETE MEKANLARI (sadece uyeler girer). Koordinatlar ORNEKTIR: /mekanyer [5-8] ile gercek yere tasi.
    AddLoc(5, "Los Namados Evi", 0, 2065.3, -1703.6, 14.1, 90.0, 2807.6, -1173.9, 1025.6, 0.0, 8);
    AddLoc(6, "Liberty Evi", 0, 2371.0, -1945.0, 13.5, 90.0, 2496.0, -1692.1, 1014.7, 180.0, 3);
    AddLoc(7, "Inferno Evi", 0, 1892.0, -1682.0, 13.5, 270.0, 2365.1, -1135.6, 1050.9, 0.0, 8);
    AddLoc(8, "Vipers Evi", 0, 2523.5, -1679.3, 15.5, 270.0, 2467.0, -1698.0, 1013.5, 90.0, 2);

    LoadLocOverrides();
    LoadCloOverrides();
    SetupRanks();
    LoadRoles();
    LoadDepAyar();
    MakeAlimTD();
    SetTimer("LevelTick", 60000, true);

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
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SaveLevel(i);
    TextDrawDestroy(TDAlim);
    if(gDB) db_close(gDB);
    return 1;
}

public OnPlayerConnect(playerid)
{
    PDep[playerid] = -1; PRank[playerid] = 0; PMaas[playerid] = 0; PDuty[playerid] = false; PAdm[playerid] = false;
    PTeleTick[playerid] = 0;
    PSkinOld[playerid] = -1;
    PLevel[playerid] = 1; PXP[playerid] = 0;
    PTelsiz[playerid] = false;
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
            if(PDep[playerid] >= 0 && PRank[playerid] > RankCnt[PDep[playerid]]) PRank[playerid] = RankCnt[PDep[playerid]];
        }
        db_free_result(r);
    }
    format(q, sizeof q, "SELECT seviye,xp FROM seviye WHERE isim='%s'", n);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            db_get_field(r, 0, f, sizeof f); PLevel[playerid] = strval(f);
            db_get_field(r, 1, f, sizeof f); PXP[playerid] = strval(f);
            if(PLevel[playerid] < 1) PLevel[playerid] = 1;
            if(PXP[playerid] < 0) PXP[playerid] = 0;
        }
        db_free_result(r);
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    SaveLevel(playerid);
    PDep[playerid] = -1; PAdm[playerid] = false; PTelsiz[playerid] = false;
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
        if(pickupid == LocJoinP[i]) { OpenJoin(playerid, i); return 1; }
        if(pickupid == LocCloP[i]) { OpenCloset(playerid, i); return 1; }
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
public OnPlayerText(playerid, text[])
{
    if(PTelsiz[playerid] && PDep[playerid] >= 0)
    {
        SendRadio(playerid, text);
        return 0;
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    new n[MAX_PLAYER_NAME], s[200];
    GetPlayerName(playerid, n, sizeof n);

    if(!strcmp(cmdtext, "/departman", true)) { ShowDepList(playerid); return 1; }

    if(!strcmp(cmdtext, "/tablet", true, 7) && (cmdtext[7] == 0 || cmdtext[7] == ' '))
    {
        if(IsAdm(playerid))
        {
            if(cmdtext[7] == ' ' && cmdtext[8] >= '0' && cmdtext[8] < '0' + MAX_DEP)
            {
                AdminAsDep(playerid, cmdtext[8] - '0');
                OpenTablet(playerid);
                return 1;
            }
            if(PDep[playerid] < 0) { ShowAdmDepList(playerid); return 1; }
        }
        OpenTablet(playerid);
        return 1;
    }

    if(!strcmp(cmdtext, "/mekanyer", true, 9))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        if(cmdtext[9] != ' ' || cmdtext[10] < '0' || cmdtext[10] >= '0' + MAX_DEP)
        {
            SendClientMessage(playerid, C_INF, "Kullanim: /mekanyer [dep 0-8]  (0 Belediye,1 FBI,2 Polis,3 EMS,4 Medya,5 Los Namados,6 Liberty,7 Inferno,8 Vipers)");
            SendClientMessage(playerid, C_INF, "Binanin kapisinin onunde, binadan uzaga (sokaga) bakarak dur ve yaz. Giris noktasi bulundugun yer olur.");
            return 1;
        }
        new li = FindLocByDep(cmdtext[10] - '0');
        if(li < 0) { SendClientMessage(playerid, C_ERR, "Bu departmanin mekani yok."); return 1; }
        if(GetPlayerInterior(playerid) != 0) { SendClientMessage(playerid, C_ERR, "Dis mekanda (interior 0) olmalisin."); return 1; }
        new Float:px, Float:py, Float:pz, Float:pa, q2[160];
        GetPlayerPos(playerid, px, py, pz);
        GetPlayerFacingAngle(playerid, pa);
        pz -= 0.5;
        MoveLocOut(li, px, py, pz, pa);
        format(q2, sizeof q2, "INSERT OR REPLACE INTO mekanyer (dep,x,y,z,a) VALUES (%d,%.4f,%.4f,%.4f,%.2f)", cmdtext[10] - '0', px, py, pz, pa);
        DbExec(q2);
        format(s, sizeof s, "%s giris noktasi buraya tasindi ve kaydedildi.", LocName[li]);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }

    if(!strcmp(cmdtext, "/kiyafetyer", true, 11))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        if(cmdtext[11] != ' ' || cmdtext[12] < '0' || cmdtext[12] >= '0' + MAX_DEP)
        {
            SendClientMessage(playerid, C_INF, "Kullanim: /kiyafetyer [dep 0-8]  (mekanin ICINDE, kiyafet yeri olacak noktada dur)");
            return 1;
        }
        new li = FindLocByDep(cmdtext[12] - '0');
        if(li < 0) { SendClientMessage(playerid, C_ERR, "Bu departmanin mekani yok."); return 1; }
        if(GetPlayerVirtualWorld(playerid) != li + 1) { SendClientMessage(playerid, C_ERR, "O mekanin ICINDE olmalisin."); return 1; }
        new Float:cx, Float:cy, Float:cz, q3[160];
        GetPlayerPos(playerid, cx, cy, cz);
        cz -= 0.5;
        LocClo[li][0] = cx; LocClo[li][1] = cy; LocClo[li][2] = cz;
        MakeCloSpot(li);
        format(q3, sizeof q3, "INSERT OR REPLACE INTO kiyafetyer (dep,x,y,z) VALUES (%d,%.4f,%.4f,%.4f)", cmdtext[12] - '0', cx, cy, cz);
        DbExec(q3);
        format(s, sizeof s, "%s kiyafet yeri buraya tasindi ve kaydedildi.", LocName[li]);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }

    if(!strcmp(cmdtext, "/mekangit", true, 9))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        if(cmdtext[9] != ' ' || cmdtext[10] < '0' || cmdtext[10] >= '0' + MAX_DEP)
        {
            SendClientMessage(playerid, C_INF, "Kullanim: /mekangit [dep 0-8]  (0 Belediye,1 FBI,2 Polis,3 EMS,4 Medya,5 Los Namados,6 Liberty,7 Inferno,8 Vipers)");
            return 1;
        }
        new li = FindLocByDep(cmdtext[10] - '0');
        if(li < 0) { SendClientMessage(playerid, C_ERR, "Bu departmanin mekani yok."); return 1; }
        SetPlayerInterior(playerid, 0);
        SetPlayerVirtualWorld(playerid, 0);
        SetPlayerPos(playerid, LocOut[li][0], LocOut[li][1], LocOut[li][2] + 1.0);
        SendClientMessage(playerid, C_OK, "Mekan girisine isinlandin.");
        return 1;
    }

    if(!strcmp(cmdtext, "/yardim", true) || !strcmp(cmdtext, "/komutlar", true))
    {
        new h[2800];
        h[0] = 0;
        strcat(h, "{FFFFFF}/departman  {AAAAAA}- Departman menusunu acar (herkes)\n", sizeof h);
        strcat(h, "{FFFFFF}/yardim  {AAAAAA}- Bu menuyu acar\n", sizeof h);
        strcat(h, "{FFFFFF}/tablet  {AAAAAA}- Yetkili oldugun departmanin tabletini acar\n", sizeof h);
        strcat(h, "{FFFFFF}/gorev  {AAAAAA}- Gorev durumunu degistirir\n", sizeof h);
        strcat(h, "{FFFFFF}/d /t /r /telsiz [mesaj]  {AAAAAA}- Telsizle konus (departman/cete)\n", sizeof h);
        strcat(h, "{FFFFFF}/telsiz  {AAAAAA}- Telsiz modunu ac/kapat (acikken yazdigin telsize gider)\n", sizeof h);
        strcat(h, "{FFFFFF}/ayril  {AAAAAA}- Departmandan/cetedan ayrilir (tabletten de olur)\n", sizeof h);
        strcat(h, "{FFFFFF}/seviye  {AAAAAA}- Seviyeni gosterir     {FFFFFF}/siralama  {AAAAAA}- Seviye siralamasi\n", sizeof h);
        strcat(h, "{FFFFFF}/mekanlar  {AAAAAA}- Departman mekanlari, haritada isaretler\n", sizeof h);
        strcat(h, "{FFFFFF}/haberler  {AAAAAA}- Medya haber akisi\n", sizeof h);
        strcat(h, "{FFFFFF}/ihbar [mesaj]  {AAAAAA}- Polise ihbar\n", sizeof h);
        strcat(h, "{FFFFFF}/acil [mesaj]  {AAAAAA}- Hastaneye acil cagri\n", sizeof h);
        strcat(h, "{FFFFFF}/sikayet [mesaj]  {AAAAAA}- Belediyeye sikayet", sizeof h);
        if(IsAdm(playerid))
        {
            strcat(h, "\n\n{FF8800}ADMIN:\n", sizeof h);
            strcat(h, "{FFFFFF}/tablet [0-8]  {AAAAAA}- Istedigin departmanin tabletini tam yetkiyle acar\n", sizeof h);
            strcat(h, "{FFFFFF}/mekangit [0-8]  {AAAAAA}- Departman mekanina isinlanir\n", sizeof h);
            strcat(h, "{FFFFFF}/mekanyer [0-8]  {AAAAAA}- Mekan girisini bulundugun yere tasir\n", sizeof h);
            strcat(h, "{FFFFFF}/seviyever [id] [seviye]  {AAAAAA}- Oyuncunun seviyesini ayarlar\n", sizeof h);
            strcat(h, "{FFFFFF}/kiyafetyer [0-8]  {AAAAAA}- Ic mekandaki kiyafet yerini bulundugun yere tasir\n", sizeof h);
            strcat(h, "{FFFFFF}/departmanver [id] [dep] [rutbe]  {AAAAAA}- Oyuncuyu departmana alir", sizeof h);
        }
        ShowPlayerDialog(playerid, D_NONE, DIALOG_STYLE_MSGBOX, "Yardim - Komutlar", h, "Kapat", "");
        return 1;
    }

    if(!strcmp(cmdtext, "/gorev", true))
    {
        if(PDep[playerid] < 0) { SendClientMessage(playerid, C_ERR, "Departman personeli degilsin."); return 1; }
        PDuty[playerid] = !PDuty[playerid];
        format(s, sizeof s, "Gorev durumu: %s", PDuty[playerid] ? "AKTIF" : "PASIF");
        SendClientMessage(playerid, PDuty[playerid] ? C_OK : C_INF, s);
        ShowPanel(playerid);
        return 1;
    }

    // ---------------- TELSIZ ----------------
    // /d, /t, /r, /telsiz  [mesaj]  -> kendi kurumunun telsizine konus (baskasi duymaz)
    // /telsiz  (mesajsiz)           -> telsiz modunu ac/kapat (acikken yazdigin telsize gider)
    {
        new tl = 0;
        if(!strcmp(cmdtext, "/telsiz", true, 7) && (cmdtext[7] == 0 || cmdtext[7] == ' ')) tl = 7;
        else if(!strcmp(cmdtext, "/d", true, 2) && (cmdtext[2] == 0 || cmdtext[2] == ' ')) tl = 2;
        else if(!strcmp(cmdtext, "/t", true, 2) && (cmdtext[2] == 0 || cmdtext[2] == ' ')) tl = 2;
        else if(!strcmp(cmdtext, "/r", true, 2) && (cmdtext[2] == 0 || cmdtext[2] == ' ')) tl = 2;
        if(tl)
        {
            if(PDep[playerid] < 0) { SendClientMessage(playerid, C_ERR, "Telsizin yok. Bir departman/cete uyesi olmalisin."); return 1; }
            new ti = tl;
            while(cmdtext[ti] == ' ') ti++;
            if(!cmdtext[ti]) { ToggleTelsiz(playerid); return 1; }
            SendRadio(playerid, cmdtext[ti]);
            return 1;
        }
    }

    if(!strcmp(cmdtext, "/ayril", true))
    {
        if(PDep[playerid] < 0) { SendClientMessage(playerid, C_ERR, "Herhangi bir departman/cetede degilsin."); return 1; }
        ShowAyril(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/seviye", true)) { ShowSeviye(playerid); return 1; }
    if(!strcmp(cmdtext, "/siralama", true)) { ShowSiralama(playerid, false); return 1; }
    if(!strcmp(cmdtext, "/seviyever", true, 10))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        new sidx = 10, sa[16], sb[16];
        Token(cmdtext, sidx, sa);
        Token(cmdtext, sidx, sb);
        if(!sa[0] || !sb[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /seviyever [id] [seviye 1-999]"); return 1; }
        new st = strval(sa), sl = strval(sb);
        if(st < 0 || st >= MAX_PLAYERS || !IsPlayerConnected(st)) { SendClientMessage(playerid, C_ERR, "Oyuncu bulunamadi."); return 1; }
        if(sl < 1 || sl > 999) { SendClientMessage(playerid, C_ERR, "Seviye 1 ile 999 arasinda olmali."); return 1; }
        PLevel[st] = sl;
        PXP[st] = 0;
        SaveLevel(st);
        ShowPanel(st);
        format(s, sizeof s, "Seviyen %d olarak ayarlandi.", sl);
        SendClientMessage(st, C_OK, s);
        SendClientMessage(playerid, C_OK, "Seviye ayarlandi.");
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
        if(!cmdtext[7]) { SendClientMessage(playerid, C_INF, "Kullanim: /ihbar [mesaj]"); return 1; }
        InsertRec(2, 1, n, n, cmdtext[7]);
        format(s, sizeof s, "[IHBAR] %s (ID:%d): %s", n, playerid, cmdtext[7]);
        SendDep(2, 0x3498DBFF, s);
        SendClientMessage(playerid, C_OK, "Ihbarin polise iletildi.");
        return 1;
    }

    if(!strcmp(cmdtext, "/acil ", true, 6))
    {
        if(!cmdtext[6]) { SendClientMessage(playerid, C_INF, "Kullanim: /acil [mesaj]"); return 1; }
        InsertRec(3, 3, n, n, cmdtext[6]);
        format(s, sizeof s, "[ACIL CAGRI] %s (ID:%d): %s", n, playerid, cmdtext[6]);
        SendDep(3, 0xE74C3CFF, s);
        SendClientMessage(playerid, C_OK, "Acil cagrin hastaneye iletildi.");
        return 1;
    }

    if(!strcmp(cmdtext, "/sikayet ", true, 9))
    {
        if(!cmdtext[9]) { SendClientMessage(playerid, C_INF, "Kullanim: /sikayet [mesaj]"); return 1; }
        InsertRec(0, 2, n, n, cmdtext[9]);
        SendClientMessage(playerid, C_OK, "Sikayetin belediyeye iletildi.");
        return 1;
    }

    if(!strcmp(cmdtext, "/departmanver", true, 13))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        new idx = 13, a[16], b[16], c[16];
        Token(cmdtext, idx, a); Token(cmdtext, idx, b); Token(cmdtext, idx, c);
        if(!a[0] || !b[0] || !c[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /departmanver [id] [dep 0-8] [rutbe 1-10]  (0-4 departman, 5 Los Namados,6 Liberty,7 Inferno,8 Vipers)"); return 1; }
        new t = strval(a), d = strval(b), r = strval(c);
        if(t < 0 || t >= MAX_PLAYERS || !IsPlayerConnected(t)) { SendClientMessage(playerid, C_ERR, "Oyuncu bulunamadi."); return 1; }
        if(d < 0 || d >= MAX_DEP || r < 1 || r > RankCnt[d]) { SendClientMessage(playerid, C_ERR, "Gecersiz departman/rutbe."); return 1; }
        SetMember(t, d, r);
        SendClientMessage(playerid, C_OK, "Islem tamamlandi.");
        return 1;
    }
    return 0;
}

// ==================================================================
//  DIALOG CEVAPLARI
// ==================================================================
stock DepDialogResp(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid < D_NONE || dialogid > D_ROLENEW) return 0;

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
        if(PDep[playerid] == dd) ShowAyril(playerid);
        else TryJoin(playerid, dd, true);
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

    if(dialogid == D_ADMDEP)
    {
        if(!response || !IsAdm(playerid) || listitem < 0 || listitem >= MAX_DEP) return 1;
        AdminAsDep(playerid, listitem);
        OpenTablet(playerid);
        return 1;
    }

    if(dialogid == D_KATIL)
    {
        new dd = PTmp[playerid];
        if(!response || dd < 0 || dd >= MAX_DEP) return 1;
        TryJoin(playerid, dd, true);
        return 1;
    }

    if(dialogid == D_KIYAFET)
    {
        new dd = PTmp[playerid];
        if(!response || dd < 0 || dd >= MAX_DEP) return 1;
        if(PDep[playerid] != dd && !IsAdm(playerid))
        {
            SendClientMessage(playerid, C_ERR, "Bu kiyafeti sadece personel giyebilir.");
            return 1;
        }
        if(listitem == 0)
        {
            if(GetPlayerSkin(playerid) != DepSkin[dd]) PSkinOld[playerid] = GetPlayerSkin(playerid);
            SetPlayerSkin(playerid, DepSkin[dd]);
            format(s, sizeof s, "%s kiyafetini giydin.", DepName[dd]);
            SendClientMessage(playerid, DepColor[dd], s);
        }
        else
        {
            if(PSkinOld[playerid] >= 0)
            {
                SetPlayerSkin(playerid, PSkinOld[playerid]);
                SendClientMessage(playerid, C_INF, "Eski kiyafetine dondun.");
            }
            else SendClientMessage(playerid, C_INF, "Kayitli eski kiyafetin yok.");
        }
        return 1;
    }

    // Bundan sonrasi sadece personel icin
    if(d < 0) return 1;

    // ---------------- Ana tablet ----------------
    if(dialogid == D_TAB)
    {
        if(!response || listitem < 0 || listitem >= MAX_TABITEM) return 1;
        new act = PTab[playerid][listitem];
        #if DEBUG_DEP
        format(s, sizeof s, "[DEBUG] act=%d izin=%d", act, ActAllowed(playerid, act));
        SendClientMessage(playerid, 0xFFFF00FF, s);
        #endif
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
                if(HasPerm(playerid, P_BUTCE))
                {
                    format(s, sizeof s, "Butce Bakiyesi: $%d\nPara Yatir\nPara Cek (Sadece Lider)", b);
                    ShowPlayerDialog(playerid, D_BUTCE, DIALOG_STYLE_LIST, "Departman Butcesi", s, "Sec", "Geri");
                }
                else
                {
                    format(s, sizeof s, "Departman butcesi: {44FF44}$%d", b);
                    ShowBack(playerid, DIALOG_STYLE_MSGBOX, "Departman Butcesi", s);
                }
            }
            case ACT_YONET: ShowYonet(playerid);
            case ACT_PROFIL: ShowProfil(playerid);
            case ACT_ALIM: ShowAlim(playerid);
            case ACT_AYRIL: ShowAyril(playerid);
            case ACT_SIRALAMA: ShowSiralama(playerid, true);
            case ACT_ROLLER: ShowRoller(playerid);
            case ACT_TELSIZ:
            {
                ToggleTelsiz(playerid);
                OpenTablet(playerid);
            }
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
        if(!HasPerm(playerid, P_DUYURU) || !buf[0]) return 1;
        new t[24];
        TimeStr(t);
        format(q, sizeof q, "INSERT INTO duyurular (dep,yazar,metin,tarih) VALUES (%d,'%s','%s','%s')", d, n, buf, t);
        DbExec(q);
        format(s, sizeof s, "[%s DUYURU] %s: %s", DepName[d], n, buf);
        SendDep(d, DepColor[d], s);
        SendClientMessage(playerid, C_OK, "Duyuru paylasildi.");
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
        if(!HasPerm(playerid, P_BUTCE)) return 1;
        if(listitem == 1)
        {
            PAct[playerid] = 1;
            ShowPlayerDialog(playerid, D_BUTCEMIKTAR, DIALOG_STYLE_INPUT, "Para Yatir", "Yatirilacak miktar:", "Onayla", "Geri");
        }
        else if(listitem == 2)
        {
            if(!HasPerm(playerid, P_YONETICI)) { SendClientMessage(playerid, C_ERR, "Butceden para cekmek sadece lider/yonetici yetkisindedir."); return 1; }
            PAct[playerid] = 2;
            ShowPlayerDialog(playerid, D_BUTCEMIKTAR, DIALOG_STYLE_INPUT, "Para Cek", "Cekilecek miktar:", "Onayla", "Geri");
        }
        else OpenTablet(playerid);
        return 1;
    }
    if(dialogid == D_BUTCEMIKTAR)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!HasPerm(playerid, P_BUTCE)) return 1;
        new amt = strval(buf);
        if(amt <= 0 || amt > 10000000) { SendClientMessage(playerid, C_ERR, "Gecersiz miktar."); return 1; }
        if(PAct[playerid] == 1)
        {
            if(GetPlayerMoney(playerid) < amt) { SendClientMessage(playerid, C_ERR, "Yeterli paran yok."); return 1; }
            GivePlayerMoney(playerid, -amt);
            format(q, sizeof q, "UPDATE butce SET miktar=miktar+%d WHERE dep=%d", amt, d);
            DbExec(q);
            format(s, sizeof s, "Butceye $%d yatirdin.", amt);
            SendClientMessage(playerid, C_OK, s);
        }
        else
        {
            if(!HasPerm(playerid, P_YONETICI)) return 1;
            format(q, sizeof q, "SELECT miktar FROM butce WHERE dep=%d", d);
            if(DbGetInt(q) < amt) { SendClientMessage(playerid, C_ERR, "Butcede yeterli para yok."); return 1; }
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
        if(listitem < 0 || listitem >= MAX_LISTITEM) return 1;
        new code = PList[playerid][listitem];
        if(code == 1)
        {
            if(!HasPerm(playerid, P_RUTBE | P_CIKAR | P_MAAS)) return 1;
            ShowPlist(playerid);
        }
        else if(code == 2)
        {
            if(!HasPerm(playerid, P_ISEAL)) return 1;
            PAct[playerid] = 1;
            ShowPlayerDialog(playerid, D_YONETID, DIALOG_STYLE_INPUT, "Ise Al", "Ise alinacak oyuncunun ID'si veya ismi (cevrimici olmali):", "Ise Al", "Geri");
        }
        else if(code == 3)
        {
            if(!HasPerm(playerid, P_ISEAL | P_CIKAR | P_RUTBE | P_MAAS)) return 1;
            PAct[playerid] = 7;
            ShowPlayerDialog(playerid, D_YONETID, DIALOG_STYLE_INPUT, "Personel Gecmisi", "Oyuncu ID'si veya tam ismi:", "Goster", "Geri");
        }
        return 1;
    }
    if(dialogid == D_YONETID)
    {
        if(!response) { ShowYonet(playerid); return 1; }
        if(!buf[0]) return 1;
        if(PAct[playerid] == 7)
        {
            if(!HasPerm(playerid, P_ISEAL | P_CIKAR | P_RUTBE | P_MAAS)) return 1;
            new nm[32], t2 = ResolveTarget(inputtext);
            if(t2 != INVALID_PLAYER_ID) GetPlayerName(t2, nm, sizeof nm);
            else format(nm, sizeof nm, "%s", buf);
            ShowHistory(playerid, nm);
            return 1;
        }
        if(!HasPerm(playerid, P_ISEAL)) return 1;
        new t = ResolveTarget(inputtext);
        if(t == INVALID_PLAYER_ID) { SendClientMessage(playerid, C_ERR, "Oyuncu bulunamadi."); return 1; }
        if(PDep[t] >= 0)
        {
            format(s, sizeof s, "Oyuncu zaten %s icinde. Bir kisi ayni anda en fazla 1 departman/cetede olabilir.", DepName[PDep[t]]);
            SendLong(playerid, C_ERR, s);
            return 1;
        }
        SetMember(t, d, 1);
        SendClientMessage(playerid, C_OK, "Oyuncu ise alindi.");
        return 1;
    }
    if(dialogid == D_PLIST)
    {
        if(!response) { ShowYonet(playerid); return 1; }
        if(!HasPerm(playerid, P_RUTBE | P_CIKAR | P_MAAS)) return 1;
        new nm[32];
        if(!GetMemberByIndex(d, listitem, nm, sizeof nm)) return 1;
        format(PTmpStr[playerid], 128, "%s", nm);
        ShowPact(playerid);
        return 1;
    }
    if(dialogid == D_PACT)
    {
        if(!response) { ShowPlist(playerid); return 1; }
        if(listitem < 0 || listitem >= MAX_LISTITEM) return 1;
        new code = PList[playerid][listitem], nm[32], tr;
        format(nm, sizeof nm, "%s", PTmpStr[playerid]);
        tr = GetMemberRank(nm, d);
        if(tr < 1 || code == 0) return 1;
        if(code == 6) { ShowHistory(playerid, nm); return 1; }
        if(!CanManage(playerid, tr, nm)) { SendClientMessage(playerid, C_ERR, "Bu kisiye islem yapamazsin."); return 1; }
        switch(code)
        {
            case 1:
            {
                if(!HasPerm(playerid, P_RUTBE)) return 1;
                new mx = MaxAssignable(playerid), rl[400];
                if(mx > RankCnt[d]) mx = RankCnt[d];
                if(mx < 1) { SendClientMessage(playerid, C_ERR, "Verebilecegin rutbe yok."); return 1; }
                rl[0] = 0;
                for(new r = 0; r < mx; r++)
                {
                    format(s, sizeof s, "%d) %s\n", r + 1, RankName[d][r]);
                    strcat(rl, s, sizeof rl);
                }
                ShowPlayerDialog(playerid, D_YONETRANK, DIALOG_STYLE_LIST, "Rutbe Sec", rl, "Ver", "Iptal");
            }
            case 2:
            {
                if(!HasPerm(playerid, P_RUTBE)) return 1;
                if(tr + 1 > MaxAssignable(playerid) || tr + 1 > RankCnt[d]) { SendClientMessage(playerid, C_ERR, "Bu kisiyi daha fazla terfi ettiremezsin."); return 1; }
                SetRankByName(nm, d, tr + 1);
                SendClientMessage(playerid, C_OK, "Terfi verildi.");
                ShowPlist(playerid);
            }
            case 3:
            {
                if(!HasPerm(playerid, P_RUTBE)) return 1;
                if(tr <= 1) { SendClientMessage(playerid, C_ERR, "Zaten en alt rutbede."); return 1; }
                SetRankByName(nm, d, tr - 1);
                SendClientMessage(playerid, C_OK, "Rutbe dusuruldu.");
                ShowPlist(playerid);
            }
            case 4:
            {
                if(!HasPerm(playerid, P_MAAS)) return 1;
                ShowPlayerDialog(playerid, D_YONETMAAS, DIALOG_STYLE_INPUT, "Maas Belirle", "Yeni maas miktari (0 - 50000):", "Kaydet", "Iptal");
            }
            case 5:
            {
                if(!HasPerm(playerid, P_CIKAR)) return 1;
                RemoveByName(nm, d);
                SendClientMessage(playerid, C_OK, "Personel isten cikarildi.");
                ShowPlist(playerid);
            }
        }
        return 1;
    }
    if(dialogid == D_YONETRANK)
    {
        if(!response) { ShowPact(playerid); return 1; }
        if(!HasPerm(playerid, P_RUTBE)) return 1;
        new nm[32], tr, nr = listitem + 1;
        format(nm, sizeof nm, "%s", PTmpStr[playerid]);
        tr = GetMemberRank(nm, d);
        if(tr < 1 || !CanManage(playerid, tr, nm) || nr > MaxAssignable(playerid) || nr > RankCnt[d]) return 1;
        SetRankByName(nm, d, nr);
        SendClientMessage(playerid, C_OK, "Rutbe verildi.");
        ShowPlist(playerid);
        return 1;
    }
    if(dialogid == D_YONETMAAS)
    {
        if(!response) { ShowPact(playerid); return 1; }
        if(!HasPerm(playerid, P_MAAS)) return 1;
        new nm[32], tr, m = strval(buf);
        format(nm, sizeof nm, "%s", PTmpStr[playerid]);
        tr = GetMemberRank(nm, d);
        if(tr < 1 || !CanManage(playerid, tr, nm)) return 1;
        if(m < 0 || m > 50000) { SendClientMessage(playerid, C_ERR, "Maas 0 ile 50000 arasinda olmali."); return 1; }
        SetMaasByName(nm, d, m);
        SendClientMessage(playerid, C_OK, "Maas guncellendi.");
        ShowPlist(playerid);
        return 1;
    }

    // ---------------- Alim yonetimi ----------------
    if(dialogid == D_ALIM)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!HasPerm(playerid, P_ALIM)) return 1;
        if(listitem == 0)
        {
            SetAlim(d, DepAlim[d] ? 0 : 1);
            ShowAlim(playerid);
        }
        else ShowPlayerDialog(playerid, D_ALIMLVL, DIALOG_STYLE_INPUT, "Minimum Seviye", "Katilmak icin gereken minimum seviye (1 - 999):", "Kaydet", "Geri");
        return 1;
    }
    if(dialogid == D_ALIMLVL)
    {
        if(!response) { ShowAlim(playerid); return 1; }
        if(!HasPerm(playerid, P_ALIM)) return 1;
        new m = strval(buf);
        if(m < 1 || m > 999) { SendClientMessage(playerid, C_ERR, "Seviye 1 ile 999 arasinda olmali."); return 1; }
        DepMinLvl[d] = m;
        format(q, sizeof q, "UPDATE depayar SET minlvl=%d WHERE dep=%d", m, d);
        DbExec(q);
        format(s, sizeof s, "Minimum seviye %d olarak ayarlandi.", m);
        SendClientMessage(playerid, C_OK, s);
        ShowAlim(playerid);
        return 1;
    }

    // ---------------- Ayrilma ----------------
    if(dialogid == D_AYRIL)
    {
        if(response) LeaveDept(playerid);
        else OpenTablet(playerid);
        return 1;
    }

    // ---------------- Rutbe & yetki ayarlari (sadece admin) ----------------
    if(dialogid == D_ROLES)
    {
        if(!response) { OpenTablet(playerid); return 1; }
        if(!IsAdm(playerid)) return 1;
        if(listitem >= 0 && listitem < RankCnt[d])
        {
            PTmp[playerid] = listitem;
            ShowRoleAct(playerid);
        }
        else if(listitem == RankCnt[d])
        {
            if(RankCnt[d] >= MAX_RANK) { SendClientMessage(playerid, C_ERR, "En fazla 10 rutbe olabilir."); ShowRoller(playerid); return 1; }
            ShowPlayerDialog(playerid, D_ROLENEW, DIALOG_STYLE_INPUT, "Yeni Rutbe", "Yeni rutbenin adi (en alt rutbe olarak eklenir):", "Ekle", "Geri");
        }
        return 1;
    }
    if(dialogid == D_ROLEACT)
    {
        if(!response) { ShowRoller(playerid); return 1; }
        if(!IsAdm(playerid)) return 1;
        new ri = PTmp[playerid];
        if(ri < 0 || ri >= RankCnt[d]) return 1;
        if(listitem == 0) ShowPlayerDialog(playerid, D_ROLENAME, DIALOG_STYLE_INPUT, "Rutbe Ismi", "Yeni isim (en fazla 20 karakter):", "Kaydet", "Geri");
        else if(listitem == 1) ShowRolePerm(playerid);
        else
        {
            if(RankDelete(d, ri)) SendClientMessage(playerid, C_OK, "Rutbe silindi, uyeler bir alt rutbeye alindi.");
            else SendClientMessage(playerid, C_ERR, "Bu rutbe silinemez (lider rutbesi silinemez, en az 2 rutbe kalmali).");
            ShowRoller(playerid);
        }
        return 1;
    }
    if(dialogid == D_ROLENAME)
    {
        if(!response) { ShowRoleAct(playerid); return 1; }
        if(!IsAdm(playerid)) return 1;
        new ri = PTmp[playerid];
        if(ri < 0 || ri >= RankCnt[d]) return 1;
        if(!buf[0] || strlen(buf) > 20) { SendClientMessage(playerid, C_ERR, "Isim 1-20 karakter olmali."); return 1; }
        format(RankName[d][ri], 24, "%s", buf);
        SaveRoles(d);
        SendClientMessage(playerid, C_OK, "Rutbe ismi guncellendi.");
        ShowRoleAct(playerid);
        return 1;
    }
    if(dialogid == D_ROLEPERM)
    {
        if(!response) { ShowRoleAct(playerid); return 1; }
        if(!IsAdm(playerid)) return 1;
        new ri = PTmp[playerid];
        if(ri < 0 || ri >= RankCnt[d] || listitem < 0 || listitem >= PERM_COUNT) return 1;
        RankPerm[d][ri] ^= (1 << listitem);
        SaveRoles(d);
        ShowRolePerm(playerid);
        return 1;
    }
    if(dialogid == D_ROLENEW)
    {
        if(!response) { ShowRoller(playerid); return 1; }
        if(!IsAdm(playerid)) return 1;
        if(!buf[0] || strlen(buf) > 20) { SendClientMessage(playerid, C_ERR, "Isim 1-20 karakter olmali."); return 1; }
        if(RankAddBottom(d, buf)) SendClientMessage(playerid, C_OK, "Yeni rutbe eklendi (en alt rutbe). Yetkilerini 'Yetkileri Duzenle'den ayarla.");
        else SendClientMessage(playerid, C_ERR, "Rutbe eklenemedi (en fazla 10).");
        ShowRoller(playerid);
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
        if(!pl[0] || !sh[0]) { SendClientMessage(playerid, C_ERR, "Format: PLAKA, SAHIP ADI, MODEL"); return 1; }
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
        if(!HasPerm(playerid, P_MEDYA) || d != 4 || listitem < 0 || listitem >= MAX_LISTITEM) return 1;
        new id = PList[playerid][listitem];
        if(id <= 0) return 1;
        PTmp[playerid] = id;
        HaberDetay(id, s, sizeof s);
        ShowPlayerDialog(playerid, D_HONAYACT, DIALOG_STYLE_MSGBOX, "Haber Onayi", s, "Onayla", "Reddet");
        return 1;
    }
    if(dialogid == D_HONAYACT)
    {
        if(!HasPerm(playerid, P_MEDYA) || d != 4) return 1;
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
        if(HasPerm(playerid, P_MEDYA))
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
        if(!HasPerm(playerid, P_MEDYA) || d != 4) return 1;
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
        if(!HasPerm(playerid, P_MEDYA) || d != 4 || !buf[0]) return 1;
        format(q, sizeof q, "UPDATE haberler SET baslik='%s' WHERE id=%d", buf, PTmp[playerid]);
        DbExec(q);
        SendClientMessage(playerid, C_OK, "Baslik guncellendi.");
        return 1;
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid < D_NONE || dialogid > D_ROLENEW) return 0;
    gInDlg[playerid] = true;
    #if DEBUG_DEP
    new dbg[96];
    format(dbg, sizeof dbg, "[DEBUG] dialog=%d resp=%d item=%d dep=%d", dialogid, response, listitem, PDep[playerid]);
    SendClientMessage(playerid, 0xFFFF00FF, dbg);
    #endif
    new r = DepDialogResp(playerid, dialogid, response, listitem, inputtext);
    gInDlg[playerid] = false;
    return r;
}
