// =====================================================================
//  mekan.pwn - Bina giris/cikis sistemi (oyuncular icin)
//  Okla isaretli pickup'a yuruyerek girilir/cikilir (mobil icin ideal).
//  Yedek: kapinin yaninda /gir ve /cik komutlari.
//
//  Yeni bina eklemek icin asagidaki Mekanlar listesine bir satir ekle
//  ve MAX_MEKAN sayisini artir.
//
//  server.cfg:  filterscripts oyuncu galeri admin oyuncu2 mekan
// =====================================================================

#include <a_samp>

#define MAX_MEKAN        3
#define PICKUP_MODEL     1318      // yesil ok
#define GIRIS_BEKLEME    3000      // ms, ust uste girisi engeller

enum E_MEKAN
{
    mkAd[32],
    Float:mkDisX, Float:mkDisY, Float:mkDisZ, Float:mkDisA,
    mkInt,
    Float:mkIcX, Float:mkIcY, Float:mkIcZ, Float:mkIcA
}

// Ad, DIS (x, y, z, aci), interior id, IC (x, y, z, aci)
// NOT: Koordinatlar standart SA-MP interior listesinden; gerekirse oyunda kontrol edip duzelt.
new const Mekanlar[MAX_MEKAN][E_MEKAN] =
{
    {"Los Santos Polis Departmani", 1554.5, -1675.6, 16.2, 90.0,  6, 246.78, 63.90, 1003.64, 0.0},
    {"Los Santos Belediyesi",       1481.0, -1767.8, 18.8, 0.0,   3, 390.77, 173.80, 1008.38, 90.0},
    {"All Saints Hastanesi",        1177.8, -1323.7, 14.0, 270.0, 17, -25.88, -185.87, 1003.55, 0.0}
};
// NOT: GTA SA'da yuruyerek girilebilen gercek bir hastane ici yok. Hastane icin gecici olarak
// "24/7 market" interior'u kullanildi. Daha uygun bir interior bulursan son satirdaki
// interior id (17) ve ic koordinatlari degistir.

new MekanDisPickup[MAX_MEKAN];
new MekanIcPickup[MAX_MEKAN];
new Text3D:MekanDisLabel[MAX_MEKAN];
new Text3D:MekanIcLabel[MAX_MEKAN];
new SonGiris[MAX_PLAYERS];

stock MekanGir(playerid, m)
{
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, 0xFF6347FF, "Aractayken binaya giremezsin.");
        return 0;
    }
    SetPlayerInterior(playerid, Mekanlar[m][mkInt]);
    SetPlayerPos(playerid, Mekanlar[m][mkIcX], Mekanlar[m][mkIcY], Mekanlar[m][mkIcZ]);
    SetPlayerFacingAngle(playerid, Mekanlar[m][mkIcA]);
    SetCameraBehindPlayer(playerid);
    new msg[96];
    format(msg, sizeof msg, "%s binasina girdin.", Mekanlar[m][mkAd]);
    SendClientMessage(playerid, 0x33CCFFFF, msg);
    return 1;
}

stock MekanCik(playerid, m)
{
    SetPlayerInterior(playerid, 0);
    SetPlayerPos(playerid, Mekanlar[m][mkDisX], Mekanlar[m][mkDisY], Mekanlar[m][mkDisZ]);
    SetPlayerFacingAngle(playerid, Mekanlar[m][mkDisA] + 180.0);
    SetCameraBehindPlayer(playerid);
    return 1;
}

public OnFilterScriptInit()
{
    for (new m = 0; m < MAX_MEKAN; m++)
    {
        new txt[64];
        MekanDisPickup[m] = CreatePickup(PICKUP_MODEL, 1, Mekanlar[m][mkDisX], Mekanlar[m][mkDisY], Mekanlar[m][mkDisZ], -1);
        format(txt, sizeof txt, "%s\n(Girmek icin oka yuru)", Mekanlar[m][mkAd]);
        MekanDisLabel[m] = Create3DTextLabel(txt, 0xFFFF66FF, Mekanlar[m][mkDisX], Mekanlar[m][mkDisY], Mekanlar[m][mkDisZ] + 0.8, 20.0, 0, 0);

        MekanIcPickup[m] = CreatePickup(PICKUP_MODEL, 1, Mekanlar[m][mkIcX], Mekanlar[m][mkIcY], Mekanlar[m][mkIcZ], -1);
        MekanIcLabel[m] = Create3DTextLabel("Cikis\n(Cikmak icin oka yuru)", 0xFFFF66FF, Mekanlar[m][mkIcX], Mekanlar[m][mkIcY], Mekanlar[m][mkIcZ] + 0.8, 15.0, 0, 0);
    }
    print("[mekan] Bina giris/cikis sistemi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    for (new m = 0; m < MAX_MEKAN; m++)
    {
        DestroyPickup(MekanDisPickup[m]);
        DestroyPickup(MekanIcPickup[m]);
        Delete3DTextLabel(MekanDisLabel[m]);
        Delete3DTextLabel(MekanIcLabel[m]);
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    SonGiris[playerid] = 0;
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if (GetTickCount() - SonGiris[playerid] < GIRIS_BEKLEME) return 1;
    for (new m = 0; m < MAX_MEKAN; m++)
    {
        if (pickupid == MekanDisPickup[m])
        {
            SonGiris[playerid] = GetTickCount();
            MekanGir(playerid, m);
            return 1;
        }
        if (pickupid == MekanIcPickup[m])
        {
            SonGiris[playerid] = GetTickCount();
            MekanCik(playerid, m);
            return 1;
        }
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!strcmp(cmdtext, "/gir", true))
    {
        for (new m = 0; m < MAX_MEKAN; m++)
        {
            if (GetPlayerInterior(playerid) == 0 && IsPlayerInRangeOfPoint(playerid, 3.0, Mekanlar[m][mkDisX], Mekanlar[m][mkDisY], Mekanlar[m][mkDisZ]))
            {
                MekanGir(playerid, m);
                return 1;
            }
        }
        SendClientMessage(playerid, 0xFF6347FF, "Yakinda girilecek bir bina yok.");
        return 1;
    }
    if (!strcmp(cmdtext, "/cik", true))
    {
        for (new m = 0; m < MAX_MEKAN; m++)
        {
            if (GetPlayerInterior(playerid) == Mekanlar[m][mkInt] && IsPlayerInRangeOfPoint(playerid, 3.0, Mekanlar[m][mkIcX], Mekanlar[m][mkIcY], Mekanlar[m][mkIcZ]))
            {
                MekanCik(playerid, m);
                return 1;
            }
        }
        SendClientMessage(playerid, 0xFF6347FF, "Cikis noktasinin yaninda degilsin.");
        return 1;
    }
    return 0;
}
