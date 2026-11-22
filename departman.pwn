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

    KOMUTLAR (tablet/dialog yok, hepsi chat komutu - detay icin oyunda /yardim):
      GENEL : /departman [no] /katil [no] /ayril /profil /gorev /seviye /siralama /mekanlar [no] /haberler
              /telsiz /d /t /r [mesaj] /ihbar /acil /sikayet /kiyafet [giy|eski]
      PERSONEL: /personel /rutbeler /duyurular /duyuru /dmesaj /butce /butceyatir /butcecek /kayit /kayitekle
              /sorgu /plaka /ruhsat /gecmis /iseal /cikar /rutbever /terfi /dusur /maasayarla /alim /alimseviye
      MEDYA : /haberyaz /yayingecmisi /haberbekleyen /haberbak /haberonay /haberred /haberkaldir /haberbaslik
      ADMIN : /admindep [0-8] /rutbeisim /rutbeyetki /rutbeekle /rutbesil /mekangit /mekanyer /kiyafetyer
              /seviyever /departmanver
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

// Yetkiler (Discord rolleri gibi). Admin komutla her rutbe icin acilip kapatilir.
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
new PList[MAX_PLAYERS][MAX_LISTITEM];
new PTeleTick[MAX_PLAYERS];
new PSkinOld[MAX_PLAYERS];
new PLevel[MAX_PLAYERS], PXP[MAX_PLAYERS];

