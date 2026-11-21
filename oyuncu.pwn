/*
    XYRAL ROLEPLAY - OYUNCU DOSYASI (filterscript)
    Sadece oyuncu tarafi: acilis/yukleme ekrani, karakter secimi (3 slot), karakter degistirme,
    kiyafet degistirme, HUD, bolge adi, envanter, market ve SAG ALTTA OTOMATIK TELEFON.
    Admin paneli YOK (kendi gamemode'unda var).

    Telefon: oyuna girince sag altta kendiliginden gorunur. Uygulamalara basmak icin N tusuna
    bas (fare imleci acilir), uygulamaya tikla. ESC veya tekrar N ile imleci kapat.

    Kurulum:
      1) filterscripts/oyuncu.pwn olarak koy, derle -> oyuncu.amx
      2) server.cfg icinde:  filterscripts oyuncu
      3) mkdir -p scriptfiles/Karakter
      4) Gamemode'undaki kendi spawn/HUD/karakter kodunu kapat (cakisma olmasin).
    Dosyada Turkce ozel karakter yok (SA-MP kodlama sorunu olmasin diye).
*/

#define FILTERSCRIPT

#include <a_samp>

#define SUNUCU_ADI      "XYRAL ROLEPLAY"
#define MAX_SLOT        3
#define SKIN_SAYISI     310
#define KIYAFET_UCRETI  100

#define PRV_X   1481.0
#define PRV_Y   -1738.0
#define PRV_Z   13.55

#define SPAWN_X 1481.0
#define SPAWN_Y -1745.0
#define SPAWN_Z 13.55
#define HOSP_X  1177.5
#define HOSP_Y  -1323.9
#define HOSP_Z  14.0

#define BASILDI(%0) (((newkeys & (%0)) == (%0)) && ((oldkeys & (%0)) != (%0)))

enum
{
    D_YOK = 7000,
    D_SLOT,
    D_ISIM,
    D_ENV,
    D_ENV_ISLEM,
    D_MARKET,
    D_GPS,
    D_SMS,
    D_NOT,
    D_YARDIM,
    D_CINS,
    D_YAS,
    D_HOSGELDIN
}

enum pInfo
{
    pAd[25],
    pSkin,
    pPara,
    Float:pX,
    Float:pY,
    Float:pZ,
    Float:pA,
    pAclik,
    pSusuz,
    pEkmek,
    pSu,
    pBandaj,
    pNot[96],
    pDurum,     // 0 yukleme, 1 karakter secimi, 2 skin secimi, 3 oyunda
    pSlot,
    pMod,       // 1 yeni karakter, 2 kiyafet degistirme
    pSkinIdx,
    pTick,
    pOlu,
    pZone,
    pSecim,
    pCins,      // 1 erkek, 2 kadin
    pYas,
    bool:pHud,
    bool:pBasladi,
    bool:pTel
}
new PI[MAX_PLAYERS][pInfo];

// Global textdraw'lar
new Text:TdYuk, Text:TdYukBaslik, Text:TdYukAlt;
new Text:TdSkinBaslik, Text:TdSkinOnce, Text:TdSkinSec, Text:TdSkinSonra, Text:TdSkinIpucu;
// Telefon
new Text:TdTelCerceve, Text:TdTelEkran, Text:TdTelGPS, Text:TdTelSMS, Text:TdTelNot, Text:TdTelPara, Text:TdTelIpucu;

// Oyuncu textdraw'lari
new PlayerText:PtBg[MAX_PLAYERS][4];
new PlayerText:PtFill[MAX_PLAYERS][4];
new PlayerText:PtPara[MAX_PLAYERS];
new PlayerText:PtZone[MAX_PLAYERS];
new PlayerText:PtSkin[MAX_PLAYERS];
new PlayerText:PtSaat[MAX_PLAYERS];
new PlayerText:PtTelPara[MAX_PLAYERS];

new const Float:BolgeKutu[][4] =
{
    {2222.5, -1852.8, 2632.8, -1722.3},
    {1812.6, -1852.8, 2222.5, -1742.3},
    {1701.9, -1842.2, 1812.6, -1722.2},
    {1323.9, -1842.2, 1701.9, -1722.2},
    {1440.9, -1722.2, 1583.5, -1577.5},
    {1370.8, -1577.5, 1463.9, -1384.9},
    {787.4, -1416.2, 1072.6, -1310.2},
    {1812.6, -1449.6, 1996.9, -1350.0}
};
new const BolgeAd[][20] =
{
    "Ganton", "Idlewood", "Little Mexico", "Commerce",
    "Pershing Square", "Downtown LS", "Market", "Glen Park"
};

new const ItemAd[][12] = {"Ekmek", "Su", "Bandaj"};
new const ItemFiyat[3] = {10, 5, 25};

new const Float:GpsPos[][3] =
{
    {1177.5, -1323.9, 14.0},
    {1554.8, -1675.6, 16.2},
    {1481.0, -1738.0, 13.5}
};

forward LoadingBitti(playerid);
forward GenelZamanlayici();

// ---------------------------------------------------------------- yardimcilar

stock Float:StrFloat(const s[])
{
    new Float:r = 0.0, Float:b = 0.1, bool:neg = false, bool:nokta = false;
    for(new i = 0; s[i] != 0; i++)
    {
        if(s[i] == '-' && i == 0) { neg = true; continue; }
        if(s[i] == '.') { nokta = true; continue; }
        if(s[i] < '0' || s[i] > '9') break;
        if(nokta == false) r = r * 10.0 + float(s[i] - '0');
        else { r += float(s[i] - '0') * b; b *= 0.1; }
    }
    if(neg) r = -r;
    return r;
}

stock ResetPI(playerid)
{
    new bos[pInfo];
    PI[playerid] = bos;
    PI[playerid][pZone] = -2;
}

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

stock SkinId(idx)
{
    new id = idx + 1;
    if(id >= 74) id++;
    return id;
}

stock SkinIdx(id)
{
    if(id > 74) id--;
    id--;
    if(id < 0 || id >= SKIN_SAYISI) id = 0;
    return id;
}

