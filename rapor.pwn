/*
    DUKTUR RP - ADMIN RAPOR YONETIM SISTEMI  (rapor.pwn)

    Filterscript olarak calisir, baska dosyalara dokunmaz.
    Kalici kayit: scriptfiles/duktur_rapor_<ID>.txt  (rapor basina bir dosya)

    Oyuncu komutlari : /rapor [id/isim]   /raporlarim
    Admin komutlari  : /raporlar          /raporgor [rapor id]
    Ekranda          : Haritanin altinda "AKTIF RAPORLAR [n]" butonu (sadece adminlerde)

    ADMIN ENTEGRASYONU:
    Varsayilan olarak sadece RCON admini (IsPlayerAdmin) rapor yonetebilir.
    admin.pwn icinde su public'i tanimlarsan oradaki admin seviyesi kullanilir:

        forward RaporAdminSeviye(playerid);
        public RaporAdminSeviye(playerid) { return SENIN_ADMIN_SEVIYE_DEGISKENIN[playerid]; }

    (0 = admin degil, 1 ve uzeri = admin)
*/

#include <a_samp>

#pragma dynamic 65536

// ------------------------------------------------------------------
// AYARLAR
// ------------------------------------------------------------------
#define MAX_RAPOR                100
#define MAX_MESAJ                20
#define MAX_LOG                  25
#define SAYFA_BOYUT              12
#define OYUNCU_LISTE_MAX         15
#define MAX_ACIK_RAPOR_OYUNCU    3
#define RAPOR_BEKLEME            30      // saniye
#define YENIDEN_ACMA_MIN_SEVIYE  1       // kapali raporu yeniden acabilmek icin gereken admin seviyesi
#define DOSYA_FORMAT             "duktur_rapor_%d.txt"

#define RENK_BILGI   0x7FB3D5FF
#define RENK_HATA    0xE06666FF
#define RENK_OK      0x82C98AFF

#define DURUM_BEKLIYOR           0
#define DURUM_INCELENIYOR        1
#define DURUM_ISLEM              2
#define DURUM_RED                3
#define DURUM_INCELENDI          4

enum
{
    D_A_LISTE = 7700,
    D_A_DURUM_FLT,
    D_A_ONC_FLT,
    D_A_DETAY,
    D_A_ISLEM,
    D_A_DURUM,
    D_A_ONCELIK,
    D_A_MESAJLAR,
    D_A_MESAJ_YAZ,
    D_A_KAPAT,
    D_A_ACMA,
    D_O_ISIM,
    D_O_KAT,
    D_O_ACIK,
    D_O_KANIT,
    D_O_LISTE,
    D_O_DETAY,
    D_O_MESAJLAR,
    D_O_MESAJ_YAZ,
    D_AYARLAR
}

new const DurumAd[5][]    = {"BEKLİYOR", "İNCELENİYOR", "İŞLEM UYGULANACAK", "RED EDİLDİ", "İNCELENDİ"};
new const DurumRenk[5][]  = {"{9AA5B1}", "{5DADE2}", "{F0B040}", "{E06666}", "{82C98A}"};
new const OncAd[4][]      = {"Düşük", "Normal", "Yüksek", "Acil"};
new const KategoriAd[6][] = {"Hile / Cheat", "Kural İhlali (RDM / DM)", "Hakaret / Küfür", "Bug / Hata Suistimali", "Admin Şikâyeti", "Diğer"};

// ------------------------------------------------------------------
// VERI
// ------------------------------------------------------------------
enum E_RAPOR
{
    rUsed,
    rGonderen[MAX_PLAYER_NAME],
    rSikayet[MAX_PLAYER_NAME],
    rKategori,
    rDurum,
    rOncelik,
    rKapali,
    rZaman[20],
    rAciklama[128],
    rKanit[96],
    rOyOkunmamis,
    rAdOkunmamis,
    rMesajSayi,
    rLogSayi
}

new Rapor[MAX_RAPOR][E_RAPOR];

new MsgZaman[MAX_RAPOR][MAX_MESAJ][12];
new MsgIsim[MAX_RAPOR][MAX_MESAJ][MAX_PLAYER_NAME];
new MsgAdmin[MAX_RAPOR][MAX_MESAJ];
new MsgMetin[MAX_RAPOR][MAX_MESAJ][80];

new LogZaman[MAX_RAPOR][MAX_LOG][12];
new LogMetin[MAX_RAPOR][MAX_LOG][96];

// oyuncu bazli gecici veriler
new pRaporSec[MAX_PLAYERS];
new pFltDurum[MAX_PLAYERS];
new pFltOnc[MAX_PLAYERS];
new pSayfa[MAX_PLAYERS];
new pGecmis[MAX_PLAYERS];
new pRowTip[MAX_PLAYERS][20];
new pRowVal[MAX_PLAYERS][20];
new pOyMap[MAX_PLAYERS][OYUNCU_LISTE_MAX];

new pHedef[MAX_PLAYERS][MAX_PLAYER_NAME];
new pKat[MAX_PLAYERS];
new pAcik[MAX_PLAYERS][128];
new pSonRapor[MAX_PLAYERS];

// arayuz
new PlayerText:ptBtn[MAX_PLAYERS];
new PlayerText:ptToast[MAX_PLAYERS];
new bool:pBtn[MAX_PLAYERS];
new bool:pToastVar[MAX_PLAYERS];
new bool:pBilgi[MAX_PLAYERS];
new pBtnSayi[MAX_PLAYERS];
new pBtnAcil[MAX_PLAYERS];
new pToastRapor[MAX_PLAYERS];
new pToastSeq[MAX_PLAYERS];

// buyuk metinler icin ortak tamponlar
new gDlg[4096];
new gTmp[512];

forward RaporUI();
forward ToastGizle(playerid, seq);

// ------------------------------------------------------------------
// YARDIMCI FONKSIYONLAR
// ------------------------------------------------------------------
stock RaporAdminSeviyesi(playerid)
{
    if(IsPlayerAdmin(playerid)) return 99;
    return CallRemoteFunction("RaporAdminSeviye", "i", playerid);
}

stock RaporGecerli(idx)
{
    return (idx >= 0 && idx < MAX_RAPOR && Rapor[idx][rUsed]);
}

stock Temizle(str[])
{
    for(new i = 0; str[i] != EOS; i++)
    {
        if(str[i] == '|') str[i] = '/';
        else if(str[i] == '{') str[i] = '(';
        else if(str[i] == '}') str[i] = ')';
        else if(str[i] < ' ') str[i] = ' ';
    }
}

stock BosMu(const s[])
{
    for(new i = 0; s[i] != EOS; i++)
    {
        if(s[i] != ' ') return 0;
    }
    return 1;
}

stock SayiMi(const s[])
{
    if(s[0] == EOS) return 0;
    for(new i = 0; s[i] != EOS; i++)
    {
        if(s[i] < '0' || s[i] > '9') return 0;
    }
    return 1;
}

stock ZamanKisa(dest[], size)
{
    new y, mo, d, h, mi, s;
    getdate(y, mo, d);
    gettime(h, mi, s);
    format(dest, size, "%02d.%02d %02d:%02d", d, mo, h, mi);
}

stock ZamanTam(dest[], size)
{
    new y, mo, d, h, mi, s;
    getdate(y, mo, d);
    gettime(h, mi, s);
    format(dest, size, "%02d.%02d.%d %02d:%02d", d, mo, y, h, mi);
}

stock AdminAdi(playerid, dest[], size)
{
    new n[MAX_PLAYER_NAME];
    GetPlayerName(playerid, n, sizeof n);
    format(dest, size, "Admin %s", n);
}

stock OncMetin(o, dest[], size)
{
    switch(o)
    {
        case 3: format(dest, size, "{E06666}(!!!) Acil");
        case 2: format(dest, size, "{F0B040}(!) Yüksek");
        case 1: format(dest, size, "{FFFFFF}Normal");
        default: format(dest, size, "{9AA5B1}Düşük");
    }
}

