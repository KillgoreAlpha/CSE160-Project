interface NeighborDiscovery{
    command void start();
    command void reply(pack* DISCOVERY_PACKET);

}