stock IsimGecerli(const ad[])
{
    new l = strlen(ad);
    if(l < 3 || l > 24) return 0;
    for(new i = 0; i < l; i++)
    {
        if(!((ad[i] >= 'a' && ad[i] <= 'z') || (ad[i] >= 'A' && ad[i] <= 'Z') || ad[i] == '_')) return 0;
    }
    return 1;
}

stock AddMoney(playerid, miktar)
{
    PI[playerid][pPara] += miktar;
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, PI[playerid][pPara]);
}

stock KameraAyarla(playerid)
{
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerCameraPos(playerid, 1470.0, -1700.0, 30.0);
    SetPlayerCameraLookAt(playerid, 1481.0, -1738.0, 14.0);
}

stock ItemAl(playerid, idx)
{
    switch(idx)
    {
        case 0: return PI[playerid][pEkmek];
        case 1: return PI[playerid][pSu];
        case 2: return PI[playerid][pBandaj];
    }
    return 0;
}

stock ItemEkle(playerid, idx, miktar)
{
    switch(idx)
    {
        case 0: PI[playerid][pEkmek] += miktar;
        case 1: PI[playerid][pSu] += miktar;
        case 2: PI[playerid][pBandaj] += miktar;
    }
}

// ---------------------------------------------------------------- karakter dosyasi

stock KarakterYolu(playerid, slot, yol[])
{
    new n[MAX_PLAYER_NAME];
    GetPlayerName(playerid, n, sizeof(n));
    format(yol, 64, "Karakter/%s_%d.txt", n, slot);
}

stock CharAdOku(playerid, slot, ad[])
{
    new yol[64], satir[320];
    KarakterYolu(playerid, slot, yol);
    if(!fexist(yol)) return 0;
    new File:f = fopen(yol, io_read);
    if(!f) return 0;
    fread(f, satir, sizeof(satir));
    fclose(f);
    GetField(satir, 0, ad, 25);
    return 1;
}

stock CharYukle(playerid, slot)
{
    new yol[64], satir[320], t[40];
    KarakterYolu(playerid, slot, yol);
    if(!fexist(yol)) return 0;
    new File:f = fopen(yol, io_read);
    if(!f) return 0;
    fread(f, satir, sizeof(satir));
    fclose(f);

    new l = strlen(satir);
    while(l > 0 && (satir[l - 1] == '\n' || satir[l - 1] == '\r')) satir[--l] = 0;

    GetField(satir, 0, PI[playerid][pAd], 25);
    GetField(satir, 1, t, sizeof(t));  PI[playerid][pSkin] = strval(t);
    GetField(satir, 2, t, sizeof(t));  PI[playerid][pPara] = strval(t);
    GetField(satir, 3, t, sizeof(t));  PI[playerid][pX] = StrFloat(t);
    GetField(satir, 4, t, sizeof(t));  PI[playerid][pY] = StrFloat(t);
    GetField(satir, 5, t, sizeof(t));  PI[playerid][pZ] = StrFloat(t);
    GetField(satir, 6, t, sizeof(t));  PI[playerid][pA] = StrFloat(t);
    GetField(satir, 7, t, sizeof(t));  PI[playerid][pAclik] = strval(t);
    GetField(satir, 8, t, sizeof(t));  PI[playerid][pSusuz] = strval(t);
    GetField(satir, 9, t, sizeof(t));  PI[playerid][pEkmek] = strval(t);
    GetField(satir, 10, t, sizeof(t)); PI[playerid][pSu] = strval(t);
    GetField(satir, 11, t, sizeof(t)); PI[playerid][pBandaj] = strval(t);
    GetField(satir, 12, PI[playerid][pNot], 96);
    GetField(satir, 13, t, sizeof(t)); PI[playerid][pCins] = strval(t);
    GetField(satir, 14, t, sizeof(t)); PI[playerid][pYas] = strval(t);
    PI[playerid][pSlot] = slot;
    return 1;
}

stock CharKaydet(playerid)
{
    if(PI[playerid][pSlot] < 1 || PI[playerid][pAd][0] == 0) return 0;
    if(PI[playerid][pDurum] == 3 && GetPlayerVirtualWorld(playerid) == 0)
    {
        GetPlayerPos(playerid, PI[playerid][pX], PI[playerid][pY], PI[playerid][pZ]);
        GetPlayerFacingAngle(playerid, PI[playerid][pA]);
    }
    new yol[64], satir[320];
    KarakterYolu(playerid, PI[playerid][pSlot], yol);
    format(satir, sizeof(satir), "%s|%d|%d|%.2f|%.2f|%.2f|%.2f|%d|%d|%d|%d|%d|%s|%d|%d",
        PI[playerid][pAd], PI[playerid][pSkin], PI[playerid][pPara],
        PI[playerid][pX], PI[playerid][pY], PI[playerid][pZ], PI[playerid][pA],
        PI[playerid][pAclik], PI[playerid][pSusuz],
        PI[playerid][pEkmek], PI[playerid][pSu], PI[playerid][pBandaj],
        PI[playerid][pNot], PI[playerid][pCins], PI[playerid][pYas]);
    new File:f = fopen(yol, io_write);
    if(!f) return 0;
    fwrite(f, satir);
    fclose(f);
    return 1;
}

// ---------------------------------------------------------------- telefon (sag alt, otomatik)

stock Text:KutuYap(Float:x, Float:y, Float:w, Float:h, renk)
{
    new Text:t = TextDrawCreate(x, y, "LD_SPAC:white");
    TextDrawFont(t, 4);
    TextDrawTextSize(t, w, h);
    TextDrawColor(t, renk);
    return t;
}

stock Text:BtnYap(const yazi[], Float:x, Float:y, Float:w, renk, Float:harf = 0.4, Float:harfY = 1.6)
{
    new Text:t = TextDrawCreate(x, y, yazi);
    TextDrawLetterSize(t, harf, harfY);
    TextDrawTextSize(t, x + w, 18.0);
    TextDrawUseBox(t, 1);
    TextDrawBoxColor(t, renk);
    TextDrawColor(t, -1);
    TextDrawFont(t, 1);
    TextDrawSetOutline(t, 1);
    TextDrawSetSelectable(t, true);
    return t;
}