stock SahipBul(idx)
{
    new n[MAX_PLAYER_NAME];
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if(!strcmp(n, Rapor[idx][rGonderen], true)) return i;
    }
    return INVALID_PLAYER_ID;
}

stock IsSahip(playerid, idx)
{
    new n[MAX_PLAYER_NAME];
    GetPlayerName(playerid, n, sizeof n);
    return (!strcmp(n, Rapor[idx][rGonderen], true));
}

stock AcikRaporSayisi()
{
    new c = 0;
    for(new i = 0; i < MAX_RAPOR; i++)
    {
        if(Rapor[i][rUsed] && !Rapor[i][rKapali]) c++;
    }
    return c;
}

stock AcilRaporSayisi()
{
    new c = 0;
    for(new i = 0; i < MAX_RAPOR; i++)
    {
        if(Rapor[i][rUsed] && !Rapor[i][rKapali] && Rapor[i][rOncelik] >= 3) c++;
    }
    return c;
}

stock Bol(const src[], parts[][130], maxparts)
{
    new n = 0, j = 0, len = strlen(src);
    for(new i = 0; i <= len; i++)
    {
        if(i == len || src[i] == '|')
        {
            if(n < maxparts)
            {
                parts[n][j] = EOS;
                n++;
            }
            j = 0;
        }
        else if(n < maxparts && j < 129)
        {
            parts[n][j++] = src[i];
        }
    }
    return n;
}

stock RaporTemizle(idx)
{
    Rapor[idx][rUsed] = 0;
    Rapor[idx][rGonderen][0] = EOS;
    Rapor[idx][rSikayet][0] = EOS;
    Rapor[idx][rKategori] = 0;
    Rapor[idx][rDurum] = 0;
    Rapor[idx][rOncelik] = 1;
    Rapor[idx][rKapali] = 0;
    Rapor[idx][rZaman][0] = EOS;
    Rapor[idx][rAciklama][0] = EOS;
    Rapor[idx][rKanit][0] = EOS;
    Rapor[idx][rOyOkunmamis] = 0;
    Rapor[idx][rAdOkunmamis] = 0;
    Rapor[idx][rMesajSayi] = 0;
    Rapor[idx][rLogSayi] = 0;
}

stock LogEkle(idx, const metin[])
{
    if(Rapor[idx][rLogSayi] >= MAX_LOG)
    {
        for(new k = 1; k < MAX_LOG; k++)
        {
            format(LogZaman[idx][k - 1], 12, "%s", LogZaman[idx][k]);
            format(LogMetin[idx][k - 1], 96, "%s", LogMetin[idx][k]);
        }
        Rapor[idx][rLogSayi] = MAX_LOG - 1;
    }
    new n = Rapor[idx][rLogSayi];
    ZamanKisa(LogZaman[idx][n], 12);
    format(LogMetin[idx][n], 96, "%s", metin);
    Rapor[idx][rLogSayi]++;
}

stock MesajEkle(idx, const isim[], admin, const metin[])
{
    if(Rapor[idx][rMesajSayi] >= MAX_MESAJ)
    {
        for(new k = 1; k < MAX_MESAJ; k++)
        {
            format(MsgZaman[idx][k - 1], 12, "%s", MsgZaman[idx][k]);
            format(MsgIsim[idx][k - 1], MAX_PLAYER_NAME, "%s", MsgIsim[idx][k]);
            MsgAdmin[idx][k - 1] = MsgAdmin[idx][k];
            format(MsgMetin[idx][k - 1], 80, "%s", MsgMetin[idx][k]);
        }
        Rapor[idx][rMesajSayi] = MAX_MESAJ - 1;
    }
    new n = Rapor[idx][rMesajSayi];
    ZamanKisa(MsgZaman[idx][n], 12);
    format(MsgIsim[idx][n], MAX_PLAYER_NAME, "%s", isim);
    MsgAdmin[idx][n] = admin;
    strmid(MsgMetin[idx][n], metin, 0, 79, 80);
    Rapor[idx][rMesajSayi]++;
}

// ------------------------------------------------------------------
// KALICI KAYIT
// ------------------------------------------------------------------
stock RaporKaydet(idx)
{
    new path[40], line[420];
    format(path, sizeof path, DOSYA_FORMAT, idx + 1);
    new File:f = fopen(path, io_write);
    if(!f) return 0;

    format(line, sizeof line, "H|%d|%s|%s|%d|%d|%d|%d|%s|%s|%s|%d|%d\n",
        idx + 1, Rapor[idx][rGonderen], Rapor[idx][rSikayet], Rapor[idx][rKategori],
        Rapor[idx][rDurum], Rapor[idx][rOncelik], Rapor[idx][rKapali], Rapor[idx][rZaman],
        Rapor[idx][rAciklama], Rapor[idx][rKanit], Rapor[idx][rOyOkunmamis], Rapor[idx][rAdOkunmamis]);
    fwrite(f, line);

    for(new k = 0; k < Rapor[idx][rMesajSayi]; k++)
    {
        format(line, sizeof line, "M|%s|%s|%d|%s\n", MsgZaman[idx][k], MsgIsim[idx][k], MsgAdmin[idx][k], MsgMetin[idx][k]);
        fwrite(f, line);
    }
    for(new k = 0; k < Rapor[idx][rLogSayi]; k++)
    {
        format(line, sizeof line, "L|%s|%s\n", LogZaman[idx][k], LogMetin[idx][k]);
        fwrite(f, line);
    }
    fclose(f);
    return 1;
}

