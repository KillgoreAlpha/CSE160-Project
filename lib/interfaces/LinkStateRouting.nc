#include "../../includes/packet.h"

interface LinkStateRouting {
    command error_t start();
    command void ping(uint16_t destination, uint8_t *payload);
    command void routePacket(pack* myMsg);
    command void handleLinkState(pack* linkStatePacket);
    command void handleNeighborLost(uint16_t lostNeighbor);
    command void handleNeighborFound(uint16_t neighbor, float quality);
    command void printLinkState();
    command void printRouteTable();
}