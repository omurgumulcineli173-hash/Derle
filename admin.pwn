/*
    XYRAL ROLEPLAY - ADMIN SISTEMI (filterscript)  -  Mobil/dokunmatik uyumlu

    - Tum menuler dialog + dokunmatik textdraw. /admin ile ac.
    - Oyuncu sistemi (oyuncu.pwn) ile cakismaz. server.cfg'de ADMIN ONCE yazilmali:
          filterscripts admin oyuncu
    - Yetki: scriptfiles/Admin/yetkili.txt  ("isim seviye").  RCON admin = seviye 5.
      Ilk yetkili icin: /rcon login <sifre>  sonra  /adminver <id> <1-5>
    - Dosyada Turkce ozel karakter yok (SA-MP kodlama sorunu olmasin diye).

    Seviyeler: 1 Destek, 2 Moderator, 3 Admin, 4 Ust Yonetici, 5 Kurucu
*/

#define FILTERSCRIPT
#include <a_samp>
#undef MAX_PLAYERS
#define MAX_PLAYERS 50

#define DOSYA_YETKILI   "Admin/yetkili.txt"
#define DOSYA_BAN       "Admin/banlar.txt"
#define DOSYA_CEZA      "Admin/cezalar.txt"
#define MAX_YETKILI     50
#define RENK_ADMIN      0x8E44ADFF
#define RENK_DUTY       0xFF0000FF
#define RENK_YESIL      0x2ECC71FF
#define RENK_KIRMIZI    0xE74C3CFF
#define RENK_SARI       0xF1C40FFF
#define RENK_MAVI       0x3498DBFF

enum
{
    DA_ANA = 8100, DA_ANASAYFA, DA_TOOLS, DA_SPEC_ID, DA_TP, DA_TP_KOORD,
    DA_OYUNCU, DA_DETAY, DA_NEDEN, DA_ARAC, DA_ARAC_ARA, DA_ARAC_SONUC,
    DA_ARAC_GECMIS, DA_CEZA, DA_UNBAN, DA_CEZA_GECMIS, DA_CEZA_SONUC,
    DA_SUNUCU, DA_DUYURU, DA_HAVA, DA_SAAT, DA_MSG, DA_INT, DA_OBJE, DA_RAPOR, DA_SON
}

enum { B_OK, B_HATA, B_YETKI, B_BILGI, B_OYUNCU, B_SUNUCU }
enum { T_YOK, T_KICK, T_BAN, T_JAIL, T_WARN, T_BANKALICI, T_BANGECICI }

// ---------------------------------------------------------------- veriler
new AdminIsim[MAX_YETKILI][MAX_PLAYER_NAME];
new AdminLv[MAX_YETKILI];
new AdminSayi;

new const LvAd[6][14] = {"Oyuncu", "Destek", "Moderator", "Admin", "Ust Yonetici", "Kurucu"};

new bool:AdmDuty[MAX_PLAYERS];
new bool:AdmNoclip[MAX_PLAYERS];
new bool:AdmFly[MAX_PLAYERS];
new bool:AdmInv[MAX_PLAYERS];
new bool:AdmGod[MAX_PLAYERS];
new Text3D:AdmEtiket[MAX_PLAYERS];
new bool:AdmEtiketVar[MAX_PLAYERS];
new AdmEskiSkin[MAX_PLAYERS];
new bool:AdmDonuk[MAX_PLAYERS];
new bool:NcTouch[MAX_PLAYERS];
new bool:NcOncekiInv[MAX_PLAYERS];
new bool:SpecDon[MAX_PLAYERS];
new AdmSpec[MAX_PLAYERS];
new NcHiz[MAX_PLAYERS];
new NcBtn[MAX_PLAYERS];
new AdmKoruma[MAX_PLAYERS];
new JailKalan[MAX_PLAYERS];
new WarnSayi[MAX_PLAYERS];
new AdmHedef[MAX_PLAYERS];
new AdmIslem[MAX_PLAYERS];
new AdmListeMod[MAX_PLAYERS];
new AdmListe[MAX_PLAYERS][40];
new AdmAracListe[MAX_PLAYERS][40];
new Float:SpecPos[MAX_PLAYERS][3];
new SpecInt[MAX_PLAYERS];
new SpecVw[MAX_PLAYERS];

new SonIslem[10][96];
new SonIslemSayi;
new AracGecmis[15][72];
new AracGecmisSayi;
new AdmAracId[100];
new AdmAracSayi;

// FiveM tarzi panel
#define PN_YOK (PlayerText:0xFFFF)
new PlayerText:PnTd[MAX_PLAYERS][26];
new bool:PnAcik[MAX_PLAYERS];
new bool:AdmMermi[MAX_PLAYERS];
new bool:KoordVar[MAX_PLAYERS];
new MuteKalan[MAX_PLAYERS];
new Float:AdmKoord[MAX_PLAYERS][3];
new ObjeId[100];
new ObjeSayi;
new Rapor[10][110];
new RaporSayi;

new const PnYazi[22][18] =
{
    "OYUNCULAR", "MASTER", "RAPORLAR", "BANLAR", "X",
    "REVIVE", "KOORD KOPYALA", "KOORDA GIT",
    "SPEED BOOST", "NC HIZ -", "NC HIZ +",
    "ARAC OLUSTUR", "ARAC TAMIR", "ARAC SIL",
    "INTERIOR TP", "OBJE OLUSTUR",
    "NOCLIP", "SONSUZ MERMI", "GODMODE", "FLY", "INVISIBLE", "ADMIN DUTY"
};
new const Float:PnPos[22][3] =
{
    {118.0, 78.0, 88.0}, {210.0, 78.0, 88.0}, {302.0, 78.0, 88.0}, {394.0, 78.0, 88.0}, {490.0, 78.0, 32.0},
    {118.0, 124.0, 126.0}, {118.0, 152.0, 126.0}, {118.0, 180.0, 126.0},
    {252.0, 124.0, 126.0}, {252.0, 152.0, 126.0}, {252.0, 180.0, 126.0},
    {386.0, 124.0, 126.0}, {386.0, 152.0, 126.0}, {386.0, 180.0, 126.0},
    {118.0, 214.0, 190.0}, {322.0, 214.0, 190.0},
    {118.0, 262.0, 126.0}, {252.0, 262.0, 126.0}, {386.0, 262.0, 126.0},
    {118.0, 290.0, 126.0}, {252.0, 290.0, 126.0}, {386.0, 290.0, 126.0}
};

new const IntAd[9][24] =
{
    "LSPD Karakol", "Ammu-Nation", "Cluckin Bell", "Burger Shot", "Pizza Stack",
    "Zip", "Binco", "Four Dragons Casino", "Disari (Interior 0)"
};
new const Float:IntPos[9][3] =
{
    {246.4, 62.3, 1003.6}, {286.1, -40.6, 1001.5}, {365.7, -9.9, 1001.8}, {363.4, -74.9, 1001.5},
    {372.3, -133.5, 1001.5}, {161.4, -93.2, 1001.8}, {207.7, -109.0, 1005.1},
    {2016.1, 1017.1, 996.9}, {1481.0, -1738.0, 13.5}
};
new const IntId[9] = {6, 1, 9, 10, 5, 18, 15, 10, 0};

new const Float:NcHizlar[4] = {0.4, 1.0, 2.5, 6.0};
new const NcHizAd[4][12] = {"Yavas", "Normal", "Hizli", "Cok hizli"};

new Text:TdNcBg, Text:TdNcBaslik;
new Text:TdNc[11];

new const TpAd[][24] =
{
    "Hastane", "Polis Departmani", "Pershing Square", "Grove Street",
    "LS Havalimani", "SF Havalimani", "LV Strip", "Chiliad Dagi"
};
new const Float:TpPos[][3] =
{
    {1177.5, -1323.9, 14.0}, {1554.8, -1675.6, 16.2}, {1481.0, -1738.0, 13.5},
    {2495.0, -1688.0, 13.8}, {1958.3, -2180.0, 13.5}, {-1422.0, -292.0, 14.1},
    {2027.0, 1008.0, 10.8}, {-2321.5, -1633.7, 483.7}
};

new const DetayMinLv[12] = {1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 2, 3};

new const AracAd[][24] =
{
    "Landstalker", "Bravura", "Buffalo", "Linerunner", "Perennial", "Sentinel", "Dumper", "Fire Truck",
    "Trashmaster", "Stretch", "Manana", "Infernus", "Voodoo", "Pony", "Mule", "Cheetah",
    "Ambulance", "Leviathan", "Moonbeam", "Esperanto", "Taxi", "Washington", "Bobcat", "Mr Whoopee",
    "BF Injection", "Hunter", "Premier", "Enforcer", "Securicar", "Banshee", "Predator", "Bus",
    "Rhino", "Barracks", "Hotknife", "Article Trailer", "Previon", "Coach", "Cabbie", "Stallion",
    "Rumpo", "RC Bandit", "Romero", "Packer", "Monster", "Admiral", "Squalo", "Seasparrow",
    "Pizzaboy", "Tram", "Article Trailer 2", "Turismo", "Speeder", "Reefer", "Tropic", "Flatbed",
    "Yankee", "Caddy", "Solair", "Berkley RC Van", "Skimmer", "PCJ-600", "Faggio", "Freeway",
    "RC Baron", "RC Raider", "Glendale", "Oceanic", "Sanchez", "Sparrow", "Patriot", "Quad",
    "Coastguard", "Dinghy", "Hermes", "Sabre", "Rustler", "ZR-350", "Walton", "Regina",
    "Comet", "BMX", "Burrito", "Camper", "Marquis", "Baggage", "Dozer", "Maverick",
    "News Chopper", "Rancher", "FBI Rancher", "Virgo", "Greenwood", "Jetmax", "Hotring Racer", "Sandking",
    "Blista Compact", "Police Maverick", "Boxville", "Benson", "Mesa", "RC Goblin", "Hotring Racer A", "Hotring Racer B",
    "Bloodring Banger", "Rancher Lure", "Super GT", "Elegant", "Journey", "Bike", "Mountain Bike", "Beagle",
    "Cropduster", "Stuntplane", "Tanker", "Roadtrain", "Nebula", "Majestic", "Buccaneer", "Shamal",
    "Hydra", "FCR-900", "NRG-500", "HPV1000", "Cement Truck", "Tow Truck", "Fortune", "Cadrona",
    "FBI Truck", "Willard", "Forklift", "Tractor", "Combine Harvester", "Feltzer", "Remington", "Slamvan",
    "Blade", "Freight", "Brownstreak", "Vortex", "Vincent", "Bullet", "Clover", "Sadler",
    "Fire Truck Ladder", "Hustler", "Intruder", "Primo", "Cargobob", "Tampa", "Sunrise", "Merit",
    "Utility Van", "Nevada", "Yosemite", "Windsor", "Monster A", "Monster B", "Uranus", "Jester",
    "Sultan", "Stratum", "Elegy", "Raindance", "RC Tiger", "Flash", "Tahoma", "Savanna",
    "Bandito", "Freight Flat", "Streak Trailer", "Kart", "Mower", "Dune", "Sweeper", "Broadway",
    "Tornado", "AT-400", "DFT-30", "Huntley", "Stafford", "BF-400", "Newsvan", "Tug",
    "Petrol Trailer", "Emperor", "Wayfarer", "Euros", "Hotdog", "Club", "Freight Box", "Article Trailer 3",
    "Andromada", "Dodo", "RC Cam", "Launch", "Police LS", "Police SF", "Police LV", "Police Ranger",
    "Picador", "SWAT", "Alpha", "Phoenix", "Glendale Damaged", "Sadler Damaged", "Baggage Trailer A", "Baggage Trailer B",
    "Tug Stairs Trailer", "Boxville 2", "Farm Trailer", "Utility Trailer"
};

forward NcTick();
forward AdmZaman();
forward KickGec(playerid);
forward AdmHosgeldin(playerid);
forward SpecDonus(playerid);
forward JailDon(playerid);

// ---------------------------------------------------------------- yardimcilar

stock Float:SayiOku(const s[])
{
    new i = 0, bool:neg = false, Float:r = 0.0, Float:bol = 0.1;
    if(s[i] == '-') { neg = true; i++; }
    while(s[i] >= '0' && s[i] <= '9') { r = r * 10.0 + float(s[i] - '0'); i++; }
    if(s[i] == '.')
    {
        i++;
        while(s[i] >= '0' && s[i] <= '9') { r += float(s[i] - '0') * bol; bol *= 0.1; i++; }
    }
    return neg ? (-r) : r;
}

stock SatirTemizle(s[])
{
    new l = strlen(s);
    while(l > 0 && (s[l - 1] == '\n' || s[l - 1] == '\r')) s[--l] = 0;
}

stock Ayir(const src[], ayrac, idx, dest[], len)
{
    new bas = 0, say = 0, n = strlen(src);
    dest[0] = 0;
    for(new i = 0; i <= n; i++)
    {
        if(i == n || src[i] == ayrac)
        {
            if(say == idx)
            {
                new k = 0;
                for(new j = bas; j < i && k < len - 1; j++) dest[k++] = src[j];
                dest[k] = 0;
                return 1;
            }
            say++;
            bas = i + 1;
        }
    }
    return 0;
}

stock TarihYaz(ts, out[], len)
{
    ts += 10800; // UTC+3
    new z = ts / 86400 + 719468;
    new era = z / 146097;
    new doe = z - era * 146097;
    new yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    new doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    new mp = (5 * doy + 2) / 153;
    new d = doy - (153 * mp + 2) / 5 + 1;
    new m = (mp < 10) ? (mp + 3) : (mp - 9);
    format(out, len, "%02d.%02d %02d:%02d", d, m, (ts % 86400) / 3600, (ts % 3600) / 60);
}

stock Saat2(out[], len)
{
    new t = gettime() + 10800;
    format(out, len, "%02d:%02d", (t % 86400) / 3600, (t % 3600) / 60);
}

stock Lv(playerid)
{
    if(playerid < 0 || playerid >= MAX_PLAYERS || !IsPlayerConnected(playerid)) return 0;
    if(IsPlayerAdmin(playerid)) return 5;
    new ad[MAX_PLAYER_NAME];
    GetPlayerName(playerid, ad, sizeof(ad));
    for(new i = 0; i < AdminSayi; i++)
    {
        if(!strcmp(AdminIsim[i], ad, true)) return AdminLv[i];
    }
    return 0;
}

