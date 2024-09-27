#include "../../packet.h"
#include "../../includes/channels.h"

interface Flooding{
    command void send(pack msg, uint16_t dest );
}