stock TelGoster(playerid)
{
    TextDrawShowForPlayer(playerid, TdTelCerceve);
    TextDrawShowForPlayer(playerid, TdTelEkran);
    TextDrawShowForPlayer(playerid, TdTelGPS);
    TextDrawShowForPlayer(playerid, TdTelSMS);
    TextDrawShowForPlayer(playerid, TdTelNot);
    TextDrawShowForPlayer(playerid, TdTelPara);
    TextDrawShowForPlayer(playerid, TdTelIpucu);

    PtSaat[playerid] = CreatePlayerTextDraw(playerid, 554.0, 179.0, "00:00");
    PlayerTextDrawFont(playerid, PtSaat[playerid], 1);
    PlayerTextDrawLetterSize(playerid, PtSaat[playerid], 0.36, 1.5);
    PlayerTextDrawColor(playerid, PtSaat[playerid], -1);
    PlayerTextDrawSetOutline(playerid, PtSaat[playerid], 1);
    PlayerTextDrawShow(playerid, PtSaat[playerid]);

    PtTelPara[playerid] = CreatePlayerTextDraw(playerid, 554.0, 197.0, "$0");
    PlayerTextDrawFont(playerid, PtTelPara[playerid], 1);
    PlayerTextDrawLetterSize(playerid, PtTelPara[playerid], 0.28, 1.2);
    PlayerTextDrawColor(playerid, PtTelPara[playerid], 0x2ECC71FF);
    PlayerTextDrawSetOutline(playerid, PtTelPara[playerid], 1);
    PlayerTextDrawShow(playerid, PtTelPara[playerid]);
}

stock TelGizle(playerid)
{
    TextDrawHideForPlayer(playerid, TdTelCerceve);
    TextDrawHideForPlayer(playerid, TdTelEkran);
    TextDrawHideForPlayer(playerid, TdTelGPS);
    TextDrawHideForPlayer(playerid, TdTelSMS);
    TextDrawHideForPlayer(playerid, TdTelNot);
    TextDrawHideForPlayer(playerid, TdTelPara);
    TextDrawHideForPlayer(playerid, TdTelIpucu);
    PlayerTextDrawDestroy(playerid, PtSaat[playerid]);
    PlayerTextDrawDestroy(playerid, PtTelPara[playerid]);
}

stock TelKapat(playerid)
{
    if(!PI[playerid][pTel]) return 0;
    PI[playerid][pTel] = false;
    CancelSelectTextDraw(playerid);
    return 1;
}

// ---------------------------------------------------------------- HUD

stock CreateHud(playerid)
{
    new cols[4] = {0xE74C3CFF, 0xBDC3C7FF, 0xE67E22FF, 0x3498DBFF};
    for(new i = 0; i < 4; i++)
    {
        new Float:y = 112.0 + float(i) * 11.0;

        PtBg[playerid][i] = CreatePlayerTextDraw(playerid, 500.0, y, "LD_SPAC:white");
        PlayerTextDrawFont(playerid, PtBg[playerid][i], 4);
        PlayerTextDrawTextSize(playerid, PtBg[playerid][i], 100.0, 8.0);
        PlayerTextDrawColor(playerid, PtBg[playerid][i], 0x000000AA);
        PlayerTextDrawShow(playerid, PtBg[playerid][i]);

        PtFill[playerid][i] = CreatePlayerTextDraw(playerid, 500.0, y, "LD_SPAC:white");
        PlayerTextDrawFont(playerid, PtFill[playerid][i], 4);
        PlayerTextDrawTextSize(playerid, PtFill[playerid][i], 100.0, 8.0);
        PlayerTextDrawColor(playerid, PtFill[playerid][i], cols[i]);
        PlayerTextDrawShow(playerid, PtFill[playerid][i]);
    }
    PtPara[playerid] = CreatePlayerTextDraw(playerid, 500.0, 92.0, "$0");
    PlayerTextDrawFont(playerid, PtPara[playerid], 3);
    PlayerTextDrawLetterSize(playerid, PtPara[playerid], 0.5, 1.7);
    PlayerTextDrawColor(playerid, PtPara[playerid], 0x2ECC71FF);
    PlayerTextDrawSetOutline(playerid, PtPara[playerid], 1);
    PlayerTextDrawShow(playerid, PtPara[playerid]);

    PtZone[playerid] = CreatePlayerTextDraw(playerid, 20.0, 425.0, "San Andreas");
    PlayerTextDrawFont(playerid, PtZone[playerid], 1);
    PlayerTextDrawLetterSize(playerid, PtZone[playerid], 0.45, 1.8);
    PlayerTextDrawColor(playerid, PtZone[playerid], -1);
    PlayerTextDrawSetOutline(playerid, PtZone[playerid], 1);
    PlayerTextDrawShow(playerid, PtZone[playerid]);

    TelGoster(playerid);

    PI[playerid][pHud] = true;
    PI[playerid][pZone] = -2;
}

stock DestroyHud(playerid)
{
    if(!PI[playerid][pHud]) return 0;
    TelKapat(playerid);
    for(new i = 0; i < 4; i++)
    {
        PlayerTextDrawDestroy(playerid, PtBg[playerid][i]);
        PlayerTextDrawDestroy(playerid, PtFill[playerid][i]);
    }
    PlayerTextDrawDestroy(playerid, PtPara[playerid]);
    PlayerTextDrawDestroy(playerid, PtZone[playerid]);
    TelGizle(playerid);
    PI[playerid][pHud] = false;
    return 1;
}

stock SetBar(playerid, i, Float:deger)
{
    if(deger < 1.0) deger = 1.0;
    if(deger > 100.0) deger = 100.0;
    PlayerTextDrawTextSize(playerid, PtFill[playerid][i], deger, 8.0);
    PlayerTextDrawShow(playerid, PtFill[playerid][i]);
}