stock AdSay()
{
    new n = 0;
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && Lv(i) > 0) n++;
    return n;
}

stock OnlineSay()
{
    new n = 0;
    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) n++;
    return n;
}

stock Bildir(playerid, tip, const mesaj[])
{
    new renk = 0xFFFFFFFF, tag[16], gt[24], s[160];
    switch(tip)
    {
        case B_OK:     { renk = RENK_YESIL;   format(tag, sizeof(tag), "BASARILI"); format(gt, sizeof(gt), "~g~BASARILI"); }
        case B_HATA:   { renk = RENK_KIRMIZI; format(tag, sizeof(tag), "HATA");     format(gt, sizeof(gt), "~r~HATA"); }
        case B_YETKI:  { renk = RENK_KIRMIZI; format(tag, sizeof(tag), "YETKI");    format(gt, sizeof(gt), "~r~YETKI YOK"); }
        case B_BILGI:  { renk = RENK_MAVI;    format(tag, sizeof(tag), "BILGI");    format(gt, sizeof(gt), "~b~BILGI"); }
        case B_OYUNCU: { renk = RENK_SARI;    format(tag, sizeof(tag), "OYUNCU");   format(gt, sizeof(gt), "~y~OYUNCU"); }
        case B_SUNUCU: { renk = RENK_ADMIN;   format(tag, sizeof(tag), "SUNUCU");   format(gt, sizeof(gt), "~p~SUNUCU"); }
    }
    format(s, sizeof(s), "[%s] %s", tag, mesaj);
    SendClientMessage(playerid, renk, s);
    GameTextForPlayer(playerid, gt, 1500, 3);
    return 1;
}

stock AdminMesaj(const mesaj[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && Lv(i) > 0) SendClientMessage(i, 0xBB86FCFF, mesaj);
    }
}

stock SonIslemEkle(const s[])
{
    new t[12];
    Saat2(t, sizeof(t));
    format(SonIslem[SonIslemSayi % 10], 96, "%s  %s", t, s);
    SonIslemSayi++;
}

stock YetkiVar(playerid, seviye)
{
    if(Lv(playerid) >= seviye) return 1;
    new s[64];
    format(s, sizeof(s), "Bu islem icin en az seviye %d gerekli.", seviye);
    Bildir(playerid, B_YETKI, s);
    return 0;
}

stock DutyVar(playerid)
{
    if(AdmDuty[playerid]) return 1;
    Bildir(playerid, B_HATA, "Once Admin Duty'yi ac.");
    return 0;
}

// ---------------------------------------------------------------- yetki dosyasi

stock YetkiYukle()
{
    AdminSayi = 0;
    if(!fexist(DOSYA_YETKILI)) return 0;
    new File:f = fopen(DOSYA_YETKILI, io_read);
    if(!f) return 0;
    new satir[64], ad[MAX_PLAYER_NAME], lv[8];
    while(fread(f, satir) && AdminSayi < MAX_YETKILI)
    {
        SatirTemizle(satir);
        Ayir(satir, ' ', 0, ad, sizeof(ad));
        if(!strlen(ad)) continue;
        Ayir(satir, ' ', 1, lv, sizeof(lv));
        format(AdminIsim[AdminSayi], MAX_PLAYER_NAME, "%s", ad);
        AdminLv[AdminSayi] = strval(lv);
        AdminSayi++;
    }
    fclose(f);
    return 1;
}

stock YetkiKaydet()
{
    new File:f = fopen(DOSYA_YETKILI, io_write);
    if(!f)
    {
        print("[ADMIN] HATA: scriptfiles/Admin klasoru yok! mkdir -p scriptfiles/Admin");
        return 0;
    }
    new s[64];
    for(new i = 0; i < AdminSayi; i++)
    {
        format(s, sizeof(s), "%s %d\n", AdminIsim[i], AdminLv[i]);
        fwrite(f, s);
    }
    fclose(f);
    return 1;
}

stock YetkiAyarla(const ad[], lv)
{
    new idx = -1;
    for(new i = 0; i < AdminSayi; i++) if(!strcmp(AdminIsim[i], ad, true)) idx = i;
    if(lv <= 0)
    {
        if(idx == -1) return 0;
        for(new i = idx; i < AdminSayi - 1; i++)
        {
            format(AdminIsim[i], MAX_PLAYER_NAME, "%s", AdminIsim[i + 1]);
            AdminLv[i] = AdminLv[i + 1];
        }
        AdminSayi--;
    }
    else
    {
        if(idx == -1)
        {
            if(AdminSayi >= MAX_YETKILI) return 0;
            idx = AdminSayi++;
            format(AdminIsim[idx], MAX_PLAYER_NAME, "%s", ad);
        }
        AdminLv[idx] = lv;
    }
    return YetkiKaydet();
}

// ---------------------------------------------------------------- ceza dosyalari

stock DosyaEkle(const dosya[], const satir[])
{
    new File:f = fopen(dosya, io_append);
    if(!f)
    {
        print("[ADMIN] HATA: scriptfiles/Admin klasoru yok!");
        return 0;
    }
    fwrite(f, satir);
    fwrite(f, "\n");
    fclose(f);
    return 1;
}

stock CezaLog(const hedef[], const tur[], const admin[], sure, const sebep[])
{
    new s[200];
    format(s, sizeof(s), "%d|%s|%s|%s|%d|%s", gettime(), hedef, tur, admin, sure, sebep);
    DosyaEkle(DOSYA_CEZA, s);
}

// ban satiri: isim|bitis|admin|sebep   (bitis 0 = kalici, -1 = ban kaldirildi isareti)
stock BanDurum(const ad[], &bitis, sebep[], slen, admin[], alen)
{
    new bool:yasakli = false;
    bitis = 0;
    if(!fexist(DOSYA_BAN)) return 0;
    new File:f = fopen(DOSYA_BAN, io_read);
    if(!f) return 0;
    new satir[200], a[MAX_PLAYER_NAME], b[16];
    while(fread(f, satir))
    {
        SatirTemizle(satir);
        Ayir(satir, '|', 0, a, sizeof(a));
        if(strcmp(a, ad, true)) continue;
        Ayir(satir, '|', 1, b, sizeof(b));
        new t = strval(b);
        if(t == -1) { yasakli = false; continue; }
        yasakli = true;
        bitis = t;
        Ayir(satir, '|', 2, admin, alen);
        Ayir(satir, '|', 3, sebep, slen);
    }
    fclose(f);
    if(yasakli && bitis != 0 && bitis <= gettime()) yasakli = false;
    return yasakli;
}

stock BanKontrol(playerid)
{
    new ad[MAX_PLAYER_NAME], bitis, sebep[48], admin[MAX_PLAYER_NAME], s[144], t[24];
    GetPlayerName(playerid, ad, sizeof(ad));
    if(!BanDurum(ad, bitis, sebep, sizeof(sebep), admin, sizeof(admin))) return 0;
    if(bitis == 0) format(t, sizeof(t), "KALICI");
    else TarihYaz(bitis, t, sizeof(t));
    format(s, sizeof(s), "Sunucudan yasaklisin. Bitis: %s | Sebep: %s", t, sebep);
    SendClientMessage(playerid, RENK_KIRMIZI, s);
    SetTimerEx("KickGec", 1000, false, "i", playerid);
    return 1;
}

public KickGec(playerid)
{
    if(IsPlayerConnected(playerid)) Kick(playerid);
    return 1;
}

stock CezaGecmisiGoster(playerid, const filtre[])
{
    new ring[15][200], n = 0, satir[200], h[MAX_PLAYER_NAME];
    if(fexist(DOSYA_CEZA))
    {
        new File:f = fopen(DOSYA_CEZA, io_read);
        if(f)
        {
            while(fread(f, satir))
            {
                SatirTemizle(satir);
                if(strlen(filtre) > 0)
                {
                    Ayir(satir, '|', 1, h, sizeof(h));
                    if(strcmp(h, filtre, true)) continue;
                }
                format(ring[n % 15], 200, "%s", satir);
                n++;
            }
            fclose(f);
        }
    }
    if(n == 0)
    {
        Bildir(playerid, B_BILGI, "Kayit bulunamadi.");
        return 1;
    }
    new s[3000], bas = (n > 15) ? (n - 15) : 0;
    new ts[12], ho[MAX_PLAYER_NAME], tur[12], ad[MAX_PLAYER_NAME], su[12], se[48], tarih[20], l[160];
    for(new k = bas; k < n; k++)
    {
        Ayir(ring[k % 15], '|', 0, ts, sizeof(ts));
        Ayir(ring[k % 15], '|', 1, ho, sizeof(ho));
        Ayir(ring[k % 15], '|', 2, tur, sizeof(tur));
        Ayir(ring[k % 15], '|', 3, ad, sizeof(ad));
        Ayir(ring[k % 15], '|', 4, su, sizeof(su));
        Ayir(ring[k % 15], '|', 5, se, sizeof(se));
        TarihYaz(strval(ts), tarih, sizeof(tarih));
        format(l, sizeof(l), "{BB86FC}%s {FFFFFF}%s {E74C3C}%s {FFFFFF}(%s, %sdk) %s\n", tarih, ho, tur, ad, su, se);
        strcat(s, l);
    }
    ShowPlayerDialog(playerid, DA_MSG, DIALOG_STYLE_MSGBOX, "Ceza Gecmisi (son 15)", s, "Tamam", "");
    return 1;
}

// ---------------------------------------------------------------- admin durumu

stock EtiketSil(playerid)
{
    if(AdmEtiketVar[playerid])
    {
        Delete3DTextLabel(AdmEtiket[playerid]);
        AdmEtiketVar[playerid] = false;
    }
}

stock EtiketAc(playerid)
{
    EtiketSil(playerid);
    AdmEtiket[playerid] = Create3DTextLabel("ADMIN", 0xFF0000FF, 0.0, 0.0, 0.0, 40.0, 0, 1);
    Attach3DTextLabelToPlayer(AdmEtiket[playerid], playerid, 0.0, 0.0, 0.45);
    AdmEtiketVar[playerid] = true;
}

stock AdmReset(playerid)
{
    EtiketSil(playerid);
    AdmDuty[playerid] = false;
    AdmNoclip[playerid] = false;
    AdmFly[playerid] = false;
    AdmInv[playerid] = false;
    AdmGod[playerid] = false;
    AdmDonuk[playerid] = false;
    NcTouch[playerid] = false;
    SpecDon[playerid] = false;
    AdmSpec[playerid] = -1;
    NcHiz[playerid] = 1;
    NcBtn[playerid] = 0;
    AdmKoruma[playerid] = 0;
    JailKalan[playerid] = 0;
    WarnSayi[playerid] = 0;
    AdmHedef[playerid] = -1;
    AdmIslem[playerid] = 0;
    AdmListeMod[playerid] = 0;
    AdmMermi[playerid] = false;
    NcOncekiInv[playerid] = false;
    MuteKalan[playerid] = 0;
    PnAcik[playerid] = false;
    KoordVar[playerid] = false;
}

stock IsinlaK(playerid, Float:x, Float:y, Float:z)
{
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    if(IsPlayerInAnyVehicle(playerid) && GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
        SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
    else SetPlayerPos(playerid, x, y, z);
}

// ---------------------------------------------------------------- noclip paneli

stock InvAyarla(playerid, bool:ac)
{
    AdmInv[playerid] = ac;
    if(ac) SetPlayerColor(playerid, 0xFFFFFF00);
    else SetPlayerColor(playerid, AdmDuty[playerid] ? RENK_ADMIN : 0xFFFFFFFF);
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && i != playerid) ShowPlayerNameTagForPlayer(i, playerid, !ac);
    }
}

stock Text:NcBtnYap(const yazi[], Float:x, Float:y, Float:w, renk)
{
    new Text:t = TextDrawCreate(x, y, yazi);
    TextDrawLetterSize(t, 0.28, 1.3);
    TextDrawTextSize(t, x + w, 18.0);
    TextDrawUseBox(t, 1);
    TextDrawBoxColor(t, renk);
    TextDrawColor(t, -1);
    TextDrawSetOutline(t, 1);
    TextDrawFont(t, 1);
    TextDrawSetSelectable(t, true);
    return t;
}

stock NcPanelKur()
{
    TdNcBg = TextDrawCreate(14.0, 150.0, "LD_SPAC:white");
    TextDrawFont(TdNcBg, 4);
    TextDrawTextSize(TdNcBg, 204.0, 134.0);
    TextDrawColor(TdNcBg, 0x14141ECC);

    TdNcBaslik = TextDrawCreate(20.0, 155.0, "NOCLIP KONTROL");
    TextDrawFont(TdNcBaslik, 2);
    TextDrawLetterSize(TdNcBaslik, 0.3, 1.4);
    TextDrawColor(TdNcBaslik, 0xBB86FCFF);
    TextDrawSetOutline(TdNcBaslik, 1);

    TdNc[0]  = NcBtnYap(" YUKARI",   20.0, 180.0, 60.0, 0x2980B9DD);
    TdNc[1]  = NcBtnYap("  ILERI",   88.0, 180.0, 60.0, 0x34495EDD);
    TdNc[2]  = NcBtnYap(" ASAGI",   156.0, 180.0, 60.0, 0x2980B9DD);
    TdNc[3]  = NcBtnYap("   SOL",    20.0, 206.0, 60.0, 0x34495EDD);
    TdNc[4]  = NcBtnYap("   DUR",    88.0, 206.0, 60.0, 0xC0392BDD);
    TdNc[5]  = NcBtnYap("   SAG",   156.0, 206.0, 60.0, 0x34495EDD);
    TdNc[6]  = NcBtnYap("  HIZ -",   20.0, 232.0, 60.0, 0x8E44ADDD);
    TdNc[7]  = NcBtnYap("  GERI",    88.0, 232.0, 60.0, 0x34495EDD);
    TdNc[8]  = NcBtnYap("  HIZ +",  156.0, 232.0, 60.0, 0x8E44ADDD);
    TdNc[9]  = NcBtnYap("  JOYSTICK", 20.0, 258.0, 100.0, 0x27AE60DD);
    TdNc[10] = NcBtnYap("   KAPAT",  126.0, 258.0, 90.0, 0xC0392BDD);
}

