#include "../../includes/packet.h"
#include "../../includes/channels.h"

interface Flooding{
    command void newFlood(uint16_t TARGET, uint8_t *payload);
    command void forwardFlood(pack* FLOOD_PACKET);
}