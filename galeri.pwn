/*
    XYRAL ROLEPLAY - ARAC GALERISI + GARAJ + ARAC KONTROL (filterscript)
    Sadece oyuncu tarafi. Admin sistemine dokunmaz.

    Ozellikler:
      - Galeri: 8 kategori, fiyat ve hiz bilgisi, dokunmatik dialog menuleri
      - Satin alinan arac karakterin garajina kaydedilir (dosyada, sunucu kapansa da kalir)
      - /araclarim : garajdan arac cikar, garaja al, plaka goster, sat
      - /kilit /motor /far /bagaj /kaput : arac kontrolu
      - /konum : kendi koordinatini gosterir (galeri yerini ayarlamak icin)

    Kurulum:
      1) oyuncu.pwn de guncel olmali (OyuncuPara, OyuncuParaEkle fonksiyonlari)
      2) server.cfg:  filterscripts oyuncu galeri admin   (oyuncu, galeriden ONCE gelmeli)
      3) scriptfiles/Karakter klasoru olmali (zaten var)
    Dosyada Turkce ozel karakter yok.
*/

#define FILTERSCRIPT

#include <a_samp>

#define GAL_X           1498.0
#define GAL_Y           -1710.0
#define GAL_Z           14.0
#define GAL_MESAFE      40.0

#define MAX_GARAJ       10
#define KAT_SAYISI      8
#define LISTE_MAX       24
#define SATIS_ORAN      60

enum
{
    D_GAL_KAT = 9100,
    D_GAL_LISTE,
    D_GAL_ONAY,
    D_GRJ_LISTE,
    D_GRJ_ISLEM,
    D_GRJ_SAT
}

enum gInfo
{
    gKat,
    gModel,
    gFiyat,
    gHiz,
    gAd[20]
}

new const KatAd[KAT_SAYISI][12] =
{
    "Ekonomik", "Sedan", "Spor", "Luks", "SUV", "Motosiklet", "Ticari", "Klasik"
};

// kategori, model, fiyat, yaklasik maks hiz (km/s), ad
new GalVeri[][gInfo] =
{
    // 0 Ekonomik
    {0, 410, 4500, 140, "Manana"},
    {0, 404, 5000, 145, "Perennial"},
    {0, 436, 5500, 160, "Previon"},
    {0, 529, 6000, 155, "Willard"},
    {0, 549, 6500, 165, "Tampa"},
    {0, 419, 7000, 165, "Esperanto"},
    {0, 542, 7500, 180, "Clover"},
    {0, 496, 8000, 175, "Blista Compact"},
    // 1 Sedan
    {1, 546, 10000, 165, "Intruder"},
    {1, 561, 11000, 170, "Stratum"},
    {1, 426, 12000, 175, "Premier"},
    {1, 421, 14000, 170, "Washington"},
    {1, 551, 15000, 170, "Merit"},
    {1, 405, 16000, 180, "Sentinel"},
    {1, 445, 18000, 175, "Admiral"},
    // 2 Spor
    {2, 558, 36000, 190, "Uranus"},
    {2, 565, 38000, 195, "Flash"},
    {2, 559, 42000, 200, "Jester"},
    {2, 562, 45000, 200, "Elegy"},
    {2, 560, 55000, 195, "Sultan"},
    {2, 402, 60000, 200, "Buffalo"},
    {2, 429, 90000, 230, "Banshee"},
    // 3 Luks
    {3, 477, 95000, 210, "ZR-350"},
    {3, 480, 110000, 205, "Comet"},
    {3, 409, 120000, 170, "Stretch"},
    {3, 541, 150000, 235, "Bullet"},
    {3, 506, 160000, 220, "Super GT"},
    {3, 415, 170000, 225, "Cheetah"},
    {3, 451, 220000, 240, "Turismo"},
    {3, 411, 250000, 245, "Infernus"},
    // 4 SUV
    {4, 500, 18000, 145, "Mesa"},
    {4, 400, 22000, 160, "Landstalker"},
    {4, 489, 25000, 155, "Rancher"},
    {4, 579, 35000, 170, "Huntley"},
    {4, 495, 45000, 175, "Sandking"},
    // 5 Motosiklet
    {5, 462, 1500, 90, "Faggio"},
    {5, 448, 2500, 100, "Pizzaboy"},
    {5, 586, 7000, 125, "Wayfarer"},
    {5, 463, 9000, 130, "Freeway"},
    {5, 468, 10000, 130, "Sanchez"},
    {5, 581, 14000, 150, "BF-400"},
    {5, 461, 16000, 165, "PCJ-600"},
    {5, 521, 20000, 170, "FCR-900"},
    {5, 522, 60000, 190, "NRG-500"},
    // 6 Ticari
    {6, 478, 8000, 120, "Walton"},
    {6, 543, 8500, 135, "Sadler"},
    {6, 422, 12000, 140, "Bobcat"},
    {6, 482, 14000, 145, "Burrito"},
    {6, 413, 15000, 125, "Pony"},
    {6, 498, 18000, 120, "Boxville"},
    {6, 554, 20000, 150, "Yosemite"},
    {6, 499, 25000, 120, "Benson"},
    // 7 Klasik
    {7, 518, 15000, 170, "Buccaneer"},
    {7, 474, 17000, 160, "Hermes"},
    {7, 412, 20000, 175, "Voodoo"},
    {7, 576, 22000, 170, "Tornado"},
    {7, 536, 24000, 175, "Blade"},
    {7, 567, 25000, 175, "Savanna"},
    {7, 575, 26000, 170, "Broadway"},
    {7, 534, 28000, 175, "Remington"},
    {7, 535, 30000, 165, "Slamvan"}
};