stock NcPanelGoster(playerid)
{
    TextDrawShowForPlayer(playerid, TdNcBg);
    TextDrawShowForPlayer(playerid, TdNcBaslik);
    for(new i = 0; i < 11; i++) TextDrawShowForPlayer(playerid, TdNc[i]);
}

stock NcPanelGizle(playerid)
{
    TextDrawHideForPlayer(playerid, TdNcBg);
    TextDrawHideForPlayer(playerid, TdNcBaslik);
    for(new i = 0; i < 11; i++) TextDrawHideForPlayer(playerid, TdNc[i]);
}

stock NoclipAc(playerid)
{
    if(AdmSpec[playerid] != -1) return Bildir(playerid, B_HATA, "Spectate acikken noclip acilamaz.");
    if(IsPlayerInAnyVehicle(playerid)) RemovePlayerFromVehicle(playerid);
    AdmNoclip[playerid] = true;
    AdmFly[playerid] = false;
    NcBtn[playerid] = 0;
    TogglePlayerControllable(playerid, false);
    NcOncekiInv[playerid] = AdmInv[playerid];
    if(!AdmInv[playerid]) InvAyarla(playerid, true);
    NcTouch[playerid] = false;
    Bildir(playerid, B_OK, "Noclip ACIK + GORUNMEZ. Joystick=hareket, Zipla=yukari, Egil=asagi, Kos=hizli. Dugme paneli: /ncpanel");
    return 1;
}

stock NoclipKapat(playerid)
{
    if(!AdmNoclip[playerid]) return 0;
    AdmNoclip[playerid] = false;
    NcBtn[playerid] = 0;
    if(!NcOncekiInv[playerid] && AdmInv[playerid]) InvAyarla(playerid, false);
    NcPanelGizle(playerid);
    if(NcTouch[playerid]) { NcTouch[playerid] = false; CancelSelectTextDraw(playerid); }
    if(!AdmDonuk[playerid]) TogglePlayerControllable(playerid, true);
    AdmKoruma[playerid] = 8;
    Bildir(playerid, B_OK, "Noclip KAPALI.");
    return 1;
}

stock NcButon(playerid, i)
{
    switch(i)
    {
        case 0: NcBtn[playerid] = (NcBtn[playerid] == 5) ? 0 : 5;
        case 1: NcBtn[playerid] = (NcBtn[playerid] == 1) ? 0 : 1;
        case 2: NcBtn[playerid] = (NcBtn[playerid] == 6) ? 0 : 6;
        case 3: NcBtn[playerid] = (NcBtn[playerid] == 3) ? 0 : 3;
        case 4: NcBtn[playerid] = 0;
        case 5: NcBtn[playerid] = (NcBtn[playerid] == 4) ? 0 : 4;
        case 7: NcBtn[playerid] = (NcBtn[playerid] == 2) ? 0 : 2;
        case 6, 8:
        {
            if(i == 8 && NcHiz[playerid] < 3) NcHiz[playerid]++;
            if(i == 6 && NcHiz[playerid] > 0) NcHiz[playerid]--;
            new s[40];
            format(s, sizeof(s), "~b~Hiz: ~w~%s", NcHizAd[NcHiz[playerid]]);
            GameTextForPlayer(playerid, s, 1200, 3);
        }
        case 9:
        {
            NcTouch[playerid] = false;
            NcBtn[playerid] = 0;
            CancelSelectTextDraw(playerid);
            NcPanelGizle(playerid);
            SendClientMessage(playerid, RENK_MAVI, "Joystick modu: kamera yonune joystick ile git. Paneli geri acmak icin /ncpanel");
        }
        case 10: NoclipKapat(playerid);
    }
}

public NcTick()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!AdmNoclip[i] || !IsPlayerConnected(i)) continue;
        new keys, ud, lr;
        GetPlayerKeys(i, keys, ud, lr);
        new Float:fx, Float:fy, Float:fz;
        GetPlayerCameraFrontVector(i, fx, fy, fz);
        new Float:mx = 0.0, Float:my = 0.0, Float:mz = 0.0;
        new yon = NcBtn[i];
        if(ud < 0 || yon == 1) { mx += fx; my += fy; mz += fz; }
        if(ud > 0 || yon == 2) { mx -= fx; my -= fy; mz -= fz; }
        if(lr > 0 || yon == 4) { mx += fy; my -= fx; }
        if(lr < 0 || yon == 3) { mx -= fy; my += fx; }
        if((keys & KEY_JUMP) || yon == 5) mz += 1.0;
        if((keys & KEY_CROUCH) || yon == 6) mz -= 1.0;
        if(mx == 0.0 && my == 0.0 && mz == 0.0) continue;
        new Float:x, Float:y, Float:z;
        new Float:h = NcHizlar[NcHiz[i]];
        if(keys & KEY_SPRINT) h *= 3.0;
        GetPlayerPos(i, x, y, z);
        SetPlayerPos(i, x + mx * h, y + my * h, z + mz * h);
    }
    return 1;
}

// ---------------------------------------------------------------- araclar (tools)

stock FlyAyarla(playerid, bool:ac)
{
    AdmFly[playerid] = ac;
    if(ac) SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
    else SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
}

stock ToolsSifirla(playerid)
{
    NoclipKapat(playerid);
    if(AdmFly[playerid]) FlyAyarla(playerid, false);
    if(AdmInv[playerid]) InvAyarla(playerid, false);
    AdmGod[playerid] = false;
    AdmMermi[playerid] = false;
}

stock DutyAyarla(playerid, bool:ac)
{
    new ad[MAX_PLAYER_NAME], s[100];
    GetPlayerName(playerid, ad, sizeof(ad));
    AdmDuty[playerid] = ac;
    if(ac)
    {
        AdmEskiSkin[playerid] = GetPlayerSkin(playerid);
        SetPlayerSkin(playerid, 165);
        SetPlayerColor(playerid, RENK_DUTY);
        AdmGod[playerid] = true;
        SetPlayerHealth(playerid, 100.0);
        SetPlayerArmour(playerid, 100.0);
        EtiketAc(playerid);
        PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
        format(s, sizeof(s), "%s Admin Duty'ye girdi.", ad);
    }
    else
    {
        ToolsSifirla(playerid);
        EtiketSil(playerid);
        SetPlayerSkin(playerid, AdmEskiSkin[playerid]);
        SetPlayerColor(playerid, 0xFFFFFFFF);
        format(s, sizeof(s), "%s Admin Duty'den cikti.", ad);
    }
    Bildir(playerid, B_OK, s);
    SonIslemEkle(s);
}

stock Iyilestir(hedef)
{
    SetPlayerHealth(hedef, 100.0);
    ClearAnimations(hedef);
}

stock SpecBaslat(admin, hedef)
{
    if(AdmNoclip[admin]) NoclipKapat(admin);
    if(AdmSpec[admin] == -1)
    {
        GetPlayerPos(admin, SpecPos[admin][0], SpecPos[admin][1], SpecPos[admin][2]);
        SpecInt[admin] = GetPlayerInterior(admin);
        SpecVw[admin] = GetPlayerVirtualWorld(admin);
    }
    TogglePlayerSpectating(admin, true);
    SetPlayerInterior(admin, GetPlayerInterior(hedef));
    SetPlayerVirtualWorld(admin, GetPlayerVirtualWorld(hedef));
    if(IsPlayerInAnyVehicle(hedef)) PlayerSpectateVehicle(admin, GetPlayerVehicleID(hedef));
    else PlayerSpectatePlayer(admin, hedef);
    AdmSpec[admin] = hedef;
    new s[64], ad[MAX_PLAYER_NAME];
    GetPlayerName(hedef, ad, sizeof(ad));
    format(s, sizeof(s), "Izleniyor: %s (%d). Cikmak: /specoff", ad, hedef);
    Bildir(admin, B_BILGI, s);
}

stock SpecDurdur(admin)
{
    if(AdmSpec[admin] == -1) return 0;
    AdmSpec[admin] = -1;
    SpecDon[admin] = true;
    TogglePlayerSpectating(admin, false);
    return 1;
}

public SpecDonus(playerid)
{
    if(!IsPlayerConnected(playerid) || !SpecDon[playerid]) return 1;
    SpecDon[playerid] = false;
    SetPlayerInterior(playerid, SpecInt[playerid]);
    SetPlayerVirtualWorld(playerid, SpecVw[playerid]);
    SetPlayerPos(playerid, SpecPos[playerid][0], SpecPos[playerid][1], SpecPos[playerid][2]);
    return 1;
}

public JailDon(playerid)
{
    if(!IsPlayerConnected(playerid) || JailKalan[playerid] <= 0) return 1;
    SetPlayerInterior(playerid, 6);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, 264.6, 77.5, 1001.04);
    return 1;
}

// ---------------------------------------------------------------- ceza uygulama

stock CezaVer(admin, hedef, tur, sure, const sebep[])
{
    new an[MAX_PLAYER_NAME], hn[MAX_PLAYER_NAME], s[144], temiz[48];
    GetPlayerName(admin, an, sizeof(an));
    GetPlayerName(hedef, hn, sizeof(hn));
    format(temiz, sizeof(temiz), "%s", sebep);
    for(new i = 0, l = strlen(temiz); i < l; i++) if(temiz[i] == '|') temiz[i] = ' ';

    switch(tur)
    {
        case T_KICK:
        {
            format(s, sizeof(s), "[ADMIN] %s -> %s KICK. Sebep: %s", an, hn, temiz);
            SendClientMessageToAll(RENK_KIRMIZI, s);
            CezaLog(hn, "KICK", an, 0, temiz);
            SetTimerEx("KickGec", 800, false, "i", hedef);
        }
        case T_BAN, T_BANKALICI, T_BANGECICI:
        {
            if(tur == T_BANKALICI) sure = 0;
            new bitis = (sure > 0) ? (gettime() + sure * 60) : 0, b[200];
            format(b, sizeof(b), "%s|%d|%s|%s", hn, bitis, an, temiz);
            DosyaEkle(DOSYA_BAN, b);
            if(sure > 0) format(s, sizeof(s), "[ADMIN] %s -> %s BAN (%d dk). Sebep: %s", an, hn, sure, temiz);
            else format(s, sizeof(s), "[ADMIN] %s -> %s KALICI BAN. Sebep: %s", an, hn, temiz);
            SendClientMessageToAll(RENK_KIRMIZI, s);
            CezaLog(hn, "BAN", an, sure, temiz);
            SetTimerEx("KickGec", 800, false, "i", hedef);
        }
        case T_JAIL:
        {
            if(sure <= 0) sure = 5;
            JailKalan[hedef] = sure * 60;
            if(IsPlayerInAnyVehicle(hedef)) RemovePlayerFromVehicle(hedef);
            ResetPlayerWeapons(hedef);
            SetPlayerInterior(hedef, 6);
            SetPlayerVirtualWorld(hedef, 0);
            SetPlayerPos(hedef, 264.6, 77.5, 1001.04);
            format(s, sizeof(s), "[ADMIN] %s -> %s JAIL (%d dk). Sebep: %s", an, hn, sure, temiz);
            SendClientMessageToAll(RENK_SARI, s);
            CezaLog(hn, "JAIL", an, sure, temiz);
        }
        case T_WARN:
        {
            WarnSayi[hedef]++;
            format(s, sizeof(s), "[ADMIN] %s -> %s WARN (%d/3). Sebep: %s", an, hn, WarnSayi[hedef], temiz);
            SendClientMessageToAll(RENK_SARI, s);
            CezaLog(hn, "WARN", an, 0, temiz);
            if(WarnSayi[hedef] >= 3)
            {
                SendClientMessage(hedef, RENK_KIRMIZI, "3 uyari doldu, sunucudan atiliyorsun.");
                SetTimerEx("KickGec", 1500, false, "i", hedef);
            }
        }
    }
    SonIslemEkle(s);
    Bildir(admin, B_OK, "Ceza uygulandi.");
}

// ---------------------------------------------------------------- araclar

stock AracKayit(playerid, model, veh)
{
    new an[MAX_PLAYER_NAME], t[12];
    GetPlayerName(playerid, an, sizeof(an));
    Saat2(t, sizeof(t));
    format(AracGecmis[AracGecmisSayi % 15], 72, "%s  %s: %s (%d)", t, an, AracAd[model - 400], model);
    AracGecmisSayi++;
    AdmAracId[AdmAracSayi % 100] = veh;
    AdmAracSayi++;
}

stock AracYarat(playerid, model)
{
    if(model < 400 || model > 611) return Bildir(playerid, B_HATA, "Gecersiz model (400-611).");
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    new v = CreateVehicle(model, x + 3.0 * floatsin(-a, degrees), y + 3.0 * floatcos(-a, degrees), z + 0.5, a, -1, -1, -1);
    if(v == INVALID_VEHICLE_ID) return Bildir(playerid, B_HATA, "Arac olusturulamadi.");
    LinkVehicleToInterior(v, GetPlayerInterior(playerid));
    SetVehicleVirtualWorld(v, GetPlayerVirtualWorld(playerid));
    if(!IsPlayerInAnyVehicle(playerid)) PutPlayerInVehicle(playerid, v, 0);
    AracKayit(playerid, model, v);
    new s[64];
    format(s, sizeof(s), "%s olusturuldu.", AracAd[model - 400]);
    Bildir(playerid, B_OK, s);
    SonIslemEkle(s);
    return 1;
}

stock YakinArac(playerid)
{
    if(IsPlayerInAnyVehicle(playerid)) return GetPlayerVehicleID(playerid);
    new Float:px, Float:py, Float:pz, Float:vx, Float:vy, Float:vz, Float:en = 8.0, bul = 0;
    GetPlayerPos(playerid, px, py, pz);
    for(new v = 1; v < MAX_VEHICLES; v++)
    {
        if(!GetVehicleModel(v)) continue;
        GetVehiclePos(v, vx, vy, vz);
        new Float:d = floatsqroot((px - vx) * (px - vx) + (py - vy) * (py - vy) + (pz - vz) * (pz - vz));
        if(d < en) { en = d; bul = v; }
    }
    return bul;
}

