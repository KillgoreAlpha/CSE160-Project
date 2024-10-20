#include "../../includes/packet.h"

interface LinkStateRouting {
    command error_t start();
    command void ping(uint16_t destination, uint8_t *payload);
    command void routePacket(pack* myMsg);
    command void handleLinkState(pack* myMsg);
    command void handleNeighborLost(uint16_t lostNeighbor);
    command void handleNeighborFound();
    command void printLinkState();
    command void printRouteTable();
}