// oyuncu basina
new GalSecim[MAX_PLAYERS];
new GalKatSecim[MAX_PLAYERS];
new GalListe[MAX_PLAYERS][LISTE_MAX];
new GalTick[MAX_PLAYERS];
new GrjSecim[MAX_PLAYERS];

new GSayi[MAX_PLAYERS];
new GModel[MAX_PLAYERS][MAX_GARAJ];
new GPlaka[MAX_PLAYERS][MAX_GARAJ][12];
new GR1[MAX_PLAYERS][MAX_GARAJ];
new GR2[MAX_PLAYERS][MAX_GARAJ];

// arac basina (oyunda cikarilmis araclar)
new VSahip[MAX_VEHICLES + 1];       // playerid + 1, 0 = sahipsiz
new VSlot[MAX_VEHICLES + 1];
new VPlaka[MAX_VEHICLES + 1][12];

new GalPickup;
new Text3D:GalEtiket;

// ---------------------------------------------------------------- yardimcilar

stock GetField(const src[], field, dest[], len)
{
    new start = 0, cur = 0;
    for(;;)
    {
        new pos = strfind(src, "|", false, start);
        if(cur == field)
        {
            if(pos == -1) strmid(dest, src, start, strlen(src), len);
            else strmid(dest, src, start, pos, len);
            return 1;
        }
        if(pos == -1)
        {
            dest[0] = 0;
            return 0;
        }
        start = pos + 1;
        cur++;
    }
    return 0;
}

stock OyuncuHazir(playerid)
{
    if(CallRemoteFunction("OyuncuDurum", "i", playerid) != 3)
    {
        SendClientMessage(playerid, 0xE74C3CFF, "Once bir karakterle oyuna girmelisin.");
        return 0;
    }
    return 1;
}

stock OyuncuSlotAl(playerid)
{
    return CallRemoteFunction("OyuncuSlot", "i", playerid);
}

stock GalYakin(playerid)
{
    return IsPlayerInRangeOfPoint(playerid, GAL_MESAFE, GAL_X, GAL_Y, GAL_Z);
}

stock GalAdBul(model, ad[], len)
{
    for(new i = 0; i < sizeof(GalVeri); i++)
    {
        if(GalVeri[i][gModel] == model)
        {
            format(ad, len, "%s", GalVeri[i][gAd]);
            return 1;
        }
    }
    format(ad, len, "Arac %d", model);
    return 0;
}

stock GalFiyatBul(model)
{
    for(new i = 0; i < sizeof(GalVeri); i++)
    {
        if(GalVeri[i][gModel] == model) return GalVeri[i][gFiyat];
    }
    return 0;
}

stock PlakaUret(plaka[])
{
    format(plaka, 12, "%02d %c%c%c %03d", 1 + random(81), 'A' + random(26), 'A' + random(26), 'A' + random(26), random(1000));
}

// ---------------------------------------------------------------- garaj dosyasi

