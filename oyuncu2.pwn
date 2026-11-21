// =====================================================================
//  oyuncu2.pwn  -  Xyral Roleplay | OYUNCU EK PAKETI (sadece oyuncu)
//  Admin sistemine DOKUNMAZ. Mevcut "oyuncu" filterscript'i ile birlikte calisir.
//
//  Eklenenler: banka/IBAN/havale, meslek+maas, belediye (kimlik, ehliyet),
//  rehber/arama/SMS, ilan sistemi, sosyal medya, gorev+basarim, profil,
//  biyografi, /me /do /b /pay /id /report, animasyonlar, yerel sohbet.
//
//  Kayit: scriptfiles icinde oyuncu2_*.txt (sunucu kapansa da silinmez).
//  Derleme: derle.yml (pawncc 3.10.10 + samp-stdlib), ek eklenti gerekmez.
//
//  server.cfg:  filterscripts oyuncu galeri admin oyuncu2
// =====================================================================

#include <a_samp>

#undef MAX_PLAYERS
#define MAX_PLAYERS 100

// ------------------------- AYARLAR -----------------------------------
#define BELEDIYE_KONUM_KONTROLU  0        // 1 yaparsan belediye menusu sadece binanin yaninda acilir
#define BELEDIYE_X               1481.0   // (koordinatlari kendine gore duzelt)
#define BELEDIYE_Y               -1749.0
#define BELEDIYE_Z               15.7
#define BELEDIYE_MESAFE          80.0

#define YEREL_SOHBET             1        // 1: yazilar sadece yakindakilere gider
#define SOHBET_MESAFE            20.0
#define MAAS_DAKIKA              10       // kac dakikada bir maas
#define EHLIYET_UCRET            500
#define ILAN_UCRET               50
#define MAX_ILAN                 30
#define MAX_SOSYAL               10
#define MAX_REHBER               8

// ------------------------- RENKLER -----------------------------------
#define COL_BILGI   0x33CCFFFF
#define COL_HATA    0xFF6347FF
#define COL_OK      0x66FF66FF
#define COL_RP      0xC2A2DAFF
#define COL_OOC     0xAAAAAAFF
#define COL_TEL     0xFFFF66FF
#define COL_BEYAZ   0xFFFFFFFF

// ------------------------- DIALOG ID'LERI -----------------------------
#define D_BANKA         7801
#define D_YATIR         7802
#define D_CEK           7803
#define D_HAV_ALICI     7804
#define D_HAV_MIKTAR    7805
#define D_MESLEK        7810
#define D_MESLEK_ONAY   7811
#define D_BELEDIYE      7820
#define D_EHLIYET       7821
#define D_REH           7830
#define D_REH_EKLE_NO   7831
#define D_REH_EKLE_ISIM 7832
#define D_REH_KISI      7833
#define D_REH_SMS       7834
#define D_ILAN          7840
#define D_ILAN_KAT      7841
#define D_ILAN_BASLIK   7842
#define D_ILAN_FIYAT    7843
#define D_ILAN_LISTE    7844
#define D_ILAN_DETAY    7845
#define D_SOSYAL        7850
#define D_SOS_YAZ       7851
#define D_BIO           7860
#define D_BILGI         7899

// ------------------------- VERI --------------------------------------
enum E_PD
{
    pdYuklu,
    pdKey[56],
    pdBanka,
    pdIban,
    pdTel,
    pdMeslek,
    pdDeney,
    pdDakika,
    pdGorev,
    pdLisans,
    pdBio[64]
}

new PD[MAX_PLAYERS][E_PD];
new PHist[MAX_PLAYERS][5][64];
new PRehNo[MAX_PLAYERS][MAX_REHBER];
new PRehIsim[MAX_PLAYERS][MAX_REHBER][20];
new PCagri[MAX_PLAYERS];
new PCagriDurum[MAX_PLAYERS];       // 0 yok, 1 ariyor, 2 caliyor, 3 konusuyor
new PTmp[MAX_PLAYERS][8];
new PTmpS[MAX_PLAYERS][48];
new PMap[MAX_PLAYERS][MAX_ILAN];
new PDakikaSayac[MAX_PLAYERS];
new PReportT[MAX_PLAYERS];
new GCounter;

new IlanVar[MAX_ILAN];
new IlanKat[MAX_ILAN];
new IlanFiyat[MAX_ILAN];
new IlanTel[MAX_ILAN];
new IlanZaman[MAX_ILAN];
new IlanSahip[MAX_ILAN][MAX_PLAYER_NAME];
new IlanBaslik[MAX_ILAN][40];

new SosZaman[MAX_SOSYAL];
new SosYazar[MAX_SOSYAL][MAX_PLAYER_NAME];
new SosMetin[MAX_SOSYAL][80];

new const IlanKatAd[7][20] =
{
    "Arac satilik", "Ev satilik", "Ev kiralik", "Is ilani",
    "Esya satilik", "Isletme satilik", "Genel ilan"
};

new const JobAd[21][26] =
{
    "Issiz", "Polis Memuru", "Doktor", "Ambulans Gorevlisi", "Mekanik",
    "Taksi Soforu", "Otobus Soforu", "Kamyon Soforu", "Copcu", "Belediye Calisani",
    "Guvenlik Gorevlisi", "Balikci", "Ciftci", "Madenci", "Kurye",
    "Insaat Iscisi", "Gazeteci", "Emlakci", "Garson", "Asci", "Benzin Ist. Calisani"
};
new const JobMaas[21] =
{
    50, 400, 420, 380, 300, 280, 300, 320, 200, 250,
    260, 220, 220, 260, 240, 270, 230, 300, 200, 230, 210
};
// 1 = baska oyuncu/yonetim onayi gerekir (ileride), su an kilitli
new const JobKilit[21] =
{
    0, 1, 1, 1, 0, 0, 0, 0, 0, 0,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};
// 1 = ehliyet gerekir
new const JobLisans[21] =
{
    0, 0, 0, 0, 0, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0
};

new const GorevAd[8][40] =
{
    "Ilk isine basla", "Ilk maasini kazan", "Bankaya para yatir", "Ilk havale / odeme yap",
    "Ehliyet al", "Ilk ilanini ver", "1 saat oyna", "Rehbere bir kisi ekle"
};
new const GorevOdul[8] = { 300, 300, 100, 200, 500, 200, 500, 100 };

forward OyDakika();
forward CagriZaman(a, b);

// ------------------------- YARDIMCI ----------------------------------
stock CutEOL(str[])
{
    new len = strlen(str);
    while (len > 0 && (str[len - 1] == '\n' || str[len - 1] == '\r'))
    {
        str[len - 1] = 0;
        len--;
    }
}

stock Temizle(str[])
{
    new l = strlen(str);
    for (new i = 0; i < l; i++)
    {
        if (str[i] == '|') str[i] = '/';
        else if (str[i] == '%') str[i] = '#';
        else if (str[i] == '\n' || str[i] == '\r') str[i] = ' ';
    }
}

stock GetPiece(const src[], idx, dest[], size)
{
    dest[0] = 0;
    new cur = 0, start = 0, len = strlen(src);
    for (new i = 0; i <= len; i++)
    {
        if (i == len || src[i] == '|')
        {
            if (cur == idx)
            {
                strmid(dest, src, start, i, size);
                return 1;
            }
            cur++;
            start = i + 1;
        }
    }
    return 0;
}

stock GetPieceInt(const src[], idx)
{
    new tmp[24];
    GetPiece(src, idx, tmp, sizeof tmp);
    return strval(tmp);
}

// n. kelimeyi al (rest=1 ise n. kelimeden sonuna kadar)
stock Kelime(const s[], n, out[], size, rest = 0)
{
    new len = strlen(s), i = 0, k = 0, st;
    out[0] = 0;
    while (i < len)
    {
        while (i < len && s[i] == ' ') i++;
        if (i >= len) break;
        st = i;
        while (i < len && s[i] != ' ') i++;
        if (k == n)
        {
            if (rest) strmid(out, s, st, len, size);
            else strmid(out, s, st, i, size);
            return 1;
        }
        k++;
    }
    return 0;
}

stock KomutAyir(const cmdtext[], cmd[], cmdsize, par[], parsize)
{
    new len = strlen(cmdtext), i = 0;
    while (i < len && cmdtext[i] != ' ') i++;
    strmid(cmd, cmdtext, 0, i, cmdsize);
    while (i < len && cmdtext[i] == ' ') i++;
    strmid(par, cmdtext, i, len, parsize);
}

stock RPIsim(playerid, out[], size = sizeof out)
{
    GetPlayerName(playerid, out, size);
    new l = strlen(out);
    for (new i = 0; i < l; i++)
    {
        if (out[i] == '_') out[i] = ' ';
    }
}

stock YerelMesaj(playerid, color, const text[], Float:radius = SOHBET_MESAFE)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    new vw = GetPlayerVirtualWorld(playerid), intr = GetPlayerInterior(playerid);
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        if (GetPlayerVirtualWorld(i) != vw || GetPlayerInterior(i) != intr) continue;
        if (IsPlayerInRangeOfPoint(i, radius, x, y, z)) SendClientMessage(i, color, text);
    }
    return 1;
}