stock BolgeBul(playerid)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    for(new i = 0; i < sizeof(BolgeAd); i++)
    {
        if(x >= BolgeKutu[i][0] && y >= BolgeKutu[i][1] && x <= BolgeKutu[i][2] && y <= BolgeKutu[i][3]) return i;
    }
    return -1;
}

stock UpdateHud(playerid)
{
    if(!PI[playerid][pHud]) return 0;
    new Float:h, Float:a, s[24];
    GetPlayerHealth(playerid, h);
    GetPlayerArmour(playerid, a);
    SetBar(playerid, 0, h);
    SetBar(playerid, 1, a);
    SetBar(playerid, 2, float(PI[playerid][pAclik]));
    SetBar(playerid, 3, float(PI[playerid][pSusuz]));

    format(s, sizeof(s), "$%d", PI[playerid][pPara]);
    PlayerTextDrawSetString(playerid, PtPara[playerid], s);
    PlayerTextDrawSetString(playerid, PtTelPara[playerid], s);

    new sa, dk, sn;
    gettime(sa, dk, sn);
    format(s, sizeof(s), "%02d:%02d", sa, dk);
    PlayerTextDrawSetString(playerid, PtSaat[playerid], s);

    new z = BolgeBul(playerid);
    if(z != PI[playerid][pZone])
    {
        PI[playerid][pZone] = z;
        if(z == -1) PlayerTextDrawSetString(playerid, PtZone[playerid], "San Andreas");
        else PlayerTextDrawSetString(playerid, PtZone[playerid], BolgeAd[z]);
    }
    return 1;
}

// ---------------------------------------------------------------- skin secimi

stock SkinGuncelle(playerid)
{
    new s[48];
    SetPlayerSkin(playerid, SkinId(PI[playerid][pSkinIdx]));
    format(s, sizeof(s), "Skin ID: %d  (%d/%d)", SkinId(PI[playerid][pSkinIdx]), PI[playerid][pSkinIdx] + 1, SKIN_SAYISI);
    PlayerTextDrawSetString(playerid, PtSkin[playerid], s);
}

stock SkinOnizlemeKur(playerid)
{
    TelKapat(playerid);
    SetPlayerVirtualWorld(playerid, playerid + 1);
    SetPlayerInterior(playerid, 0);
    SetPlayerPos(playerid, PRV_X, PRV_Y, PRV_Z);
    SetPlayerFacingAngle(playerid, 0.0);
    SetPlayerHealth(playerid, 100.0);
    SetPlayerCameraPos(playerid, PRV_X, PRV_Y + 3.5, PRV_Z + 0.6);
    SetPlayerCameraLookAt(playerid, PRV_X, PRV_Y, PRV_Z + 0.2);
    TogglePlayerControllable(playerid, false);

    PtSkin[playerid] = CreatePlayerTextDraw(playerid, 250.0, 345.0, "Skin");
    PlayerTextDrawFont(playerid, PtSkin[playerid], 1);
    PlayerTextDrawLetterSize(playerid, PtSkin[playerid], 0.4, 1.6);
    PlayerTextDrawColor(playerid, PtSkin[playerid], -1);
    PlayerTextDrawSetOutline(playerid, PtSkin[playerid], 1);
    PlayerTextDrawShow(playerid, PtSkin[playerid]);

    SkinGuncelle(playerid);

    TextDrawShowForPlayer(playerid, TdSkinBaslik);
    TextDrawShowForPlayer(playerid, TdSkinOnce);
    TextDrawShowForPlayer(playerid, TdSkinSec);
    TextDrawShowForPlayer(playerid, TdSkinSonra);
    TextDrawShowForPlayer(playerid, TdSkinIpucu);
    SelectTextDraw(playerid, 0xFFAA00FF);
}

stock SkinBitir(playerid, onay)
{
    new mod = PI[playerid][pMod];
    PI[playerid][pDurum] = 3;
    CancelSelectTextDraw(playerid);
    TextDrawHideForPlayer(playerid, TdSkinBaslik);
    TextDrawHideForPlayer(playerid, TdSkinOnce);
    TextDrawHideForPlayer(playerid, TdSkinSec);
    TextDrawHideForPlayer(playerid, TdSkinSonra);
    TextDrawHideForPlayer(playerid, TdSkinIpucu);
    PlayerTextDrawDestroy(playerid, PtSkin[playerid]);

    SetPlayerVirtualWorld(playerid, 0);
    TogglePlayerControllable(playerid, true);

    if(mod == 1)
    {
        PI[playerid][pSkin] = SkinId(PI[playerid][pSkinIdx]);
        new ilk = 1, adx[25];
        for(new k = 1; k <= MAX_SLOT; k++)
        {
            if(k != PI[playerid][pSlot] && CharAdOku(playerid, k, adx)) ilk = 0;
        }
        PI[playerid][pPara] = ilk ? 5000 : 500;
        PI[playerid][pAclik] = 100;
        PI[playerid][pSusuz] = 100;
        PI[playerid][pEkmek] = 2;
        PI[playerid][pSu] = 2;
        PI[playerid][pBandaj] = 1;
        PI[playerid][pX] = SPAWN_X;
        PI[playerid][pY] = SPAWN_Y;
        PI[playerid][pZ] = SPAWN_Z;
        PI[playerid][pA] = 0.0;
        PI[playerid][pTick] = 0;
        PI[playerid][pOlu] = 0;
        SetPlayerSkin(playerid, PI[playerid][pSkin]);
        SetPlayerPos(playerid, SPAWN_X, SPAWN_Y, SPAWN_Z);
        SetPlayerFacingAngle(playerid, 0.0);
        SetPlayerHealth(playerid, 100.0);
        ResetPlayerMoney(playerid);
        GivePlayerMoney(playerid, PI[playerid][pPara]);
        if(!PI[playerid][pHud]) CreateHud(playerid);
        UpdateHud(playerid);
        CharKaydet(playerid);
        SendClientMessage(playerid, 0x2ECC71FF, "Karakterin olusturuldu. Yardim icin /yardim");
        ShowPlayerDialog(playerid, D_HOSGELDIN, DIALOG_STYLE_MSGBOX, "Belediye - Hosgeldin",
            "Los Santos'a hos geldin!\n\nTelefonun hazir: /tel\nEhliyet: belediyeden alinabilecek (yakinda)\n\nBaslangic gorevleri:\n1) /market ile ekmek ve su al\n2) /tel ile GPS'ten hastaneyi isaretle\n3) /yardim ile komutlari ogren\n4) /karakterim ile bilgilerine bak",
            "Tamam", "");
    }
    else
    {
        if(onay)
        {
            if(PI[playerid][pPara] >= KIYAFET_UCRETI)
            {
                AddMoney(playerid, -KIYAFET_UCRETI);
                PI[playerid][pSkin] = SkinId(PI[playerid][pSkinIdx]);
                SendClientMessage(playerid, 0x2ECC71FF, "Yeni kiyafetin hazir!");
            }
            else SendClientMessage(playerid, 0xE74C3CFF, "Yeterli paran yok.");
        }
        SetPlayerSkin(playerid, PI[playerid][pSkin]);
        SetPlayerPos(playerid, PI[playerid][pX], PI[playerid][pY], PI[playerid][pZ]);
        SetPlayerFacingAngle(playerid, PI[playerid][pA]);
        CharKaydet(playerid);
    }
    SetCameraBehindPlayer(playerid);
    return 1;
}