stock RaporlariYukle()
{
    new path[40], line[420], parts[13][130], yuklenen = 0;
    for(new i = 0; i < MAX_RAPOR; i++)
    {
        RaporTemizle(i);
        format(path, sizeof path, DOSYA_FORMAT, i + 1);
        if(!fexist(path)) continue;
        new File:f = fopen(path, io_read);
        if(!f) continue;

        while(fread(f, line))
        {
            new n = strlen(line);
            while(n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r')) line[--n] = EOS;
            if(n < 2) continue;

            new cnt = Bol(line, parts, 13);
            switch(line[0])
            {
                case 'H':
                {
                    if(cnt < 11) continue;
                    Rapor[i][rUsed] = 1;
                    format(Rapor[i][rGonderen], MAX_PLAYER_NAME, "%s", parts[2]);
                    format(Rapor[i][rSikayet], MAX_PLAYER_NAME, "%s", parts[3]);
                    Rapor[i][rKategori] = strval(parts[4]);
                    Rapor[i][rDurum] = strval(parts[5]);
                    Rapor[i][rOncelik] = strval(parts[6]);
                    Rapor[i][rKapali] = strval(parts[7]);
                    format(Rapor[i][rZaman], 20, "%s", parts[8]);
                    format(Rapor[i][rAciklama], 128, "%s", parts[9]);
                    format(Rapor[i][rKanit], 96, "%s", parts[10]);
                    if(cnt >= 13)
                    {
                        Rapor[i][rOyOkunmamis] = strval(parts[11]);
                        Rapor[i][rAdOkunmamis] = strval(parts[12]);
                    }
                    if(Rapor[i][rKategori] < 0 || Rapor[i][rKategori] > 5) Rapor[i][rKategori] = 5;
                    if(Rapor[i][rDurum] < 0 || Rapor[i][rDurum] > 4) Rapor[i][rDurum] = 0;
                    if(Rapor[i][rOncelik] < 0 || Rapor[i][rOncelik] > 3) Rapor[i][rOncelik] = 1;
                    if(Rapor[i][rKapali] != 0) Rapor[i][rKapali] = 1;
                }
                case 'M':
                {
                    if(cnt < 5 || Rapor[i][rMesajSayi] >= MAX_MESAJ) continue;
                    new m = Rapor[i][rMesajSayi];
                    format(MsgZaman[i][m], 12, "%s", parts[1]);
                    format(MsgIsim[i][m], MAX_PLAYER_NAME, "%s", parts[2]);
                    MsgAdmin[i][m] = strval(parts[3]);
                    format(MsgMetin[i][m], 80, "%s", parts[4]);
                    Rapor[i][rMesajSayi]++;
                }
                case 'L':
                {
                    if(cnt < 3 || Rapor[i][rLogSayi] >= MAX_LOG) continue;
                    new l = Rapor[i][rLogSayi];
                    format(LogZaman[i][l], 12, "%s", parts[1]);
                    format(LogMetin[i][l], 96, "%s", parts[2]);
                    Rapor[i][rLogSayi]++;
                }
            }
        }
        fclose(f);
        if(Rapor[i][rUsed]) yuklenen++;
    }
    printf("[RAPOR] %d rapor yuklendi.", yuklenen);
}

// ------------------------------------------------------------------
// ARAYUZ (buton + bildirim)
// ------------------------------------------------------------------
stock AdminUIOlustur(playerid)
{
    if(pBtn[playerid]) return 1;
    new str[48];
    pBtnSayi[playerid] = AcikRaporSayisi();
    pBtnAcil[playerid] = AcilRaporSayisi();
    format(str, sizeof str, "AKTIF RAPORLAR [%d]", pBtnSayi[playerid]);

    ptBtn[playerid] = CreatePlayerTextDraw(playerid, 18.0, 436.0, str);
    PlayerTextDrawLetterSize(playerid, ptBtn[playerid], 0.22, 1.0);
    PlayerTextDrawTextSize(playerid, ptBtn[playerid], 128.0, 12.0);
    PlayerTextDrawAlignment(playerid, ptBtn[playerid], 1);
    PlayerTextDrawColor(playerid, ptBtn[playerid], 0xFFFFFFFF);
    PlayerTextDrawUseBox(playerid, ptBtn[playerid], 1);
    PlayerTextDrawBoxColor(playerid, ptBtn[playerid], pBtnAcil[playerid] > 0 ? 0x8C3A3ACC : 0x1E2A38CC);
    PlayerTextDrawFont(playerid, ptBtn[playerid], 1);
    PlayerTextDrawSetShadow(playerid, ptBtn[playerid], 0);
    PlayerTextDrawSetOutline(playerid, ptBtn[playerid], 0);
    PlayerTextDrawSetSelectable(playerid, ptBtn[playerid], 1);
    PlayerTextDrawShow(playerid, ptBtn[playerid]);
    pBtn[playerid] = true;
    return 1;
}

stock AdminUIKaldir(playerid)
{
    if(pBtn[playerid])
    {
        PlayerTextDrawDestroy(playerid, ptBtn[playerid]);
        pBtn[playerid] = false;
    }
    if(pToastVar[playerid])
    {
        PlayerTextDrawDestroy(playerid, ptToast[playerid]);
        pToastVar[playerid] = false;
    }
    pToastRapor[playerid] = -1;
}

stock AdminUIGuncelle(playerid, sayi, acil)
{
    if(!pBtn[playerid]) return 0;
    if(sayi == pBtnSayi[playerid] && acil == pBtnAcil[playerid]) return 1;
    new str[48];
    pBtnSayi[playerid] = sayi;
    pBtnAcil[playerid] = acil;
    format(str, sizeof str, "AKTIF RAPORLAR [%d]", sayi);
    PlayerTextDrawSetString(playerid, ptBtn[playerid], str);
    PlayerTextDrawBoxColor(playerid, ptBtn[playerid], acil > 0 ? 0x8C3A3ACC : 0x1E2A38CC);
    PlayerTextDrawShow(playerid, ptBtn[playerid]);
    return 1;
}

stock ToastGoster(playerid, idx)
{
    AdminUIOlustur(playerid);
    if(!pToastVar[playerid])
    {
        ptToast[playerid] = CreatePlayerTextDraw(playerid, 225.0, 92.0, "_");
        PlayerTextDrawLetterSize(playerid, ptToast[playerid], 0.30, 1.4);
        PlayerTextDrawTextSize(playerid, ptToast[playerid], 415.0, 14.0);
        PlayerTextDrawAlignment(playerid, ptToast[playerid], 1);
        PlayerTextDrawColor(playerid, ptToast[playerid], 0xFFFFFFFF);
        PlayerTextDrawUseBox(playerid, ptToast[playerid], 1);
        PlayerTextDrawBoxColor(playerid, ptToast[playerid], 0x1B2733DD);
        PlayerTextDrawFont(playerid, ptToast[playerid], 1);
        PlayerTextDrawSetShadow(playerid, ptToast[playerid], 0);
        PlayerTextDrawSetSelectable(playerid, ptToast[playerid], 1);
        pToastVar[playerid] = true;
    }
    new str[96];
    format(str, sizeof str, "~y~Yeni Bir Rapor Düştü!~n~~w~Rapor #%d - %s", idx + 1, Rapor[idx][rGonderen]);
    PlayerTextDrawSetString(playerid, ptToast[playerid], str);
    PlayerTextDrawShow(playerid, ptToast[playerid]);
    pToastRapor[playerid] = idx;
    pToastSeq[playerid]++;
    SetTimerEx("ToastGizle", 6000, false, "ii", playerid, pToastSeq[playerid]);
    return 1;
}

public ToastGizle(playerid, seq)
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(pToastSeq[playerid] != seq) return 1;
    if(pToastVar[playerid]) PlayerTextDrawHide(playerid, ptToast[playerid]);
    pToastRapor[playerid] = -1;
    return 1;
}

public RaporUI()
{
    new sayi = AcikRaporSayisi(), acil = AcilRaporSayisi();
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || IsPlayerNPC(i)) continue;
        if(RaporAdminSeviyesi(i) > 0)
        {
            if(GetPlayerState(i) == PLAYER_STATE_NONE) continue;
            if(!pBtn[i])
            {
                AdminUIOlustur(i);
                if(!pBilgi[i])
                {
                    pBilgi[i] = true;
                    if(sayi > 0)
                    {
                        format(gTmp, sizeof gTmp, "[RAPOR] Bekleyen %d aktif rapor var. Haritanın altındaki butona veya /raporlar komutuna bas.", sayi);
                        SendClientMessage(i, RENK_BILGI, gTmp);
                    }
                }
            }
            else AdminUIGuncelle(i, sayi, acil);
        }
        else if(pBtn[i] || pToastVar[i])
        {
            AdminUIKaldir(i);
        }
    }
    return 1;
}

// ------------------------------------------------------------------
// BILDIRIMLER
// ------------------------------------------------------------------
stock YeniRaporBildir(idx, gonderenId)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || IsPlayerNPC(i) || i == gonderenId) continue;
        if(RaporAdminSeviyesi(i) < 1) continue;
        PlayerPlaySound(i, 1057, 0.0, 0.0, 0.0);
        ToastGoster(i, idx);
        format(gTmp, sizeof gTmp, "[RAPOR #%d] Yeni Bir Rapor Düştü! Gönderen: %s | Kategori: %s | /raporgor %d", idx + 1, Rapor[idx][rGonderen], KategoriAd[Rapor[idx][rKategori]], idx + 1);
        SendClientMessage(i, RENK_BILGI, gTmp);
    }
}

stock SahibeBildir(idx, const mesaj[])
{
    new sahip = SahipBul(idx);
    if(sahip == INVALID_PLAYER_ID) return 0;
    format(gTmp, sizeof gTmp, "[Rapor #%d] %s", idx + 1, mesaj);
    SendClientMessage(sahip, RENK_BILGI, gTmp);
    PlayerPlaySound(sahip, 1058, 0.0, 0.0, 0.0);
    return 1;
}