stock Bilgi(playerid, const baslik[], const metin[])
{
    return ShowPlayerDialog(playerid, D_BILGI, DIALOG_STYLE_MSGBOX, baslik, metin, "Tamam", "");
}

// Para: mevcut "oyuncu" filterscript'indeki public fonksiyonlar uzerinden
stock Nakit(playerid) return CallRemoteFunction("OyuncuPara", "i", playerid);
stock NakitEkle(playerid, miktar) return CallRemoteFunction("OyuncuParaEkle", "ii", playerid, miktar);

stock Seviye(playerid)
{
    new l = PD[playerid][pdDeney] / 5 + 1;
    if (l > 10) l = 10;
    return l;
}

stock TelBul(tel)
{
    if (tel <= 0) return INVALID_PLAYER_ID;
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && PD[i][pdYuklu] && PD[i][pdTel] == tel) return i;
    }
    return INVALID_PLAYER_ID;
}

stock IbanBul(iban)
{
    if (iban <= 0) return INVALID_PLAYER_ID;
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && PD[i][pdYuklu] && PD[i][pdIban] == iban) return i;
    }
    return INVALID_PLAYER_ID;
}

stock Gecmis(playerid, const text[])
{
    new h, m, s, line[64];
    gettime(h, m, s);
    for (new i = 4; i > 0; i--)
    {
        format(PHist[playerid][i], 64, "%s", PHist[playerid][i - 1]);
    }
    format(line, sizeof line, "[%02d:%02d] %s", h, m, text);
    format(PHist[playerid][0], 64, "%s", line);
}

// ------------------------- KAYIT / YUKLEME ---------------------------
stock GlobalYukle()
{
    GCounter = 0;
    if (!fexist("oyuncu2_global.txt")) return 0;
    new File:f = fopen("oyuncu2_global.txt", io_read);
    if (!f) return 0;
    new l[32];
    l[0] = 0;
    fread(f, l, sizeof l);
    fclose(f);
    GCounter = strval(l);
    return 1;
}

stock GlobalKaydet()
{
    new File:f = fopen("oyuncu2_global.txt", io_write);
    if (!f) return 0;
    new l[32];
    format(l, sizeof l, "%d\n", GCounter);
    fwrite(f, l);
    fclose(f);
    return 1;
}

stock VeriSifirla(playerid)
{
    PD[playerid][pdYuklu] = 0;
    PD[playerid][pdKey][0] = 0;
    PD[playerid][pdBanka] = 0;
    PD[playerid][pdIban] = 0;
    PD[playerid][pdTel] = 0;
    PD[playerid][pdMeslek] = 0;
    PD[playerid][pdDeney] = 0;
    PD[playerid][pdDakika] = 0;
    PD[playerid][pdGorev] = 0;
    PD[playerid][pdLisans] = 0;
    PD[playerid][pdBio][0] = 0;
    for (new h = 0; h < 5; h++) PHist[playerid][h][0] = 0;
    for (new r = 0; r < MAX_REHBER; r++)
    {
        PRehNo[playerid][r] = 0;
        PRehIsim[playerid][r][0] = 0;
    }
    PDakikaSayac[playerid] = 0;
}

stock KeyOlustur(playerid, key[], size)
{
    new name[MAX_PLAYER_NAME], slot;
    GetPlayerName(playerid, name, sizeof name);
    slot = CallRemoteFunction("OyuncuSlot", "i", playerid);
    format(key, size, "oyuncu2_%s_%d.txt", name, slot);
}

stock VeriKaydet(playerid)
{
    if (!PD[playerid][pdYuklu]) return 0;
    new File:f = fopen(PD[playerid][pdKey], io_write);
    if (!f) return 0;
    new line[160];
    format(line, sizeof line, "%d|%d|%d|%d|%d|%d|%d|%d\n",
        PD[playerid][pdBanka], PD[playerid][pdIban], PD[playerid][pdTel], PD[playerid][pdMeslek],
        PD[playerid][pdDeney], PD[playerid][pdDakika], PD[playerid][pdGorev], PD[playerid][pdLisans]);
    fwrite(f, line);
    format(line, sizeof line, "%s\n", PD[playerid][pdBio]);
    fwrite(f, line);
    for (new h = 0; h < 5; h++)
    {
        format(line, sizeof line, "%s\n", PHist[playerid][h]);
        fwrite(f, line);
    }
    for (new r = 0; r < MAX_REHBER; r++)
    {
        format(line, sizeof line, "%d|%s\n", PRehNo[playerid][r], PRehIsim[playerid][r]);
        fwrite(f, line);
    }
    fclose(f);
    return 1;
}

stock VeriYukle(playerid)
{
    new key[56];
    KeyOlustur(playerid, key, sizeof key);
    VeriSifirla(playerid);
    format(PD[playerid][pdKey], 56, "%s", key);
    PD[playerid][pdYuklu] = 1;

    if (!fexist(key))
    {
        GCounter++;
        PD[playerid][pdIban] = 100000 + GCounter;
        PD[playerid][pdTel] = 5550000 + GCounter;
        GlobalKaydet();
        VeriKaydet(playerid);
        return 1;
    }

    new File:f = fopen(key, io_read);
    if (f)
    {
        new line[160];
        line[0] = 0; fread(f, line, sizeof line); CutEOL(line);
        PD[playerid][pdBanka] = GetPieceInt(line, 0);
        PD[playerid][pdIban] = GetPieceInt(line, 1);
        PD[playerid][pdTel] = GetPieceInt(line, 2);
        PD[playerid][pdMeslek] = GetPieceInt(line, 3);
        PD[playerid][pdDeney] = GetPieceInt(line, 4);
        PD[playerid][pdDakika] = GetPieceInt(line, 5);
        PD[playerid][pdGorev] = GetPieceInt(line, 6);
        PD[playerid][pdLisans] = GetPieceInt(line, 7);
        if (PD[playerid][pdMeslek] < 0 || PD[playerid][pdMeslek] > 20) PD[playerid][pdMeslek] = 0;
        if (PD[playerid][pdBanka] < 0) PD[playerid][pdBanka] = 0;

        line[0] = 0; fread(f, line, sizeof line); CutEOL(line);
        format(PD[playerid][pdBio], 64, "%s", line);

        for (new h = 0; h < 5; h++)
        {
            line[0] = 0; fread(f, line, sizeof line); CutEOL(line);
            format(PHist[playerid][h], 64, "%s", line);
        }
        for (new r = 0; r < MAX_REHBER; r++)
        {
            line[0] = 0; fread(f, line, sizeof line); CutEOL(line);
            PRehNo[playerid][r] = GetPieceInt(line, 0);
            GetPiece(line, 1, PRehIsim[playerid][r], 20);
        }
        fclose(f);
    }
    return 1;
}

// Karakter degistiyse (slot farkli) eski karakteri kaydedip yenisini yukler
stock Hazirla(playerid)
{
    if (!IsPlayerConnected(playerid)) return 0;
    new key[56];
    KeyOlustur(playerid, key, sizeof key);
    if (PD[playerid][pdYuklu] && !strcmp(key, PD[playerid][pdKey])) return 1;
    if (PD[playerid][pdYuklu]) VeriKaydet(playerid);
    VeriYukle(playerid);
    return 1;
}

stock IlanKaydet()
{
    new File:f = fopen("oyuncu2_ilan.txt", io_write);
    if (!f) return 0;
    new line[200];
    for (new i = 0; i < MAX_ILAN; i++)
    {
        if (!IlanVar[i]) continue;
        format(line, sizeof line, "%d|%d|%d|%d|%s|%s\n", IlanKat[i], IlanFiyat[i], IlanTel[i], IlanZaman[i], IlanSahip[i], IlanBaslik[i]);
        fwrite(f, line);
    }
    fclose(f);
    return 1;
}

stock IlanYukle()
{
    for (new i = 0; i < MAX_ILAN; i++) IlanVar[i] = 0;
    if (!fexist("oyuncu2_ilan.txt")) return 0;
    new File:f = fopen("oyuncu2_ilan.txt", io_read);
    if (!f) return 0;
    new line[200], n = 0;
    while (n < MAX_ILAN)
    {
        line[0] = 0;
        if (!fread(f, line, sizeof line)) break;
        CutEOL(line);
        if (strlen(line) < 6) continue;
        IlanKat[n] = GetPieceInt(line, 0);
        if (IlanKat[n] < 0 || IlanKat[n] > 6) IlanKat[n] = 6;
        IlanFiyat[n] = GetPieceInt(line, 1);
        IlanTel[n] = GetPieceInt(line, 2);
        IlanZaman[n] = GetPieceInt(line, 3);
        GetPiece(line, 4, IlanSahip[n], MAX_PLAYER_NAME);
        GetPiece(line, 5, IlanBaslik[n], 40);
        IlanVar[n] = 1;
        n++;
    }
    fclose(f);
    return 1;
}