// ---------------------------------------------------------------- karakter akisi

stock SlotDialog(playerid)
{
    new s[200], ad[25], satir[48];
    for(new i = 1; i <= MAX_SLOT; i++)
    {
        if(CharAdOku(playerid, i, ad)) format(satir, sizeof(satir), "Slot %d: %s\n", i, ad);
        else format(satir, sizeof(satir), "Slot %d: [Bos - yeni karakter]\n", i);
        strcat(s, satir);
    }
    ShowPlayerDialog(playerid, D_SLOT, DIALOG_STYLE_LIST, "Karakter Secimi", s, "Sec", "");
}

stock YeniIsimDialog(playerid)
{
    ShowPlayerDialog(playerid, D_ISIM, DIALOG_STYLE_INPUT, "Yeni Karakter",
        "Karakter adini yaz (ornek: Ahmet_Yilmaz)\nSadece harf ve _ kullan, 3-24 karakter.", "Devam", "Geri");
}

stock MevcutKarakterBaslat(playerid)
{
    PI[playerid][pDurum] = 3;
    PI[playerid][pTick] = 0;
    PI[playerid][pOlu] = 0;
    SetSpawnInfo(playerid, 0, PI[playerid][pSkin], PI[playerid][pX], PI[playerid][pY], PI[playerid][pZ], PI[playerid][pA], 0, 0, 0, 0, 0, 0);
    TogglePlayerSpectating(playerid, false);
}

stock YeniKarakterBaslat(playerid)
{
    PI[playerid][pNot][0] = 0;
    PI[playerid][pMod] = 1;
    PI[playerid][pSkinIdx] = 0;
    PI[playerid][pDurum] = 2;
    SetSpawnInfo(playerid, 0, SkinId(0), PRV_X, PRV_Y, PRV_Z, 0.0, 0, 0, 0, 0, 0, 0);
    TogglePlayerSpectating(playerid, false);
}

stock YuklemeBaslat(playerid)
{
    TogglePlayerSpectating(playerid, true);
    KameraAyarla(playerid);
    TextDrawShowForPlayer(playerid, TdYuk);
    TextDrawShowForPlayer(playerid, TdYukBaslik);
    TextDrawShowForPlayer(playerid, TdYukAlt);
    SetTimerEx("LoadingBitti", 4000, false, "i", playerid);
}

public LoadingBitti(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    TextDrawHideForPlayer(playerid, TdYuk);
    TextDrawHideForPlayer(playerid, TdYukBaslik);
    TextDrawHideForPlayer(playerid, TdYukAlt);
    PI[playerid][pDurum] = 1;
    KameraAyarla(playerid);
    SlotDialog(playerid);
    return 1;
}

// ---------------------------------------------------------------- envanter / market

stock EnvanterGoster(playerid)
{
    new s[128];
    format(s, sizeof(s), "%s  (x%d)\n%s  (x%d)\n%s  (x%d)",
        ItemAd[0], PI[playerid][pEkmek], ItemAd[1], PI[playerid][pSu], ItemAd[2], PI[playerid][pBandaj]);
    ShowPlayerDialog(playerid, D_ENV, DIALOG_STYLE_LIST, "Envanter", s, "Sec", "Kapat");
}

stock ItemKullan(playerid, idx)
{
    if(ItemAl(playerid, idx) <= 0)
    {
        SendClientMessage(playerid, 0xE74C3CFF, "Bu esyadan yok.");
        return 0;
    }
    ItemEkle(playerid, idx, -1);
    switch(idx)
    {
        case 0:
        {
            PI[playerid][pAclik] += 30;
            if(PI[playerid][pAclik] > 100) PI[playerid][pAclik] = 100;
            SendClientMessage(playerid, 0x2ECC71FF, "Ekmek yedin.");
        }
        case 1:
        {
            PI[playerid][pSusuz] += 30;
            if(PI[playerid][pSusuz] > 100) PI[playerid][pSusuz] = 100;
            SendClientMessage(playerid, 0x2ECC71FF, "Su ictin.");
        }
        case 2:
        {
            new Float:h;
            GetPlayerHealth(playerid, h);
            h += 25.0;
            if(h > 100.0) h = 100.0;
            SetPlayerHealth(playerid, h);
            SendClientMessage(playerid, 0x2ECC71FF, "Bandaj sardin.");
        }
    }
    UpdateHud(playerid);
    return 1;
}

stock MarketGoster(playerid)
{
    new s[128];
    format(s, sizeof(s), "%s - $%d\n%s - $%d\n%s - $%d",
        ItemAd[0], ItemFiyat[0], ItemAd[1], ItemFiyat[1], ItemAd[2], ItemFiyat[2]);
    ShowPlayerDialog(playerid, D_MARKET, DIALOG_STYLE_LIST, "Market", s, "Satin Al", "Kapat");
}