stock AdminlereMesajBildir(idx)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || IsPlayerNPC(i)) continue;
        if(RaporAdminSeviyesi(i) < 1) continue;
        format(gTmp, sizeof gTmp, "[RAPOR #%d] %s yeni mesaj gönderdi. (/raporgor %d)", idx + 1, Rapor[idx][rGonderen], idx + 1);
        SendClientMessage(i, RENK_BILGI, gTmp);
        PlayerPlaySound(i, 1058, 0.0, 0.0, 0.0);
    }
}

// ------------------------------------------------------------------
// ADMIN EKRANLARI
// ------------------------------------------------------------------
stock AdminListe(playerid)
{
    if(RaporAdminSeviyesi(playerid) < 1) return 0;

    new liste[MAX_RAPOR], adet = 0;
    for(new i = MAX_RAPOR - 1; i >= 0; i--)
    {
        if(!Rapor[i][rUsed]) continue;
        if(Rapor[i][rKapali] != pGecmis[playerid]) continue;
        if(pFltDurum[playerid] != -1 && Rapor[i][rDurum] != pFltDurum[playerid]) continue;
        if(pFltOnc[playerid] != -1 && Rapor[i][rOncelik] != pFltOnc[playerid]) continue;
        liste[adet++] = i;
    }

    new toplamSayfa = (adet + SAYFA_BOYUT - 1) / SAYFA_BOYUT;
    if(toplamSayfa < 1) toplamSayfa = 1;
    if(pSayfa[playerid] >= toplamSayfa) pSayfa[playerid] = toplamSayfa - 1;
    if(pSayfa[playerid] < 0) pSayfa[playerid] = 0;

    for(new k = 0; k < 20; k++)
    {
        pRowTip[playerid][k] = -1;
        pRowVal[playerid][k] = -1;
    }

    new row[220], satir = 0, ad1[40], ad2[40], onc[40];
    format(gDlg, sizeof gDlg, "ID\tGönderen\tŞikâyet Edilen\tDurum\tÖncelik\n");

    // filtre ve gecis satirlari
    if(pFltDurum[playerid] == -1) format(ad1, sizeof ad1, "Tümü");
    else format(ad1, sizeof ad1, "%s", DurumAd[pFltDurum[playerid]]);
    format(row, sizeof row, "{9AA5B1}>>\t{9AA5B1}Durum filtresi\t \t{FFFFFF}%s\t \n", ad1);
    strcat(gDlg, row, sizeof gDlg);
    pRowTip[playerid][satir++] = 1;

    if(pFltOnc[playerid] == -1) format(ad2, sizeof ad2, "Tümü");
    else format(ad2, sizeof ad2, "%s", OncAd[pFltOnc[playerid]]);
    format(row, sizeof row, "{9AA5B1}>>\t{9AA5B1}Öncelik filtresi\t \t \t{FFFFFF}%s\n", ad2);
    strcat(gDlg, row, sizeof gDlg);
    pRowTip[playerid][satir++] = 2;

    if(pGecmis[playerid]) format(row, sizeof row, "{9AA5B1}>>\t{9AA5B1}Aktif raporlara dön\t \t \t \n");
    else format(row, sizeof row, "{9AA5B1}>>\t{9AA5B1}Geçmiş / Sonuçlandırılmış raporlar\t \t \t \n");
    strcat(gDlg, row, sizeof gDlg);
    pRowTip[playerid][satir++] = 3;

    new bas = pSayfa[playerid] * SAYFA_BOYUT;
    new son = bas + SAYFA_BOYUT;
    if(son > adet) son = adet;

    if(adet == 0)
    {
        strcat(gDlg, "{FFFFFF}-\tGösterilecek rapor yok\t \t \t \n", sizeof gDlg);
        pRowTip[playerid][satir] = 0;
        pRowVal[playerid][satir] = -1;
        satir++;
    }
    for(new i = bas; i < son; i++)
    {
        new idx = liste[i];
        OncMetin(Rapor[idx][rOncelik], onc, sizeof onc);
        format(row, sizeof row, "{FFFFFF}#%d%s\t%s\t%s\t%s%s{FFFFFF}\t%s\n",
            idx + 1, (Rapor[idx][rAdOkunmamis] > 0) ? (" *") : (""),
            Rapor[idx][rGonderen], Rapor[idx][rSikayet],
            DurumRenk[Rapor[idx][rDurum]], DurumAd[Rapor[idx][rDurum]], onc);
        strcat(gDlg, row, sizeof gDlg);
        pRowTip[playerid][satir] = 0;
        pRowVal[playerid][satir] = idx;
        satir++;
    }
    if(pSayfa[playerid] > 0)
    {
        strcat(gDlg, "{9AA5B1}<<\t{9AA5B1}Önceki sayfa\t \t \t \n", sizeof gDlg);
        pRowTip[playerid][satir++] = 5;
    }
    if(pSayfa[playerid] < toplamSayfa - 1)
    {
        strcat(gDlg, "{9AA5B1}>>\t{9AA5B1}Sonraki sayfa\t \t \t \n", sizeof gDlg);
        pRowTip[playerid][satir++] = 4;
    }

    new baslik[96];
    if(pGecmis[playerid]) format(baslik, sizeof baslik, "Geçmiş Raporlar (%d) - Sayfa %d/%d", adet, pSayfa[playerid] + 1, toplamSayfa);
    else format(baslik, sizeof baslik, "Aktif Raporlar (%d) - Sayfa %d/%d", adet, pSayfa[playerid] + 1, toplamSayfa);

    ShowPlayerDialog(playerid, D_A_LISTE, DIALOG_STYLE_TABLIST_HEADERS, baslik, gDlg, "Seç", "Kapat");
    return 1;
}

stock AdminDetay(playerid, idx)
{
    if(RaporAdminSeviyesi(playerid) < 1 || !RaporGecerli(idx)) return 0;
    pRaporSec[playerid] = idx;

    new adm[40], tmp[128];

    // ilk kez acilan bekleyen rapor otomatik incelemeye alinir
    if(Rapor[idx][rKapali] == 0 && Rapor[idx][rDurum] == DURUM_BEKLIYOR)
    {
        Rapor[idx][rDurum] = DURUM_INCELENIYOR;
        AdminAdi(playerid, adm, sizeof adm);
        format(tmp, sizeof tmp, "%s raporu incelemeye aldı", adm);
        LogEkle(idx, tmp);
        RaporKaydet(idx);
        SahibeBildir(idx, "Raporunuz incelemeye alındı.");
    }

    new onc[40];
    OncMetin(Rapor[idx][rOncelik], onc, sizeof onc);

    format(gDlg, sizeof gDlg,
        "{9AA5B1}Rapor ID: {FFFFFF}#%d\n{9AA5B1}Gönderen: {FFFFFF}%s\n{9AA5B1}Şikâyet edilen: {FFFFFF}%s\n{9AA5B1}Kategori: {FFFFFF}%s\n{9AA5B1}Tarih: {FFFFFF}%s\n{9AA5B1}Durum: %s%s{FFFFFF}%s\n{9AA5B1}Öncelik: %s\n",
        idx + 1, Rapor[idx][rGonderen], Rapor[idx][rSikayet], KategoriAd[Rapor[idx][rKategori]], Rapor[idx][rZaman],
        DurumRenk[Rapor[idx][rDurum]], DurumAd[Rapor[idx][rDurum]], (Rapor[idx][rKapali]) ? ("  (KAPALI)") : (""), onc);

    format(gTmp, sizeof gTmp, "{9AA5B1}Açıklama: {FFFFFF}%s\n{9AA5B1}Kanıt: {FFFFFF}%s\n{9AA5B1}Mesaj sayısı: {FFFFFF}%d\n\n{9AA5B1}--- İşlem Geçmişi ---\n",
        Rapor[idx][rAciklama], Rapor[idx][rKanit], Rapor[idx][rMesajSayi]);
    strcat(gDlg, gTmp, sizeof gDlg);

    if(Rapor[idx][rLogSayi] == 0) strcat(gDlg, "{FFFFFF}Kayıt yok.\n", sizeof gDlg);
    for(new k = 0; k < Rapor[idx][rLogSayi]; k++)
    {
        format(gTmp, sizeof gTmp, "{9AA5B1}%s  {FFFFFF}%s\n", LogZaman[idx][k], LogMetin[idx][k]);
        strcat(gDlg, gTmp, sizeof gDlg);
    }

    format(tmp, sizeof tmp, "Rapor #%d", idx + 1);
    ShowPlayerDialog(playerid, D_A_DETAY, DIALOG_STYLE_MSGBOX, tmp, gDlg, "İşlemler", "Geri");
    return 1;
}

