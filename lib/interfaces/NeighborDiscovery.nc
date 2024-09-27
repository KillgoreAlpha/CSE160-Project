interface NeighborDiscovery{
    command void start();
    command void reply(pack* DISCOVERY_PACKET);
    command void readDiscovery(pack* DISCOVERY_PACKET);
}