stock SosyalKaydet()
{
    new File:f = fopen("oyuncu2_sosyal.txt", io_write);
    if (!f) return 0;
    new line[160];
    for (new i = 0; i < MAX_SOSYAL; i++)
    {
        if (SosZaman[i] == 0) continue;
        format(line, sizeof line, "%d|%s|%s\n", SosZaman[i], SosYazar[i], SosMetin[i]);
        fwrite(f, line);
    }
    fclose(f);
    return 1;
}

stock SosyalYukle()
{
    for (new i = 0; i < MAX_SOSYAL; i++) SosZaman[i] = 0;
    if (!fexist("oyuncu2_sosyal.txt")) return 0;
    new File:f = fopen("oyuncu2_sosyal.txt", io_read);
    if (!f) return 0;
    new line[160], n = 0;
    while (n < MAX_SOSYAL)
    {
        line[0] = 0;
        if (!fread(f, line, sizeof line)) break;
        CutEOL(line);
        if (strlen(line) < 5) continue;
        SosZaman[n] = GetPieceInt(line, 0);
        GetPiece(line, 1, SosYazar[n], MAX_PLAYER_NAME);
        GetPiece(line, 2, SosMetin[n], 80);
        n++;
    }
    fclose(f);
    return 1;
}

// ------------------------- GOREV / BASARIM ----------------------------
stock GorevTamamla(playerid, g)
{
    if (!PD[playerid][pdYuklu] || g < 0 || g > 7) return 0;
    if (PD[playerid][pdGorev] & (1 << g)) return 0;
    PD[playerid][pdGorev] |= (1 << g);
    PD[playerid][pdBanka] += GorevOdul[g];
    new msg[128], gl[48];
    format(msg, sizeof msg, "[GOREV] '%s' tamamlandi! Odul: $%d bankana yatirildi.", GorevAd[g], GorevOdul[g]);
    SendClientMessage(playerid, COL_OK, msg);
    format(gl, sizeof gl, "Gorev odulu +$%d", GorevOdul[g]);
    Gecmis(playerid, gl);
    return 1;
}

stock GorevlerGoster(playerid, sadeceBitenler)
{
    new s[900], t[96], c = 0;
    s[0] = 0;
    for (new g = 0; g < 8; g++)
    {
        if (PD[playerid][pdGorev] & (1 << g))
        {
            format(t, sizeof t, "{66FF66}[X] %s\n", GorevAd[g]);
            strcat(s, t);
            c++;
        }
        else if (!sadeceBitenler)
        {
            format(t, sizeof t, "{FFFFFF}[ ] %s (Odul: $%d)\n", GorevAd[g], GorevOdul[g]);
            strcat(s, t);
        }
    }
    if (sadeceBitenler)
    {
        if (c == 0) format(s, sizeof s, "Henuz basarimin yok. /gorevler ile gorevlere bak.");
        Bilgi(playerid, "Basarimlar", s);
    }
    else Bilgi(playerid, "Gorevler", s);
    return 1;
}

// ------------------------- MENULER -----------------------------------
stock BankaMenu(playerid)
{
    new s[96];
    format(s, sizeof s, "Para yatir\nPara cek\nHavale gonder\nIslem gecmisi\nBakiye bilgisi");
    return ShowPlayerDialog(playerid, D_BANKA, DIALOG_STYLE_LIST, "Banka", s, "Sec", "Kapat");
}

stock MeslekMenu(playerid)
{
    new s[900], t[64];
    s[0] = 0;
    for (new i = 1; i <= 20; i++)
    {
        if (JobKilit[i]) format(t, sizeof t, "%s [Kilitli]\n", JobAd[i]);
        else format(t, sizeof t, "%s\n", JobAd[i]);
        strcat(s, t);
    }
    return ShowPlayerDialog(playerid, D_MESLEK, DIALOG_STYLE_LIST, "Meslekler", s, "Sec", "Kapat");
}

stock BelediyeMenu(playerid)
{
#if BELEDIYE_KONUM_KONTROLU
    if (!IsPlayerInRangeOfPoint(playerid, BELEDIYE_MESAFE, BELEDIYE_X, BELEDIYE_Y, BELEDIYE_Z))
    {
        SendClientMessage(playerid, COL_HATA, "Belediye binasinin yakininda olmalisin.");
        return 0;
    }
#endif
    return ShowPlayerDialog(playerid, D_BELEDIYE, DIALOG_STYLE_LIST, "Belediye",
        "Kimlik karti\nEhliyet basvurusu\nIs basvurusu (meslekler)\nKarakter belgesi\nBiyografi duzenle",
        "Sec", "Kapat");
}

stock KimlikGoster(playerid)
{
    new s[300], nm[MAX_PLAYER_NAME], rp[MAX_PLAYER_NAME];
    GetPlayerName(playerid, nm, sizeof nm);
    RPIsim(playerid, rp, sizeof rp);
    format(s, sizeof s, "Ad Soyad: %s\nHesap: %s\nTelefon: %d\nIBAN: %d\nMeslek: %s\nEhliyet: %s",
        rp, nm, PD[playerid][pdTel], PD[playerid][pdIban], JobAd[PD[playerid][pdMeslek]],
        PD[playerid][pdLisans] ? "Var" : "Yok");
    return Bilgi(playerid, "Kimlik Karti", s);
}

stock ProfilGoster(playerid, target)
{
    if (!IsPlayerConnected(target) || !PD[target][pdYuklu])
    {
        SendClientMessage(playerid, COL_HATA, "Oyuncu bulunamadi veya karakteri henuz secmedi.");
        return 0;
    }
    new s[600], rp[MAX_PLAYER_NAME], bio[64], cnt = 0;
    RPIsim(target, rp, sizeof rp);
    for (new g = 0; g < 8; g++)
    {
        if (PD[target][pdGorev] & (1 << g)) cnt++;
    }
    if (strlen(PD[target][pdBio]) > 0) format(bio, sizeof bio, "%s", PD[target][pdBio]);
    else format(bio, sizeof bio, "-");
    new h = PD[target][pdDakika] / 60, m = PD[target][pdDakika] % 60;
    if (playerid == target)
    {
        format(s, sizeof s,
            "Karakter: %s\nMeslek: %s (Seviye %d)\nBanka: $%d\nNakit: $%d\nTelefon: %d | IBAN: %d\nEhliyet: %s\nOyun suresi: %d saat %d dk\nBasarim: %d/8\nBiyografi: %s",
            rp, JobAd[PD[target][pdMeslek]], Seviye(target), PD[target][pdBanka], Nakit(target),
            PD[target][pdTel], PD[target][pdIban], PD[target][pdLisans] ? "Var" : "Yok", h, m, cnt, bio);
    }
    else
    {
        format(s, sizeof s,
            "Karakter: %s\nMeslek: %s (Seviye %d)\nOyun suresi: %d saat %d dk\nBasarim: %d/8\nBiyografi: %s",
            rp, JobAd[PD[target][pdMeslek]], Seviye(target), h, m, cnt, bio);
    }
    return Bilgi(playerid, "Oyuncu Profili", s);
}

stock RehberMenu(playerid)
{
    new s[500], t[64], n = 0;
    s[0] = 0;
    strcat(s, "+ Kisi ekle\n");
    for (new r = 0; r < MAX_REHBER; r++)
    {
        if (PRehNo[playerid][r] <= 0) continue;
        PMap[playerid][n] = r;
        n++;
        format(t, sizeof t, "%s - %d\n", PRehIsim[playerid][r], PRehNo[playerid][r]);
        strcat(s, t);
    }
    return ShowPlayerDialog(playerid, D_REH, DIALOG_STYLE_LIST, "Rehber", s, "Sec", "Kapat");
}

stock IlanMenu(playerid)
{
    return ShowPlayerDialog(playerid, D_ILAN, DIALOG_STYLE_LIST, "Ilanlar",
        "Ilan ver\nTum ilanlari gor\nIlanlarim", "Sec", "Kapat");
}

stock IlanListe(playerid, mode)
{
    new s[2400], t[120], n = 0, nm[MAX_PLAYER_NAME];
    GetPlayerName(playerid, nm, sizeof nm);
    s[0] = 0;
    for (new i = 0; i < MAX_ILAN; i++)
    {
        if (!IlanVar[i]) continue;
        if (mode == 1 && strcmp(IlanSahip[i], nm)) continue;
        PMap[playerid][n] = i;
        n++;
        format(t, sizeof t, "[%s] %s - $%d\n", IlanKatAd[IlanKat[i]], IlanBaslik[i], IlanFiyat[i]);
        strcat(s, t);
    }
    if (n == 0)
    {
        Bilgi(playerid, "Ilanlar", "Ilan bulunamadi.");
        return 0;
    }
    PTmp[playerid][4] = mode;
    return ShowPlayerDialog(playerid, D_ILAN_LISTE, DIALOG_STYLE_LIST, "Ilanlar", s, "Sec", "Geri");
}

stock SosyalMenu(playerid)
{
    return ShowPlayerDialog(playerid, D_SOSYAL, DIALOG_STYLE_LIST, "Sosyal Medya",
        "Gonderi paylas\nAkis (son gonderiler)\nProfilim", "Sec", "Kapat");
}