stock AdminIslemMenu(playerid, idx)
{
    new baslik[32];
    format(baslik, sizeof baslik, "Rapor #%d - İşlemler", idx + 1);
    if(Rapor[idx][rKapali])
        ShowPlayerDialog(playerid, D_A_ISLEM, DIALOG_STYLE_LIST, baslik, "Mesajları Görüntüle\nRaporu Yeniden Aç", "Seç", "Geri");
    else
        ShowPlayerDialog(playerid, D_A_ISLEM, DIALOG_STYLE_LIST, baslik, "Durum Değiştir\nÖncelik Değiştir\nMesajlar / Yanıt Yaz\nRaporu Kapat", "Seç", "Geri");
}

stock MesajMetniOlustur(idx)
{
    gDlg[0] = EOS;
    if(Rapor[idx][rMesajSayi] == 0)
    {
        strcat(gDlg, "{FFFFFF}Henüz mesaj yok.", sizeof gDlg);
        return 1;
    }
    for(new k = 0; k < Rapor[idx][rMesajSayi]; k++)
    {
        if(MsgAdmin[idx][k])
            format(gTmp, sizeof gTmp, "{9AA5B1}[%s] {5DADE2}%s (Admin){FFFFFF}: %s\n", MsgZaman[idx][k], MsgIsim[idx][k], MsgMetin[idx][k]);
        else
            format(gTmp, sizeof gTmp, "{9AA5B1}[%s] {E0E0E0}%s{FFFFFF}: %s\n", MsgZaman[idx][k], MsgIsim[idx][k], MsgMetin[idx][k]);
        strcat(gDlg, gTmp, sizeof gDlg);
    }
    return 1;
}

stock AdminMesajlar(playerid, idx)
{
    if(RaporAdminSeviyesi(playerid) < 1 || !RaporGecerli(idx)) return 0;
    pRaporSec[playerid] = idx;
    if(Rapor[idx][rAdOkunmamis] > 0)
    {
        Rapor[idx][rAdOkunmamis] = 0;
        RaporKaydet(idx);
    }
    MesajMetniOlustur(idx);
    new baslik[32];
    format(baslik, sizeof baslik, "Rapor #%d - Mesajlar", idx + 1);
    if(Rapor[idx][rKapali]) ShowPlayerDialog(playerid, D_A_MESAJLAR, DIALOG_STYLE_MSGBOX, baslik, gDlg, "Geri", "");
    else ShowPlayerDialog(playerid, D_A_MESAJLAR, DIALOG_STYLE_MSGBOX, baslik, gDlg, "Yanıt Yaz", "Geri");
    return 1;
}

// ------------------------------------------------------------------
// OYUNCU EKRANLARI
// ------------------------------------------------------------------
stock OyuncuListe(playerid)
{
    new adet = 0;
    for(new i = 0; i < OYUNCU_LISTE_MAX; i++) pOyMap[playerid][i] = -1;

    format(gDlg, sizeof gDlg, "ID\tŞikâyet Edilen\tDurum\tTarih\n");
    for(new i = MAX_RAPOR - 1; i >= 0 && adet < OYUNCU_LISTE_MAX; i--)
    {
        if(!Rapor[i][rUsed]) continue;
        if(!IsSahip(playerid, i)) continue;
        pOyMap[playerid][adet++] = i;
        format(gTmp, sizeof gTmp, "{FFFFFF}#%d%s\t%s\t%s%s{FFFFFF}\t%s\n", i + 1,
            (Rapor[i][rOyOkunmamis] > 0) ? (" (yeni mesaj)") : (""),
            Rapor[i][rSikayet], DurumRenk[Rapor[i][rDurum]], DurumAd[Rapor[i][rDurum]], Rapor[i][rZaman]);
        strcat(gDlg, gTmp, sizeof gDlg);
    }
    if(adet == 0)
    {
        SendClientMessage(playerid, RENK_HATA, "[Rapor] Henüz bir rapor göndermedin. (/rapor)");
        return 0;
    }
    ShowPlayerDialog(playerid, D_O_LISTE, DIALOG_STYLE_TABLIST_HEADERS, "Raporlarım", gDlg, "Aç", "Kapat");
    return 1;
}

stock OyuncuDetay(playerid, idx)
{
    if(!RaporGecerli(idx) || !IsSahip(playerid, idx)) return 0;
    pRaporSec[playerid] = idx;

    format(gDlg, sizeof gDlg,
        "{9AA5B1}Rapor ID: {FFFFFF}#%d\n{9AA5B1}Şikâyet edilen: {FFFFFF}%s\n{9AA5B1}Kategori: {FFFFFF}%s\n{9AA5B1}Tarih: {FFFFFF}%s\n{9AA5B1}Durum: %s%s{FFFFFF}%s\n",
        idx + 1, Rapor[idx][rSikayet], KategoriAd[Rapor[idx][rKategori]], Rapor[idx][rZaman],
        DurumRenk[Rapor[idx][rDurum]], DurumAd[Rapor[idx][rDurum]], (Rapor[idx][rKapali]) ? ("  (KAPANDI)") : (""));
    format(gTmp, sizeof gTmp, "{9AA5B1}Açıklama: {FFFFFF}%s\n{9AA5B1}Kanıt: {FFFFFF}%s\n{9AA5B1}Mesaj sayısı: {FFFFFF}%d",
        Rapor[idx][rAciklama], Rapor[idx][rKanit], Rapor[idx][rMesajSayi]);
    strcat(gDlg, gTmp, sizeof gDlg);

    format(gTmp, sizeof gTmp, "Rapor #%d", idx + 1);
    ShowPlayerDialog(playerid, D_O_DETAY, DIALOG_STYLE_MSGBOX, gTmp, gDlg, "Mesajlar", "Geri");
    return 1;
}

stock OyuncuMesajlar(playerid, idx)
{
    if(!RaporGecerli(idx) || !IsSahip(playerid, idx)) return 0;
    pRaporSec[playerid] = idx;
    if(Rapor[idx][rOyOkunmamis] > 0)
    {
        Rapor[idx][rOyOkunmamis] = 0;
        RaporKaydet(idx);
    }
    MesajMetniOlustur(idx);
    new baslik[32];
    format(baslik, sizeof baslik, "Rapor #%d - Mesajlar", idx + 1);
    if(Rapor[idx][rKapali]) ShowPlayerDialog(playerid, D_O_MESAJLAR, DIALOG_STYLE_MSGBOX, baslik, gDlg, "Geri", "");
    else ShowPlayerDialog(playerid, D_O_MESAJLAR, DIALOG_STYLE_MSGBOX, baslik, gDlg, "Mesaj Yaz", "Geri");
    return 1;
}

// ------------------------------------------------------------------
// RAPOR OLUSTURMA
// ------------------------------------------------------------------
stock HedefBul(const girdi[], hedef[], size)
{
    new n[MAX_PLAYER_NAME];
    if(SayiMi(girdi))
    {
        new id = strval(girdi);
        if(id < 0 || id >= MAX_PLAYERS || !IsPlayerConnected(id)) return 0;
        GetPlayerName(id, hedef, size);
        return 1;
    }
    if(strlen(girdi) < 3) return 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if(!strcmp(n, girdi, true))
        {
            format(hedef, size, "%s", n);
            return 1;
        }
    }
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if(strfind(n, girdi, true) != -1)
        {
            format(hedef, size, "%s", n);
            return 1;
        }
    }
    // oyundan cikmis olabilir: yazilan isim aynen kaydedilir
    format(hedef, size, "%s", girdi);
    return 1;
}