stock AracAra(playerid, const q[])
{
    new s[2048], satir[64], k = 0;
    format(s, sizeof(s), "Model\tIsim\n");
    for(new i = 0; i < sizeof(AracAd) && k < 40; i++)
    {
        if(strfind(AracAd[i], q, true) == -1) continue;
        format(satir, sizeof(satir), "%d\t%s\n", i + 400, AracAd[i]);
        strcat(s, satir);
        AdmAracListe[playerid][k++] = i + 400;
    }
    if(k == 0) return Bildir(playerid, B_HATA, "Model bulunamadi.");
    if(k == 1) return AracYarat(playerid, AdmAracListe[playerid][0]);
    ShowPlayerDialog(playerid, DA_ARAC_SONUC, DIALOG_STYLE_TABLIST_HEADERS, "Arac Sonuclari", s, "Olustur", "Geri");
    return 1;
}

// ---------------------------------------------------------------- menuler

stock AnaListe(playerid)
{
    new s[48];
    format(s, sizeof(s), "Admin Panel | Lv%d | Duty: %s", Lv(playerid), AdmDuty[playerid] ? ("ACIK") : ("KAPALI"));
    ShowPlayerDialog(playerid, DA_ANA, DIALOG_STYLE_LIST, s,
        "Ana Sayfa (Durum)\nAdmin Tools\nOyuncu Yonetimi\nArac Yonetimi\nCeza Sistemi\nSunucu Islemleri\nSon Admin Islemleri\nHizli: Kendimi Iyilestir",
        "Sec", "Kapat");
}

stock AnaSayfa(playerid)
{
    new s[400], ad[MAX_PLAYER_NAME];
    GetPlayerName(playerid, ad, sizeof(ad));
    format(s, sizeof(s),
        "{FFFFFF}Yetkili: {BB86FC}%s\n{FFFFFF}Seviye: {BB86FC}%d - %s\n{FFFFFF}Admin Duty: %s\n{FFFFFF}Sunucu: {2ECC71}Bagli\n\n{FFFFFF}Aktif oyuncu: {3498DB}%d\n{FFFFFF}Aktif yetkili: {3498DB}%d\n{FFFFFF}Pingin: {3498DB}%d",
        ad, Lv(playerid), LvAd[Lv(playerid)], AdmDuty[playerid] ? ("{2ECC71}ACIK") : ("{E74C3C}KAPALI"),
        OnlineSay(), AdSay(), GetPlayerPing(playerid));
    ShowPlayerDialog(playerid, DA_ANASAYFA, DIALOG_STYLE_MSGBOX, "Ana Sayfa", s, "Geri", "Kapat");
}

stock DurumYaz(bool:b, out[], len)
{
    if(b) format(out, len, "{2ECC71}AKTIF");
    else format(out, len, "{E74C3C}PASIF");
}

stock ToolsMenu(playerid)
{
    new s[640], d[5][20];
    DurumYaz(AdmNoclip[playerid], d[0], 20);
    DurumYaz(AdmFly[playerid], d[1], 20);
    DurumYaz(AdmInv[playerid], d[2], 20);
    DurumYaz(AdmGod[playerid], d[3], 20);
    DurumYaz(AdmSpec[playerid] != -1, d[4], 20);
    new du[20];
    DurumYaz(AdmDuty[playerid], du, sizeof(du));
    format(s, sizeof(s),
        "{FFFFFF}NOCLIP\t%s\n{FFFFFF}FLY\t%s\n{FFFFFF}INVISIBLE\t%s\n{FFFFFF}GODMODE\t%s\n{FFFFFF}SPECTATE\t%s\n{FFFFFF}REVIVE\t{BBBBBB}dokun\n{FFFFFF}HEAL\t{BBBBBB}dokun\n{FFFFFF}ARMOR\t{BBBBBB}dokun\n{FFFFFF}TELEPORT\t{BBBBBB}dokun\n{FFFFFF}ADMIN DUTY\t%s",
        d[0], d[1], d[2], d[3], d[4], du);
    ShowPlayerDialog(playerid, DA_TOOLS, DIALOG_STYLE_TABLIST, "Admin Tools", s, "Ac/Kapat", "Geri");
}

stock TpMenu(playerid)
{
    new s[400];
    for(new i = 0; i < sizeof(TpAd); i++) { strcat(s, TpAd[i]); strcat(s, "\n"); }
    strcat(s, "Koordinat gir (x y z)");
    ShowPlayerDialog(playerid, DA_TP, DIALOG_STYLE_LIST, "Teleport", s, "Git", "Geri");
}

stock OyuncuListeGoster(playerid, mod)
{
    AdmListeMod[playerid] = mod;
    new s[2048], satir[110], ad[MAX_PLAYER_NAME], k = 0, durum[24];
    format(s, sizeof(s), "ID\tIsim\tPing\tDurum\n");
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || k >= 40) continue;
        GetPlayerName(i, ad, sizeof(ad));
        if(JailKalan[i] > 0) format(durum, sizeof(durum), "Jail");
        else if(AdmDonuk[i]) format(durum, sizeof(durum), "Freeze");
        else if(Lv(i) > 0) format(durum, sizeof(durum), "Yetkili %d", Lv(i));
        else format(durum, sizeof(durum), "Online");
        format(satir, sizeof(satir), "%d\t%s\t%d\t%s\n", i, ad, GetPlayerPing(i), durum);
        strcat(s, satir);
        AdmListe[playerid][k++] = i;
    }
    ShowPlayerDialog(playerid, DA_OYUNCU, DIALOG_STYLE_TABLIST_HEADERS, "Oyuncular", s, "Sec", "Geri");
}

stock DetayMenu(playerid)
{
    new h = AdmHedef[playerid], s[64], ad[MAX_PLAYER_NAME], Float:hp;
    GetPlayerName(h, ad, sizeof(ad));
    GetPlayerHealth(h, hp);
    format(s, sizeof(s), "[%d] %s | HP %.0f | Ping %d", h, ad, hp, GetPlayerPing(h));
    ShowPlayerDialog(playerid, DA_DETAY, DIALOG_STYLE_LIST, s,
        "Getir\nYanina Git\nSpectate\nFreeze\nUnfreeze\nRevive\nHeal\nArmor\nWarn\nKick\nJail\nBan",
        "Uygula", "Geri");
}

stock NedenMenu(playerid, tur)
{
    AdmIslem[playerid] = tur;
    switch(tur)
    {
        case T_KICK: ShowPlayerDialog(playerid, DA_NEDEN, DIALOG_STYLE_INPUT, "Kick", "Sebep yaz:", "At", "Iptal");
        case T_WARN: ShowPlayerDialog(playerid, DA_NEDEN, DIALOG_STYLE_INPUT, "Warn", "Sebep yaz:", "Uyar", "Iptal");
        case T_BANKALICI: ShowPlayerDialog(playerid, DA_NEDEN, DIALOG_STYLE_INPUT, "Kalici Ban", "Sebep yaz:", "Banla", "Iptal");
        case T_JAIL: ShowPlayerDialog(playerid, DA_NEDEN, DIALOG_STYLE_INPUT, "Jail", "Format: SURE(dk) SEBEP\nOrnek: 10 DM", "Hapset", "Iptal");
        case T_BAN, T_BANGECICI: ShowPlayerDialog(playerid, DA_NEDEN, DIALOG_STYLE_INPUT, "Ban", "Format: SURE(dk) SEBEP  (0 = kalici)\nOrnek: 1440 Hile", "Banla", "Iptal");
    }
}

stock DetayIslem(playerid, idx)
{
    new h = AdmHedef[playerid];
    if(!IsPlayerConnected(h)) return Bildir(playerid, B_HATA, "Oyuncu cevrimdisi.");
    if(!YetkiVar(playerid, DetayMinLv[idx])) return 1;
    if(idx >= 8 && h != playerid && Lv(h) >= Lv(playerid))
        return Bildir(playerid, B_YETKI, "Esit/ustun yetkiliye ceza veremezsin.");

    new an[MAX_PLAYER_NAME], hn[MAX_PLAYER_NAME], s[100], Float:x, Float:y, Float:z;
    GetPlayerName(playerid, an, sizeof(an));
    GetPlayerName(h, hn, sizeof(hn));
    switch(idx)
    {
        case 0:
        {
            GetPlayerPos(playerid, x, y, z);
            SetPlayerInterior(h, GetPlayerInterior(playerid));
            SetPlayerVirtualWorld(h, GetPlayerVirtualWorld(playerid));
            SetPlayerPos(h, x + 1.5, y, z);
            format(s, sizeof(s), "%s getirildi.", hn);
            Bildir(playerid, B_OK, s);
            Bildir(h, B_OYUNCU, "Bir yetkili seni yanina isinladi.");
        }
        case 1:
        {
            GetPlayerPos(h, x, y, z);
            SetPlayerInterior(playerid, GetPlayerInterior(h));
            SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(h));
            SetPlayerPos(playerid, x + 1.5, y, z);
            format(s, sizeof(s), "%s yanina gidildi.", hn);
            Bildir(playerid, B_OK, s);
        }
        case 2:
        {
            if(h == playerid) return Bildir(playerid, B_HATA, "Kendini izleyemezsin.");
            SpecBaslat(playerid, h);
        }
        case 3:
        {
            AdmDonuk[h] = true;
            TogglePlayerControllable(h, false);
            format(s, sizeof(s), "%s donduruldu.", hn);
            Bildir(playerid, B_OK, s);
            Bildir(h, B_OYUNCU, "Bir yetkili seni dondurdu.");
            SonIslemEkle(s);
        }
        case 4:
        {
            AdmDonuk[h] = false;
            TogglePlayerControllable(h, true);
            format(s, sizeof(s), "%s cozuldu.", hn);
            Bildir(playerid, B_OK, s);
            Bildir(h, B_OYUNCU, "Donman cozuldu.");
        }
        case 5, 6:
        {
            Iyilestir(h);
            format(s, sizeof(s), "%s %s.", hn, (idx == 5) ? ("canlandirildi") : ("iyilestirildi"));
            Bildir(playerid, B_OK, s);
            Bildir(h, B_OYUNCU, "Bir yetkili seni iyilestirdi.");
            SonIslemEkle(s);
        }
        case 7:
        {
            SetPlayerArmour(h, 100.0);
            format(s, sizeof(s), "%s zirh aldi.", hn);
            Bildir(playerid, B_OK, s);
        }
        case 8: NedenMenu(playerid, T_WARN);
        case 9: NedenMenu(playerid, T_KICK);
        case 10: NedenMenu(playerid, T_JAIL);
        case 11: NedenMenu(playerid, T_BAN);
    }
    if(idx < 8) DetayMenu(playerid);
    return 1;
}

stock ToolIslem(playerid, idx)
{
    if(idx != 9 && idx != 8 && !DutyVar(playerid)) { ToolsMenu(playerid); return 1; }
    switch(idx)
    {
        case 0:
        {
            if(AdmNoclip[playerid]) NoclipKapat(playerid);
            else { NoclipAc(playerid); return 1; }
        }
        case 1:
        {
            if(AdmNoclip[playerid]) NoclipKapat(playerid);
            FlyAyarla(playerid, !AdmFly[playerid]);
            Bildir(playerid, B_OK, AdmFly[playerid] ? ("Fly ACIK (jetpack).") : ("Fly KAPALI."));
        }
        case 2:
        {
            InvAyarla(playerid, !AdmInv[playerid]);
            Bildir(playerid, B_OK, AdmInv[playerid] ? ("Invisible ACIK (isim/isaret gizli).") : ("Invisible KAPALI."));
        }
        case 3:
        {
            AdmGod[playerid] = !AdmGod[playerid];
            if(AdmGod[playerid]) { SetPlayerHealth(playerid, 100.0); SetPlayerArmour(playerid, 100.0); }
            Bildir(playerid, B_OK, AdmGod[playerid] ? ("Godmode ACIK.") : ("Godmode KAPALI."));
        }
        case 4:
        {
            if(AdmSpec[playerid] != -1)
            {
                SpecDurdur(playerid);
                Bildir(playerid, B_OK, "Spectate KAPALI.");
            }
            else
            {
                ShowPlayerDialog(playerid, DA_SPEC_ID, DIALOG_STYLE_INPUT, "Spectate", "Izlenecek oyuncu ID:", "Izle", "Geri");
                return 1;
            }
        }
        case 5: { Iyilestir(playerid); Bildir(playerid, B_OK, "Canlandin/iyilestin."); }
        case 6: { SetPlayerHealth(playerid, 100.0); Bildir(playerid, B_OK, "Can dolduruldu."); }
        case 7: { SetPlayerArmour(playerid, 100.0); Bildir(playerid, B_OK, "Zirh dolduruldu."); }
        case 8: { TpMenu(playerid); return 1; }
        case 9:
        {
            DutyAyarla(playerid, !AdmDuty[playerid]);
        }
    }
    ToolsMenu(playerid);
    return 1;
}

// ---------------------------------------------------------------- callback'ler

public OnFilterScriptInit()
{
    YetkiYukle();
    NcPanelKur();
    for(new i = 0; i < MAX_PLAYERS; i++) AdmReset(i);
    SetTimer("NcTick", 50, true);
    SetTimer("AdmZaman", 1000, true);
    printf("[ADMIN] Admin sistemi yuklendi. Yetkili sayisi: %d", AdminSayi);
    return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        PanelKapat(i);
        if(AdmNoclip[i]) NoclipKapat(i);
        if(AdmInv[i]) InvAyarla(i, false);
        if(AdmDonuk[i]) TogglePlayerControllable(i, true);
    }
    TextDrawDestroy(TdNcBg);
    TextDrawDestroy(TdNcBaslik);
    for(new i = 0; i < 11; i++) TextDrawDestroy(TdNc[i]);
    return 1;
}

public OnPlayerConnect(playerid)
{
    AdmReset(playerid);
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && AdmInv[i]) ShowPlayerNameTagForPlayer(playerid, i, false);
    }
    if(BanKontrol(playerid)) return 1;
    new ad[MAX_PLAYER_NAME], s[80];
    GetPlayerName(playerid, ad, sizeof(ad));
    format(s, sizeof(s), "[SUNUCU] Baglandi: %s (%d)", ad, playerid);
    AdminMesaj(s);
    SetTimerEx("AdmHosgeldin", 4000, false, "i", playerid);
    return 1;
}

