interface NeighborDiscovery{
    command void start();
    command void reply(pack* NEIGHBOR_DISCOVERY_PACKET);
    command void readDiscovery(pack* NEIGHBOR_REPLY_PACKET);
    
}