stock GarajYolu(playerid, yol[])
{
    new n[MAX_PLAYER_NAME];
    GetPlayerName(playerid, n, sizeof(n));
    format(yol, 64, "Karakter/Garaj_%s_%d.txt", n, OyuncuSlotAl(playerid));
}

stock GarajYukle(playerid)
{
    GSayi[playerid] = 0;
    new yol[64];
    GarajYolu(playerid, yol);
    if(!fexist(yol)) return 1;
    new File:f = fopen(yol, io_read);
    if(!f) return 0;
    new satir[96], t[16];
    while(fread(f, satir) && GSayi[playerid] < MAX_GARAJ)
    {
        GetField(satir, 0, t, sizeof(t));
        new m = strval(t);
        if(m < 400 || m > 611) continue;
        new i = GSayi[playerid];
        GModel[playerid][i] = m;
        GetField(satir, 1, GPlaka[playerid][i], 12);
        GetField(satir, 2, t, sizeof(t)); GR1[playerid][i] = strval(t);
        GetField(satir, 3, t, sizeof(t)); GR2[playerid][i] = strval(t);
        GSayi[playerid]++;
    }
    fclose(f);
    return 1;
}

stock GarajKaydet(playerid)
{
    new yol[64];
    GarajYolu(playerid, yol);
    new File:f = fopen(yol, io_write);
    if(!f) return 0;
    new satir[64];
    for(new i = 0; i < GSayi[playerid]; i++)
    {
        format(satir, sizeof(satir), "%d|%s|%d|%d|\n", GModel[playerid][i], GPlaka[playerid][i], GR1[playerid][i], GR2[playerid][i]);
        fwrite(f, satir);
    }
    fclose(f);
    return 1;
}

// ---------------------------------------------------------------- arac olusturma / takip

stock AracSil(v)
{
    VSahip[v] = 0;
    VSlot[v] = 0;
    VPlaka[v][0] = 0;
    DestroyVehicle(v);
}

stock SahipMi(playerid, v)
{
    if(v < 1 || v > MAX_VEHICLES) return 0;
    if(VSahip[v] != playerid + 1) return 0;
    if(VSlot[v] != OyuncuSlotAl(playerid)) return 0;
    return 1;
}

stock AracBul(playerid, const plaka[])
{
    new slot = OyuncuSlotAl(playerid);
    for(new v = 1; v <= MAX_VEHICLES; v++)
    {
        if(VSahip[v] != playerid + 1) continue;
        if(VSlot[v] != slot) continue;
        if(!GetVehicleModel(v)) continue;
        if(!strcmp(VPlaka[v], plaka, true)) return v;
    }
    return 0;
}

stock AracCikar(playerid, model, const plaka[], r1, r2, bool:motorAcik)
{
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    new v = CreateVehicle(model, x + 3.0 * floatsin(-a, degrees), y + 3.0 * floatcos(-a, degrees), z + 0.5, a, r1, r2, -1);
    if(v == INVALID_VEHICLE_ID) return 0;
    SetVehicleNumberPlate(v, plaka);
    SetVehicleToRespawn(v);
    LinkVehicleToInterior(v, GetPlayerInterior(playerid));
    SetVehicleVirtualWorld(v, GetPlayerVirtualWorld(playerid));
    SetVehicleParamsEx(v, (motorAcik) ? (1) : (0), 0, 0, 0, 0, 0, 0);
    VSahip[v] = playerid + 1;
    VSlot[v] = OyuncuSlotAl(playerid);
    format(VPlaka[v], 12, "%s", plaka);
    return v;
}

stock YakinAracim(playerid, Float:mesafe = 6.0)
{
    if(IsPlayerInAnyVehicle(playerid))
    {
        new pv = GetPlayerVehicleID(playerid);
        if(SahipMi(playerid, pv)) return pv;
    }
    new Float:x, Float:y, Float:z, Float:enYakin = mesafe + 1.0, bul = 0;
    for(new v = 1; v <= MAX_VEHICLES; v++)
    {
        if(!SahipMi(playerid, v)) continue;
        if(!GetVehicleModel(v)) continue;
        GetVehiclePos(v, x, y, z);
        new Float:d = GetPlayerDistanceFromPoint(playerid, x, y, z);
        if(d < mesafe && d < enYakin)
        {
            enYakin = d;
            bul = v;
        }
    }
    return bul;
}