public AdmHosgeldin(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(Lv(playerid) > 0)
    {
        new s[96];
        format(s, sizeof(s), "Sunucuya baglandin. Yetki: %d (%s). Menu: /admin", Lv(playerid), LvAd[Lv(playerid)]);
        Bildir(playerid, B_SUNUCU, s);
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || i == playerid) continue;
        if(AdmSpec[i] == playerid)
        {
            SpecDurdur(i);
            Bildir(i, B_BILGI, "Izledigin oyuncu cikti.");
        }
        if(AdmInv[playerid]) ShowPlayerNameTagForPlayer(i, playerid, true);
    }
    new ad[MAX_PLAYER_NAME], s[80];
    GetPlayerName(playerid, ad, sizeof(ad));
    format(s, sizeof(s), "[SUNUCU] Ayrildi: %s (%d)", ad, playerid);
    AdminMesaj(s);
    AdmReset(playerid);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(SpecDon[playerid]) SetTimerEx("SpecDonus", 1200, false, "i", playerid);
    if(JailKalan[playerid] > 0) SetTimerEx("JailDon", 1500, false, "i", playerid);
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    for(new a = 0; a < MAX_PLAYERS; a++)
    {
        if(!IsPlayerConnected(a) || AdmSpec[a] != playerid) continue;
        if(newstate == PLAYER_STATE_DRIVER || newstate == PLAYER_STATE_PASSENGER)
            PlayerSpectateVehicle(a, GetPlayerVehicleID(playerid));
        else if(oldstate == PLAYER_STATE_DRIVER || oldstate == PLAYER_STATE_PASSENGER)
            PlayerSpectatePlayer(a, playerid);
    }
    return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
    for(new a = 0; a < MAX_PLAYERS; a++)
    {
        if(IsPlayerConnected(a) && AdmSpec[a] == playerid) SetPlayerInterior(a, newinteriorid);
    }
    return 1;
}

public AdmZaman()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        if(AdmGod[i] || AdmKoruma[i] > 0)
        {
            SetPlayerHealth(i, 100.0);
            if(AdmKoruma[i] > 0) AdmKoruma[i]--;
        }
        if(AdmMermi[i])
        {
            new w, am;
            for(new sl = 2; sl <= 9; sl++)
            {
                GetPlayerWeaponData(i, sl, w, am);
                if(w > 0 && am < 300) SetPlayerAmmo(i, w, 999);
            }
        }
        if(MuteKalan[i] > 0)
        {
            MuteKalan[i]--;
            if(MuteKalan[i] == 0) Bildir(i, B_OYUNCU, "Susturman kalkti.");
        }
        if(JailKalan[i] > 0)
        {
            JailKalan[i]--;
            if(JailKalan[i] == 0)
            {
                SetPlayerInterior(i, 0);
                SetPlayerVirtualWorld(i, 0);
                SetPlayerPos(i, 1554.8, -1675.6, 16.2);
                Bildir(i, B_OYUNCU, "Hapis suren doldu, serbestsin.");
            }
        }
    }
    return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    if(PnAcik[playerid] && clickedid == INVALID_TEXT_DRAW)
    {
        PanelKapat(playerid);
        return 1;
    }
    if(!AdmNoclip[playerid]) return 0;
    if(clickedid == INVALID_TEXT_DRAW)
    {
        if(NcTouch[playerid])
        {
            NcTouch[playerid] = false;
            NcPanelGizle(playerid);
            SendClientMessage(playerid, RENK_MAVI, "Joystick modu. Paneli geri acmak icin /ncpanel");
        }
        return 1;
    }
    for(new i = 0; i < 11; i++)
    {
        if(clickedid == TdNc[i]) { NcButon(playerid, i); return 1; }
    }
    return 0;
}

// ---------------------------------------------------------------- FiveM tarzi panel

stock PnRenk(playerid, idx)
{
    if(idx == 1) return 0x6D28D9FF;
    if(idx < 4) return 0x2E2E48FF;
    if(idx == 4) return 0xC0392BFF;
    if(idx < 16) return 0x6D28D9FF;
    new bool:d = false;
    switch(idx)
    {
        case 16: d = AdmNoclip[playerid];
        case 17: d = AdmMermi[playerid];
        case 18: d = AdmGod[playerid];
        case 19: d = AdmFly[playerid];
        case 20: d = AdmInv[playerid];
        case 21: d = AdmDuty[playerid];
    }
    return d ? 0x2ECC71FF : 0xE06666FF;
}

stock PnYap(playerid, id)
{
    new s[48], n = floatround((PnPos[id][2] - strlen(PnYazi[id]) * 7.0) / 6.4, floatround_floor);
    if(n < 0) n = 0;
    if(n > 20) n = 20;
    s[0] = 0;
    for(new k = 0; k < n; k++) strcat(s, " ");
    strcat(s, PnYazi[id]);
    new PlayerText:t = CreatePlayerTextDraw(playerid, PnPos[id][0], PnPos[id][1], s);
    PlayerTextDrawLetterSize(playerid, t, 0.26, 1.3);
    PlayerTextDrawTextSize(playerid, t, PnPos[id][0] + PnPos[id][2], 18.0);
    PlayerTextDrawUseBox(playerid, t, 1);
    PlayerTextDrawBoxColor(playerid, t, PnRenk(playerid, id));
    PlayerTextDrawColor(playerid, t, -1);
    PlayerTextDrawFont(playerid, t, 1);
    PlayerTextDrawSetProportional(playerid, t, 1);
    PlayerTextDrawSetSelectable(playerid, t, true);
    PnTd[playerid][id] = t;
}

stock PnMetin(playerid, slot, const yazi[], Float:x, Float:y, al, Float:lx, Float:ly, renk)
{
    new PlayerText:t = CreatePlayerTextDraw(playerid, x, y, yazi);
    PlayerTextDrawLetterSize(playerid, t, lx, ly);
    PlayerTextDrawAlignment(playerid, t, al);
    PlayerTextDrawColor(playerid, t, renk);
    PlayerTextDrawFont(playerid, t, 1);
    PlayerTextDrawSetOutline(playerid, t, 1);
    PlayerTextDrawSetProportional(playerid, t, 1);
    PlayerTextDrawShow(playerid, t);
    PnTd[playerid][slot] = t;
}

stock PnBilgi(playerid)
{
    if(!PnAcik[playerid]) return 0;
    new s[100], ad[MAX_PLAYER_NAME];
    GetPlayerName(playerid, ad, sizeof(ad));
    format(s, sizeof(s), "%s  |  Lv%d %s  |  Duty: %s  |  Online: %d", ad, Lv(playerid), LvAd[Lv(playerid)], AdmDuty[playerid] ? ("ACIK") : ("KAPALI"), OnlineSay());
    PlayerTextDrawSetString(playerid, PnTd[playerid][25], s);
    return 1;
}

stock PnYenile(playerid)
{
    if(!PnAcik[playerid]) return 0;
    for(new i = 16; i < 22; i++)
    {
        PlayerTextDrawBoxColor(playerid, PnTd[playerid][i], PnRenk(playerid, i));
        PlayerTextDrawShow(playerid, PnTd[playerid][i]);
    }
    PnBilgi(playerid);
    return 1;
}

stock PanelAc(playerid)
{
    if(AdmNoclip[playerid]) return Bildir(playerid, B_HATA, "Noclip acikken panel acilmaz. /nc ile kapat.");
    if(PnAcik[playerid]) return 1;
    new PlayerText:b = CreatePlayerTextDraw(playerid, 110.0, 70.0, "LD_SPAC:white");
    PlayerTextDrawFont(playerid, b, 4);
    PlayerTextDrawTextSize(playerid, b, 420.0, 282.0);
    PlayerTextDrawColor(playerid, b, 0x15151FF0);
    PlayerTextDrawShow(playerid, b);
    PnTd[playerid][22] = b;
    PnMetin(playerid, 23, "Tools", 320.0, 102.0, 2, 0.34, 1.5, 0xFFFFFFFF);
    PnMetin(playerid, 24, "Toggles", 320.0, 240.0, 2, 0.34, 1.5, 0xFFFFFFFF);
    PnMetin(playerid, 25, "-", 118.0, 322.0, 1, 0.22, 1.1, 0xBBBBBBFF);
    for(new i = 0; i < 22; i++)
    {
        PnYap(playerid, i);
        PlayerTextDrawShow(playerid, PnTd[playerid][i]);
    }
    PnAcik[playerid] = true;
    SelectTextDraw(playerid, 0xBB86FCFF);
    PnBilgi(playerid);
    return 1;
}

stock PanelKapat(playerid)
{
    if(!PnAcik[playerid]) return 0;
    PnAcik[playerid] = false;
    for(new i = 0; i < 26; i++)
    {
        PlayerTextDrawDestroy(playerid, PnTd[playerid][i]);
        PnTd[playerid][i] = PN_YOK;
    }
    CancelSelectTextDraw(playerid);
    return 1;
}

stock AnaMenu(playerid)
{
    return PanelAc(playerid);
}

stock CezaMenu(playerid)
{
    ShowPlayerDialog(playerid, DA_CEZA, DIALOG_STYLE_LIST, "Ceza Sistemi",
        "Oyuncu Banla (kalici)\nGecici Ban\nKick\nJail\nWarn\nBan Kaldir\nCeza Gecmisi", "Sec", "Geri");
}

stock RaporGoster(playerid)
{
    new s[1200], bas = (RaporSayi > 10) ? (RaporSayi - 10) : 0;
    for(new k = bas; k < RaporSayi; k++) { strcat(s, Rapor[k % 10]); strcat(s, "\n"); }
    if(RaporSayi == 0) format(s, sizeof(s), "Rapor yok. Oyuncular /rapor <mesaj> ile gonderir.");
    ShowPlayerDialog(playerid, DA_RAPOR, DIALOG_STYLE_MSGBOX, "Raporlar (son 10)", s, "Geri", "Kapat");
}

stock IntMenu(playerid)
{
    new s[400];
    for(new i = 0; i < sizeof(IntAd); i++) { strcat(s, IntAd[i]); strcat(s, "\n"); }
    ShowPlayerDialog(playerid, DA_INT, DIALOG_STYLE_LIST, "Interior Isinlan", s, "Git", "Geri");
}

stock PnTikla(playerid, idx)
{
    new s[100];
    switch(idx)
    {
        case 0: { PanelKapat(playerid); OyuncuListeGoster(playerid, 0); }
        case 1: PnYenile(playerid);
        case 2: { PanelKapat(playerid); RaporGoster(playerid); }
        case 3: { PanelKapat(playerid); CezaMenu(playerid); }
        case 4: PanelKapat(playerid);
        case 5: { Iyilestir(playerid); Bildir(playerid, B_OK, "Canlandin/iyilestin."); }
        case 6:
        {
            GetPlayerPos(playerid, AdmKoord[playerid][0], AdmKoord[playerid][1], AdmKoord[playerid][2]);
            KoordVar[playerid] = true;
            format(s, sizeof(s), "%.2f, %.2f, %.2f", AdmKoord[playerid][0], AdmKoord[playerid][1], AdmKoord[playerid][2]);
            DosyaEkle("Admin/koordlar.txt", s);
            Bildir(playerid, B_OK, s);
        }
        case 7:
        {
            if(!KoordVar[playerid])
            {
                PanelKapat(playerid);
                ShowPlayerDialog(playerid, DA_TP_KOORD, DIALOG_STYLE_INPUT, "Koordinat", "Kayitli koordinat yok.\nFormat: X Y Z", "Git", "Geri");
            }
            else
            {
                IsinlaK(playerid, AdmKoord[playerid][0], AdmKoord[playerid][1], AdmKoord[playerid][2]);
                Bildir(playerid, B_OK, "Kayitli koordinata gidildi.");
            }
        }
        case 8:
        {
            new Float:fx, Float:fy, Float:fz;
            GetPlayerCameraFrontVector(playerid, fx, fy, fz);
            if(IsPlayerInAnyVehicle(playerid)) SetVehicleVelocity(GetPlayerVehicleID(playerid), fx * 1.5, fy * 1.5, 0.1);
            else SetPlayerVelocity(playerid, fx * 1.2, fy * 1.2, 0.2);
        }
        case 9, 10:
        {
            if(idx == 10 && NcHiz[playerid] < 3) NcHiz[playerid]++;
            if(idx == 9 && NcHiz[playerid] > 0) NcHiz[playerid]--;
            format(s, sizeof(s), "~b~Hiz: ~w~%s", NcHizAd[NcHiz[playerid]]);
            GameTextForPlayer(playerid, s, 1200, 3);
        }
        case 11:
        {
            if(!YetkiVar(playerid, 2)) return 1;
            PanelKapat(playerid);
            ShowPlayerDialog(playerid, DA_ARAC_ARA, DIALOG_STYLE_INPUT, "Arac Ara", "Model ID veya isim yaz.\nOrnek: infernus, 411, police", "Ara", "Geri");
        }
        case 12, 13:
        {
            if(!YetkiVar(playerid, 2)) return 1;
            new v = YakinArac(playerid);
            if(!v) return Bildir(playerid, B_HATA, "Yakinda arac yok.");
            if(idx == 12) { RepairVehicle(v); SetVehicleHealth(v, 1000.0); Bildir(playerid, B_OK, "Arac tamir edildi."); }
            else { DestroyVehicle(v); Bildir(playerid, B_OK, "Arac silindi."); }
        }
        case 14: { PanelKapat(playerid); IntMenu(playerid); }
        case 15:
        {
            if(!YetkiVar(playerid, 2)) return 1;
            PanelKapat(playerid);
            ShowPlayerDialog(playerid, DA_OBJE, DIALOG_STYLE_INPUT, "Obje Olustur", "Obje model ID yaz.\n'sil' yazarsan olusturulan objeler silinir.", "Olustur", "Geri");
        }
        case 16, 17, 18, 19, 20:
        {
            if(!DutyVar(playerid)) return 1;
            switch(idx)
            {
                case 16: { PanelKapat(playerid); NoclipAc(playerid); return 1; }
                case 17: AdmMermi[playerid] = !AdmMermi[playerid];
                case 18:
                {
                    AdmGod[playerid] = !AdmGod[playerid];
                    if(AdmGod[playerid]) { SetPlayerHealth(playerid, 100.0); SetPlayerArmour(playerid, 100.0); }
                }
                case 19: FlyAyarla(playerid, !AdmFly[playerid]);
                case 20: InvAyarla(playerid, !AdmInv[playerid]);
            }
            PnYenile(playerid);
        }
        case 21:
        {
            DutyAyarla(playerid, !AdmDuty[playerid]);
            PnYenile(playerid);
        }
    }
    return 1;
}