// ------------------------- TELEFON / ARAMA ----------------------------
stock CagriBitir(playerid)
{
    new p = PCagri[playerid];
    PCagri[playerid] = -1;
    PCagriDurum[playerid] = 0;
    if (p >= 0 && p < MAX_PLAYERS && IsPlayerConnected(p) && PCagri[p] == playerid)
    {
        PCagri[p] = -1;
        PCagriDurum[p] = 0;
        SendClientMessage(p, COL_HATA, "[TELEFON] Gorusme sona erdi.");
    }
    return 1;
}

stock CagriBaslat(playerid, tel)
{
    if (!PD[playerid][pdYuklu]) return 0;
    if (PCagriDurum[playerid] != 0)
    {
        SendClientMessage(playerid, COL_HATA, "Zaten bir gorusmedesin. (/hangup)");
        return 0;
    }
    new t = TelBul(tel);
    if (t == INVALID_PLAYER_ID || t == playerid)
    {
        SendClientMessage(playerid, COL_HATA, "[TELEFON] Aradiginiz numaraya su anda ulasilamiyor.");
        return 0;
    }
    if (PCagriDurum[t] != 0)
    {
        SendClientMessage(playerid, COL_HATA, "[TELEFON] Hat mesgul.");
        return 0;
    }
    PCagri[playerid] = t;
    PCagri[t] = playerid;
    PCagriDurum[playerid] = 1;
    PCagriDurum[t] = 2;

    new msg[128], isim[20];
    isim[0] = 0;
    for (new r = 0; r < MAX_REHBER; r++)
    {
        if (PRehNo[t][r] == PD[playerid][pdTel]) format(isim, sizeof isim, "%s", PRehIsim[t][r]);
    }
    format(msg, sizeof msg, "[TELEFON] %d araniyor... (iptal: /hangup)", tel);
    SendClientMessage(playerid, COL_TEL, msg);
    if (strlen(isim) > 0) format(msg, sizeof msg, "[TELEFON] Telefonun caliyor! Arayan: %s (%d) | /cevap  veya  /hangup", isim, PD[playerid][pdTel]);
    else format(msg, sizeof msg, "[TELEFON] Telefonun caliyor! Arayan: %d | /cevap  veya  /hangup", PD[playerid][pdTel]);
    SendClientMessage(t, COL_TEL, msg);
    SetTimerEx("CagriZaman", 20000, false, "ii", playerid, t);
    return 1;
}

public CagriZaman(a, b)
{
    if (a >= 0 && a < MAX_PLAYERS && IsPlayerConnected(a) && PCagri[a] == b && PCagriDurum[a] == 1)
    {
        SendClientMessage(a, COL_HATA, "[TELEFON] Cevap verilmedi.");
        CagriBitir(a);
    }
    return 1;
}

stock SmsGonder(playerid, tel, const text[])
{
    if (strlen(text) < 1)
    {
        SendClientMessage(playerid, COL_HATA, "Mesaj bos olamaz.");
        return 0;
    }
    new t = TelBul(tel);
    if (t == INVALID_PLAYER_ID || t == playerid)
    {
        SendClientMessage(playerid, COL_HATA, "[SMS] Gonderilemedi: numara kapali veya cevrimdisi.");
        return 0;
    }
    new msg[200], tmp[128];
    format(tmp, sizeof tmp, "%s", text);
    Temizle(tmp);
    format(msg, sizeof msg, "[SMS] %d: %s", PD[playerid][pdTel], tmp);
    SendClientMessage(t, COL_TEL, msg);
    format(msg, sizeof msg, "[SMS] %d numarasina gonderildi.", tel);
    SendClientMessage(playerid, COL_TEL, msg);
    return 1;
}

// ------------------------- MAAS / ZAMANLAYICI --------------------------
stock MaasVer(playerid)
{
    new job = PD[playerid][pdMeslek];
    new base = JobMaas[job], lvl = Seviye(playerid);
    new maas = base + (lvl - 1) * (base / 10);
    PD[playerid][pdBanka] += maas;
    new msg[128], gl[48];
    format(msg, sizeof msg, "[MAAS] %s: $%d bankana yatirildi. (Meslek seviyesi: %d)", JobAd[job], maas, lvl);
    SendClientMessage(playerid, COL_OK, msg);
    format(gl, sizeof gl, "Maas +$%d", maas);
    Gecmis(playerid, gl);
    if (job != 0)
    {
        new onceki = Seviye(playerid);
        PD[playerid][pdDeney]++;
        if (Seviye(playerid) > onceki)
        {
            format(msg, sizeof msg, "[MESLEK] Tebrikler! %s seviyen %d oldu.", JobAd[job], Seviye(playerid));
            SendClientMessage(playerid, COL_OK, msg);
        }
    }
    GorevTamamla(playerid, 1);
    VeriKaydet(playerid);
    return 1;
}

public OyDakika()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || !PD[i][pdYuklu]) continue;
        PD[i][pdDakika]++;
        PDakikaSayac[i]++;
        if (PDakikaSayac[i] >= MAAS_DAKIKA)
        {
            PDakikaSayac[i] = 0;
            MaasVer(i);
        }
        if (PD[i][pdDakika] >= 60) GorevTamamla(i, 6);
    }
    return 1;
}

// ------------------------- CALLBACKS ----------------------------------
public OnFilterScriptInit()
{
    GlobalYukle();
    IlanYukle();
    SosyalYukle();
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        VeriSifirla(i);
        PCagri[i] = -1;
        PCagriDurum[i] = 0;
        PReportT[i] = 0;
    }
    SetTimer("OyDakika", 60000, true);
    print("[oyuncu2] Oyuncu ek paketi yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && PD[i][pdYuklu]) VeriKaydet(i);
    }
    IlanKaydet();
    SosyalKaydet();
    return 1;
}

public OnPlayerConnect(playerid)
{
    VeriSifirla(playerid);
    PCagri[playerid] = -1;
    PCagriDurum[playerid] = 0;
    PReportT[playerid] = 0;
    // animasyon kutuphanelerini onceden yukle
    ApplyAnimation(playerid, "BEACH", "null", 0.0, 0, 0, 0, 0, 0);
    ApplyAnimation(playerid, "GANGS", "null", 0.0, 0, 0, 0, 0, 0);
    ApplyAnimation(playerid, "ON_LOOKERS", "null", 0.0, 0, 0, 0, 0, 0);
    ApplyAnimation(playerid, "PED", "null", 0.0, 0, 0, 0, 0, 0);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    CagriBitir(playerid);
    if (PD[playerid][pdYuklu]) VeriKaydet(playerid);
    VeriSifirla(playerid);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    Hazirla(playerid);
    return 1;
}

