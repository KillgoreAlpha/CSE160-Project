#include "../../includes/packet.h"

interface NeighborDiscovery {
    command void start();
    command void reply(pack* NEIGHBOR_DISCOVERY_PACKET);
    command void readDiscovery(pack* NEIGHBOR_REPLY_PACKET);
    command bool isNeighbor(uint16_t nodeId);
    command uint16_t getLastHeard(uint16_t nodeId);
    command void printNeighbors();
    command uint32_t* getNeighbors();
    command uint16_t getNeighborListSize();
    command float neighborQuality(uint16_t nodeId);
}