stock YardimGoster(playerid)
{
    ShowPlayerDialog(playerid, D_YARDIM, DIALOG_STYLE_MSGBOX, "Yardim",
        "Telefon sag ustte. /tel yaz = telefonu ac/kapat (dokunmatik). PC: N tusu.\nY tusu veya /envanter = Envanter\n/market = Market\n/kiyafet = Kiyafet degistir ($100)\n/karakter = Karakter degistir\n/karakterim = Karakter bilgisi",
        "Tamam", "");
}

// ---------------------------------------------------------------- callback'ler

public OnFilterScriptInit()
{
    // Yukleme ekrani
    TdYuk = TextDrawCreate(0.0, 0.0, "LD_SPAC:white");
    TextDrawFont(TdYuk, 4);
    TextDrawTextSize(TdYuk, 640.0, 480.0);
    TextDrawColor(TdYuk, 0x0B0B12FF);

    TdYukBaslik = TextDrawCreate(320.0, 190.0, SUNUCU_ADI);
    TextDrawAlignment(TdYukBaslik, 2);
    TextDrawFont(TdYukBaslik, 0);
    TextDrawLetterSize(TdYukBaslik, 1.0, 4.0);
    TextDrawTextSize(TdYukBaslik, 640.0, 480.0);
    TextDrawColor(TdYukBaslik, 0xE74C3CFF);
    TextDrawSetOutline(TdYukBaslik, 1);

    TdYukAlt = TextDrawCreate(320.0, 260.0, "Karakter sistemi yukleniyor...");
    TextDrawAlignment(TdYukAlt, 2);
    TextDrawFont(TdYukAlt, 1);
    TextDrawLetterSize(TdYukAlt, 0.4, 1.6);
    TextDrawTextSize(TdYukAlt, 640.0, 480.0);
    TextDrawColor(TdYukAlt, -1);
    TextDrawSetOutline(TdYukAlt, 1);

    // Skin secimi
    TdSkinBaslik = TextDrawCreate(320.0, 30.0, "KARAKTER / KIYAFET SECIMI");
    TextDrawAlignment(TdSkinBaslik, 2);
    TextDrawFont(TdSkinBaslik, 2);
    TextDrawLetterSize(TdSkinBaslik, 0.6, 2.4);
    TextDrawTextSize(TdSkinBaslik, 640.0, 480.0);
    TextDrawColor(TdSkinBaslik, -1);
    TextDrawSetOutline(TdSkinBaslik, 1);

    TdSkinIpucu = TextDrawCreate(320.0, 410.0, "Oklarla degistir, SEC ile onayla  |  ESC: iptal (kiyafet)");
    TextDrawAlignment(TdSkinIpucu, 2);
    TextDrawFont(TdSkinIpucu, 1);
    TextDrawLetterSize(TdSkinIpucu, 0.3, 1.3);
    TextDrawTextSize(TdSkinIpucu, 640.0, 480.0);
    TextDrawColor(TdSkinIpucu, 0xBBBBBBFF);
    TextDrawSetOutline(TdSkinIpucu, 1);

    TdSkinOnce  = BtnYap("  < ONCEKI",  150.0, 370.0, 90.0, 0x2C3E50CC);
    TdSkinSec   = BtnYap("    SEC",     260.0, 370.0, 70.0, 0x27AE60CC);
    TdSkinSonra = BtnYap("  SONRAKI >", 350.0, 370.0, 90.0, 0x2C3E50CC);

    // Telefon (sag alt)
    TdTelCerceve = KutuYap(545.0, 172.0, 82.0, 134.0, 0x000000FF);
    TdTelEkran   = KutuYap(548.0, 176.0, 76.0, 126.0, 0x1E2530FF);
    TdTelGPS  = BtnYap(" GPS", 552.0, 220.0, 34.0, 0x2980B9FF, 0.28, 1.3);
    TdTelSMS  = BtnYap(" SMS", 590.0, 220.0, 34.0, 0x27AE60FF, 0.28, 1.3);
    TdTelNot  = BtnYap(" NOT", 552.0, 248.0, 34.0, 0xF39C12FF, 0.28, 1.3);
    TdTelPara = BtnYap(" PARA", 590.0, 248.0, 34.0, 0x8E44ADFF, 0.28, 1.3);
    TdTelIpucu = TextDrawCreate(552.0, 282.0, "/tel: ac/kapat");
    TextDrawFont(TdTelIpucu, 1);
    TextDrawLetterSize(TdTelIpucu, 0.22, 1.0);
    TextDrawColor(TdTelIpucu, 0xAAAAAAFF);

    for(new i = 0; i < MAX_PLAYERS; i++) ResetPI(i);
    SetTimer("GenelZamanlayici", 1000, true);
    print("Xyral oyuncu sistemi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && PI[i][pDurum] == 3) CharKaydet(i);
    }
    return 1;
}

public GenelZamanlayici()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PI[i][pDurum] != 3) continue;
        PI[i][pTick]++;

        if(PI[i][pTick] % 90 == 0 && PI[i][pAclik] > 0) PI[i][pAclik]--;
        if(PI[i][pTick] % 60 == 0)
        {
            if(PI[i][pSusuz] > 0) PI[i][pSusuz]--;
            CharKaydet(i);
        }
        if((PI[i][pAclik] <= 0 || PI[i][pSusuz] <= 0) && PI[i][pTick] % 10 == 0)
        {
            new Float:h;
            GetPlayerHealth(i, h);
            if(h > 5.0) SetPlayerHealth(i, h - 3.0);
            SendClientMessage(i, 0xE74C3CFF, "Aciksin veya susuzsun! Bir sey ye/ic.");
        }
        UpdateHud(i);
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    ResetPI(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(PI[playerid][pDurum] == 3) CharKaydet(playerid);
    ResetPI(playerid);
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    if(!PI[playerid][pBasladi])
    {
        PI[playerid][pBasladi] = true;
        YuklemeBaslat(playerid);
    }
    return 1;
}

