/*
    DUKTUR RP - YAKIN MESAFE SES SISTEMI (ses.pwn)

    Gerekenler:
      1) Sunucuda sampvoice eklentisi (Linux icin sampvoice.so) ve server.cfg'de "plugins sampvoice.so"
      2) Derleme icin sampvoice.inc  (sampvoice deposunda documents/sampvoice.inc)

    Calisma sekli:
      - Oyuncu mikrofon (B) tusuna basili tutarken konusur.
      - 40 metre icindeki oyuncular sesi duyar.
*/

#include <a_samp>
#include <sampvoice>

#define SES_MESAFE      40.0
#define SES_TUSU        0x42        // B tusu
#define LOCAL_CHANNEL   0

new SV_UINT:lstream[MAX_PLAYERS] = { SV_NONE, ... };

public OnPlayerConnect(playerid)
{
    lstream[playerid] = SV_NONE;

    if(SvGetVersion(playerid) == 0)
    {
        SendClientMessage(playerid, 0xE06666FF, "[SES] Ses sistemi bulunamadı. Launcher ayarlarında Voice chat açık mı kontrol et.");
    }
    else if(SvHasMicro(playerid) == SV_FALSE)
    {
        SendClientMessage(playerid, 0xE06666FF, "[SES] Mikrofon bulunamadı. Telefon mikrofon iznini kontrol et.");
    }
    else if((lstream[playerid] = SvCreateStream(SES_MESAFE)) != SV_NONE)
    {
        SvSetKey(playerid, SES_TUSU, LOCAL_CHANNEL);
        SvAttachStream(playerid, lstream[playerid], LOCAL_CHANNEL);
        SvSetTarget(lstream[playerid], SvMakePlayer(playerid));
        SvSetIcon(lstream[playerid], "speaker");

        SendClientMessage(playerid, 0x82C98AFF, "[SES] Ses sistemi aktif. Mikrofon tuşuna basılı tutarak konuş.");
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(lstream[playerid] != SV_NONE)
    {
        SvDeleteStream(lstream[playerid]);
        lstream[playerid] = SV_NONE;
    }
    return 1;
}