public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
    if(!PnAcik[playerid]) return 0;
    for(new i = 0; i < 22; i++)
    {
        if(playertextid == PnTd[playerid][i]) { PnTikla(playerid, i); return 1; }
    }
    return 0;
}

stock PlayerGeriArac(playerid)
{
    if(!YetkiVar(playerid, 2)) return 1;
    ShowPlayerDialog(playerid, DA_ARAC, DIALOG_STYLE_LIST, "Arac Yonetimi",
        "Arac Olustur (ara)\nArac Sil (icinde/yakin)\nArac Tamir Et\nArac Temizle\nArac Gecmisi\nAdmin Araclarini Sil", "Sec", "Geri");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid < DA_ANA || dialogid > DA_SON) return 0;
    if(Lv(playerid) < 1) return 1;

    switch(dialogid)
    {
        case DA_ANA:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0: AnaSayfa(playerid);
                case 1: ToolsMenu(playerid);
                case 2: OyuncuListeGoster(playerid, 0);
                case 3:
                {
                    if(!YetkiVar(playerid, 2)) return 1;
                    ShowPlayerDialog(playerid, DA_ARAC, DIALOG_STYLE_LIST, "Arac Yonetimi",
                        "Arac Olustur (ara)\nArac Sil (icinde/yakin)\nArac Tamir Et\nArac Temizle\nArac Gecmisi\nAdmin Araclarini Sil", "Sec", "Geri");
                }
                case 4:
                {
                    ShowPlayerDialog(playerid, DA_CEZA, DIALOG_STYLE_LIST, "Ceza Sistemi",
                        "Oyuncu Banla (kalici)\nGecici Ban\nKick\nJail\nWarn\nBan Kaldir\nCeza Gecmisi", "Sec", "Geri");
                }
                case 5:
                {
                    if(!YetkiVar(playerid, 3)) return 1;
                    ShowPlayerDialog(playerid, DA_SUNUCU, DIALOG_STYLE_LIST, "Sunucu Islemleri",
                        "Duyuru Yap\nHava Durumu\nSaat Ayarla\nHerkesi Iyilestir\nOnline Yetkililer", "Sec", "Geri");
                }
                case 6:
                {
                    new s[1100], bas = (SonIslemSayi > 10) ? (SonIslemSayi - 10) : 0;
                    for(new k = bas; k < SonIslemSayi; k++) { strcat(s, SonIslem[k % 10]); strcat(s, "\n"); }
                    if(SonIslemSayi == 0) format(s, sizeof(s), "Henuz islem yok.");
                    ShowPlayerDialog(playerid, DA_SON, DIALOG_STYLE_MSGBOX, "Son Admin Islemleri", s, "Geri", "Kapat");
                }
                case 7:
                {
                    SetPlayerHealth(playerid, 100.0);
                    SetPlayerArmour(playerid, 100.0);
                    Bildir(playerid, B_OK, "Can ve zirh dolduruldu.");
                }
            }
            return 1;
        }
        case DA_ANASAYFA, DA_SON:
        {
            if(response) AnaMenu(playerid);
            return 1;
        }
        case DA_MSG: return 1;
        case DA_RAPOR:
        {
            if(response) AnaMenu(playerid);
            return 1;
        }
        case DA_INT:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            if(IsPlayerInAnyVehicle(playerid)) RemovePlayerFromVehicle(playerid);
            SetPlayerInterior(playerid, IntId[listitem]);
            SetPlayerVirtualWorld(playerid, 0);
            SetPlayerPos(playerid, IntPos[listitem][0], IntPos[listitem][1], IntPos[listitem][2]);
            Bildir(playerid, B_OK, IntAd[listitem]);
            return 1;
        }
        case DA_OBJE:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            if(!YetkiVar(playerid, 2)) return 1;
            if(!strcmp(inputtext, "sil", true))
            {
                for(new k = 0; k < 100; k++)
                {
                    if(ObjeId[k] > 0) DestroyObject(ObjeId[k]);
                    ObjeId[k] = 0;
                }
                return Bildir(playerid, B_OK, "Admin objeleri silindi.");
            }
            new model = strval(inputtext);
            if(model < 1 || model > 19999) return Bildir(playerid, B_HATA, "Gecersiz model ID.");
            new Float:x, Float:y, Float:z, Float:a;
            GetPlayerPos(playerid, x, y, z);
            GetPlayerFacingAngle(playerid, a);
            new o = CreateObject(model, x + 3.0 * floatsin(-a, degrees), y + 3.0 * floatcos(-a, degrees), z, 0.0, 0.0, 0.0);
            if(o == INVALID_OBJECT_ID) return Bildir(playerid, B_HATA, "Obje olusturulamadi.");
            ObjeId[ObjeSayi % 100] = o;
            ObjeSayi++;
            Bildir(playerid, B_OK, "Obje olusturuldu.");
            return 1;
        }
        case DA_TOOLS:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            ToolIslem(playerid, listitem);
            return 1;
        }
        case DA_SPEC_ID:
        {
            if(!response) { ToolsMenu(playerid); return 1; }
            new id = strval(inputtext);
            if(!IsPlayerConnected(id) || id == playerid) return Bildir(playerid, B_HATA, "Gecersiz ID.");
            SpecBaslat(playerid, id);
            return 1;
        }
        case DA_TP:
        {
            if(!response) { ToolsMenu(playerid); return 1; }
            if(listitem < sizeof(TpAd))
            {
                IsinlaK(playerid, TpPos[listitem][0], TpPos[listitem][1], TpPos[listitem][2]);
                new s[48];
                format(s, sizeof(s), "%s konumuna isinlandin.", TpAd[listitem]);
                Bildir(playerid, B_OK, s);
            }
            else ShowPlayerDialog(playerid, DA_TP_KOORD, DIALOG_STYLE_INPUT, "Koordinat", "Format: X Y Z\nOrnek: 1481.0 -1738.0 13.5", "Git", "Geri");
            return 1;
        }
        case DA_TP_KOORD:
        {
            if(!response) { TpMenu(playerid); return 1; }
            new a[16], b[16], c[16];
            Ayir(inputtext, ' ', 0, a, sizeof(a));
            Ayir(inputtext, ' ', 1, b, sizeof(b));
            Ayir(inputtext, ' ', 2, c, sizeof(c));
            if(!strlen(a) || !strlen(b) || !strlen(c)) return Bildir(playerid, B_HATA, "Format: X Y Z");
            IsinlaK(playerid, SayiOku(a), SayiOku(b), SayiOku(c));
            Bildir(playerid, B_OK, "Isinlandin.");
            return 1;
        }
        case DA_OYUNCU:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            new h = AdmListe[playerid][listitem];
            if(!IsPlayerConnected(h)) return Bildir(playerid, B_HATA, "Oyuncu cevrimdisi.");
            AdmHedef[playerid] = h;
            new mod = AdmListeMod[playerid];
            if(mod == 0) { DetayMenu(playerid); return 1; }
            if(h != playerid && Lv(h) >= Lv(playerid)) return Bildir(playerid, B_YETKI, "Esit/ustun yetkiliye ceza veremezsin.");
            NedenMenu(playerid, mod);
            return 1;
        }
        case DA_DETAY:
        {
            if(!response) { OyuncuListeGoster(playerid, 0); return 1; }
            DetayIslem(playerid, listitem);
            return 1;
        }
        case DA_NEDEN:
        {
            if(!response) return 1;
            new h = AdmHedef[playerid], tur = AdmIslem[playerid], sure = 0, sebep[48];
            if(!IsPlayerConnected(h)) return Bildir(playerid, B_HATA, "Oyuncu cevrimdisi.");
            if(tur == T_JAIL || tur == T_BAN || tur == T_BANGECICI)
            {
                if(inputtext[0] < '0' || inputtext[0] > '9')
                {
                    Bildir(playerid, B_HATA, "Once sure (dakika) yaz. Ornek: 10 DM");
                    NedenMenu(playerid, tur);
                    return 1;
                }
                sure = strval(inputtext);
                if(tur == T_BANGECICI && sure <= 0)
                {
                    Bildir(playerid, B_HATA, "Gecici ban icin sure 1 veya daha buyuk olmali.");
                    NedenMenu(playerid, tur);
                    return 1;
                }
                new pos = strfind(inputtext, " ");
                if(pos > 0) strmid(sebep, inputtext, pos + 1, strlen(inputtext), sizeof(sebep));
                else format(sebep, sizeof(sebep), "Belirtilmedi");
            }
            else
            {
                if(strlen(inputtext) == 0) format(sebep, sizeof(sebep), "Belirtilmedi");
                else strmid(sebep, inputtext, 0, strlen(inputtext), sizeof(sebep));
            }
            if(tur == T_BAN && !YetkiVar(playerid, 3)) return 1;
            if((tur == T_BANKALICI || tur == T_BANGECICI) && !YetkiVar(playerid, 3)) return 1;
            if(tur == T_JAIL && !YetkiVar(playerid, 2)) return 1;
            CezaVer(playerid, h, tur, sure, sebep);
            return 1;
        }
        case DA_ARAC:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            switch(listitem)
            {
                case 0: ShowPlayerDialog(playerid, DA_ARAC_ARA, DIALOG_STYLE_INPUT, "Arac Ara", "Model ID veya isim yaz.\nOrnek: infernus, 411, police", "Ara", "Geri");
                case 1:
                {
                    new v = YakinArac(playerid);
                    if(!v) Bildir(playerid, B_HATA, "Yakinda arac yok.");
                    else { DestroyVehicle(v); Bildir(playerid, B_OK, "Arac silindi."); SonIslemEkle("Arac silindi."); }
                }
                case 2:
                {
                    new v = YakinArac(playerid);
                    if(!v) Bildir(playerid, B_HATA, "Yakinda arac yok.");
                    else { RepairVehicle(v); SetVehicleHealth(v, 1000.0); Bildir(playerid, B_OK, "Arac tamir edildi."); }
                }
                case 3:
                {
                    new v = YakinArac(playerid);
                    if(!v) Bildir(playerid, B_HATA, "Yakinda arac yok.");
                    else { UpdateVehicleDamageStatus(v, 0, 0, 0, 0); Bildir(playerid, B_OK, "Arac hasar gorunumu temizlendi."); }
                }
                case 4:
                {
                    new s[1200], bas = (AracGecmisSayi > 15) ? (AracGecmisSayi - 15) : 0;
                    for(new k = bas; k < AracGecmisSayi; k++) { strcat(s, AracGecmis[k % 15]); strcat(s, "\n"); }
                    if(AracGecmisSayi == 0) format(s, sizeof(s), "Henuz arac olusturulmadi.");
                    ShowPlayerDialog(playerid, DA_ARAC_GECMIS, DIALOG_STYLE_MSGBOX, "Arac Gecmisi", s, "Geri", "Kapat");
                    return 1;
                }
                case 5:
                {
                    new n = 0;
                    for(new k = 0; k < 100; k++)
                    {
                        new v = AdmAracId[k];
                        if(v > 0 && GetVehicleModel(v)) { DestroyVehicle(v); n++; }
                        AdmAracId[k] = 0;
                    }
                    new s[48];
                    format(s, sizeof(s), "%d admin araci silindi.", n);
                    Bildir(playerid, B_OK, s);
                }
            }
            return 1;
        }
        case DA_ARAC_GECMIS:
        {
            if(response) PlayerGeriArac(playerid);
            return 1;
        }
        case DA_ARAC_ARA:
        {
            if(!response) { PlayerGeriArac(playerid); return 1; }
            if(!strlen(inputtext)) return Bildir(playerid, B_HATA, "Bos arama.");
            if(inputtext[0] >= '0' && inputtext[0] <= '9') AracYarat(playerid, strval(inputtext));
            else AracAra(playerid, inputtext);
            return 1;
        }
        case DA_ARAC_SONUC:
        {
            if(!response) { PlayerGeriArac(playerid); return 1; }
            AracYarat(playerid, AdmAracListe[playerid][listitem]);
            return 1;
        }
        case DA_CEZA:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            switch(listitem)
            {
                case 0: { if(YetkiVar(playerid, 3)) OyuncuListeGoster(playerid, T_BANKALICI); }
                case 1: { if(YetkiVar(playerid, 3)) OyuncuListeGoster(playerid, T_BANGECICI); }
                case 2: OyuncuListeGoster(playerid, T_KICK);
                case 3: { if(YetkiVar(playerid, 2)) OyuncuListeGoster(playerid, T_JAIL); }
                case 4: OyuncuListeGoster(playerid, T_WARN);
                case 5:
                {
                    if(YetkiVar(playerid, 3))
                        ShowPlayerDialog(playerid, DA_UNBAN, DIALOG_STYLE_INPUT, "Ban Kaldir", "Oyuncu ismini yaz:", "Kaldir", "Geri");
                }
                case 6: ShowPlayerDialog(playerid, DA_CEZA_GECMIS, DIALOG_STYLE_INPUT, "Ceza Gecmisi", "Oyuncu ismi (bos birak = tum son kayitlar):", "Goster", "Geri");
            }
            return 1;
        }
        case DA_UNBAN:
        {
            if(!response) return 1;
            if(!YetkiVar(playerid, 3)) return 1;
            new bitis, sebep[48], adm[MAX_PLAYER_NAME], s[144], an[MAX_PLAYER_NAME];
            if(!BanDurum(inputtext, bitis, sebep, sizeof(sebep), adm, sizeof(adm)))
                return Bildir(playerid, B_HATA, "Bu isimde aktif ban yok.");
            GetPlayerName(playerid, an, sizeof(an));
            format(s, sizeof(s), "%s|-1|%s|UNBAN", inputtext, an);
            DosyaEkle(DOSYA_BAN, s);
            CezaLog(inputtext, "UNBAN", an, 0, "Ban kaldirildi");
            format(s, sizeof(s), "[ADMIN] %s, %s adli oyuncunun banini kaldirdi.", an, inputtext);
            AdminMesaj(s);
            SonIslemEkle(s);
            Bildir(playerid, B_OK, "Ban kaldirildi.");
            return 1;
        }
        case DA_CEZA_GECMIS:
        {
            if(!response) return 1;
            CezaGecmisiGoster(playerid, inputtext);
            return 1;
        }
        case DA_SUNUCU:
        {
            if(!response) { AnaMenu(playerid); return 1; }
            switch(listitem)
            {
                case 0: ShowPlayerDialog(playerid, DA_DUYURU, DIALOG_STYLE_INPUT, "Duyuru", "Duyuru metni:", "Gonder", "Geri");
                case 1: ShowPlayerDialog(playerid, DA_HAVA, DIALOG_STYLE_INPUT, "Hava", "Hava ID (0-45):", "Ayarla", "Geri");
                case 2: ShowPlayerDialog(playerid, DA_SAAT, DIALOG_STYLE_INPUT, "Saat", "Saat (0-23):", "Ayarla", "Geri");
                case 3:
                {
                    for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerHealth(i, 100.0);
                    SendClientMessageToAll(RENK_YESIL, "[ADMIN] Herkes iyilestirildi.");
                    SonIslemEkle("Herkes iyilestirildi.");
                }
                case 4:
                {
                    new s[600], satir[64], ad[MAX_PLAYER_NAME];
                    for(new i = 0; i < MAX_PLAYERS; i++)
                    {
                        if(!IsPlayerConnected(i) || Lv(i) < 1) continue;
                        GetPlayerName(i, ad, sizeof(ad));
                        format(satir, sizeof(satir), "[%d] %s - Lv%d %s%s\n", i, ad, Lv(i), LvAd[Lv(i)], AdmDuty[i] ? (" (Duty)") : (""));
                        strcat(s, satir);
                    }
                    ShowPlayerDialog(playerid, DA_MSG, DIALOG_STYLE_MSGBOX, "Online Yetkililer", s, "Tamam", "");
                }
            }
            return 1;
        }
        case DA_DUYURU:
        {
            if(!response || !strlen(inputtext) || !YetkiVar(playerid, 3)) return 1;
            new s[160];
            format(s, sizeof(s), "[DUYURU] %s", inputtext);
            SendClientMessageToAll(RENK_SARI, s);
            SonIslemEkle("Duyuru yapildi.");
            return 1;
        }
        case DA_HAVA:
        {
            if(!response || !YetkiVar(playerid, 3)) return 1;
            SetWeather(strval(inputtext));
            Bildir(playerid, B_OK, "Hava ayarlandi.");
            return 1;
        }
        case DA_SAAT:
        {
            if(!response || !YetkiVar(playerid, 3)) return 1;
            SetWorldTime(strval(inputtext));
            Bildir(playerid, B_OK, "Saat ayarlandi.");
            return 1;
        }
    }
    return 1;
}