// Rutbeler ve yetkiler (admin komutla degistirilir, DB'de saklanir)
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
    format(s, sizeof s, "~w~Rutbe: ~y~%s~n~~w~Seviye: ~y~%d~n~~w~Gorev: %s~n~~w~Cevrimici: ~y~%d~n~~w~Maas: ~g~$%d~n~~n~~w~/yardim ~b~| ~w~/departman",
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
    format(q, sizeof q, "%s departmanina %s olarak katildin. Komutlar icin /yardim yaz.", DepName[dep], RankName[dep][rank - 1]);
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
//  HABER YARDIMCILARI
// ==================================================================
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

// Giristeki KATIL noktasi
stock OpenJoin(playerid, li)
{
    new d = LocDep[li], s[200];
    if(!TryJoin(playerid, d, false)) return 1;
    format(s, sizeof s, "%s icin katilim noktasi. Baslangic rutben: %s, min. seviye: %d. Katilmak icin: /katil %d", DepName[d], RankName[d][0], DepMinLvl[d], d);
    SendLong(playerid, DepColor[d], s);
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
    SendClientMessage(playerid, DepColor[d], "Kiyafet dolabi: /kiyafet giy   veya   /kiyafet eski");
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
//  SLASH KOMUTLARI  (tablet/dialog sistemi kaldirildi, her sey chat komutu)
// ==================================================================
stock DNeedDep(playerid)
{
    if(PDep[playerid] < 0)
    {
        SendClientMessage(playerid, C_ERR, "Departman/cete uyesi degilsin. /departman ile listeye bak, /katil [no] ile katil.");
        return 0;
    }
    return 1;
}

stock DNeedPerm(playerid, mask)
{
    if(!DNeedDep(playerid)) return 0;
    if(!HasPerm(playerid, mask))
    {
        SendClientMessage(playerid, C_ERR, "Bu islem icin rutbe yetkin yok.");
        return 0;
    }
    return 1;
}

stock DRest(src[], ix, dest[], size)
{
    while(src[ix] == ' ') ix++;
    strmid(dest, src, ix, strlen(src), size);
}

stock ResolveName(txt[], dest[], size)
{
    new t = ResolveTarget(txt);
    if(t != INVALID_PLAYER_ID) GetPlayerName(t, dest, size);
    else format(dest, size, "%s", txt);
}

// "ilk kisim, ikinci kisim" -> iki parcaya boler. Virgul yoksa 0 doner.
stock SplitComma(src[], a[], asize, b[], bsize)
{
    new c = strfind(src, ",");
    a[0] = 0; b[0] = 0;
    if(c < 1) return 0;
    strmid(a, src, 0, c, asize);
    strmid(b, src, c + 1, strlen(src), bsize);
    while(a[0] && a[strlen(a) - 1] == ' ') a[strlen(a) - 1] = 0;
    while(b[0] == ' ') strdel(b, 0, 1);
    if(!a[0] || !b[0]) return 0;
    return 1;
}

stock CmdDepList(playerid)
{
    new s[220], mud[32];
    SendClientMessage(playerid, C_INF, "===== DEPARTMANLAR / CETELER =====");
    for(new d = 0; d < MAX_DEP; d++)
    {
        GetMudur(d, mud, sizeof mud);
        format(s, sizeof s, "%s[%d] %s {FFFFFF}| Personel: %d | Yonetici: %s | Alim: %s", DepEmbed[d], d, DepName[d], CountMembers(d), mud, DepAlim[d] ? "{44FF44}Acik" : "{FF4444}Kapali");
        SendLong(playerid, DepColor[d], s);
    }
    SendClientMessage(playerid, C_INF, "Detay: /departman [no]    Katilmak icin: /katil [no]");
    return 1;
}

stock CmdDepInfo(playerid, d)
{
    new s[300], l[100], mud[32], rl[300], ml[300];
    if(d < 0 || d >= MAX_DEP)
    {
        SendClientMessage(playerid, C_ERR, "Gecersiz no. 0-8 arasi gir. Liste icin /departman");
        return 1;
    }
    GetMudur(d, mud, sizeof mud);
    format(s, sizeof s, "===== %s =====", DepName[d]);
    SendClientMessage(playerid, DepColor[d], s);
    SendLong(playerid, 0xFFFFFFFF, DepDesc[d]);
    format(s, sizeof s, "Yonetici: %s | Personel: %d (cevrimici %d) | Alim: %s | Min. seviye: %d", mud, CountMembers(d), CountOnline(d), DepAlim[d] ? "ACIK" : "KAPALI", DepMinLvl[d]);
    SendLong(playerid, 0xFFFFFFFF, s);
    rl[0] = 0;
    for(new r = 0; r < RankCnt[d]; r++)
    {
        format(l, sizeof l, "%d) %s   ", r + 1, RankName[d][r]);
        strcat(rl, l, sizeof rl);
    }
    format(s, sizeof s, "Rutbeler: %s", rl);
    SendLong(playerid, 0xAAAAAAFF, s);
    ml[0] = 0;
    for(new i = 0; i < LocCount; i++)
    {
        if(LocDep[i] != d) continue;
        format(l, sizeof l, "%s (%s)   ", LocName[i], LocPub[i] ? "Herkese Acik" : "Sadece Personel");
        strcat(ml, l, sizeof ml);
    }
    format(s, sizeof s, "Mekanlar: %s", ml);
    SendLong(playerid, 0xAAAAAAFF, s);
    if(PDep[playerid] == d) SendClientMessage(playerid, C_INF, "Bu kurumdasin. Ayrilmak icin: /ayril");
    else
    {
        format(s, sizeof s, "Katilmak icin: /katil %d", d);
        SendClientMessage(playerid, C_INF, s);
    }
    return 1;
}

stock CmdProfil(playerid)
{
    if(!DNeedDep(playerid)) return 1;
    new d = PDep[playerid], n[MAX_PLAYER_NAME], s[220], pl[300], l[60], rk = PRank[playerid], c = 0;
    if(rk < 1) rk = 1;
    if(rk > RankCnt[d]) rk = RankCnt[d];
    GetPlayerName(playerid, n, sizeof n);
    SendClientMessage(playerid, C_INF, "===== PROFILIM =====");
    format(s, sizeof s, "%s | Kurum: %s | Rutbe: %s (%d/%d) | Maas: $%d | Gorev: %s", n, DepName[d], RankName[d][rk - 1], rk, RankCnt[d], PMaas[playerid], PDuty[playerid] ? "Aktif" : "Pasif");
    SendLong(playerid, DepColor[d], s);
    if(IsAdm(playerid)) format(s, sizeof s, "Seviye: %d (ADMIN)", MAX_ADMIN_LEVEL);
    else format(s, sizeof s, "Seviye: %d (XP: %d/%d dk)", PLevel[playerid], PXP[playerid], LevelNeed(PLevel[playerid]));
    SendClientMessage(playerid, 0xFFFFFFFF, s);
    pl[0] = 0;
    for(new p = 0; p < PERM_COUNT; p++)
    {
        if(HasPerm(playerid, (1 << p)))
        {
            format(l, sizeof l, "%s, ", PermName[p]);
            strcat(pl, l, sizeof pl);
            c++;
        }
    }
    if(!c) format(pl, sizeof pl, "Yok");
    format(s, sizeof s, "Yetkilerin: %s", pl);
    SendLong(playerid, 0xAAAAAAFF, s);
    return 1;
}

stock CmdSeviye(playerid)
{
    new s[200];
    if(IsAdm(playerid)) format(s, sizeof s, "Seviyen: %d (ADMIN)", MAX_ADMIN_LEVEL);
    else format(s, sizeof s, "Seviyen: %d | XP: %d / %d dakika. Oyunda kaldikca XP kazanirsin. /siralama ile en yuksekleri gor.", PLevel[playerid], PXP[playerid], LevelNeed(PLevel[playerid]));
    SendLong(playerid, 0xFFCC00FF, s);
    return 1;
}

stock CmdSiralama(playerid)
{
    new s[140], a[32], b[12], e[12], DBResult:r, k = 0;
    r = db_query(gDB, "SELECT s.isim, CASE WHEN s.admin=1 THEN 1000 ELSE s.seviye END AS lv, s.xp, u.dep FROM seviye s LEFT JOIN uyeler u ON u.isim=s.isim ORDER BY lv DESC, s.xp DESC LIMIT 15");
    SendClientMessage(playerid, C_INF, "===== SEVIYE SIRALAMASI (Top 15) =====");
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
                format(s, sizeof s, "%d) %s - Seviye %s - %s", k, a, b, (dn >= 0 && dn < MAX_DEP) ? DepName[dn] : "-");
                SendClientMessage(playerid, 0xFFFFFFFF, s);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k) SendClientMessage(playerid, C_INF, "Henuz kayit yok.");
    return 1;
}

stock CmdPersonel(playerid)
{
    if(!DNeedDep(playerid)) return 1;
    new d = PDep[playerid], q[160], l[140], a[32], b[16], DBResult:r;
    format(l, sizeof l, "===== %s PERSONEL LISTESI =====", DepName[d]);
    SendClientMessage(playerid, DepColor[d], l);
    format(q, sizeof q, "SELECT isim,rutbe FROM uyeler WHERE dep=%d ORDER BY rutbe DESC, isim ASC LIMIT 30", d);
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
                format(l, sizeof l, "%s - %s - %s", a, RankName[d][rk - 1], IsNameOnline(a) ? "Cevrimici" : "Cevrimdisi");
                SendClientMessage(playerid, IsNameOnline(a) ? C_OK : 0xAAAAAAFF, l);
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    return 1;
}

stock CmdDuyurular(playerid)
{
    if(!DNeedDep(playerid)) return 1;
    new d = PDep[playerid], q[160], s[260], a[32], b[130], c[24], DBResult:r, k = 0;
    SendClientMessage(playerid, C_INF, "===== DEPARTMAN DUYURULARI =====");
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
                format(s, sizeof s, "[%s] %s: %s", c, a, b);
                SendLong(playerid, 0xFFFFFFFF, s);
                k++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k) SendClientMessage(playerid, C_INF, "Henuz duyuru yok.");
    return 1;
}

stock CmdKayitTurleri(playerid)
{
    new d = PDep[playerid], s[100];
    SendClientMessage(playerid, C_INF, "===== KAYIT TURLERI =====");
    for(new t = 0; t < RecCount[d]; t++)
    {
        format(s, sizeof s, "%d) %s", t + 1, RecType[d][t]);
        SendClientMessage(playerid, 0xFFFFFFFF, s);
    }
    SendClientMessage(playerid, C_INF, "Kayitlari gor: /kayit [no]     Yeni kayit: /kayitekle [no] hedef, aciklama");
    return 1;
}

stock CmdKayitlar(playerid, tur)
{
    new d = PDep[playerid], q[200], s[330], a[64], b[32], c[160], e[24], DBResult:r, k = 0;
    format(s, sizeof s, "===== %s - Son Kayitlar =====", RecType[d][tur]);
    SendClientMessage(playerid, C_INF, s);
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
                format(s, sizeof s, "[%s] %s (%s): %s", e, a, b, c);
                SendLong(playerid, 0xFFFFFFFF, s);
                k++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k) SendClientMessage(playerid, C_INF, "Bu turde kayit yok.");
    return 1;
}

