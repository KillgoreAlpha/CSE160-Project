#include "../../packet.h"
#include "../../includes/channels.h"

interface Flooding{
    command void newFlood(uint16_t TARGET);
    command void forwardFlood(pack* FLOOD_PACKET);

}