// ne: 0 motor, 1 far, 2 kapi kilidi, 3 kaput, 4 bagaj. Yeni durumu dondurur (1 acik/kilitli)
stock AracParamDegistir(v, ne)
{
    new motor, isik, alarm, kapi, kaput, bagaj, obje, yeni = 0;
    GetVehicleParamsEx(v, motor, isik, alarm, kapi, kaput, bagaj, obje);
    switch(ne)
    {
        case 0: { motor = (motor == 1) ? 0 : 1; yeni = motor; }
        case 1: { isik = (isik == 1) ? 0 : 1; yeni = isik; }
        case 2: { kapi = (kapi == 1) ? 0 : 1; yeni = kapi; }
        case 3: { kaput = (kaput == 1) ? 0 : 1; yeni = kaput; }
        case 4: { bagaj = (bagaj == 1) ? 0 : 1; yeni = bagaj; }
    }
    SetVehicleParamsEx(v, motor, isik, alarm, kapi, kaput, bagaj, obje);
    return yeni;
}

// ---------------------------------------------------------------- galeri menuleri

stock GalKatGoster(playerid)
{
    new s[160];
    for(new i = 0; i < KAT_SAYISI; i++)
    {
        strcat(s, KatAd[i]);
        if(i < KAT_SAYISI - 1) strcat(s, "\n");
    }
    ShowPlayerDialog(playerid, D_GAL_KAT, DIALOG_STYLE_LIST, "Arac Galerisi", s, "Sec", "Kapat");
}

stock GalListeGoster(playerid, kat)
{
    new s[900], t[80], n = 0;
    GalKatSecim[playerid] = kat;
    format(s, sizeof(s), "Arac\tFiyat\tHiz (~km/s)\n");
    for(new i = 0; i < sizeof(GalVeri); i++)
    {
        if(GalVeri[i][gKat] != kat) continue;
        if(n >= LISTE_MAX) break;
        GalListe[playerid][n] = i;
        n++;
        format(t, sizeof(t), "%s\t$%d\t%d\n", GalVeri[i][gAd], GalVeri[i][gFiyat], GalVeri[i][gHiz]);
        strcat(s, t);
    }
    ShowPlayerDialog(playerid, D_GAL_LISTE, DIALOG_STYLE_TABLIST_HEADERS, KatAd[kat], s, "Sec", "Geri");
}

stock GalOnayGoster(playerid, idx)
{
    new s[300];
    GalSecim[playerid] = idx;
    format(s, sizeof(s), "Arac: %s\nFiyat: $%d\nMaks hiz: ~%d km/s\nBakiyen: $%d\n\nSatin almak istiyor musun?",
        GalVeri[idx][gAd], GalVeri[idx][gFiyat], GalVeri[idx][gHiz], CallRemoteFunction("OyuncuPara", "i", playerid));
    ShowPlayerDialog(playerid, D_GAL_ONAY, DIALOG_STYLE_MSGBOX, "Satin Al", s, "Satin Al", "Geri");
}

stock SatinAl(playerid)
{
    if(!OyuncuHazir(playerid)) return 0;
    if(!GalYakin(playerid))
    {
        SendClientMessage(playerid, 0xE74C3CFF, "Galeriden uzaksin.");
        return 0;
    }
    new idx = GalSecim[playerid];
    if(idx < 0 || idx >= sizeof(GalVeri)) return 0;
    new fiyat = GalVeri[idx][gFiyat];
    GarajYukle(playerid);
    if(GSayi[playerid] >= MAX_GARAJ)
    {
        SendClientMessage(playerid, 0xE74C3CFF, "Garajin dolu (en fazla 10 arac). Once bir araci sat.");
        return 0;
    }
    if(CallRemoteFunction("OyuncuPara", "i", playerid) < fiyat)
    {
        SendClientMessage(playerid, 0xE74C3CFF, "Yeterli paran yok.");
        return 0;
    }
    if(!CallRemoteFunction("OyuncuParaEkle", "ii", playerid, -fiyat))
    {
        SendClientMessage(playerid, 0xE74C3CFF, "Odeme yapilamadi.");
        return 0;
    }
    new i = GSayi[playerid];
    GModel[playerid][i] = GalVeri[idx][gModel];
    PlakaUret(GPlaka[playerid][i]);
    GR1[playerid][i] = random(126);
    GR2[playerid][i] = random(126);
    GSayi[playerid]++;
    GarajKaydet(playerid);

    new v = AracCikar(playerid, GModel[playerid][i], GPlaka[playerid][i], GR1[playerid][i], GR2[playerid][i], true);
    new s[144];
    format(s, sizeof(s), "%s satin aldin! Plaka: %s. Arac garajina kaydedildi (/araclarim).", GalVeri[idx][gAd], GPlaka[playerid][i]);
    SendClientMessage(playerid, 0x2ECC71FF, s);
    if(v && !IsPlayerInAnyVehicle(playerid)) PutPlayerInVehicle(playerid, v, 0);
    return 1;
}