stock RaporBaslat(playerid, const girdi[])
{
    new n[MAX_PLAYER_NAME], acik = 0;
    GetPlayerName(playerid, n, sizeof n);

    if(gettime() - pSonRapor[playerid] < RAPOR_BEKLEME)
    {
        format(gTmp, sizeof gTmp, "[Rapor] Yeni rapor göndermek için %d saniye beklemelisin.", RAPOR_BEKLEME - (gettime() - pSonRapor[playerid]));
        SendClientMessage(playerid, RENK_HATA, gTmp);
        return 0;
    }
    for(new i = 0; i < MAX_RAPOR; i++)
    {
        if(Rapor[i][rUsed] && !Rapor[i][rKapali] && IsSahip(playerid, i)) acik++;
    }
    if(acik >= MAX_ACIK_RAPOR_OYUNCU)
    {
        SendClientMessage(playerid, RENK_HATA, "[Rapor] En fazla 3 açık raporun olabilir. Önce mevcut raporların sonuçlanmasını bekle. (/raporlarim)");
        return 0;
    }

    if(girdi[0] == EOS)
    {
        ShowPlayerDialog(playerid, D_O_ISIM, DIALOG_STYLE_INPUT, "Rapor Gönder (1/4)", "{FFFFFF}Şikâyet etmek istediğin oyuncunun ID'sini veya adını yaz:", "İleri", "İptal");
        return 1;
    }
    if(!HedefBul(girdi, pHedef[playerid], MAX_PLAYER_NAME))
    {
        SendClientMessage(playerid, RENK_HATA, "[Rapor] Oyuncu bulunamadı. ID veya en az 3 harfli isim yaz.");
        return 0;
    }
    if(!strcmp(pHedef[playerid], n, true))
    {
        SendClientMessage(playerid, RENK_HATA, "[Rapor] Kendini şikâyet edemezsin.");
        return 0;
    }
    DialogKategori(playerid);
    return 1;
}

stock DialogKategori(playerid)
{
    gDlg[0] = EOS;
    for(new i = 0; i < 6; i++)
    {
        strcat(gDlg, KategoriAd[i], sizeof gDlg);
        strcat(gDlg, "\n", sizeof gDlg);
    }
    ShowPlayerDialog(playerid, D_O_KAT, DIALOG_STYLE_LIST, "Rapor Gönder (2/4) - Kategori", gDlg, "İleri", "İptal");
}

stock RaporOlustur(playerid, const kanit[])
{
    new idx = -1;
    for(new i = 0; i < MAX_RAPOR; i++)
    {
        if(!Rapor[i][rUsed]) { idx = i; break; }
    }
    if(idx == -1) return -1;

    RaporTemizle(idx);
    Rapor[idx][rUsed] = 1;
    GetPlayerName(playerid, Rapor[idx][rGonderen], MAX_PLAYER_NAME);
    format(Rapor[idx][rSikayet], MAX_PLAYER_NAME, "%s", pHedef[playerid]);
    Rapor[idx][rKategori] = pKat[playerid];
    Rapor[idx][rDurum] = DURUM_BEKLIYOR;
    Rapor[idx][rOncelik] = 1;
    Rapor[idx][rKapali] = 0;
    ZamanTam(Rapor[idx][rZaman], 20);
    format(Rapor[idx][rAciklama], 128, "%s", pAcik[playerid]);
    format(Rapor[idx][rKanit], 96, "%s", kanit);

    new tmp[64];
    format(tmp, sizeof tmp, "%s raporu oluşturdu", Rapor[idx][rGonderen]);
    LogEkle(idx, tmp);
    RaporKaydet(idx);
    return idx;
}

// ------------------------------------------------------------------
// BASLANGIC / BITIS
// ------------------------------------------------------------------
public OnFilterScriptInit()
{
    RaporlariYukle();
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        pRaporSec[i] = -1;
        pFltDurum[i] = -1;
        pFltOnc[i] = -1;
        pToastRapor[i] = -1;
    }
    SetTimer("RaporUI", 2000, true);
    print("[RAPOR] DUKTUR RP Admin Rapor Yonetim Sistemi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i)) AdminUIKaldir(i);
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    pRaporSec[playerid] = -1;
    pFltDurum[playerid] = -1;
    pFltOnc[playerid] = -1;
    pSayfa[playerid] = 0;
    pGecmis[playerid] = 0;
    pSonRapor[playerid] = 0;
    pBtn[playerid] = false;
    pToastVar[playerid] = false;
    pBilgi[playerid] = false;
    pToastRapor[playerid] = -1;
    pBtnSayi[playerid] = -1;
    pBtnAcil[playerid] = -1;
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    pBtn[playerid] = false;
    pToastVar[playerid] = false;
    pBilgi[playerid] = false;
    pToastSeq[playerid]++;
    return 1;
}

// ------------------------------------------------------------------
// AYARLAR MENUSU (/ayarlar)
// Diger sistemlerin komutlari buradan degistirilebilir:
// ------------------------------------------------------------------
#define KOMUT_GIRIS     "/giris"
#define KOMUT_KAYIT     "/kayit"
#define KOMUT_EVENTER   "/eventer"
#define KOMUT_TELEFON   "/telefon"

stock AyarlarMenu(playerid)
{
    format(gDlg, sizeof gDlg, "Giriş\nKayıt\nRapor\nRaporlarım\nEventer\nTelefon");
    if(RaporAdminSeviyesi(playerid) > 0)
    {
        format(gTmp, sizeof gTmp, "\nAktif Raporlar [%d]", AcikRaporSayisi());
        strcat(gDlg, gTmp, sizeof gDlg);
    }
    ShowPlayerDialog(playerid, D_AYARLAR, DIALOG_STYLE_LIST, "Ayarlar", gDlg, "Seç", "Kapat");
}

stock AyarKomutCalistir(playerid, const komut[])
{
    CallRemoteFunction("OnPlayerCommandText", "is", playerid, komut);
}