stock CmdGecmis(playerid, name[])
{
    new d = PDep[playerid], nm[32], DBResult:r, a[100], b[24], l[200], q[200], k = 0;
    format(nm, sizeof nm, "%s", name);
    Esc(nm);
    format(l, sizeof l, "===== Personel Gecmisi: %s =====", nm);
    SendClientMessage(playerid, C_INF, l);
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
                format(l, sizeof l, "[%s] %s", b, a);
                SendClientMessage(playerid, 0xFFFFFFFF, l);
                k++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k) SendClientMessage(playerid, C_INF, "Kayit bulunamadi.");
    return 1;
}

stock CmdHaberFeed(playerid)
{
    new q[260], s[330], a[70], b[140], c[32], e[24], f[4], DBResult:r, k = 0;
    if(PDep[playerid] == 4) format(q, sizeof q, "SELECT baslik,metin,yazar,tarih,herkes FROM haberler WHERE durum=1 ORDER BY id DESC LIMIT 10");
    else format(q, sizeof q, "SELECT baslik,metin,yazar,tarih,herkes FROM haberler WHERE durum=1 AND herkes=1 ORDER BY id DESC LIMIT 10");
    SendClientMessage(playerid, 0x9B59B6FF, "===== HABER AKISI (NEWS) =====");
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
                format(s, sizeof s, "[%s] %s%s - %s (%s)", e, a, (strval(f) == 0) ? " [Departman]" : "", b, c);
                SendLong(playerid, 0xFFFFFFFF, s);
                k++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k) SendClientMessage(playerid, C_INF, "Yayinlanmis haber yok.");
    return 1;
}

// Haber listesi. mode 0 = onay bekleyenler, 1 = yayin gecmisi
stock CmdHaberListe(playerid, mode)
{
    new DBResult:r, a[8], b[70], c[32], e[24], s[200], k = 0;
    if(mode == 0)
    {
        SendClientMessage(playerid, 0x9B59B6FF, "===== ONAY BEKLEYEN HABERLER =====");
        r = db_query(gDB, "SELECT id,baslik,yazar,tarih FROM haberler WHERE durum=0 ORDER BY id ASC LIMIT 20");
    }
    else
    {
        SendClientMessage(playerid, 0x9B59B6FF, "===== YAYIN GECMISI =====");
        r = db_query(gDB, "SELECT id,baslik,durum,tarih FROM haberler ORDER BY id DESC LIMIT 20");
    }
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
                if(mode == 0) format(s, sizeof s, "#%s - %s (%s) [%s]", a, b, c, e);
                else format(s, sizeof s, "#%s - %s [%s] %s", a, b, (strval(c) == 0) ? "Bekliyor" : ((strval(c) == 1) ? "Yayinda" : "Kaldirildi"), e);
                SendLong(playerid, 0xFFFFFFFF, s);
                k++;
            }
            while(db_next_row(r));
        }
        db_free_result(r);
    }
    if(!k) SendClientMessage(playerid, C_INF, "Haber yok.");
    return 1;
}

stock CmdHaberBak(playerid, id)
{
    new q[200], a[70], b[140], c[32], e[24], g[8], DBResult:r, s[330], found = 0;
    format(q, sizeof q, "SELECT baslik,metin,yazar,tarih,durum FROM haberler WHERE id=%d", id);
    r = db_query(gDB, q);
    if(r)
    {
        if(db_num_rows(r))
        {
            db_get_field(r, 0, a, sizeof a);
            db_get_field(r, 1, b, sizeof b);
            db_get_field(r, 2, c, sizeof c);
            db_get_field(r, 3, e, sizeof e);
            db_get_field(r, 4, g, sizeof g);
            format(s, sizeof s, "#%d %s - %s | Yazar: %s | %s | Durum: %s", id, a, b, c, e, (strval(g) == 0) ? "Onay Bekliyor" : ((strval(g) == 1) ? "Yayinda" : "Kaldirildi"));
            SendLong(playerid, 0xFFFFFFFF, s);
            found = 1;
        }
        db_free_result(r);
    }
    if(!found) SendClientMessage(playerid, C_ERR, "Haber bulunamadi.");
    return 1;
}