// ---------------------------------------------------------------- garaj menuleri

stock GarajGoster(playerid)
{
    if(!OyuncuHazir(playerid)) return 0;
    GarajYukle(playerid);
    if(GSayi[playerid] == 0)
    {
        SendClientMessage(playerid, 0x3498DBFF, "Garajin bos. Araba almak icin galeriye git (/galeri).");
        return 0;
    }
    new s[600], t[96], ad[24];
    format(s, sizeof(s), "Arac\tPlaka\tDurum\n");
    for(new i = 0; i < GSayi[playerid]; i++)
    {
        GalAdBul(GModel[playerid][i], ad, sizeof(ad));
        format(t, sizeof(t), "%s\t%s\t%s\n", ad, GPlaka[playerid][i], (AracBul(playerid, GPlaka[playerid][i])) ? ("Disarida") : ("Garajda"));
        strcat(s, t);
    }
    ShowPlayerDialog(playerid, D_GRJ_LISTE, DIALOG_STYLE_TABLIST_HEADERS, "Araclarim", s, "Sec", "Kapat");
    return 1;
}

// ---------------------------------------------------------------- callback'ler

public OnFilterScriptInit()
{
    GalPickup = CreatePickup(1239, 1, GAL_X, GAL_Y, GAL_Z, 0);
    GalEtiket = Create3DTextLabel("ARAC GALERISI\n/galeri", 0x3498DBFF, GAL_X, GAL_Y, GAL_Z + 0.8, 25.0, 0, 0);
    print("[galeri] Arac galerisi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    for(new v = 1; v <= MAX_VEHICLES; v++)
    {
        if(VSahip[v]) AracSil(v);
    }
    DestroyPickup(GalPickup);
    Delete3DTextLabel(GalEtiket);
    return 1;
}

public OnPlayerConnect(playerid)
{
    GalTick[playerid] = 0;
    GSayi[playerid] = 0;
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    for(new v = 1; v <= MAX_VEHICLES; v++)
    {
        if(VSahip[v] == playerid + 1) AracSil(v);
    }
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(pickupid != GalPickup) return 1;
    if(GetTickCount() - GalTick[playerid] < 4000) return 1;
    GalTick[playerid] = GetTickCount();
    if(CallRemoteFunction("OyuncuDurum", "i", playerid) != 3) return 1;
    GalKatGoster(playerid);
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER)
    {
        new v = GetPlayerVehicleID(playerid);
        new motor, isik, alarm, kapi, kaput, bagaj, obje;
        GetVehicleParamsEx(v, motor, isik, alarm, kapi, kaput, bagaj, obje);
        if(VSahip[v] && motor != 1)
        {
            if(SahipMi(playerid, v)) SendClientMessage(playerid, 0x3498DBFF, "Motor kapali. Calistirmak icin /motor yaz.");
            else SendClientMessage(playerid, 0xE74C3CFF, "Motor kapali ve bu arac senin degil.");
        }
    }
    return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
    if(vehicleid >= 1 && vehicleid <= MAX_VEHICLES && VSahip[vehicleid])
    {
        new sahip = VSahip[vehicleid] - 1;
        if(IsPlayerConnected(sahip)) SendClientMessage(sahip, 0xE74C3CFF, "Araciniz yok oldu. /araclarim ile garajindan tekrar cikarabilirsin.");
        AracSil(vehicleid);
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case D_GAL_KAT:
        {
            if(!response) return 1;
            if(listitem < 0 || listitem >= KAT_SAYISI) return 1;
            GalListeGoster(playerid, listitem);
            return 1;
        }
        case D_GAL_LISTE:
        {
            if(!response) { GalKatGoster(playerid); return 1; }
            if(listitem < 0 || listitem >= LISTE_MAX) return 1;
            new idx = GalListe[playerid][listitem];
            if(idx < 0 || idx >= sizeof(GalVeri)) return 1;
            GalOnayGoster(playerid, idx);
            return 1;
        }
        case D_GAL_ONAY:
        {
            if(!response) { GalListeGoster(playerid, GalKatSecim[playerid]); return 1; }
            SatinAl(playerid);
            return 1;
        }
        case D_GRJ_LISTE:
        {
            if(!response) return 1;
            GarajYukle(playerid);
            if(listitem < 0 || listitem >= GSayi[playerid]) return 1;
            GrjSecim[playerid] = listitem;
            new baslik[48], ad[24];
            GalAdBul(GModel[playerid][listitem], ad, sizeof(ad));
            format(baslik, sizeof(baslik), "%s  [%s]", ad, GPlaka[playerid][listitem]);
            ShowPlayerDialog(playerid, D_GRJ_ISLEM, DIALOG_STYLE_LIST, baslik,
                "Yanima Cikar\nGaraja Al (Park)\nPlaka Goster\nAraci Sat", "Sec", "Geri");
            return 1;
        }
        case D_GRJ_ISLEM:
        {
            if(!response) { GarajGoster(playerid); return 1; }
            GarajYukle(playerid);
            new i = GrjSecim[playerid];
            if(i < 0 || i >= GSayi[playerid]) return 1;
            switch(listitem)
            {
                case 0:
                {
                    if(AracBul(playerid, GPlaka[playerid][i]))
                    {
                        SendClientMessage(playerid, 0xE74C3CFF, "Bu arac zaten disarida.");
                        return 1;
                    }
                    if(IsPlayerInAnyVehicle(playerid))
                    {
                        SendClientMessage(playerid, 0xE74C3CFF, "Aractayken arac cikaramazsin.");
                        return 1;
                    }
                    if(!AracCikar(playerid, GModel[playerid][i], GPlaka[playerid][i], GR1[playerid][i], GR2[playerid][i], false))
                    {
                        SendClientMessage(playerid, 0xE74C3CFF, "Arac olusturulamadi.");
                        return 1;
                    }
                    SendClientMessage(playerid, 0x2ECC71FF, "Araciniz yaninda. Motor icin /motor, kilit icin /kilit.");
                }
                case 1:
                {
                    new v = AracBul(playerid, GPlaka[playerid][i]);
                    if(!v)
                    {
                        SendClientMessage(playerid, 0xE74C3CFF, "Bu arac zaten garajda.");
                        return 1;
                    }
                    new Float:x, Float:y, Float:z;
                    GetVehiclePos(v, x, y, z);
                    if(GetPlayerVehicleID(playerid) != v && GetPlayerDistanceFromPoint(playerid, x, y, z) > 20.0)
                    {
                        SendClientMessage(playerid, 0xE74C3CFF, "Araca 20 metreden yakin olmalisin.");
                        return 1;
                    }
                    AracSil(v);
                    SendClientMessage(playerid, 0x2ECC71FF, "Arac garaja alindi.");
                }
                case 2:
                {
                    new s[64];
                    format(s, sizeof(s), "Plaka: %s", GPlaka[playerid][i]);
                    SendClientMessage(playerid, 0x3498DBFF, s);
                }
                case 3:
                {
                    new s[160], ad[24];
                    GalAdBul(GModel[playerid][i], ad, sizeof(ad));
                    format(s, sizeof(s), "%s (%s) araci satilsin mi?\nSatis fiyati: $%d (galeri fiyatinin %%%d'i)", ad, GPlaka[playerid][i],
                        GalFiyatBul(GModel[playerid][i]) * SATIS_ORAN / 100, SATIS_ORAN);
                    ShowPlayerDialog(playerid, D_GRJ_SAT, DIALOG_STYLE_MSGBOX, "Araci Sat", s, "Sat", "Vazgec");
                }
            }
            return 1;
        }
        case D_GRJ_SAT:
        {
            if(!response) return 1;
            if(!OyuncuHazir(playerid)) return 1;
            GarajYukle(playerid);
            new i = GrjSecim[playerid];
            if(i < 0 || i >= GSayi[playerid]) return 1;
            new fiyat = GalFiyatBul(GModel[playerid][i]) * SATIS_ORAN / 100;
            new v = AracBul(playerid, GPlaka[playerid][i]);
            if(v) AracSil(v);
            for(new j = i; j < GSayi[playerid] - 1; j++)
            {
                GModel[playerid][j] = GModel[playerid][j + 1];
                format(GPlaka[playerid][j], 12, "%s", GPlaka[playerid][j + 1]);
                GR1[playerid][j] = GR1[playerid][j + 1];
                GR2[playerid][j] = GR2[playerid][j + 1];
            }
            GSayi[playerid]--;
            GarajKaydet(playerid);
            CallRemoteFunction("OyuncuParaEkle", "ii", playerid, fiyat);
            new s[64];
            format(s, sizeof(s), "Araci sattin ve $%d aldin.", fiyat);
            SendClientMessage(playerid, 0x2ECC71FF, s);
            return 1;
        }
    }
    return 0;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!strcmp(cmdtext, "/galeri", true))
    {
        if(!OyuncuHazir(playerid)) return 1;
        if(!GalYakin(playerid))
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Galeriden uzaksin. Telefon > GPS > Arac Galerisi ile isaretle.");
            return 1;
        }
        GalKatGoster(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/araclarim", true))
    {
        GarajGoster(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/kilit", true))
    {
        if(!OyuncuHazir(playerid)) return 1;
        new v = YakinAracim(playerid);
        if(!v)
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Yakinda senin araban yok. (/araclarim ile cikarabilirsin)");
            return 1;
        }
        if(AracParamDegistir(v, 2)) SendClientMessage(playerid, 0x2ECC71FF, "Arac kilitlendi.");
        else SendClientMessage(playerid, 0x2ECC71FF, "Arac kilidi acildi.");
        return 1;
    }
    if(!strcmp(cmdtext, "/motor", true))
    {
        if(!OyuncuHazir(playerid)) return 1;
        if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Surucu koltugunda olmalisin.");
            return 1;
        }
        new v = GetPlayerVehicleID(playerid);
        if(!SahipMi(playerid, v))
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Bu arac senin degil.");
            return 1;
        }
        if(AracParamDegistir(v, 0)) SendClientMessage(playerid, 0x2ECC71FF, "Motor calistirildi.");
        else SendClientMessage(playerid, 0x2ECC71FF, "Motor kapatildi.");
        return 1;
    }
    if(!strcmp(cmdtext, "/far", true))
    {
        if(!OyuncuHazir(playerid)) return 1;
        if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Surucu koltugunda olmalisin.");
            return 1;
        }
        if(AracParamDegistir(GetPlayerVehicleID(playerid), 1)) SendClientMessage(playerid, 0x2ECC71FF, "Farlar acildi.");
        else SendClientMessage(playerid, 0x2ECC71FF, "Farlar kapatildi.");
        return 1;
    }
    if(!strcmp(cmdtext, "/kaput", true) || !strcmp(cmdtext, "/bagaj", true))
    {
        if(!OyuncuHazir(playerid)) return 1;
        new v = YakinAracim(playerid);
        if(!v)
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Yakinda senin araban yok.");
            return 1;
        }
        if(!strcmp(cmdtext, "/kaput", true))
        {
            if(AracParamDegistir(v, 3)) SendClientMessage(playerid, 0x2ECC71FF, "Kaput acildi.");
            else SendClientMessage(playerid, 0x2ECC71FF, "Kaput kapatildi.");
        }
        else
        {
            if(AracParamDegistir(v, 4)) SendClientMessage(playerid, 0x2ECC71FF, "Bagaj acildi.");
            else SendClientMessage(playerid, 0x2ECC71FF, "Bagaj kapatildi.");
        }
        return 1;
    }
    if(!strcmp(cmdtext, "/plaka", true))
    {
        if(!OyuncuHazir(playerid)) return 1;
        new v = YakinAracim(playerid);
        if(!v)
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Yakinda senin araban yok.");
            return 1;
        }
        new s[48];
        format(s, sizeof(s), "Plaka: %s", VPlaka[v]);
        SendClientMessage(playerid, 0x3498DBFF, s);
        return 1;
    }
    if(!strcmp(cmdtext, "/konum", true))
    {
        new Float:x, Float:y, Float:z, Float:a, s[96];
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, a);
        format(s, sizeof(s), "Konum: %.1f, %.1f, %.1f  Aci: %.1f", x, y, z, a);
        SendClientMessage(playerid, 0x3498DBFF, s);
        return 1;
    }
    return 0;
}
