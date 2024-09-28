interface NeighborDiscovery{
    command void start();
    command void reply(pack* NEIGHBOR_DISCOVERY_PACKET);
    command void readDiscovery(pack* NEIGHBOR_REPLY_PACKET);
    command bool NeighborDiscovery.isNeighbor(uint16_t nodeId);
    command uint16_t NeighborDiscovery.getLastHeard(uint16_t nodeId);
}