stock DYardim(playerid)
{
    SendClientMessage(playerid, C_INF, "===== DEPARTMAN KOMUTLARI =====");
    SendClientMessage(playerid, 0xFFFFFFFF, "/departman [no]  /katil [no]  /ayril  /profil  /gorev  /seviye  /siralama  /mekanlar [no]  /haberler");
    SendClientMessage(playerid, 0xFFFFFFFF, "/telsiz (ac/kapat)  /d /t /r [mesaj] telsiz  /ihbar [mesaj]  /acil [mesaj]  /sikayet [mesaj]  /kiyafet [giy/eski]");
    if(PDep[playerid] < 0) return 1;
    SendClientMessage(playerid, 0xFFCC00FF, "--- Personel ---");
    SendClientMessage(playerid, 0xFFFFFFFF, "/personel  /rutbeler  /duyurular  /dmesaj [mesaj]  /butce  /kayit [no]  /kayitekle [no] hedef, aciklama");
    new d = PDep[playerid];
    if(d <= 3) SendClientMessage(playerid, 0xFFFFFFFF, "/sorgu [id/isim] (vatandas sorgula)");
    if(d == 1 || d == 2) SendClientMessage(playerid, 0xFFFFFFFF, "/plaka [plaka] (arac sorgula)");
    if(d == 0) SendClientMessage(playerid, 0xFFFFFFFF, "/ruhsat plaka, sahip adi, model");
    if(d == 4) SendClientMessage(playerid, 0xFFFFFFFF, "/haberyaz [tur 0-4] baslik, metin  (0 Haber, 1 Dep.Ici, 2 Son Dakika, 3 Canli, 4 Etkinlik)  /yayingecmisi");
    if(HasPerm(playerid, P_DUYURU)) SendClientMessage(playerid, 0xFFFFFFFF, "/duyuru [metin]");
    if(HasPerm(playerid, P_BUTCE)) SendClientMessage(playerid, 0xFFFFFFFF, "/butceyatir [miktar]  /butcecek [miktar] (lider)");
    if(HasPerm(playerid, P_ALIM)) SendClientMessage(playerid, 0xFFFFFFFF, "/alim (ac/kapat)  /alimseviye [1-999]");
    if(HasPerm(playerid, P_ISEAL)) SendClientMessage(playerid, 0xFFFFFFFF, "/iseal [id/isim]");
    if(HasPerm(playerid, P_CIKAR)) SendClientMessage(playerid, 0xFFFFFFFF, "/cikar [isim]");
    if(HasPerm(playerid, P_RUTBE)) SendClientMessage(playerid, 0xFFFFFFFF, "/rutbever [isim] [rutbe no]  /terfi [isim]  /dusur [isim]");
    if(HasPerm(playerid, P_MAAS)) SendClientMessage(playerid, 0xFFFFFFFF, "/maasayarla [isim] [miktar]");
    if(HasPerm(playerid, P_ISEAL | P_CIKAR | P_RUTBE | P_MAAS)) SendClientMessage(playerid, 0xFFFFFFFF, "/gecmis [isim]");
    if(HasPerm(playerid, P_MEDYA) && d == 4) SendClientMessage(playerid, 0xFFFFFFFF, "/haberbekleyen  /haberbak [id]  /haberonay [id]  /haberred [id]  /haberkaldir [id]  /haberbaslik [id] [yeni baslik]");
    if(IsAdm(playerid))
    {
        SendClientMessage(playerid, 0xFF8800FF, "--- ADMIN ---");
        SendClientMessage(playerid, 0xFFFFFFFF, "/admindep [0-8]  /mekangit [0-8]  /mekanyer [0-8]  /kiyafetyer [0-8]  /seviyever [id] [seviye]  /departmanver [id] [dep] [rutbe]");
        SendClientMessage(playerid, 0xFFFFFFFF, "/rutbeler  /rutbeisim [no] [isim]  /rutbeyetki [no] [yetki no]  /rutbeekle [isim]  /rutbesil [no]   (once /admindep ile kurum sec)");
    }
    return 1;
}