// ---------------------------------------------------------------- yazili komutlar

stock Kalan(const src[], n, out[], len)
{
    new i = 0, say = 0, l = strlen(src), k = 0;
    out[0] = 0;
    while(i < l && say < n)
    {
        if(src[i] == ' ') say++;
        i++;
    }
    while(i < l && k < len - 1) out[k++] = src[i++];
    out[k] = 0;
}

stock HedefBul(const q[])
{
    if(!strlen(q)) return -1;
    if(q[0] >= '0' && q[0] <= '9')
    {
        new id = strval(q);
        if(id >= 0 && id < MAX_PLAYERS && IsPlayerConnected(id)) return id;
        return -1;
    }
    new ad[MAX_PLAYER_NAME], bul = -1;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, ad, sizeof(ad));
        if(strfind(ad, q, true) != -1)
        {
            if(bul != -1) return -2;
            bul = i;
        }
    }
    return bul;
}

stock HedefAl(playerid, const q[])
{
    if(!strlen(q))
    {
        Bildir(playerid, B_HATA, "Oyuncu ID veya isim yaz.");
        return -1;
    }
    new h = HedefBul(q);
    if(h == -2) { Bildir(playerid, B_HATA, "Birden fazla oyuncu eslesti, ID kullan."); return -1; }
    if(h == -1) { Bildir(playerid, B_HATA, "Oyuncu bulunamadi."); return -1; }
    return h;
}

stock HiyerarsiOk(playerid, h)
{
    if(h != playerid && Lv(h) >= Lv(playerid))
    {
        Bildir(playerid, B_YETKI, "Esit/ustun yetkiliye islem yapamazsin.");
        return 0;
    }
    return 1;
}

stock BanKaldir(playerid, const isim[])
{
    new bitis, sebep[48], adm[MAX_PLAYER_NAME], s[144], an[MAX_PLAYER_NAME];
    if(!BanDurum(isim, bitis, sebep, sizeof(sebep), adm, sizeof(adm)))
        return Bildir(playerid, B_HATA, "Bu isimde aktif ban yok.");
    GetPlayerName(playerid, an, sizeof(an));
    format(s, sizeof(s), "%s|-1|%s|UNBAN", isim, an);
    DosyaEkle(DOSYA_BAN, s);
    CezaLog(isim, "UNBAN", an, 0, "Ban kaldirildi");
    format(s, sizeof(s), "[ADMIN] %s, %s adli oyuncunun banini kaldirdi.", an, isim);
    AdminMesaj(s);
    SonIslemEkle(s);
    return Bildir(playerid, B_OK, "Ban kaldirildi.");
}

stock KomutListesi(playerid)
{
    new s[1500];
    format(s, sizeof(s),
        "{BB86FC}Seviye 1:{FFFFFF}\n/admin /duty /nc /fly /inv /god /specoff /adminler /oyuncular\n/goto /gethere /spec /freeze /unfreeze /heal /armor /revive\n/kick /warn /mute /unmute /slap /ac /pos /tp /bul /ping /cezalar\n\n");
    strcat(s, "{BB86FC}Seviye 2:{FFFFFF}\n/jail /unjail /oldur /arac /aracsil /tamir\n/setskin /silah /silahsil /setint /setvw /clear\n\n");
    strcat(s, "{BB86FC}Seviye 3:{FFFFFF}\n/ban /unban /duyuru /hava /saat /sethp /setarmor /healall /ip\n\n");
    strcat(s, "{BB86FC}Seviye 4-5:{FFFFFF}\n/setrank /yetkiler (kendinden dusuk seviye)\n/adminver /adminsil\n\n{BBBBBB}ID yerine isim parcasi da yazabilirsin.");
    ShowPlayerDialog(playerid, DA_MSG, DIALOG_STYLE_MSGBOX, "Admin Komutlari", s, "Tamam", "");
}