public OnPlayerSpawn(playerid)
{
    switch(PI[playerid][pDurum])
    {
        case 2:
        {
            SkinOnizlemeKur(playerid);
        }
        case 3:
        {
            SetPlayerVirtualWorld(playerid, 0);
            SetPlayerInterior(playerid, 0);
            TogglePlayerControllable(playerid, true);
            SetPlayerSkin(playerid, PI[playerid][pSkin]);
            SetPlayerHealth(playerid, 100.0);
            if(PI[playerid][pOlu])
            {
                PI[playerid][pOlu] = 0;
                SetPlayerPos(playerid, HOSP_X, HOSP_Y, HOSP_Z);
                SendClientMessage(playerid, 0xF1C40FFF, "Hastanede uyandin.");
            }
            ResetPlayerMoney(playerid);
            GivePlayerMoney(playerid, PI[playerid][pPara]);
            if(!PI[playerid][pHud]) CreateHud(playerid);
            UpdateHud(playerid);
            SetCameraBehindPlayer(playerid);
        }
    }
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    if(PI[playerid][pDurum] == 3)
    {
        PI[playerid][pOlu] = 1;
        TelKapat(playerid);
    }
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    if(PI[playerid][pDurum] != 3) return 0;
    DisablePlayerCheckpoint(playerid);
    SendClientMessage(playerid, 0x2ECC71FF, "Hedefe ulastin.");
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    if(PI[playerid][pDurum] != 3) return 1;
    if(BASILDI(KEY_YES)) EnvanterGoster(playerid);
    if(BASILDI(KEY_NO))
    {
        // Telefon imlecini ac/kapat
        if(PI[playerid][pTel]) TelKapat(playerid);
        else
        {
            PI[playerid][pTel] = true;
            SelectTextDraw(playerid, 0x3498DBFF);
        }
    }
    return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    // Oyundayken: telefon
    if(PI[playerid][pDurum] == 3)
    {
        if(clickedid == INVALID_TEXT_DRAW)
        {
            PI[playerid][pTel] = false;
            return 1;
        }
        if(clickedid == TdTelGPS)
        {
            TelKapat(playerid);
            ShowPlayerDialog(playerid, D_GPS, DIALOG_STYLE_LIST, "GPS",
                "Hastane\nPolis Departmani\nPershing Square\nGPS Kapat", "Git", "Kapat");
            return 1;
        }
        if(clickedid == TdTelSMS)
        {
            TelKapat(playerid);
            ShowPlayerDialog(playerid, D_SMS, DIALOG_STYLE_INPUT, "SMS",
                "Format: ID mesaj\nOrnek: 3 Merhaba", "Gonder", "Iptal");
            return 1;
        }
        if(clickedid == TdTelNot)
        {
            TelKapat(playerid);
            new s[192];
            format(s, sizeof(s), "Mevcut not:\n%s\n\nYeni notu yaz:", PI[playerid][pNot]);
            ShowPlayerDialog(playerid, D_NOT, DIALOG_STYLE_INPUT, "Notlar", s, "Kaydet", "Iptal");
            return 1;
        }
        if(clickedid == TdTelPara)
        {
            TelKapat(playerid);
            new s[64];
            format(s, sizeof(s), "Bakiyen: $%d", PI[playerid][pPara]);
            SendClientMessage(playerid, 0x2ECC71FF, s);
            return 1;
        }
        return 1;
    }

    // Skin secimi
    if(PI[playerid][pDurum] != 2) return 0;

    if(clickedid == INVALID_TEXT_DRAW)
    {
        if(PI[playerid][pMod] == 1) SelectTextDraw(playerid, 0xFFAA00FF);
        else SkinBitir(playerid, 0);
        return 1;
    }
    if(clickedid == TdSkinSonra)
    {
        PI[playerid][pSkinIdx] = (PI[playerid][pSkinIdx] + 1) % SKIN_SAYISI;
        SkinGuncelle(playerid);
        return 1;
    }
    if(clickedid == TdSkinOnce)
    {
        PI[playerid][pSkinIdx] = (PI[playerid][pSkinIdx] + SKIN_SAYISI - 1) % SKIN_SAYISI;
        SkinGuncelle(playerid);
        return 1;
    }
    if(clickedid == TdSkinSec)
    {
        SkinBitir(playerid, 1);
        return 1;
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case D_SLOT:
        {
            if(!response) { SlotDialog(playerid); return 1; }
            if(CharYukle(playerid, listitem + 1)) MevcutKarakterBaslat(playerid);
            else
            {
                PI[playerid][pSlot] = listitem + 1;
                YeniIsimDialog(playerid);
            }
            return 1;
        }
        case D_ISIM:
        {
            if(!response) { SlotDialog(playerid); return 1; }
            if(!IsimGecerli(inputtext))
            {
                SendClientMessage(playerid, 0xE74C3CFF, "Gecersiz isim. Sadece harf ve _ kullan (3-24).");
                YeniIsimDialog(playerid);
                return 1;
            }
            format(PI[playerid][pAd], 25, "%s", inputtext);
            ShowPlayerDialog(playerid, D_CINS, DIALOG_STYLE_LIST, "Cinsiyet", "Erkek\nKadin", "Devam", "Geri");
            return 1;
        }
        case D_CINS:
        {
            if(!response) { YeniIsimDialog(playerid); return 1; }
            PI[playerid][pCins] = listitem + 1;
            ShowPlayerDialog(playerid, D_YAS, DIALOG_STYLE_INPUT, "Yas", "Karakterin yasini yaz (18-80):", "Devam", "Geri");
            return 1;
        }
        case D_YAS:
        {
            if(!response)
            {
                ShowPlayerDialog(playerid, D_CINS, DIALOG_STYLE_LIST, "Cinsiyet", "Erkek\nKadin", "Devam", "Geri");
                return 1;
            }
            new yas = strval(inputtext);
            if(yas < 18 || yas > 80)
            {
                SendClientMessage(playerid, 0xE74C3CFF, "Yas 18 ile 80 arasinda olmali.");
                ShowPlayerDialog(playerid, D_YAS, DIALOG_STYLE_INPUT, "Yas", "Karakterin yasini yaz (18-80):", "Devam", "Geri");
                return 1;
            }
            PI[playerid][pYas] = yas;
            YeniKarakterBaslat(playerid);
            return 1;
        }
        case D_ENV:
        {
            if(!response) return 1;
            PI[playerid][pSecim] = listitem;
            ShowPlayerDialog(playerid, D_ENV_ISLEM, DIALOG_STYLE_LIST, ItemAd[listitem], "Kullan\nBirak", "Sec", "Geri");
            return 1;
        }
        case D_ENV_ISLEM:
        {
            if(!response) { EnvanterGoster(playerid); return 1; }
            if(listitem == 0) ItemKullan(playerid, PI[playerid][pSecim]);
            else
            {
                if(ItemAl(playerid, PI[playerid][pSecim]) > 0)
                {
                    ItemEkle(playerid, PI[playerid][pSecim], -1);
                    SendClientMessage(playerid, 0xF1C40FFF, "Esyayi yere biraktin.");
                }
            }
            EnvanterGoster(playerid);
            return 1;
        }
        case D_MARKET:
        {
            if(!response) return 1;
            if(PI[playerid][pPara] < ItemFiyat[listitem])
            {
                SendClientMessage(playerid, 0xE74C3CFF, "Yeterli paran yok.");
            }
            else
            {
                AddMoney(playerid, -ItemFiyat[listitem]);
                ItemEkle(playerid, listitem, 1);
                SendClientMessage(playerid, 0x2ECC71FF, "Satin alindi.");
            }
            MarketGoster(playerid);
            return 1;
        }
        case D_GPS:
        {
            if(!response) return 1;
            if(listitem < 3)
            {
                SetPlayerCheckpoint(playerid, GpsPos[listitem][0], GpsPos[listitem][1], GpsPos[listitem][2], 5.0);
                SendClientMessage(playerid, 0x3498DBFF, "GPS hedefi haritada isaretlendi.");
            }
            else DisablePlayerCheckpoint(playerid);
            return 1;
        }
        case D_SMS:
        {
            if(!response) return 1;
            new id = strval(inputtext);
            new pos = strfind(inputtext, " ");
            if(pos < 1 || !IsPlayerConnected(id) || PI[id][pDurum] != 3)
            {
                SendClientMessage(playerid, 0xE74C3CFF, "Gecersiz ID veya format.");
                return 1;
            }
            new s[200];
            format(s, sizeof(s), "[SMS] %s (ID %d): %s", PI[playerid][pAd], playerid, inputtext[pos + 1]);
            SendClientMessage(id, 0x3498DBFF, s);
            SendClientMessage(playerid, 0x3498DBFF, "SMS gonderildi.");
            return 1;
        }
        case D_NOT:
        {
            if(!response) return 1;
            for(new i = 0, l = strlen(inputtext); i < l; i++)
            {
                if(inputtext[i] == '|') inputtext[i] = ' ';
            }
            format(PI[playerid][pNot], 96, "%s", inputtext);
            CharKaydet(playerid);
            SendClientMessage(playerid, 0x2ECC71FF, "Not kaydedildi.");
            return 1;
        }
        case D_YARDIM, D_HOSGELDIN:
        {
            return 1;
        }
    }
    return 0;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!strcmp(cmdtext, "/tel", true) || !strcmp(cmdtext, "/telefon", true))
    {
        if(PI[playerid][pDurum] == 3)
        {
            if(PI[playerid][pTel]) TelKapat(playerid);
            else
            {
                PI[playerid][pTel] = true;
                SelectTextDraw(playerid, 0x3498DBFF);
            }
        }
        return 1;
    }
    if(!strcmp(cmdtext, "/yardim", true))
    {
        if(PI[playerid][pDurum] == 3) YardimGoster(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/envanter", true))
    {
        if(PI[playerid][pDurum] == 3) EnvanterGoster(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/market", true))
    {
        if(PI[playerid][pDurum] == 3) MarketGoster(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/kiyafet", true))
    {
        if(PI[playerid][pDurum] != 3) return 1;
        if(IsPlayerInAnyVehicle(playerid))
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Aractayken kiyafet degistiremezsin.");
            return 1;
        }
        if(PI[playerid][pPara] < KIYAFET_UCRETI)
        {
            SendClientMessage(playerid, 0xE74C3CFF, "Kiyafet degistirmek icin $100 gerekli.");
            return 1;
        }
        GetPlayerPos(playerid, PI[playerid][pX], PI[playerid][pY], PI[playerid][pZ]);
        GetPlayerFacingAngle(playerid, PI[playerid][pA]);
        PI[playerid][pMod] = 2;
        PI[playerid][pSkinIdx] = SkinIdx(PI[playerid][pSkin]);
        PI[playerid][pDurum] = 2;
        SkinOnizlemeKur(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/karakter", true))
    {
        if(PI[playerid][pDurum] != 3) return 1;
        if(IsPlayerInAnyVehicle(playerid)) RemovePlayerFromVehicle(playerid);
        CharKaydet(playerid);
        DestroyHud(playerid);
        DisablePlayerCheckpoint(playerid);
        PI[playerid][pDurum] = 1;
        TogglePlayerSpectating(playerid, true);
        KameraAyarla(playerid);
        SlotDialog(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/karakterim", true))
    {
        if(PI[playerid][pDurum] != 3) return 1;
        new s[128];
        format(s, sizeof(s), "Ad: %s | Cinsiyet: %s | Yas: %d | Para: $%d", PI[playerid][pAd],
            (PI[playerid][pCins] == 1) ? ("Erkek") : ((PI[playerid][pCins] == 2) ? ("Kadin") : ("?")),
            PI[playerid][pYas], PI[playerid][pPara]);
        SendClientMessage(playerid, 0x3498DBFF, s);
        return 1;
    }
    return 0;
}