// ------------------------------------------------------------------
// KOMUTLAR
// ------------------------------------------------------------------
public OnPlayerCommandText(playerid, cmdtext[])
{
    new cmd[24], idx = 0, param[64];
    while(cmdtext[idx] > ' ' && idx < 23)
    {
        cmd[idx] = cmdtext[idx];
        idx++;
    }
    cmd[idx] = EOS;
    while(cmdtext[idx] == ' ') idx++;
    format(param, sizeof param, "%s", cmdtext[idx]);

    if(!strcmp(cmd, "/rapor", true))
    {
        Temizle(param);
        RaporBaslat(playerid, param);
        return 1;
    }
    if(!strcmp(cmd, "/ayarlar", true))
    {
        AyarlarMenu(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/raporlarim", true))
    {
        OyuncuListe(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/raporlar", true))
    {
        if(RaporAdminSeviyesi(playerid) < 1) return SendClientMessage(playerid, RENK_HATA, "[Rapor] Bu komutu kullanma yetkin yok.");
        pSayfa[playerid] = 0;
        AdminListe(playerid);
        return 1;
    }
    if(!strcmp(cmd, "/raporgor", true))
    {
        if(RaporAdminSeviyesi(playerid) < 1) return SendClientMessage(playerid, RENK_HATA, "[Rapor] Bu komutu kullanma yetkin yok.");
        if(!SayiMi(param)) return SendClientMessage(playerid, RENK_BILGI, "Kullanım: /raporgor [rapor id]");
        new r = strval(param) - 1;
        if(!RaporGecerli(r)) return SendClientMessage(playerid, RENK_HATA, "[Rapor] Böyle bir rapor yok.");
        AdminDetay(playerid, r);
        return 1;
    }
    return 0;
}

// ------------------------------------------------------------------
// TIKLAMA (buton ve bildirim)
// ------------------------------------------------------------------
public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
    if(pBtn[playerid] && playertextid == ptBtn[playerid])
    {
        CancelSelectTextDraw(playerid);
        if(RaporAdminSeviyesi(playerid) < 1) return 1;
        pSayfa[playerid] = 0;
        AdminListe(playerid);
        return 1;
    }
    if(pToastVar[playerid] && playertextid == ptToast[playerid])
    {
        CancelSelectTextDraw(playerid);
        if(RaporAdminSeviyesi(playerid) < 1) return 1;
        new r = pToastRapor[playerid];
        PlayerTextDrawHide(playerid, ptToast[playerid]);
        pToastRapor[playerid] = -1;
        if(RaporGecerli(r)) AdminDetay(playerid, r);
        return 1;
    }
    return 0;
}

// ------------------------------------------------------------------
// DIYALOGLAR
// ------------------------------------------------------------------
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        // ================= ADMIN =================
        case D_A_LISTE:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            if(!response) return 1;
            if(listitem < 0 || listitem >= 20) return 1;

            switch(pRowTip[playerid][listitem])
            {
                case 0:
                {
                    new r = pRowVal[playerid][listitem];
                    if(RaporGecerli(r)) AdminDetay(playerid, r);
                    else AdminListe(playerid);
                }
                case 1:
                {
                    gDlg[0] = EOS;
                    strcat(gDlg, "Tümü\n", sizeof gDlg);
                    for(new i = 0; i < 5; i++)
                    {
                        strcat(gDlg, DurumAd[i], sizeof gDlg);
                        strcat(gDlg, "\n", sizeof gDlg);
                    }
                    ShowPlayerDialog(playerid, D_A_DURUM_FLT, DIALOG_STYLE_LIST, "Duruma göre filtrele", gDlg, "Seç", "Geri");
                }
                case 2:
                {
                    ShowPlayerDialog(playerid, D_A_ONC_FLT, DIALOG_STYLE_LIST, "Önceliğe göre filtrele", "Tümü\nDüşük\nNormal\nYüksek\nAcil", "Seç", "Geri");
                }
                case 3:
                {
                    pGecmis[playerid] = !pGecmis[playerid];
                    pSayfa[playerid] = 0;
                    AdminListe(playerid);
                }
                case 4:
                {
                    pSayfa[playerid]++;
                    AdminListe(playerid);
                }
                case 5:
                {
                    pSayfa[playerid]--;
                    AdminListe(playerid);
                }
                default: AdminListe(playerid);
            }
            return 1;
        }
        case D_A_DURUM_FLT:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            if(response)
            {
                pFltDurum[playerid] = listitem - 1;
                pSayfa[playerid] = 0;
            }
            AdminListe(playerid);
            return 1;
        }
        case D_A_ONC_FLT:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            if(response)
            {
                pFltOnc[playerid] = listitem - 1;
                pSayfa[playerid] = 0;
            }
            AdminListe(playerid);
            return 1;
        }
        case D_A_DETAY:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r)) return 1;
            if(response) AdminIslemMenu(playerid, r);
            else AdminListe(playerid);
            return 1;
        }
        case D_A_ISLEM:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r)) return 1;
            if(!response)
            {
                AdminDetay(playerid, r);
                return 1;
            }
            if(Rapor[r][rKapali])
            {
                if(listitem == 0) AdminMesajlar(playerid, r);
                else
                {
                    if(RaporAdminSeviyesi(playerid) < YENIDEN_ACMA_MIN_SEVIYE)
                    {
                        SendClientMessage(playerid, RENK_HATA, "[Rapor] Kapalı raporu yeniden açma yetkin yok.");
                        AdminDetay(playerid, r);
                    }
                    else
                    {
                        ShowPlayerDialog(playerid, D_A_ACMA, DIALOG_STYLE_MSGBOX, "Raporu Yeniden Aç", "{FFFFFF}Bu raporu yeniden açmak istediğine emin misin?", "Evet, Aç", "Vazgeç");
                    }
                }
                return 1;
            }
            switch(listitem)
            {
                case 0:
                {
                    gDlg[0] = EOS;
                    for(new i = 1; i < 5; i++)
                    {
                        strcat(gDlg, DurumRenk[i], sizeof gDlg);
                        strcat(gDlg, DurumAd[i], sizeof gDlg);
                        strcat(gDlg, "\n", sizeof gDlg);
                    }
                    ShowPlayerDialog(playerid, D_A_DURUM, DIALOG_STYLE_LIST, "Rapor Durumu", gDlg, "Uygula", "Geri");
                }
                case 1:
                {
                    ShowPlayerDialog(playerid, D_A_ONCELIK, DIALOG_STYLE_LIST, "Rapor Önceliği", "Düşük\nNormal\nYüksek\nAcil", "Uygula", "Geri");
                }
                case 2: AdminMesajlar(playerid, r);
                case 3:
                {
                    ShowPlayerDialog(playerid, D_A_KAPAT, DIALOG_STYLE_MSGBOX, "Raporu Kapat", "{FFFFFF}Raporu sonuçlandırıp kapatmak istediğine emin misin?\n{9AA5B1}Rapor silinmez, Geçmiş Raporlar bölümüne taşınır.", "Evet, Kapat", "Vazgeç");
                }
            }
            return 1;
        }
        case D_A_DURUM:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || Rapor[r][rKapali]) return 1;
            if(!response)
            {
                AdminDetay(playerid, r);
                return 1;
            }
            new yeni = listitem + 1;
            if(yeni < 1 || yeni > 4) return 1;
            if(Rapor[r][rDurum] != yeni)
            {
                new adm[40], tmp[110];
                Rapor[r][rDurum] = yeni;
                AdminAdi(playerid, adm, sizeof adm);
                format(tmp, sizeof tmp, "%s durumu %s olarak değiştirdi", adm, DurumAd[yeni]);
                LogEkle(r, tmp);
                RaporKaydet(r);
                format(tmp, sizeof tmp, "Raporunun durumu güncellendi: %s", DurumAd[yeni]);
                SahibeBildir(r, tmp);
            }
            AdminDetay(playerid, r);
            return 1;
        }
        case D_A_ONCELIK:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || Rapor[r][rKapali]) return 1;
            if(!response)
            {
                AdminDetay(playerid, r);
                return 1;
            }
            if(listitem < 0 || listitem > 3) return 1;
            if(Rapor[r][rOncelik] != listitem)
            {
                new adm[40], tmp[110];
                Rapor[r][rOncelik] = listitem;
                AdminAdi(playerid, adm, sizeof adm);
                format(tmp, sizeof tmp, "%s önceliği %s olarak değiştirdi", adm, OncAd[listitem]);
                LogEkle(r, tmp);
                RaporKaydet(r);
            }
            AdminDetay(playerid, r);
            return 1;
        }
        case D_A_MESAJLAR:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r)) return 1;
            if(response && !Rapor[r][rKapali])
            {
                new baslik[32];
                format(baslik, sizeof baslik, "Rapor #%d - Yanıt", r + 1);
                ShowPlayerDialog(playerid, D_A_MESAJ_YAZ, DIALOG_STYLE_INPUT, baslik, "{FFFFFF}Oyuncuya göndereceğin mesajı yaz:", "Gönder", "İptal");
            }
            else AdminDetay(playerid, r);
            return 1;
        }
        case D_A_MESAJ_YAZ:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || Rapor[r][rKapali]) return 1;
            if(!response)
            {
                AdminMesajlar(playerid, r);
                return 1;
            }
            Temizle(inputtext);
            if(BosMu(inputtext))
            {
                ShowPlayerDialog(playerid, D_A_MESAJ_YAZ, DIALOG_STYLE_INPUT, "Yanıt", "{E06666}Mesaj boş olamaz.\n{FFFFFF}Oyuncuya göndereceğin mesajı yaz:", "Gönder", "İptal");
                return 1;
            }
            new isim[MAX_PLAYER_NAME], adm[40], tmp[110];
            GetPlayerName(playerid, isim, sizeof isim);
            MesajEkle(r, isim, 1, inputtext);
            Rapor[r][rOyOkunmamis]++;
            AdminAdi(playerid, adm, sizeof adm);
            format(tmp, sizeof tmp, "%s rapora mesaj gönderdi", adm);
            LogEkle(r, tmp);
            RaporKaydet(r);
            format(tmp, sizeof tmp, "%s size yanıt verdi. (/raporlarim)", adm);
            SahibeBildir(r, tmp);
            AdminMesajlar(playerid, r);
            return 1;
        }
        case D_A_KAPAT:
        {
            if(RaporAdminSeviyesi(playerid) < 1) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || Rapor[r][rKapali]) return 1;
            if(!response)
            {
                AdminDetay(playerid, r);
                return 1;
            }
            new adm[40], tmp[110];
            if(Rapor[r][rDurum] == DURUM_BEKLIYOR || Rapor[r][rDurum] == DURUM_INCELENIYOR) Rapor[r][rDurum] = DURUM_INCELENDI;
            Rapor[r][rKapali] = 1;
            AdminAdi(playerid, adm, sizeof adm);
            format(tmp, sizeof tmp, "%s raporu sonuçlandırdı ve kapattı", adm);
            LogEkle(r, tmp);
            RaporKaydet(r);
            SahibeBildir(r, "Raporun sonuçlandırıldı ve kapatıldı.");
            format(tmp, sizeof tmp, "[Rapor] #%d kapatıldı ve Geçmiş Raporlar'a taşındı.", r + 1);
            SendClientMessage(playerid, RENK_OK, tmp);
            AdminListe(playerid);
            return 1;
        }
        case D_A_ACMA:
        {
            if(RaporAdminSeviyesi(playerid) < YENIDEN_ACMA_MIN_SEVIYE) return 1;
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || !Rapor[r][rKapali]) return 1;
            if(!response)
            {
                AdminDetay(playerid, r);
                return 1;
            }
            new adm[40], tmp[110];
            Rapor[r][rKapali] = 0;
            Rapor[r][rDurum] = DURUM_INCELENIYOR;
            AdminAdi(playerid, adm, sizeof adm);
            format(tmp, sizeof tmp, "%s raporu yeniden açtı", adm);
            LogEkle(r, tmp);
            RaporKaydet(r);
            SahibeBildir(r, "Raporun yeniden açıldı ve incelemeye alındı.");
            AdminDetay(playerid, r);
            return 1;
        }

        case D_AYARLAR:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0: AyarKomutCalistir(playerid, KOMUT_GIRIS);
                case 1: AyarKomutCalistir(playerid, KOMUT_KAYIT);
                case 2: RaporBaslat(playerid, "");
                case 3: OyuncuListe(playerid);
                case 4: AyarKomutCalistir(playerid, KOMUT_EVENTER);
                case 5: AyarKomutCalistir(playerid, KOMUT_TELEFON);
                case 6:
                {
                    if(RaporAdminSeviyesi(playerid) < 1) return 1;
                    pSayfa[playerid] = 0;
                    AdminListe(playerid);
                }
            }
            return 1;
        }

        // ================= OYUNCU =================
        case D_O_ISIM:
        {
            if(!response) return 1;
            Temizle(inputtext);
            if(BosMu(inputtext))
            {
                RaporBaslat(playerid, "");
                return 1;
            }
            RaporBaslat(playerid, inputtext);
            return 1;
        }
        case D_O_KAT:
        {
            if(!response) return 1;
            if(listitem < 0 || listitem > 5) return 1;
            pKat[playerid] = listitem;
            ShowPlayerDialog(playerid, D_O_ACIK, DIALOG_STYLE_INPUT, "Rapor Gönder (3/4) - Açıklama", "{FFFFFF}Olayı kısaca açıkla (en az 10 karakter):", "İleri", "İptal");
            return 1;
        }
        case D_O_ACIK:
        {
            if(!response) return 1;
            Temizle(inputtext);
            if(strlen(inputtext) < 10 || BosMu(inputtext))
            {
                ShowPlayerDialog(playerid, D_O_ACIK, DIALOG_STYLE_INPUT, "Rapor Gönder (3/4) - Açıklama", "{E06666}Açıklama en az 10 karakter olmalı.\n{FFFFFF}Olayı kısaca açıkla:", "İleri", "İptal");
                return 1;
            }
            strmid(pAcik[playerid], inputtext, 0, 127, 128);
            ShowPlayerDialog(playerid, D_O_KANIT, DIALOG_STYLE_INPUT, "Rapor Gönder (4/4) - Kanıt", "{FFFFFF}Varsa kanıt yaz (video / görsel linki, olay saati vb.).\n{9AA5B1}Kanıtın yoksa boş bırakıp Gönder'e bas.", "Gönder", "İptal");
            return 1;
        }
        case D_O_KANIT:
        {
            if(!response) return 1;
            Temizle(inputtext);
            new kanit[96];
            if(BosMu(inputtext)) format(kanit, sizeof kanit, "Yok");
            else strmid(kanit, inputtext, 0, 95, 96);

            new r = RaporOlustur(playerid, kanit);
            if(r == -1)
            {
                SendClientMessage(playerid, RENK_HATA, "[Rapor] Rapor kapasitesi dolu, lütfen bir yetkiliye haber ver.");
                return 1;
            }
            pSonRapor[playerid] = gettime();
            format(gTmp, sizeof gTmp, "[Rapor] Raporun #%d numarasıyla alındı. Durumunu /raporlarim ile takip edebilirsin.", r + 1);
            SendClientMessage(playerid, RENK_OK, gTmp);
            YeniRaporBildir(r, playerid);
            return 1;
        }
        case D_O_LISTE:
        {
            if(!response) return 1;
            if(listitem < 0 || listitem >= OYUNCU_LISTE_MAX) return 1;
            new r = pOyMap[playerid][listitem];
            if(r != -1 && RaporGecerli(r) && IsSahip(playerid, r)) OyuncuDetay(playerid, r);
            return 1;
        }
        case D_O_DETAY:
        {
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || !IsSahip(playerid, r)) return 1;
            if(response) OyuncuMesajlar(playerid, r);
            else OyuncuListe(playerid);
            return 1;
        }
        case D_O_MESAJLAR:
        {
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || !IsSahip(playerid, r)) return 1;
            if(response && !Rapor[r][rKapali])
            {
                new baslik[32];
                format(baslik, sizeof baslik, "Rapor #%d - Mesaj Yaz", r + 1);
                ShowPlayerDialog(playerid, D_O_MESAJ_YAZ, DIALOG_STYLE_INPUT, baslik, "{FFFFFF}Yetkililere göndereceğin mesajı yaz:", "Gönder", "İptal");
            }
            else OyuncuDetay(playerid, r);
            return 1;
        }
        case D_O_MESAJ_YAZ:
        {
            new r = pRaporSec[playerid];
            if(!RaporGecerli(r) || !IsSahip(playerid, r) || Rapor[r][rKapali]) return 1;
            if(!response)
            {
                OyuncuMesajlar(playerid, r);
                return 1;
            }
            Temizle(inputtext);
            if(BosMu(inputtext))
            {
                ShowPlayerDialog(playerid, D_O_MESAJ_YAZ, DIALOG_STYLE_INPUT, "Mesaj Yaz", "{E06666}Mesaj boş olamaz.\n{FFFFFF}Yetkililere göndereceğin mesajı yaz:", "Gönder", "İptal");
                return 1;
            }
            new isim[MAX_PLAYER_NAME];
            GetPlayerName(playerid, isim, sizeof isim);
            MesajEkle(r, isim, 0, inputtext);
            Rapor[r][rAdOkunmamis]++;
            RaporKaydet(r);
            AdminlereMesajBildir(r);
            OyuncuMesajlar(playerid, r);
            return 1;
        }
    }
    return 0;
}