// ---------------- GENEL KOMUTLAR ----------------
stock DK_Genel(playerid, cmd[], a1[], a2[], r0[], r1[], r2[])
{
    new s[200];
    if(!strcmp(cmd, "/departman", true))
    {
        if(a1[0]) return CmdDepInfo(playerid, strval(a1));
        return CmdDepList(playerid);
    }
    if(!strcmp(cmd, "/yardim", true) || !strcmp(cmd, "/komutlar", true) || !strcmp(cmd, "/tablet", true) || !strcmp(cmd, "/panel", true))
        return DYardim(playerid);
    if(!strcmp(cmd, "/katil", true))
    {
        if(!a1[0] || a1[0] < '0' || a1[0] > '9') { SendClientMessage(playerid, C_INF, "Kullanim: /katil [no]   (liste icin /departman)"); return 1; }
        TryJoin(playerid, strval(a1), true);
        return 1;
    }
    if(!strcmp(cmd, "/ayril", true))
    {
        if(PDep[playerid] < 0) { SendClientMessage(playerid, C_ERR, "Herhangi bir departman/cetede degilsin."); return 1; }
        if(!strcmp(a1, "onay", true)) { LeaveDept(playerid); return 1; }
        format(s, sizeof s, "%s kurumundan ayrilmak istedigine emin misin? Rutben ve maasin silinir. Onaylamak icin: /ayril onay", DepName[PDep[playerid]]);
        SendLong(playerid, C_ERR, s);
        return 1;
    }
    if(!strcmp(cmd, "/profil", true)) return CmdProfil(playerid);
    if(!strcmp(cmd, "/seviye", true)) return CmdSeviye(playerid);
    if(!strcmp(cmd, "/siralama", true)) return CmdSiralama(playerid);
    if(!strcmp(cmd, "/haberler", true)) return CmdHaberFeed(playerid);
    if(!strcmp(cmd, "/mekanlar", true))
    {
        if(a1[0])
        {
            new li = strval(a1) - 1;
            if(li < 0 || li >= LocCount) { SendClientMessage(playerid, C_ERR, "Gecersiz mekan no. Liste icin /mekanlar"); return 1; }
            SetPlayerCheckpoint(playerid, LocOut[li][0], LocOut[li][1], LocOut[li][2], 4.0);
            format(s, sizeof s, "%s haritada isaretlendi.", LocName[li]);
            SendClientMessage(playerid, C_INF, s);
            return 1;
        }
        SendClientMessage(playerid, C_INF, "===== MEKANLAR (haritada isaretlemek icin /mekanlar [no]) =====");
        for(new i = 0; i < LocCount; i++)
        {
            format(s, sizeof s, "%d) %s - %s", i + 1, DepName[LocDep[i]], LocName[i]);
            SendClientMessage(playerid, DepColor[LocDep[i]], s);
        }
        return 1;
    }
    if(!strcmp(cmd, "/kiyafet", true))
    {
        new d = -1;
        for(new li = 0; li < LocCount; li++)
        {
            if(GetPlayerVirtualWorld(playerid) == li + 1 && IsPlayerInRangeOfPoint(playerid, 5.0, LocClo[li][0], LocClo[li][1], LocClo[li][2])) { d = LocDep[li]; break; }
        }
        if(d < 0) { SendClientMessage(playerid, C_ERR, "Kiyafet dolabinin yaninda degilsin (ic mekandaki KIYAFET noktasina git)."); return 1; }
        if(PDep[playerid] != d && !IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu kiyafeti sadece personel giyebilir."); return 1; }
        if(!strcmp(a1, "giy", true))
        {
            if(GetPlayerSkin(playerid) != DepSkin[d]) PSkinOld[playerid] = GetPlayerSkin(playerid);
            SetPlayerSkin(playerid, DepSkin[d]);
            format(s, sizeof s, "%s kiyafetini giydin.", DepName[d]);
            SendClientMessage(playerid, DepColor[d], s);
        }
        else if(!strcmp(a1, "eski", true))
        {
            if(PSkinOld[playerid] >= 0) { SetPlayerSkin(playerid, PSkinOld[playerid]); SendClientMessage(playerid, C_INF, "Eski kiyafetine dondun."); }
            else SendClientMessage(playerid, C_INF, "Kayitli eski kiyafetin yok.");
        }
        else SendClientMessage(playerid, C_INF, "Kullanim: /kiyafet giy   veya   /kiyafet eski");
        return 1;
    }
    return 0;
}

// ---------------- PERSONEL KOMUTLARI ----------------
stock DK_Personel(playerid, cmd[], a1[], a2[], r0[], r1[], r2[])
{
    new d = PDep[playerid], n[MAX_PLAYER_NAME], s[400], q[400], nm[32];
    GetPlayerName(playerid, n, sizeof n);

    if(!strcmp(cmd, "/personel", true)) return CmdPersonel(playerid);
    if(!strcmp(cmd, "/duyurular", true)) return CmdDuyurular(playerid);
    if(!strcmp(cmd, "/rutbeler", true))
    {
        if(!DNeedDep(playerid)) return 1;
        format(s, sizeof s, "===== %s RUTBELERI =====", DepName[d]);
        SendClientMessage(playerid, DepColor[d], s);
        for(new r = 0; r < RankCnt[d]; r++)
        {
            format(s, sizeof s, "%d) %s%s", r + 1, RankName[d][r], (RankPerm[d][r] & P_YONETICI) ? " (YONETICI)" : "");
            SendClientMessage(playerid, 0xFFFFFFFF, s);
        }
        return 1;
    }
    if(!strcmp(cmd, "/duyuru", true))
    {
        if(!DNeedPerm(playerid, P_DUYURU)) return 1;
        if(!r0[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /duyuru [metin]"); return 1; }
        new t[24], m[130];
        format(m, sizeof m, "%s", r0);
        Esc(m);
        TimeStr(t);
        format(q, sizeof q, "INSERT INTO duyurular (dep,yazar,metin,tarih) VALUES (%d,'%s','%s','%s')", d, n, m, t);
        DbExec(q);
        format(s, sizeof s, "[%s DUYURU] %s: %s", DepName[d], n, m);
        SendDep(d, DepColor[d], s);
        SendClientMessage(playerid, C_OK, "Duyuru paylasildi.");
        return 1;
    }
    if(!strcmp(cmd, "/dmesaj", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(!r0[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /dmesaj [mesaj]"); return 1; }
        new rk = PRank[playerid];
        if(rk < 1) rk = 1;
        if(rk > RankCnt[d]) rk = RankCnt[d];
        format(s, sizeof s, "[%s MESAJ] %s %s: %s", DepName[d], RankName[d][rk - 1], n, r0);
        SendDep(d, DepColor[d], s);
        return 1;
    }

    // ---- Butce ----
    if(!strcmp(cmd, "/butce", true))
    {
        if(!DNeedDep(playerid)) return 1;
        format(q, sizeof q, "SELECT miktar FROM butce WHERE dep=%d", d);
        format(s, sizeof s, "Departman butcesi: $%d", DbGetInt(q));
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }
    if(!strcmp(cmd, "/butceyatir", true))
    {
        if(!DNeedPerm(playerid, P_BUTCE)) return 1;
        new amt = strval(a1);
        if(amt <= 0 || amt > 10000000) { SendClientMessage(playerid, C_INF, "Kullanim: /butceyatir [miktar]"); return 1; }
        if(GetPlayerMoney(playerid) < amt) { SendClientMessage(playerid, C_ERR, "Yeterli paran yok."); return 1; }
        GivePlayerMoney(playerid, -amt);
        format(q, sizeof q, "UPDATE butce SET miktar=miktar+%d WHERE dep=%d", amt, d);
        DbExec(q);
        format(s, sizeof s, "Butceye $%d yatirdin.", amt);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }
    if(!strcmp(cmd, "/butcecek", true))
    {
        if(!DNeedPerm(playerid, P_BUTCE)) return 1;
        if(!HasPerm(playerid, P_YONETICI)) { SendClientMessage(playerid, C_ERR, "Butceden para cekmek sadece lider/yonetici yetkisindedir."); return 1; }
        new amt = strval(a1);
        if(amt <= 0 || amt > 10000000) { SendClientMessage(playerid, C_INF, "Kullanim: /butcecek [miktar]"); return 1; }
        format(q, sizeof q, "SELECT miktar FROM butce WHERE dep=%d", d);
        if(DbGetInt(q) < amt) { SendClientMessage(playerid, C_ERR, "Butcede yeterli para yok."); return 1; }
        format(q, sizeof q, "UPDATE butce SET miktar=miktar-%d WHERE dep=%d", amt, d);
        DbExec(q);
        GivePlayerMoney(playerid, amt);
        format(s, sizeof s, "Butceden $%d cektin.", amt);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }

    // ---- Kayitlar ----
    if(!strcmp(cmd, "/kayit", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(!a1[0]) return CmdKayitTurleri(playerid);
        new t = strval(a1) - 1;
        if(t < 0 || t >= RecCount[d]) { SendClientMessage(playerid, C_ERR, "Gecersiz kayit turu. Liste icin /kayit"); return 1; }
        return CmdKayitlar(playerid, t);
    }
    if(!strcmp(cmd, "/kayitekle", true))
    {
        if(!DNeedDep(playerid)) return 1;
        new t = strval(a1) - 1, h[64], m[130];
        if(!a1[0] || t < 0 || t >= RecCount[d] || !SplitComma(r1, h, sizeof h, m, sizeof m))
        {
            SendClientMessage(playerid, C_INF, "Kullanim: /kayitekle [tur no] hedef, aciklama     (turler icin /kayit)");
            return 1;
        }
        InsertRec(d, t, h, n, m);
        SendClientMessage(playerid, C_OK, "Kayit olusturuldu.");
        return 1;
    }

    // ---- Sorgular ----
    if(!strcmp(cmd, "/sorgu", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(d > 3) { SendClientMessage(playerid, C_ERR, "Bu komutu kullanamazsin."); return 1; }
        if(!a1[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /sorgu [oyuncu id / isim]"); return 1; }
        new t = ResolveTarget(a1), l[300], DBResult:r, a[28], b[160], e[24], c[8], cnt = 0;
        if(t != INVALID_PLAYER_ID)
        {
            GetPlayerName(t, nm, sizeof nm);
            format(l, sizeof l, "%s (ID:%d) | Skor: %d | Ping: %d | Departman: %s", nm, t, GetPlayerScore(t), GetPlayerPing(t), (PDep[t] >= 0) ? DepName[PDep[t]] : "Yok (Vatandas)");
        }
        else
        {
            format(nm, sizeof nm, "%s", a1);
            format(l, sizeof l, "%s (cevrimdisi / kayitli isim)", nm);
        }
        SendClientMessage(playerid, C_INF, "===== VATANDAS SORGU =====");
        SendLong(playerid, 0xFFCC00FF, l);
        Esc(nm);
        if(d == 1) format(q, sizeof q, "SELECT dep,tur,metin,tarih FROM kayitlar WHERE hedef='%s' ORDER BY id DESC LIMIT 8", nm);
        else format(q, sizeof q, "SELECT dep,tur,metin,tarih FROM kayitlar WHERE hedef='%s' AND dep=%d ORDER BY id DESC LIMIT 8", nm, d);
        r = db_query(gDB, q);
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
                    format(l, sizeof l, "[%s] %s: %s", e, a, b);
                    SendLong(playerid, 0xFFFFFFFF, l);
                    cnt++;
                }
                while(db_next_row(r));
            }
            db_free_result(r);
        }
        if(!cnt) SendClientMessage(playerid, 0xAAAAAAFF, "Kayit bulunamadi.");
        return 1;
    }
    if(!strcmp(cmd, "/plaka", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(d != 1 && d != 2) { SendClientMessage(playerid, C_ERR, "Bu komutu kullanamazsin."); return 1; }
        if(!a1[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /plaka [plaka]"); return 1; }
        new pl[32], a[32], b[32], c[32], l[300], e[160], DBResult:r, found = 0, cnt = 0;
        format(pl, sizeof pl, "%s", a1);
        Esc(pl);
        format(q, sizeof q, "SELECT plaka,sahip,model FROM araclar WHERE UPPER(plaka)=UPPER('%s')", pl);
        r = db_query(gDB, q);
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
        SendClientMessage(playerid, C_INF, "===== PLAKA SORGU =====");
        if(found) format(l, sizeof l, "Plaka: %s | Sahip: %s | Model: %s", a, b, c);
        else format(l, sizeof l, "Bu plaka ruhsat kayitlarinda yok.");
        SendClientMessage(playerid, 0xFFCC00FF, l);
        format(q, sizeof q, "SELECT metin,tarih FROM kayitlar WHERE UPPER(hedef)=UPPER('%s') ORDER BY id DESC LIMIT 6", pl);
        r = db_query(gDB, q);
        if(r)
        {
            if(db_num_rows(r))
            {
                do
                {
                    db_get_field(r, 0, e, sizeof e);
                    db_get_field(r, 1, a, sizeof a);
                    format(l, sizeof l, "[%s] %s", a, e);
                    SendLong(playerid, 0xFFFFFFFF, l);
                    cnt++;
                }
                while(db_next_row(r));
            }
            db_free_result(r);
        }
        if(!cnt) SendClientMessage(playerid, 0xAAAAAAFF, "Arac raporu yok.");
        return 1;
    }
    if(!strcmp(cmd, "/ruhsat", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(d != 0) { SendClientMessage(playerid, C_ERR, "Bu komutu sadece Belediye kullanabilir."); return 1; }
        new pl[20], sh[32], md[32], t[24];
        GetPart(r0, 0, pl, sizeof pl);
        GetPart(r0, 1, sh, sizeof sh);
        GetPart(r0, 2, md, sizeof md);
        if(!pl[0] || !sh[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /ruhsat PLAKA, SAHIP ADI, MODEL"); return 1; }
        Esc(pl); Esc(sh); Esc(md);
        TimeStr(t);
        format(q, sizeof q, "INSERT OR REPLACE INTO araclar (plaka,sahip,model,tarih) VALUES ('%s','%s','%s','%s')", pl, sh, md, t);
        DbExec(q);
        format(s, sizeof s, "Arac ruhsati islendi: %s - %s", pl, sh);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }

    // ---- Yonetim ----
    if(!strcmp(cmd, "/gecmis", true))
    {
        if(!DNeedPerm(playerid, P_ISEAL | P_CIKAR | P_RUTBE | P_MAAS)) return 1;
        if(!a1[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /gecmis [isim / id]"); return 1; }
        ResolveName(a1, nm, sizeof nm);
        return CmdGecmis(playerid, nm);
    }
    if(!strcmp(cmd, "/iseal", true))
    {
        if(!DNeedPerm(playerid, P_ISEAL)) return 1;
        if(!a1[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /iseal [oyuncu id / isim]  (oyuncu cevrimici olmali)"); return 1; }
        new t = ResolveTarget(a1);
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
    if(!strcmp(cmd, "/cikar", true) || !strcmp(cmd, "/rutbever", true) || !strcmp(cmd, "/terfi", true) || !strcmp(cmd, "/dusur", true) || !strcmp(cmd, "/maasayarla", true))
    {
        if(!DNeedDep(playerid)) return 1;
        new mask = P_CIKAR;
        if(!strcmp(cmd, "/maasayarla", true)) mask = P_MAAS;
        else if(strcmp(cmd, "/cikar", true)) mask = P_RUTBE;
        if(!HasPerm(playerid, mask)) { SendClientMessage(playerid, C_ERR, "Bu islem icin rutbe yetkin yok."); return 1; }
        if(!a1[0])
        {
            if(!strcmp(cmd, "/rutbever", true)) SendClientMessage(playerid, C_INF, "Kullanim: /rutbever [isim / id] [rutbe no]   (rutbeler icin /rutbeler)");
            else if(!strcmp(cmd, "/maasayarla", true)) SendClientMessage(playerid, C_INF, "Kullanim: /maasayarla [isim / id] [0-50000]");
            else { format(s, sizeof s, "Kullanim: %s [isim / id]", cmd); SendClientMessage(playerid, C_INF, s); }
            return 1;
        }
        ResolveName(a1, nm, sizeof nm);
        new tr = GetMemberRank(nm, d);
        if(tr < 1) { SendClientMessage(playerid, C_ERR, "Bu isimde personel bulunamadi."); return 1; }
        if(tr > RankCnt[d]) tr = RankCnt[d];
        if(!CanManage(playerid, tr, nm)) { SendClientMessage(playerid, C_ERR, "Bu kisiye islem yapamazsin (senden ust/esit rutbe veya kendin)."); return 1; }
        if(!strcmp(cmd, "/cikar", true))
        {
            RemoveByName(nm, d);
            SendClientMessage(playerid, C_OK, "Personel isten cikarildi.");
        }
        else if(!strcmp(cmd, "/terfi", true))
        {
            if(tr + 1 > MaxAssignable(playerid) || tr + 1 > RankCnt[d]) { SendClientMessage(playerid, C_ERR, "Bu kisiyi daha fazla terfi ettiremezsin."); return 1; }
            SetRankByName(nm, d, tr + 1);
            SendClientMessage(playerid, C_OK, "Terfi verildi.");
        }
        else if(!strcmp(cmd, "/dusur", true))
        {
            if(tr <= 1) { SendClientMessage(playerid, C_ERR, "Zaten en alt rutbede."); return 1; }
            SetRankByName(nm, d, tr - 1);
            SendClientMessage(playerid, C_OK, "Rutbe dusuruldu.");
        }
        else if(!strcmp(cmd, "/rutbever", true))
        {
            new nr = strval(a2), mx = MaxAssignable(playerid);
            if(mx > RankCnt[d]) mx = RankCnt[d];
            if(!a2[0] || nr < 1 || nr > mx) { format(s, sizeof s, "Verebilecegin rutbe no: 1 - %d  (liste icin /rutbeler)", mx); SendClientMessage(playerid, C_ERR, s); return 1; }
            SetRankByName(nm, d, nr);
            SendClientMessage(playerid, C_OK, "Rutbe verildi.");
        }
        else
        {
            new m = strval(a2);
            if(!a2[0] || m < 0 || m > 50000) { SendClientMessage(playerid, C_ERR, "Maas 0 ile 50000 arasinda olmali."); return 1; }
            SetMaasByName(nm, d, m);
            SendClientMessage(playerid, C_OK, "Maas guncellendi.");
        }
        return 1;
    }

    // ---- Alim ----
    if(!strcmp(cmd, "/alim", true))
    {
        if(!DNeedPerm(playerid, P_ALIM)) return 1;
        SetAlim(d, DepAlim[d] ? 0 : 1);
        format(s, sizeof s, "Alimlar: %s | Minimum seviye: %d  (degistirmek icin /alimseviye [1-999])", DepAlim[d] ? "ACIK" : "KAPALI", DepMinLvl[d]);
        SendClientMessage(playerid, C_INF, s);
        return 1;
    }
    if(!strcmp(cmd, "/alimseviye", true))
    {
        if(!DNeedPerm(playerid, P_ALIM)) return 1;
        new m = strval(a1);
        if(!a1[0] || m < 1 || m > 999) { SendClientMessage(playerid, C_INF, "Kullanim: /alimseviye [1-999]"); return 1; }
        DepMinLvl[d] = m;
        format(q, sizeof q, "UPDATE depayar SET minlvl=%d WHERE dep=%d", m, d);
        DbExec(q);
        format(s, sizeof s, "Minimum seviye %d olarak ayarlandi.", m);
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }
    return 0;
}

// ---------------- MEDYA KOMUTLARI ----------------
stock DK_Medya(playerid, cmd[], a1[], a2[], r0[], r1[], r2[])
{
    new d = PDep[playerid], q[300], s[200];
    if(!strcmp(cmd, "/haberyaz", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(d != 4) { SendClientMessage(playerid, C_ERR, "Bu komutu sadece Medya (NEWS) kullanabilir."); return 1; }
        new tur = strval(a1), bs[128], mt[128];
        if(!a1[0] || tur < 0 || tur > 4 || !SplitComma(r1, bs, sizeof bs, mt, sizeof mt))
        {
            SendClientMessage(playerid, C_INF, "Kullanim: /haberyaz [tur] baslik, metin");
            SendClientMessage(playerid, C_INF, "Tur: 0 Haber (herkese acik) | 1 Haber (sadece departman) | 2 Son Dakika | 3 Canli Yayin | 4 Etkinlik");
            return 1;
        }
        format(PTmpStr[playerid], 128, "%s", bs);
        format(PTmpStr2[playerid], 128, "%s", mt);
        PTmp[playerid] = tur;
        SaveHaber(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/yayingecmisi", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(d != 4) { SendClientMessage(playerid, C_ERR, "Bu komutu sadece Medya (NEWS) kullanabilir."); return 1; }
        return CmdHaberListe(playerid, 1);
    }
    if(!strcmp(cmd, "/haberbekleyen", true) || !strcmp(cmd, "/haberbak", true) || !strcmp(cmd, "/haberonay", true) || !strcmp(cmd, "/haberred", true) || !strcmp(cmd, "/haberkaldir", true) || !strcmp(cmd, "/haberbaslik", true))
    {
        if(!DNeedDep(playerid)) return 1;
        if(d != 4) { SendClientMessage(playerid, C_ERR, "Bu komutu sadece Medya (NEWS) kullanabilir."); return 1; }
        if(!HasPerm(playerid, P_MEDYA)) { SendClientMessage(playerid, C_ERR, "Bu islem icin rutbe yetkin yok."); return 1; }
        if(!strcmp(cmd, "/haberbekleyen", true)) return CmdHaberListe(playerid, 0);
        new id = strval(a1);
        if(!a1[0] || id <= 0) { format(s, sizeof s, "Kullanim: %s [haber id]   (idleri /haberbekleyen veya /yayingecmisi gosterir)", cmd); SendClientMessage(playerid, C_INF, s); return 1; }
        if(!strcmp(cmd, "/haberbak", true)) return CmdHaberBak(playerid, id);
        if(!strcmp(cmd, "/haberonay", true))
        {
            new DBResult:r, bs[70], tf[8];
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
            return 1;
        }
        if(!strcmp(cmd, "/haberred", true))
        {
            format(q, sizeof q, "UPDATE haberler SET durum=2 WHERE id=%d AND durum=0", id);
            DbExec(q);
            SendClientMessage(playerid, C_INF, "Haber reddedildi.");
            return 1;
        }
        if(!strcmp(cmd, "/haberkaldir", true))
        {
            format(q, sizeof q, "UPDATE haberler SET durum=2 WHERE id=%d", id);
            DbExec(q);
            SendClientMessage(playerid, C_OK, "Haber kaldirildi.");
            return 1;
        }
        // /haberbaslik [id] [yeni baslik]
        new nb[100];
        if(!r1[0]) { SendClientMessage(playerid, C_INF, "Kullanim: /haberbaslik [id] [yeni baslik]"); return 1; }
        format(nb, sizeof nb, "%s", r1);
        Esc(nb);
        format(q, sizeof q, "UPDATE haberler SET baslik='%s' WHERE id=%d", nb, id);
        DbExec(q);
        SendClientMessage(playerid, C_OK, "Baslik guncellendi.");
        return 1;
    }
    return 0;
}

// ---------------- ADMIN RUTBE / YETKI KOMUTLARI ----------------
stock DK_Admin(playerid, cmd[], a1[], a2[], r0[], r1[], r2[])
{
    new d = PDep[playerid], s[200];
    if(!strcmp(cmd, "/admindep", true))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        if(!a1[0] || a1[0] < '0' || a1[0] >= '0' + MAX_DEP)
        {
            SendClientMessage(playerid, C_INF, "Kullanim: /admindep [0-8]   (0 Belediye,1 FBI,2 Polis,3 EMS,4 Medya,5 Los Namados,6 Liberty,7 Inferno,8 Vipers)");
            SendClientMessage(playerid, C_INF, "Secilen kurumda tam yetkiyle calisirsin. Cikmak icin: /ayril onay");
            return 1;
        }
        AdminAsDep(playerid, a1[0] - '0');
        return 1;
    }
    if(!strcmp(cmd, "/rutbeisim", true) || !strcmp(cmd, "/rutbeyetki", true) || !strcmp(cmd, "/rutbeekle", true) || !strcmp(cmd, "/rutbesil", true))
    {
        if(!IsAdm(playerid)) { SendClientMessage(playerid, C_ERR, "Bu komut sadece adminler icindir."); return 1; }
        if(d < 0) { SendClientMessage(playerid, C_ERR, "Once /admindep [0-8] ile bir kurum sec."); return 1; }
        new ri = strval(a1) - 1;
        if(!strcmp(cmd, "/rutbeekle", true))
        {
            if(!r0[0] || strlen(r0) > 20) { SendClientMessage(playerid, C_INF, "Kullanim: /rutbeekle [rutbe adi]  (en fazla 20 karakter, en alt rutbe olarak eklenir)"); return 1; }
            new nm2[24];
            format(nm2, sizeof nm2, "%s", r0);
            Esc(nm2);
            if(RankAddBottom(d, nm2)) SendClientMessage(playerid, C_OK, "Yeni rutbe eklendi (en alt rutbe). Yetkisi icin /rutbeyetki");
            else SendClientMessage(playerid, C_ERR, "Rutbe eklenemedi (en fazla 10).");
            return 1;
        }
        if(!a1[0] || ri < 0 || ri >= RankCnt[d])
        {
            format(s, sizeof s, "Rutbe no gecersiz (1-%d). Liste icin /rutbeler", RankCnt[d]);
            SendClientMessage(playerid, C_ERR, s);
            return 1;
        }
        if(!strcmp(cmd, "/rutbesil", true))
        {
            if(RankDelete(d, ri)) SendClientMessage(playerid, C_OK, "Rutbe silindi, uyeler bir alt rutbeye alindi.");
            else SendClientMessage(playerid, C_ERR, "Bu rutbe silinemez (lider rutbesi silinemez, en az 2 rutbe kalmali).");
            return 1;
        }
        if(!strcmp(cmd, "/rutbeisim", true))
        {
            if(!r1[0] || strlen(r1) > 20) { SendClientMessage(playerid, C_INF, "Kullanim: /rutbeisim [rutbe no] [yeni isim]  (en fazla 20 karakter)"); return 1; }
            new nm2[24];
            format(nm2, sizeof nm2, "%s", r1);
            Esc(nm2);
            format(RankName[d][ri], 24, "%s", nm2);
            SaveRoles(d);
            SendClientMessage(playerid, C_OK, "Rutbe ismi guncellendi.");
            return 1;
        }
        // /rutbeyetki [rutbe no] [yetki no]
        if(!a2[0])
        {
            format(s, sizeof s, "===== %s yetkileri (degistirmek icin /rutbeyetki %d [yetki no]) =====", RankName[d][ri], ri + 1);
            SendClientMessage(playerid, C_INF, s);
            for(new p = 0; p < PERM_COUNT; p++)
            {
                format(s, sizeof s, "%d) %s: %s", p + 1, PermName[p], (RankPerm[d][ri] & (1 << p)) ? "ACIK" : "KAPALI");
                SendClientMessage(playerid, (RankPerm[d][ri] & (1 << p)) ? C_OK : C_ERR, s);
            }
            return 1;
        }
        new pi = strval(a2) - 1;
        if(pi < 0 || pi >= PERM_COUNT) { SendClientMessage(playerid, C_ERR, "Yetki no gecersiz (1-9)."); return 1; }
        RankPerm[d][ri] ^= (1 << pi);
        SaveRoles(d);
        format(s, sizeof s, "%s: %s -> %s", RankName[d][ri], PermName[pi], (RankPerm[d][ri] & (1 << pi)) ? "ACIK" : "KAPALI");
        SendClientMessage(playerid, C_OK, s);
        return 1;
    }
    return 0;
}

stock DepKomut(playerid, cmdtext[])
{
    new cmd[24], a1[32], a2[32], r0[150], r1[150], r2[150], ix = 0, i0, i1, i2;
    Token(cmdtext, ix, cmd, sizeof cmd);
    if(cmd[0] != '/') return 0;
    i0 = ix;
    Token(cmdtext, ix, a1, sizeof a1);
    i1 = ix;
    Token(cmdtext, ix, a2, sizeof a2);
    i2 = ix;
    DRest(cmdtext, i0, r0, sizeof r0);
    DRest(cmdtext, i1, r1, sizeof r1);
    DRest(cmdtext, i2, r2, sizeof r2);
    if(DK_Genel(playerid, cmd, a1, a2, r0, r1, r2)) return 1;
    if(DK_Personel(playerid, cmd, a1, a2, r0, r1, r2)) return 1;
    if(DK_Medya(playerid, cmd, a1, a2, r0, r1, r2)) return 1;
    if(DK_Admin(playerid, cmd, a1, a2, r0, r1, r2)) return 1;
    return 0;
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

    if(DepKomut(playerid, cmdtext)) return 1;

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