stock AdmKomut(playerid, const cmdtext[])
{
    new cmd[24], a1[32], a2[32], a3[32], r[96], s[144];
    Ayir(cmdtext, ' ', 0, cmd, sizeof(cmd));
    Ayir(cmdtext, ' ', 1, a1, sizeof(a1));
    Ayir(cmdtext, ' ', 2, a2, sizeof(a2));
    Ayir(cmdtext, ' ', 3, a3, sizeof(a3));

    // ------------------------------------------------ seviye 1
    if(!strcmp(cmd, "/acmd", true) || !strcmp(cmd, "/komutlar", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        KomutListesi(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/oyuncular", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        OyuncuListeGoster(playerid, 0);
        return 1;
    }
    if(!strcmp(cmd, "/goto", true) || !strcmp(cmd, "/gethere", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        new Float:x, Float:y, Float:z;
        if(!strcmp(cmd, "/goto", true))
        {
            GetPlayerPos(h, x, y, z);
            SetPlayerInterior(playerid, GetPlayerInterior(h));
            SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(h));
            SetPlayerPos(playerid, x + 1.5, y, z);
        }
        else
        {
            if(!HiyerarsiOk(playerid, h)) return 1;
            GetPlayerPos(playerid, x, y, z);
            SetPlayerInterior(h, GetPlayerInterior(playerid));
            SetPlayerVirtualWorld(h, GetPlayerVirtualWorld(playerid));
            SetPlayerPos(h, x + 1.5, y, z);
            Bildir(h, B_OYUNCU, "Bir yetkili seni yanina isinladi.");
        }
        Bildir(playerid, B_OK, "Isinlandi.");
        return 1;
    }
    if(!strcmp(cmd, "/spec", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        if(h == playerid) return Bildir(playerid, B_HATA, "Kendini izleyemezsin.");
        SpecBaslat(playerid, h);
        return 1;
    }
    if(!strcmp(cmd, "/freeze", true) || !strcmp(cmd, "/unfreeze", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        new bool:don = !strcmp(cmd, "/freeze", true);
        AdmDonuk[h] = don;
        TogglePlayerControllable(h, !don);
        Bildir(playerid, B_OK, don ? ("Oyuncu donduruldu.") : ("Donma cozuldu."));
        Bildir(h, B_OYUNCU, don ? ("Bir yetkili seni dondurdu.") : ("Donman cozuldu."));
        return 1;
    }
    if(!strcmp(cmd, "/heal", true) || !strcmp(cmd, "/armor", true) || !strcmp(cmd, "/revive", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = playerid;
        if(strlen(a1)) { h = HedefAl(playerid, a1); if(h == -1) return 1; }
        if(!strcmp(cmd, "/armor", true)) SetPlayerArmour(h, 100.0);
        else if(!strcmp(cmd, "/heal", true)) SetPlayerHealth(h, 100.0);
        else Iyilestir(h);
        Bildir(playerid, B_OK, "Islem uygulandi.");
        if(h != playerid) Bildir(h, B_OYUNCU, "Bir yetkili seni iyilestirdi.");
        return 1;
    }
    if(!strcmp(cmd, "/kick", true) || !strcmp(cmd, "/warn", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        Kalan(cmdtext, 2, r, sizeof(r));
        if(!strlen(r)) format(r, sizeof(r), "Belirtilmedi");
        CezaVer(playerid, h, !strcmp(cmd, "/kick", true) ? T_KICK : T_WARN, 0, r);
        return 1;
    }
    if(!strcmp(cmd, "/mute", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        new dk = strval(a2);
        if(dk <= 0) dk = 5;
        MuteKalan[h] = dk * 60;
        format(s, sizeof(s), "[ADMIN] Bir oyuncu %d dk susturuldu.", dk);
        AdminMesaj(s);
        Bildir(h, B_OYUNCU, "Yetkili seni susturdu.");
        Bildir(playerid, B_OK, "Susturuldu.");
        return 1;
    }
    if(!strcmp(cmd, "/unmute", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        MuteKalan[h] = 0;
        Bildir(h, B_OYUNCU, "Susturman kalkti.");
        Bildir(playerid, B_OK, "Susturma kaldirildi.");
        return 1;
    }
    if(!strcmp(cmd, "/slap", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        new Float:x, Float:y, Float:z;
        GetPlayerPos(h, x, y, z);
        SetPlayerPos(h, x, y, z + 6.0);
        PlayerPlaySound(h, 1130, 0.0, 0.0, 0.0);
        Bildir(playerid, B_OK, "Slap atildi.");
        return 1;
    }
    if(!strcmp(cmd, "/ac", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        Kalan(cmdtext, 1, r, sizeof(r));
        if(!strlen(r)) return Bildir(playerid, B_HATA, "Kullanim: /ac <mesaj>");
        new ad[MAX_PLAYER_NAME];
        GetPlayerName(playerid, ad, sizeof(ad));
        format(s, sizeof(s), "[AC] %s: %s", ad, r);
        AdminMesaj(s);
        return 1;
    }
    if(!strcmp(cmd, "/pos", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        format(s, sizeof(s), "Konum: %.2f, %.2f, %.2f | Int: %d | VW: %d", x, y, z, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid));
        SendClientMessage(playerid, RENK_MAVI, s);
        return 1;
    }
    if(!strcmp(cmd, "/tp", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        if(!strlen(a1) || !strlen(a2) || !strlen(a3)) return Bildir(playerid, B_HATA, "Kullanim: /tp <x> <y> <z>");
        IsinlaK(playerid, SayiOku(a1), SayiOku(a2), SayiOku(a3));
        Bildir(playerid, B_OK, "Isinlandin.");
        return 1;
    }
    if(!strcmp(cmd, "/bul", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        if(!strlen(a1)) return Bildir(playerid, B_HATA, "Kullanim: /bul <isim parcasi>");
        new ad[MAX_PLAYER_NAME], n = 0;
        for(new i = 0; i < MAX_PLAYERS && n < 10; i++)
        {
            if(!IsPlayerConnected(i)) continue;
            GetPlayerName(i, ad, sizeof(ad));
            if(strfind(ad, a1, true) == -1) continue;
            format(s, sizeof(s), "[%d] %s | Ping %d", i, ad, GetPlayerPing(i));
            SendClientMessage(playerid, RENK_MAVI, s);
            n++;
        }
        if(n == 0) Bildir(playerid, B_HATA, "Eslesen oyuncu yok.");
        return 1;
    }
    if(!strcmp(cmd, "/ping", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        new ad[MAX_PLAYER_NAME];
        GetPlayerName(h, ad, sizeof(ad));
        format(s, sizeof(s), "%s ping: %d", ad, GetPlayerPing(h));
        Bildir(playerid, B_BILGI, s);
        return 1;
    }
    if(!strcmp(cmd, "/cezalar", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        CezaGecmisiGoster(playerid, a1);
        return 1;
    }

    // ------------------------------------------------ seviye 2
    if(!strcmp(cmd, "/jail", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        Kalan(cmdtext, 3, r, sizeof(r));
        if(!strlen(r)) format(r, sizeof(r), "Belirtilmedi");
        CezaVer(playerid, h, T_JAIL, strval(a2), r);
        return 1;
    }
    if(!strcmp(cmd, "/unjail", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        JailKalan[h] = 0;
        SetPlayerInterior(h, 0);
        SetPlayerVirtualWorld(h, 0);
        SetPlayerPos(h, 1554.8, -1675.6, 16.2);
        Bildir(h, B_OYUNCU, "Hapisten cikarildin.");
        Bildir(playerid, B_OK, "Hapisten cikarildi.");
        return 1;
    }
    if(!strcmp(cmd, "/oldur", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        SetPlayerHealth(h, 0.0);
        Bildir(playerid, B_OK, "Oyuncu oldurulde.");
        return 1;
    }
    if(!strcmp(cmd, "/arac", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        Kalan(cmdtext, 1, r, sizeof(r));
        if(!strlen(r)) return Bildir(playerid, B_HATA, "Kullanim: /arac <model id veya isim>");
        if(r[0] >= '0' && r[0] <= '9') { AracYarat(playerid, strval(r)); return 1; }
        for(new i = 0; i < sizeof(AracAd); i++)
        {
            if(strfind(AracAd[i], r, true) != -1) { AracYarat(playerid, i + 400); return 1; }
        }
        Bildir(playerid, B_HATA, "Model bulunamadi.");
        return 1;
    }
    if(!strcmp(cmd, "/aracsil", true) || !strcmp(cmd, "/tamir", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new v = YakinArac(playerid);
        if(!v) return Bildir(playerid, B_HATA, "Yakinda arac yok.");
        if(!strcmp(cmd, "/tamir", true)) { RepairVehicle(v); SetVehicleHealth(v, 1000.0); Bildir(playerid, B_OK, "Arac tamir edildi."); }
        else { DestroyVehicle(v); Bildir(playerid, B_OK, "Arac silindi."); }
        return 1;
    }
    if(!strcmp(cmd, "/setskin", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        new sk = strval(a2);
        if(sk < 0 || sk > 311) return Bildir(playerid, B_HATA, "Skin ID 0-311.");
        SetPlayerSkin(h, sk);
        Bildir(playerid, B_OK, "Skin degisti.");
        return 1;
    }
    if(!strcmp(cmd, "/silah", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        new w = strval(a2), m = strval(a3);
        if(w < 1 || w > 46) return Bildir(playerid, B_HATA, "Kullanim: /silah <oyuncu> <silah 1-46> [mermi]");
        if(m <= 0) m = 100;
        GivePlayerWeapon(h, w, m);
        Bildir(playerid, B_OK, "Silah verildi.");
        return 1;
    }
    if(!strcmp(cmd, "/silahsil", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        ResetPlayerWeapons(h);
        Bildir(playerid, B_OK, "Silahlar silindi.");
        return 1;
    }
    if(!strcmp(cmd, "/setint", true) || !strcmp(cmd, "/setvw", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        if(!strcmp(cmd, "/setint", true)) SetPlayerInterior(h, strval(a2));
        else SetPlayerVirtualWorld(h, strval(a2));
        Bildir(playerid, B_OK, "Ayarlandi.");
        return 1;
    }
    if(!strcmp(cmd, "/clear", true))
    {
        if(!YetkiVar(playerid, 2)) return 1;
        for(new i = 0; i < 40; i++) SendClientMessageToAll(0xFFFFFFFF, " ");
        SendClientMessageToAll(RENK_ADMIN, "[ADMIN] Sohbet temizlendi.");
        return 1;
    }

    // ------------------------------------------------ seviye 3
    if(!strcmp(cmd, "/ban", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1 || !HiyerarsiOk(playerid, h)) return 1;
        Kalan(cmdtext, 3, r, sizeof(r));
        if(!strlen(r)) format(r, sizeof(r), "Belirtilmedi");
        CezaVer(playerid, h, T_BAN, strval(a2), r);
        return 1;
    }
    if(!strcmp(cmd, "/unban", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        if(!strlen(a1)) return Bildir(playerid, B_HATA, "Kullanim: /unban <tam isim>");
        BanKaldir(playerid, a1);
        return 1;
    }
    if(!strcmp(cmd, "/duyuru", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        Kalan(cmdtext, 1, r, sizeof(r));
        if(!strlen(r)) return Bildir(playerid, B_HATA, "Kullanim: /duyuru <mesaj>");
        format(s, sizeof(s), "[DUYURU] %s", r);
        SendClientMessageToAll(RENK_SARI, s);
        SonIslemEkle("Duyuru yapildi.");
        return 1;
    }
    if(!strcmp(cmd, "/hava", true) || !strcmp(cmd, "/saat", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        if(!strlen(a1)) return Bildir(playerid, B_HATA, "Kullanim: /hava <id>  |  /saat <0-23>");
        if(!strcmp(cmd, "/hava", true)) SetWeather(strval(a1));
        else SetWorldTime(strval(a1));
        Bildir(playerid, B_OK, "Ayarlandi.");
        return 1;
    }
    if(!strcmp(cmd, "/sethp", true) || !strcmp(cmd, "/setarmor", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        if(!strcmp(cmd, "/sethp", true)) SetPlayerHealth(h, float(strval(a2)));
        else SetPlayerArmour(h, float(strval(a2)));
        Bildir(playerid, B_OK, "Ayarlandi.");
        return 1;
    }
    if(!strcmp(cmd, "/healall", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerHealth(i, 100.0);
        SendClientMessageToAll(RENK_YESIL, "[ADMIN] Herkes iyilestirildi.");
        return 1;
    }
    if(!strcmp(cmd, "/ip", true))
    {
        if(!YetkiVar(playerid, 3)) return 1;
        new h = HedefAl(playerid, a1);
        if(h == -1) return 1;
        new ip[20], ad[MAX_PLAYER_NAME];
        GetPlayerIp(h, ip, sizeof(ip));
        GetPlayerName(h, ad, sizeof(ad));
        format(s, sizeof(s), "%s IP: %s", ad, ip);
        Bildir(playerid, B_BILGI, s);
        return 1;
    }
    // ------------------------------------------------ seviye 4: yetki verme
    if(!strcmp(cmd, "/yetkiler", true))
    {
        if(!YetkiVar(playerid, 1)) return 1;
        new d[1400], satir[64];
        for(new i = 0; i < AdminSayi; i++)
        {
            format(satir, sizeof(satir), "%s - Lv%d (%s)\n", AdminIsim[i], AdminLv[i], LvAd[AdminLv[i] > 5 ? 5 : AdminLv[i]]);
            strcat(d, satir);
        }
        if(AdminSayi == 0) format(d, sizeof(d), "Kayitli yetkili yok.");
        ShowPlayerDialog(playerid, DA_MSG, DIALOG_STYLE_MSGBOX, "Kayitli Yetkililer", d, "Tamam", "");
        return 1;
    }
    if(!strcmp(cmd, "/setrank", true))
    {
        if(!YetkiVar(playerid, 4)) return 1;
        if(!strlen(a1) || !strlen(a2)) return Bildir(playerid, B_HATA, "Kullanim: /setrank <id/isim> <0-5>   (0 = yetkiyi al)");
        new yeni = strval(a2), ad[MAX_PLAYER_NAME], h = HedefBul(a1), mevcut = 0, ben = Lv(playerid);
        if(yeni < 0 || yeni > 5 || a2[0] < '0' || a2[0] > '9') return Bildir(playerid, B_HATA, "Seviye 0 ile 5 arasinda olmali.");
        if(h == -2) return Bildir(playerid, B_HATA, "Birden fazla oyuncu eslesti, ID kullan.");
        if(h >= 0)
        {
            GetPlayerName(h, ad, sizeof(ad));
            mevcut = Lv(h);
            if(h == playerid) return Bildir(playerid, B_HATA, "Kendi yetkini degistiremezsin.");
        }
        else
        {
            if(a1[0] >= '0' && a1[0] <= '9') return Bildir(playerid, B_HATA, "Oyuncu bulunamadi.");
            format(ad, sizeof(ad), "%s", a1);
            for(new i = 0; i < AdminSayi; i++) if(!strcmp(AdminIsim[i], ad, true)) mevcut = AdminLv[i];
        }
        if(ben < 5 && (yeni >= ben || mevcut >= ben))
            return Bildir(playerid, B_YETKI, "Kendi seviyenden yuksek/esit yetki veremez veya alamazsin.");
        if(!YetkiAyarla(ad, yeni)) return Bildir(playerid, B_HATA, "Kaydedilemedi (scriptfiles/Admin var mi?).");
        new an[MAX_PLAYER_NAME];
        GetPlayerName(playerid, an, sizeof(an));
        if(yeni == 0) format(s, sizeof(s), "[ADMIN] %s, %s adli oyuncunun yetkisini aldi.", an, ad);
        else format(s, sizeof(s), "[ADMIN] %s, %s adli oyuncuyu Lv%d (%s) yapti.", an, ad, yeni, LvAd[yeni]);
        AdminMesaj(s);
        SonIslemEkle(s);
        if(h >= 0)
        {
            if(yeni == 0)
            {
                ToolsSifirla(h);
                AdmDuty[h] = false;
                SetPlayerColor(h, 0xFFFFFFFF);
                Bildir(h, B_SUNUCU, "Yetkin alindi.");
            }
            else
            {
                format(s, sizeof(s), "Yetkin guncellendi: Lv%d (%s). Menu: /admin", yeni, LvAd[yeni]);
                Bildir(h, B_SUNUCU, s);
            }
        }
        Bildir(playerid, B_OK, "Yetki ayarlandi.");
        return 1;
    }
    return 0;
}

public OnPlayerText(playerid, text[])
{
    if(MuteKalan[playerid] > 0)
    {
        new s[64];
        format(s, sizeof(s), "Susturuldun. Kalan: %d sn", MuteKalan[playerid]);
        Bildir(playerid, B_HATA, s);
        return 0;
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    new cmd[24], a1[32], a2[8];
    Ayir(cmdtext, ' ', 0, cmd, sizeof(cmd));
    Ayir(cmdtext, ' ', 1, a1, sizeof(a1));
    Ayir(cmdtext, ' ', 2, a2, sizeof(a2));

    if(!strcmp(cmd, "/rapor", true))
    {
        new pos = strfind(cmdtext, " ");
        if(pos < 0 || strlen(cmdtext) <= pos + 1) return Bildir(playerid, B_HATA, "Kullanim: /rapor <mesaj>");
        new ad[MAX_PLAYER_NAME], t[12], msg[64], s[144];
        GetPlayerName(playerid, ad, sizeof(ad));
        Saat2(t, sizeof(t));
        strmid(msg, cmdtext, pos + 1, strlen(cmdtext), sizeof(msg));
        format(Rapor[RaporSayi % 10], 110, "%s [%d] %s: %s", t, playerid, ad, msg);
        RaporSayi++;
        format(s, sizeof(s), "[RAPOR] [%d] %s: %s", playerid, ad, msg);
        AdminMesaj(s);
        Bildir(playerid, B_OK, "Raporun yetkililere iletildi.");
        return 1;
    }
    if(!strcmp(cmd, "/menu", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        AnaListe(playerid);
        return 1;
    }

    if(!strcmp(cmd, "/admin", true) || !strcmp(cmd, "/a", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        AnaMenu(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/duty", true) || !strcmp(cmd, "/dupty", true) || !strcmp(cmd, "/adminduty", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        DutyAyarla(playerid, !AdmDuty[playerid]);
        return 1;
    }
    if(!strcmp(cmd, "/nc", true) || !strcmp(cmd, "/noclip", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        if(!DutyVar(playerid)) return 1;
        if(AdmNoclip[playerid]) NoclipKapat(playerid); else NoclipAc(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/ncpanel", true))
    {
        if(!AdmNoclip[playerid]) return Bildir(playerid, B_HATA, "Noclip acik degil.");
        NcTouch[playerid] = true;
        NcPanelGoster(playerid);
        SelectTextDraw(playerid, 0xBB86FCFF);
        return 1;
    }
    if(!strcmp(cmd, "/fly", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        if(!DutyVar(playerid)) return 1;
        ToolIslem(playerid, 1);
        return 1;
    }
    if(!strcmp(cmd, "/inv", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        if(!DutyVar(playerid)) return 1;
        InvAyarla(playerid, !AdmInv[playerid]);
        Bildir(playerid, B_OK, AdmInv[playerid] ? ("Invisible ACIK.") : ("Invisible KAPALI."));
        return 1;
    }
    if(!strcmp(cmd, "/god", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        if(!DutyVar(playerid)) return 1;
        AdmGod[playerid] = !AdmGod[playerid];
        Bildir(playerid, B_OK, AdmGod[playerid] ? ("Godmode ACIK.") : ("Godmode KAPALI."));
        return 1;
    }
    if(!strcmp(cmd, "/specoff", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        if(SpecDurdur(playerid)) Bildir(playerid, B_OK, "Spectate KAPALI.");
        else Bildir(playerid, B_HATA, "Spectate acik degil.");
        return 1;
    }
    if(!strcmp(cmd, "/adminler", true))
    {
        if(Lv(playerid) < 1) return Bildir(playerid, B_YETKI, "Yetkin yok.");
        new s[96], ad[MAX_PLAYER_NAME];
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || Lv(i) < 1) continue;
            GetPlayerName(i, ad, sizeof(ad));
            format(s, sizeof(s), "[%d] %s - %s%s", i, ad, LvAd[Lv(i)], AdmDuty[i] ? (" (Duty)") : (""));
            SendClientMessage(playerid, RENK_ADMIN, s);
        }
        return 1;
    }
    if(!strcmp(cmd, "/adminver", true) || !strcmp(cmd, "/adminsil", true))
    {
        if(Lv(playerid) < 5) return Bildir(playerid, B_YETKI, "Sadece seviye 5 / RCON admin.");
        new id = strval(a1), lv = strval(a2);
        if(!strcmp(cmd, "/adminsil", true)) lv = 0;
        if(!strlen(a1) || !IsPlayerConnected(id) || lv < 0 || lv > 5)
            return Bildir(playerid, B_HATA, "Kullanim: /adminver <id> <1-5>   |   /adminsil <id>");
        new hn[MAX_PLAYER_NAME], s[100];
        GetPlayerName(id, hn, sizeof(hn));
        if(!YetkiAyarla(hn, lv)) return Bildir(playerid, B_HATA, "Kaydedilemedi (scriptfiles/Admin var mi?).");
        format(s, sizeof(s), "%s yetkisi: %d (%s).", hn, lv, LvAd[lv]);
        Bildir(playerid, B_OK, s);
        Bildir(id, B_SUNUCU, "Yetkin guncellendi. /admin");
        SonIslemEkle(s);
        return 1;
    }
    return AdmKomut(playerid, cmdtext);
}