public OnPlayerText(playerid, text[])
{
    if (PCagriDurum[playerid] == 3 && PCagri[playerid] >= 0 && IsPlayerConnected(PCagri[playerid]))
    {
        new tmsg[180], tnm[MAX_PLAYER_NAME];
        RPIsim(playerid, tnm, sizeof tnm);
        format(tmsg, sizeof tmsg, "(Telefon) %s: %s", tnm, text);
        SendClientMessage(PCagri[playerid], COL_TEL, tmsg);
        format(tmsg, sizeof tmsg, "(Telefon) Sen: %s", text);
        SendClientMessage(playerid, COL_TEL, tmsg);
        return 0;
    }
#if YEREL_SOHBET
    if (!PD[playerid][pdYuklu]) return 1;
    new ymsg[180], ynm[MAX_PLAYER_NAME];
    RPIsim(playerid, ynm, sizeof ynm);
    format(ymsg, sizeof ymsg, "%s: %s", ynm, text);
    YerelMesaj(playerid, COL_BEYAZ, ymsg);
    return 0;
#else
    return 1;
#endif
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    new cmd[24], par[128];
    KomutAyir(cmdtext, cmd, sizeof cmd, par, sizeof par);

    // komutlarin hepsi icin once karakter verisini hazirla
    if (cmd[0] == '/') Hazirla(playerid);

    // ---------------- YARDIM ----------------
    if (!strcmp(cmd, "/yardim2", true))
    {
        Bilgi(playerid, "Ek Komutlar",
            "/banka  /belediye  /meslekler  /istifa  /maas\n/rehber  /call  /cevap  /hangup  /sms  /numaram\n/ilan  /sosyal  /gorevler  /basarimlar\n/profil [id]  /biyografi  /id [id]  /report [mesaj]\n/me  /do  /b  /pay [id] [miktar]\n/otur  /yat  /selam  /elsik [id]  /dur");
        return 1;
    }

    // ---------------- BANKA ----------------
    if (!strcmp(cmd, "/banka", true))
    {
        BankaMenu(playerid);
        return 1;
    }

    // ---------------- BELEDIYE / KIMLIK ----------------
    if (!strcmp(cmd, "/belediye", true))
    {
        BelediyeMenu(playerid);
        return 1;
    }
    if (!strcmp(cmd, "/biyografi", true))
    {
        ShowPlayerDialog(playerid, D_BIO, DIALOG_STYLE_INPUT, "Biyografi", "Karakterin icin kisa bir biyografi yaz (en fazla 60 karakter):", "Kaydet", "Iptal");
        return 1;
    }
    if (!strcmp(cmd, "/profil", true))
    {
        new tid = playerid;
        if (strlen(par) > 0) tid = strval(par);
        ProfilGoster(playerid, tid);
        return 1;
    }
    if (!strcmp(cmd, "/gorevler", true))
    {
        GorevlerGoster(playerid, 0);
        return 1;
    }
    if (!strcmp(cmd, "/basarimlar", true))
    {
        GorevlerGoster(playerid, 1);
        return 1;
    }

    // ---------------- MESLEK ----------------
    if (!strcmp(cmd, "/meslekler", true))
    {
        MeslekMenu(playerid);
        return 1;
    }
    if (!strcmp(cmd, "/istifa", true))
    {
        if (PD[playerid][pdMeslek] == 0)
        {
            SendClientMessage(playerid, COL_HATA, "Zaten issizsin.");
            return 1;
        }
        PD[playerid][pdMeslek] = 0;
        PD[playerid][pdDeney] = 0;
        VeriKaydet(playerid);
        SendClientMessage(playerid, COL_BILGI, "Meslekten istifa ettin.");
        return 1;
    }
    if (!strcmp(cmd, "/maas", true))
    {
        new left = MAAS_DAKIKA - PDakikaSayac[playerid];
        new msg[128];
        format(msg, sizeof msg, "[MAAS] Meslek: %s | Sonraki maas: %d dk sonra, bankana yatirilir.", JobAd[PD[playerid][pdMeslek]], left);
        SendClientMessage(playerid, COL_BILGI, msg);
        return 1;
    }

    // ---------------- TELEFON ----------------
    if (!strcmp(cmd, "/rehber", true))
    {
        RehberMenu(playerid);
        return 1;
    }
    if (!strcmp(cmd, "/numaram", true))
    {
        new msg[96];
        format(msg, sizeof msg, "[TELEFON] Numaran: %d", PD[playerid][pdTel]);
        SendClientMessage(playerid, COL_TEL, msg);
        return 1;
    }
    if (!strcmp(cmd, "/call", true))
    {
        new num = strval(par);
        if (num <= 0)
        {
            SendClientMessage(playerid, COL_BILGI, "Kullanim: /call [numara]");
            return 1;
        }
        CagriBaslat(playerid, num);
        return 1;
    }
    if (!strcmp(cmd, "/cevap", true))
    {
        new p = PCagri[playerid];
        if (PCagriDurum[playerid] != 2 || p < 0 || !IsPlayerConnected(p))
        {
            SendClientMessage(playerid, COL_HATA, "Caliyor olan bir arama yok.");
            return 1;
        }
        PCagriDurum[playerid] = 3;
        PCagriDurum[p] = 3;
        SendClientMessage(playerid, COL_TEL, "[TELEFON] Gorusme basladi. Yazdiklarin karsi tarafa gider. Kapatmak icin /hangup");
        SendClientMessage(p, COL_TEL, "[TELEFON] Arama cevaplandi. Yazdiklarin karsi tarafa gider. Kapatmak icin /hangup");
        return 1;
    }
    if (!strcmp(cmd, "/hangup", true))
    {
        if (PCagriDurum[playerid] == 0)
        {
            SendClientMessage(playerid, COL_HATA, "Aktif bir aramada degilsin.");
            return 1;
        }
        CagriBitir(playerid);
        SendClientMessage(playerid, COL_TEL, "[TELEFON] Arama kapatildi.");
        return 1;
    }
    if (!strcmp(cmd, "/sms", true))
    {
        new ns[16], ms[128];
        Kelime(par, 0, ns, sizeof ns);
        Kelime(par, 1, ms, sizeof ms, 1);
        if (strval(ns) <= 0 || strlen(ms) < 1)
        {
            SendClientMessage(playerid, COL_BILGI, "Kullanim: /sms [numara] [mesaj]");
            return 1;
        }
        SmsGonder(playerid, strval(ns), ms);
        return 1;
    }

    // ---------------- ILAN / SOSYAL ----------------
    if (!strcmp(cmd, "/ilan", true))
    {
        IlanMenu(playerid);
        return 1;
    }
    if (!strcmp(cmd, "/sosyal", true))
    {
        SosyalMenu(playerid);
        return 1;
    }

    // ---------------- ROLEPLAY ----------------
    if (!strcmp(cmd, "/me", true))
    {
        if (strlen(par) < 1) { SendClientMessage(playerid, COL_BILGI, "Kullanim: /me [eylem]"); return 1; }
        new mmsg[180], mnm[MAX_PLAYER_NAME];
        RPIsim(playerid, mnm, sizeof mnm);
        format(mmsg, sizeof mmsg, "* %s %s", mnm, par);
        YerelMesaj(playerid, COL_RP, mmsg);
        return 1;
    }
    if (!strcmp(cmd, "/do", true))
    {
        if (strlen(par) < 1) { SendClientMessage(playerid, COL_BILGI, "Kullanim: /do [durum]"); return 1; }
        new dmsg[180], dnm[MAX_PLAYER_NAME];
        RPIsim(playerid, dnm, sizeof dnm);
        format(dmsg, sizeof dmsg, "* %s (( %s ))", par, dnm);
        YerelMesaj(playerid, COL_RP, dmsg);
        return 1;
    }
    if (!strcmp(cmd, "/b", true))
    {
        if (strlen(par) < 1) { SendClientMessage(playerid, COL_BILGI, "Kullanim: /b [yerel OOC mesaj]"); return 1; }
        new bmsg[180], bnm[MAX_PLAYER_NAME];
        RPIsim(playerid, bnm, sizeof bnm);
        format(bmsg, sizeof bmsg, "(( %s [%d]: %s ))", bnm, playerid, par);
        YerelMesaj(playerid, COL_OOC, bmsg);
        return 1;
    }
    if (!strcmp(cmd, "/id", true))
    {
        new idn = playerid;
        if (strlen(par) > 0) idn = strval(par);
        if (idn < 0 || idn >= MAX_PLAYERS || !IsPlayerConnected(idn))
        {
            SendClientMessage(playerid, COL_HATA, "Oyuncu bulunamadi.");
            return 1;
        }
        new imsg[96], inm[MAX_PLAYER_NAME];
        RPIsim(idn, inm, sizeof inm);
        format(imsg, sizeof imsg, "[ID] %d - %s | Ping: %d", idn, inm, GetPlayerPing(idn));
        SendClientMessage(playerid, COL_BILGI, imsg);
        return 1;
    }
    if (!strcmp(cmd, "/pay", true))
    {
        new ts[12], ms[16];
        Kelime(par, 0, ts, sizeof ts);
        Kelime(par, 1, ms, sizeof ms);
        new tid = strval(ts), amount = strval(ms);
        if (strlen(ts) < 1 || strlen(ms) < 1)
        {
            SendClientMessage(playerid, COL_BILGI, "Kullanim: /pay [id] [miktar]");
            return 1;
        }
        if (tid < 0 || tid >= MAX_PLAYERS || !IsPlayerConnected(tid) || tid == playerid)
        {
            SendClientMessage(playerid, COL_HATA, "Gecersiz oyuncu.");
            return 1;
        }
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(tid, px, py, pz);
        if (!IsPlayerInRangeOfPoint(playerid, 5.0, px, py, pz) || GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(tid))
        {
            SendClientMessage(playerid, COL_HATA, "Oyuncuya yeterince yakin degilsin.");
            return 1;
        }
        if (amount <= 0 || amount > 5000000)
        {
            SendClientMessage(playerid, COL_HATA, "Gecersiz miktar (1 - 5.000.000).");
            return 1;
        }
        if (amount > Nakit(playerid))
        {
            SendClientMessage(playerid, COL_HATA, "Yeterli nakit paran yok.");
            return 1;
        }
        NakitEkle(playerid, -amount);
        NakitEkle(tid, amount);
        new pm[128], n1[MAX_PLAYER_NAME], n2[MAX_PLAYER_NAME];
        RPIsim(playerid, n1, sizeof n1);
        RPIsim(tid, n2, sizeof n2);
        format(pm, sizeof pm, "[PARA] %s kisisine $%d verdin.", n2, amount);
        SendClientMessage(playerid, COL_OK, pm);
        format(pm, sizeof pm, "[PARA] %s sana $%d verdi.", n1, amount);
        SendClientMessage(tid, COL_OK, pm);
        format(pm, sizeof pm, "* %s cebinden para cikarip %s kisisine verir.", n1, n2);
        YerelMesaj(playerid, COL_RP, pm);
        GorevTamamla(playerid, 3);
        return 1;
    }
    if (!strcmp(cmd, "/report", true))
    {
        if (strlen(par) < 3)
        {
            SendClientMessage(playerid, COL_BILGI, "Kullanim: /report [mesaj]");
            return 1;
        }
        if (gettime() - PReportT[playerid] < 30)
        {
            SendClientMessage(playerid, COL_HATA, "Tekrar rapor gondermek icin biraz bekle.");
            return 1;
        }
        PReportT[playerid] = gettime();
        new rm[200], rn[MAX_PLAYER_NAME];
        GetPlayerName(playerid, rn, sizeof rn);
        format(rm, sizeof rm, "[RAPOR] %s (ID %d): %s", rn, playerid, par);
        for (new i = 0; i < MAX_PLAYERS; i++)
        {
            if (IsPlayerConnected(i) && IsPlayerAdmin(i)) SendClientMessage(i, 0xFFA500FF, rm);
        }
        new File:rf = fopen("oyuncu2_report.txt", io_append);
        if (rf)
        {
            format(rm, sizeof rm, "%d|%s|%s\r\n", gettime(), rn, par);
            fwrite(rf, rm);
            fclose(rf);
        }
        SendClientMessage(playerid, COL_OK, "[RAPOR] Raporun iletildi.");
        return 1;
    }

    // ---------------- ANIMASYONLAR ----------------
    if (!strcmp(cmd, "/otur", true))
    {
        if (IsPlayerInAnyVehicle(playerid)) return 1;
        ApplyAnimation(playerid, "BEACH", "ParkSit_M_loop", 4.1, 1, 0, 0, 0, 0);
        return 1;
    }
    if (!strcmp(cmd, "/yat", true))
    {
        if (IsPlayerInAnyVehicle(playerid)) return 1;
        ApplyAnimation(playerid, "BEACH", "Lay_Bac_Loop", 4.1, 1, 0, 0, 0, 0);
        return 1;
    }
    if (!strcmp(cmd, "/selam", true))
    {
        if (IsPlayerInAnyVehicle(playerid)) return 1;
        ApplyAnimation(playerid, "ON_LOOKERS", "wave_loop", 4.1, 0, 0, 0, 0, 0);
        return 1;
    }
    if (!strcmp(cmd, "/elsik", true))
    {
        new tid = strval(par);
        if (strlen(par) < 1 || tid < 0 || tid >= MAX_PLAYERS || !IsPlayerConnected(tid) || tid == playerid)
        {
            SendClientMessage(playerid, COL_BILGI, "Kullanim: /elsik [id]");
            return 1;
        }
        new Float:ex, Float:ey, Float:ez;
        GetPlayerPos(tid, ex, ey, ez);
        if (!IsPlayerInRangeOfPoint(playerid, 3.0, ex, ey, ez))
        {
            SendClientMessage(playerid, COL_HATA, "Oyuncuya yeterince yakin degilsin.");
            return 1;
        }
        ApplyAnimation(playerid, "GANGS", "hndshkaa", 4.1, 0, 0, 0, 0, 0);
        ApplyAnimation(tid, "GANGS", "hndshkaa", 4.1, 0, 0, 0, 0, 0);
        return 1;
    }
    if (!strcmp(cmd, "/dur", true))
    {
        ClearAnimations(playerid);
        return 1;
    }

    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid < 7800 || dialogid > 7899) return 0;
    Hazirla(playerid);

    switch (dialogid)
    {
        case D_BILGI:
        {
            return 1;
        }

        // ================= BANKA =================
        case D_BANKA:
        {
            if (!response) return 1;
            switch (listitem)
            {
                case 0:
                {
                    new s[128];
                    format(s, sizeof s, "Nakit: $%d\nBanka: $%d\n\nYatirilacak miktari yaz:", Nakit(playerid), PD[playerid][pdBanka]);
                    ShowPlayerDialog(playerid, D_YATIR, DIALOG_STYLE_INPUT, "Para Yatir", s, "Yatir", "Geri");
                }
                case 1:
                {
                    new s[128];
                    format(s, sizeof s, "Banka: $%d\n\nCekilecek miktari yaz:", PD[playerid][pdBanka]);
                    ShowPlayerDialog(playerid, D_CEK, DIALOG_STYLE_INPUT, "Para Cek", s, "Cek", "Geri");
                }
                case 2:
                {
                    ShowPlayerDialog(playerid, D_HAV_ALICI, DIALOG_STYLE_INPUT, "Havale",
                        "Alici IBAN numarasini veya oyuncu ID'sini yaz:\n(Alici cevrimici olmali)", "Devam", "Geri");
                }
                case 3:
                {
                    new s[400], t[80];
                    s[0] = 0;
                    for (new h = 0; h < 5; h++)
                    {
                        if (strlen(PHist[playerid][h]) < 1) continue;
                        format(t, sizeof t, "%s\n", PHist[playerid][h]);
                        strcat(s, t);
                    }
                    if (strlen(s) < 1) format(s, sizeof s, "Henuz islem yok.");
                    Bilgi(playerid, "Islem Gecmisi (son 5)", s);
                }
                case 4:
                {
                    new s[160];
                    format(s, sizeof s, "Banka bakiyesi: $%d\nNakit: $%d\nIBAN: %d", PD[playerid][pdBanka], Nakit(playerid), PD[playerid][pdIban]);
                    Bilgi(playerid, "Bakiye", s);
                }
            }
            return 1;
        }
        case D_YATIR:
        {
            if (!response) { BankaMenu(playerid); return 1; }
            new m = strval(inputtext);
            if (m <= 0 || m > 100000000)
            {
                SendClientMessage(playerid, COL_HATA, "Gecersiz miktar.");
                BankaMenu(playerid); return 1;
            }
            if (m > Nakit(playerid))
            {
                SendClientMessage(playerid, COL_HATA, "Yeterli nakit paran yok.");
                BankaMenu(playerid); return 1;
            }
            if (PD[playerid][pdBanka] + m > 2000000000)
            {
                SendClientMessage(playerid, COL_HATA, "Banka hesabi limiti asilir.");
                BankaMenu(playerid); return 1;
            }
            NakitEkle(playerid, -m);
            PD[playerid][pdBanka] += m;
            new msg[96], gl[48];
            format(msg, sizeof msg, "[BANKA] $%d yatirdin. Bakiye: $%d", m, PD[playerid][pdBanka]);
            SendClientMessage(playerid, COL_OK, msg);
            format(gl, sizeof gl, "Yatirma +$%d", m);
            Gecmis(playerid, gl);
            GorevTamamla(playerid, 2);
            VeriKaydet(playerid);
            BankaMenu(playerid);
            return 1;
        }
        case D_CEK:
        {
            if (!response) { BankaMenu(playerid); return 1; }
            new m = strval(inputtext);
            if (m <= 0 || m > PD[playerid][pdBanka])
            {
                SendClientMessage(playerid, COL_HATA, "Gecersiz miktar veya yetersiz bakiye.");
                BankaMenu(playerid); return 1;
            }
            PD[playerid][pdBanka] -= m;
            NakitEkle(playerid, m);
            new msg[96], gl[48];
            format(msg, sizeof msg, "[BANKA] $%d cektin. Bakiye: $%d", m, PD[playerid][pdBanka]);
            SendClientMessage(playerid, COL_OK, msg);
            format(gl, sizeof gl, "Cekme -$%d", m);
            Gecmis(playerid, gl);
            VeriKaydet(playerid);
            BankaMenu(playerid);
            return 1;
        }
        case D_HAV_ALICI:
        {
            if (!response) { BankaMenu(playerid); return 1; }
            new n = strval(inputtext), t = INVALID_PLAYER_ID;
            if (n >= 100000) t = IbanBul(n);
            else if (n >= 0 && n < MAX_PLAYERS && strlen(inputtext) > 0 && IsPlayerConnected(n) && PD[n][pdYuklu]) t = n;
            if (t == INVALID_PLAYER_ID || t == playerid)
            {
                SendClientMessage(playerid, COL_HATA, "Alici bulunamadi (cevrimici olmali) veya kendine gonderemezsin.");
                BankaMenu(playerid); return 1;
            }
            PTmp[playerid][0] = t;
            PTmp[playerid][1] = PD[t][pdIban];
            new s[128], rn[MAX_PLAYER_NAME];
            RPIsim(t, rn, sizeof rn);
            format(s, sizeof s, "Alici: %s (IBAN %d)\nBanka bakiyen: $%d\n\nGonderilecek miktari yaz:", rn, PD[t][pdIban], PD[playerid][pdBanka]);
            ShowPlayerDialog(playerid, D_HAV_MIKTAR, DIALOG_STYLE_INPUT, "Havale", s, "Gonder", "Geri");
            return 1;
        }
        case D_HAV_MIKTAR:
        {
            if (!response) { BankaMenu(playerid); return 1; }
            new t = PTmp[playerid][0], m = strval(inputtext);
            if (t < 0 || t >= MAX_PLAYERS || !IsPlayerConnected(t) || !PD[t][pdYuklu] || PD[t][pdIban] != PTmp[playerid][1])
            {
                SendClientMessage(playerid, COL_HATA, "Alici artik uygun degil. Islem iptal edildi.");
                BankaMenu(playerid); return 1;
            }
            if (m <= 0 || m > 5000000 || m > PD[playerid][pdBanka])
            {
                SendClientMessage(playerid, COL_HATA, "Gecersiz miktar veya yetersiz bakiye (en fazla 5.000.000).");
                BankaMenu(playerid); return 1;
            }
            if (PD[t][pdBanka] + m > 2000000000)
            {
                SendClientMessage(playerid, COL_HATA, "Alicinin hesabi bu tutari kabul edemiyor.");
                BankaMenu(playerid); return 1;
            }
            PD[playerid][pdBanka] -= m;
            PD[t][pdBanka] += m;
            new n1[MAX_PLAYER_NAME], n2[MAX_PLAYER_NAME], msg[128], gl[64];
            RPIsim(playerid, n1, sizeof n1);
            RPIsim(t, n2, sizeof n2);
            format(msg, sizeof msg, "[BANKA] %s kisisine $%d havale ettin.", n2, m);
            SendClientMessage(playerid, COL_OK, msg);
            format(msg, sizeof msg, "[BANKA] %s sana $%d havale etti.", n1, m);
            SendClientMessage(t, COL_OK, msg);
            format(gl, sizeof gl, "Havale -$%d (%s)", m, n2);
            Gecmis(playerid, gl);
            format(gl, sizeof gl, "Havale +$%d (%s)", m, n1);
            Gecmis(t, gl);
            GorevTamamla(playerid, 3);
            VeriKaydet(playerid);
            VeriKaydet(t);
            BankaMenu(playerid);
            return 1;
        }

        // ================= MESLEK =================
        case D_MESLEK:
        {
            if (!response) return 1;
            new j = listitem + 1;
            if (j < 1 || j > 20) return 1;
            if (JobKilit[j])
            {
                SendClientMessage(playerid, COL_HATA, "Bu meslek icin yonetim/oyuncu onayi gerekir (yakinda).");
                MeslekMenu(playerid);
                return 1;
            }
            if (JobLisans[j] && !PD[playerid][pdLisans])
            {
                SendClientMessage(playerid, COL_HATA, "Bu meslek icin ehliyet gerekli. Belediyeden alabilirsin (/belediye).");
                MeslekMenu(playerid);
                return 1;
            }
            if (PD[playerid][pdMeslek] == j)
            {
                SendClientMessage(playerid, COL_HATA, "Zaten bu meslekte calisiyorsun.");
                MeslekMenu(playerid);
                return 1;
            }
            PTmp[playerid][0] = j;
            new s[200];
            format(s, sizeof s, "Meslek: %s\nMaas: $%d (her %d dakikada, bankaya)\nSeviye arttikca maas artar.\n\nBasvurmak istiyor musun?", JobAd[j], JobMaas[j], MAAS_DAKIKA);
            ShowPlayerDialog(playerid, D_MESLEK_ONAY, DIALOG_STYLE_MSGBOX, "Is Basvurusu", s, "Basvur", "Geri");
            return 1;
        }
        case D_MESLEK_ONAY:
        {
            if (!response) { MeslekMenu(playerid); return 1; }
            new j = PTmp[playerid][0];
            if (j < 1 || j > 20 || JobKilit[j]) return 1;
            if (JobLisans[j] && !PD[playerid][pdLisans]) return 1;
            PD[playerid][pdMeslek] = j;
            PD[playerid][pdDeney] = 0;
            new msg[96];
            format(msg, sizeof msg, "[MESLEK] Artik %s olarak calisiyorsun!", JobAd[j]);
            SendClientMessage(playerid, COL_OK, msg);
            GorevTamamla(playerid, 0);
            VeriKaydet(playerid);
            return 1;
        }

        // ================= BELEDIYE =================
        case D_BELEDIYE:
        {
            if (!response) return 1;
            switch (listitem)
            {
                case 0: KimlikGoster(playerid);
                case 1:
                {
                    if (PD[playerid][pdLisans])
                    {
                        Bilgi(playerid, "Ehliyet", "Zaten ehliyetin var.");
                    }
                    else
                    {
                        new s[128];
                        format(s, sizeof s, "Ehliyet ucreti: $%d (nakit)\nNakit paran: $%d\n\nBasvuruyu onayliyor musun?", EHLIYET_UCRET, Nakit(playerid));
                        ShowPlayerDialog(playerid, D_EHLIYET, DIALOG_STYLE_MSGBOX, "Ehliyet Basvurusu", s, "Onayla", "Iptal");
                    }
                }
                case 2: MeslekMenu(playerid);
                case 3: ProfilGoster(playerid, playerid);
                case 4: ShowPlayerDialog(playerid, D_BIO, DIALOG_STYLE_INPUT, "Biyografi", "Karakterin icin kisa bir biyografi yaz (en fazla 60 karakter):", "Kaydet", "Iptal");
            }
            return 1;
        }
        case D_EHLIYET:
        {
            if (!response) return 1;
            if (PD[playerid][pdLisans])
            {
                SendClientMessage(playerid, COL_HATA, "Zaten ehliyetin var.");
                return 1;
            }
            if (Nakit(playerid) < EHLIYET_UCRET)
            {
                SendClientMessage(playerid, COL_HATA, "Yeterli nakit paran yok.");
                return 1;
            }
            NakitEkle(playerid, -EHLIYET_UCRET);
            PD[playerid][pdLisans] = 1;
            SendClientMessage(playerid, COL_OK, "[BELEDIYE] Ehliyet basvurun onaylandi. Taksi, otobus, kamyon ve kurye mesleklerine basvurabilirsin.");
            GorevTamamla(playerid, 4);
            VeriKaydet(playerid);
            return 1;
        }
        case D_BIO:
        {
            if (!response) return 1;
            new b[64];
            format(b, sizeof b, "%s", inputtext);
            Temizle(b);
            format(PD[playerid][pdBio], 64, "%s", b);
            VeriKaydet(playerid);
            SendClientMessage(playerid, COL_OK, "[PROFIL] Biyografin kaydedildi.");
            return 1;
        }

        // ================= REHBER =================
        case D_REH:
        {
            if (!response) return 1;
            if (listitem == 0)
            {
                new bos = 0;
                for (new r = 0; r < MAX_REHBER; r++)
                {
                    if (PRehNo[playerid][r] <= 0) bos++;
                }
                if (bos == 0)
                {
                    SendClientMessage(playerid, COL_HATA, "Rehber dolu. Once bir kisiyi sil.");
                    RehberMenu(playerid); return 1;
                }
                ShowPlayerDialog(playerid, D_REH_EKLE_NO, DIALOG_STYLE_INPUT, "Kisi Ekle", "Kisinin telefon numarasini yaz:", "Devam", "Geri");
                return 1;
            }
            PTmp[playerid][2] = PMap[playerid][listitem - 1];
            ShowPlayerDialog(playerid, D_REH_KISI, DIALOG_STYLE_LIST, PRehIsim[playerid][PTmp[playerid][2]], "Ara\nSMS gonder\nKisiyi sil", "Sec", "Geri");
            return 1;
        }
        case D_REH_EKLE_NO:
        {
            if (!response) { RehberMenu(playerid); return 1; }
            new n = strval(inputtext);
            if (n <= 0 || n > 999999999 || n == PD[playerid][pdTel])
            {
                SendClientMessage(playerid, COL_HATA, "Gecersiz numara.");
                RehberMenu(playerid); return 1;
            }
            for (new r = 0; r < MAX_REHBER; r++)
            {
                if (PRehNo[playerid][r] == n)
                {
                    SendClientMessage(playerid, COL_HATA, "Bu numara zaten rehberde.");
                    RehberMenu(playerid); return 1;
                }
            }
            PTmp[playerid][3] = n;
            ShowPlayerDialog(playerid, D_REH_EKLE_ISIM, DIALOG_STYLE_INPUT, "Kisi Ekle", "Kisinin adini yaz (en fazla 18 karakter):", "Kaydet", "Geri");
            return 1;
        }
        case D_REH_EKLE_ISIM:
        {
            if (!response) { RehberMenu(playerid); return 1; }
            new nm[20];
            strmid(nm, inputtext, 0, 18, sizeof nm);
            Temizle(nm);
            if (strlen(nm) < 1)
            {
                SendClientMessage(playerid, COL_HATA, "Isim bos olamaz.");
                RehberMenu(playerid); return 1;
            }
            for (new r = 0; r < MAX_REHBER; r++)
            {
                if (PRehNo[playerid][r] <= 0)
                {
                    PRehNo[playerid][r] = PTmp[playerid][3];
                    format(PRehIsim[playerid][r], 20, "%s", nm);
                    break;
                }
            }
            SendClientMessage(playerid, COL_OK, "[REHBER] Kisi eklendi.");
            GorevTamamla(playerid, 7);
            VeriKaydet(playerid);
            RehberMenu(playerid);
            return 1;
        }
        case D_REH_KISI:
        {
            if (!response) { RehberMenu(playerid); return 1; }
            new r = PTmp[playerid][2];
            if (r < 0 || r >= MAX_REHBER || PRehNo[playerid][r] <= 0) return 1;
            switch (listitem)
            {
                case 0: CagriBaslat(playerid, PRehNo[playerid][r]);
                case 1:
                {
                    new s[64];
                    format(s, sizeof s, "%s (%d) kisisine SMS yaz:", PRehIsim[playerid][r], PRehNo[playerid][r]);
                    ShowPlayerDialog(playerid, D_REH_SMS, DIALOG_STYLE_INPUT, "SMS", s, "Gonder", "Iptal");
                }
                case 2:
                {
                    PRehNo[playerid][r] = 0;
                    PRehIsim[playerid][r][0] = 0;
                    VeriKaydet(playerid);
                    SendClientMessage(playerid, COL_OK, "[REHBER] Kisi silindi.");
                    RehberMenu(playerid);
                }
            }
            return 1;
        }
        case D_REH_SMS:
        {
            if (!response) return 1;
            new r = PTmp[playerid][2];
            if (r < 0 || r >= MAX_REHBER || PRehNo[playerid][r] <= 0) return 1;
            SmsGonder(playerid, PRehNo[playerid][r], inputtext);
            return 1;
        }

        // ================= ILAN =================
        case D_ILAN:
        {
            if (!response) return 1;
            switch (listitem)
            {
                case 0:
                {
                    ShowPlayerDialog(playerid, D_ILAN_KAT, DIALOG_STYLE_LIST, "Ilan Kategorisi",
                        "Arac satilik\nEv satilik\nEv kiralik\nIs ilani\nEsya satilik\nIsletme satilik\nGenel ilan", "Sec", "Geri");
                }
                case 1: IlanListe(playerid, 0);
                case 2: IlanListe(playerid, 1);
            }
            return 1;
        }
        case D_ILAN_KAT:
        {
            if (!response) { IlanMenu(playerid); return 1; }
            PTmp[playerid][6] = listitem;
            ShowPlayerDialog(playerid, D_ILAN_BASLIK, DIALOG_STYLE_INPUT, "Ilan Basligi", "Ilan basligini yaz (3-38 karakter):", "Devam", "Geri");
            return 1;
        }
        case D_ILAN_BASLIK:
        {
            if (!response) { IlanMenu(playerid); return 1; }
            new b[48];
            strmid(b, inputtext, 0, 38, sizeof b);
            Temizle(b);
            if (strlen(b) < 3)
            {
                SendClientMessage(playerid, COL_HATA, "Baslik en az 3 karakter olmali.");
                IlanMenu(playerid); return 1;
            }
            format(PTmpS[playerid], 48, "%s", b);
            ShowPlayerDialog(playerid, D_ILAN_FIYAT, DIALOG_STYLE_INPUT, "Ilan Fiyati", "Fiyati yaz ($). Pazarlik/fiyatsiz ilan icin 0 yaz:", "Yayinla", "Geri");
            return 1;
        }
        case D_ILAN_FIYAT:
        {
            if (!response) { IlanMenu(playerid); return 1; }
            new fiyat = strval(inputtext);
            if (fiyat < 0 || fiyat > 1000000000)
            {
                SendClientMessage(playerid, COL_HATA, "Gecersiz fiyat.");
                IlanMenu(playerid); return 1;
            }
            new nm[MAX_PLAYER_NAME], own = 0, slot = -1;
            GetPlayerName(playerid, nm, sizeof nm);
            for (new i = 0; i < MAX_ILAN; i++)
            {
                if (IlanVar[i] && !strcmp(IlanSahip[i], nm)) own++;
                if (!IlanVar[i] && slot == -1) slot = i;
            }
            if (own >= 3)
            {
                SendClientMessage(playerid, COL_HATA, "En fazla 3 aktif ilanin olabilir. Birini sil.");
                IlanMenu(playerid); return 1;
            }
            if (slot == -1)
            {
                SendClientMessage(playerid, COL_HATA, "Ilan listesi dolu, daha sonra tekrar dene.");
                return 1;
            }
            if (Nakit(playerid) < ILAN_UCRET)
            {
                SendClientMessage(playerid, COL_HATA, "Ilan ucreti icin yeterli nakit paran yok.");
                return 1;
            }
            NakitEkle(playerid, -ILAN_UCRET);
            IlanVar[slot] = 1;
            IlanKat[slot] = PTmp[playerid][6];
            if (IlanKat[slot] < 0 || IlanKat[slot] > 6) IlanKat[slot] = 6;
            IlanFiyat[slot] = fiyat;
            IlanTel[slot] = PD[playerid][pdTel];
            IlanZaman[slot] = gettime();
            format(IlanSahip[slot], MAX_PLAYER_NAME, "%s", nm);
            format(IlanBaslik[slot], 40, "%s", PTmpS[playerid]);
            IlanKaydet();
            new msg[96];
            format(msg, sizeof msg, "[ILAN] Ilanin yayinlandi. (Ucret: $%d)", ILAN_UCRET);
            SendClientMessage(playerid, COL_OK, msg);
            GorevTamamla(playerid, 5);
            VeriKaydet(playerid);
            return 1;
        }
        case D_ILAN_LISTE:
        {
            if (!response) { IlanMenu(playerid); return 1; }
            new idx = PMap[playerid][listitem];
            if (idx < 0 || idx >= MAX_ILAN || !IlanVar[idx])
            {
                SendClientMessage(playerid, COL_HATA, "Bu ilan artik yok.");
                return 1;
            }
            PTmp[playerid][5] = idx;
            new s[300], ago = (gettime() - IlanZaman[idx]) / 60, rn[MAX_PLAYER_NAME];
            format(rn, sizeof rn, "%s", IlanSahip[idx]);
            for (new i = 0, l = strlen(rn); i < l; i++)
            {
                if (rn[i] == '_') rn[i] = ' ';
            }
            format(s, sizeof s, "Kategori: %s\nBaslik: %s\nFiyat: $%d\nIlan sahibi: %s\nTelefon: %d\nVerilme: %d dk once",
                IlanKatAd[IlanKat[idx]], IlanBaslik[idx], IlanFiyat[idx], rn, IlanTel[idx], ago);
            if (PTmp[playerid][4] == 1) ShowPlayerDialog(playerid, D_ILAN_DETAY, DIALOG_STYLE_MSGBOX, "Ilanim", s, "Ilani Sil", "Geri");
            else ShowPlayerDialog(playerid, D_ILAN_DETAY, DIALOG_STYLE_MSGBOX, "Ilan", s, "Ara", "Geri");
            return 1;
        }
        case D_ILAN_DETAY:
        {
            if (!response) { IlanMenu(playerid); return 1; }
            new idx = PTmp[playerid][5];
            if (idx < 0 || idx >= MAX_ILAN || !IlanVar[idx])
            {
                SendClientMessage(playerid, COL_HATA, "Bu ilan artik yok.");
                return 1;
            }
            if (PTmp[playerid][4] == 1)
            {
                new nm[MAX_PLAYER_NAME];
                GetPlayerName(playerid, nm, sizeof nm);
                if (strcmp(IlanSahip[idx], nm)) return 1;
                IlanVar[idx] = 0;
                IlanKaydet();
                SendClientMessage(playerid, COL_OK, "[ILAN] Ilan silindi.");
            }
            else CagriBaslat(playerid, IlanTel[idx]);
            return 1;
        }

        // ================= SOSYAL =================
        case D_SOSYAL:
        {
            if (!response) return 1;
            switch (listitem)
            {
                case 0: ShowPlayerDialog(playerid, D_SOS_YAZ, DIALOG_STYLE_INPUT, "Gonderi Paylas", "Gonderini yaz (en fazla 75 karakter):", "Paylas", "Iptal");
                case 1:
                {
                    new s[1000], t[140], c = 0, ago;
                    s[0] = 0;
                    for (new i = 0; i < MAX_SOSYAL; i++)
                    {
                        if (SosZaman[i] == 0) continue;
                        ago = (gettime() - SosZaman[i]) / 60;
                        new an[MAX_PLAYER_NAME];
                        format(an, sizeof an, "%s", SosYazar[i]);
                        for (new k = 0, l = strlen(an); k < l; k++)
                        {
                            if (an[k] == '_') an[k] = ' ';
                        }
                        format(t, sizeof t, "@%s (%d dk once)\n%s\n\n", an, ago, SosMetin[i]);
                        strcat(s, t);
                        c++;
                    }
                    if (c == 0) format(s, sizeof s, "Henuz gonderi yok. Ilk paylasan sen ol!");
                    Bilgi(playerid, "Sosyal Medya Akisi", s);
                }
                case 2: ProfilGoster(playerid, playerid);
            }
            return 1;
        }
        case D_SOS_YAZ:
        {
            if (!response) return 1;
            new b[80];
            strmid(b, inputtext, 0, 75, sizeof b);
            Temizle(b);
            if (strlen(b) < 2)
            {
                SendClientMessage(playerid, COL_HATA, "Gonderi cok kisa.");
                return 1;
            }
            for (new i = MAX_SOSYAL - 1; i > 0; i--)
            {
                SosZaman[i] = SosZaman[i - 1];
                format(SosYazar[i], MAX_PLAYER_NAME, "%s", SosYazar[i - 1]);
                format(SosMetin[i], 80, "%s", SosMetin[i - 1]);
            }
            SosZaman[0] = gettime();
            GetPlayerName(playerid, SosYazar[0], MAX_PLAYER_NAME);
            format(SosMetin[0], 80, "%s", b);
            SosyalKaydet();
            SendClientMessage(playerid, COL_OK, "[SOSYAL] Gonderin paylasildi.");
            return 1;
        }
    }
    return 1;
}
