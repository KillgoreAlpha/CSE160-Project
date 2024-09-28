#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#define INACTIVE_THRESHOLD 5
#define TICKS 1000
#define MAX_NEIGHBORS 20

typedef struct neighbor {
    uint16_t id;
    uint16_t lastHeard;
} neighbor_t;

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as sendTimer;
    uses interface SimpleSend;
    uses interface Packet;
    uses interface Hashmap<uint16_t> as SeqNoMap;
}

implementation {
    pack localNeighborDiscoveryPacket;
    pack localNeighborReplyPacket;

    uint16_t sequenceNumber = 0;
    neighbor_t neighbors[MAX_NEIGHBORS];
    uint8_t neighborCount = 0;

    command void NeighborDiscovery.start() {
        call sendTimer.startPeriodic(30 * TICKS);
    }

    event void sendTimer.fired() {
        uint8_t payload[] = {};
        uint8_t ttl = 1;

        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERY SENT \n");

        makePack(&localNeighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, ttl, PROTOCOL_NEIGHBOR, sequenceNumber, payload, 0);
        
        call SimpleSend.send(localNeighborDiscoveryPacket, AM_BROADCAST_ADDR);

        sequenceNumber++;
    }

    command void NeighborDiscovery.reply(pack* NEIGHBOR_DISCOVERY_PACKET) {
        uint8_t payload[] = {};
        uint8_t ttl = 1;

        if (!call SeqNoMap.contains(NEIGHBOR_DISCOVERY_PACKET->src)) {
            call SeqNoMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
            
            makePack(&localNeighborReplyPacket, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, ttl, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, payload, 0);
            
            call SimpleSend.send(localNeighborReplyPacket, NEIGHBOR_DISCOVERY_PACKET->src);
            
            dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT \n");
        } else {
            uint16_t lastSeq = call SeqNoMap.get(NEIGHBOR_DISCOVERY_PACKET->src);
            if (NEIGHBOR_DISCOVERY_PACKET->seq > lastSeq) {
                call SeqNoMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
                
                makePack(&localNeighborReplyPacket, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, ttl, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, payload, 0);
                call SimpleSend.send(localNeighborReplyPacket, NEIGHBOR_DISCOVERY_PACKET->src);
                
                dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT \n");
            }
        }
    }

    command void NeighborDiscovery.readDiscovery(pack* NEIGHBOR_REPLY_PACKET) {
        uint16_t neighborId = NEIGHBOR_REPLY_PACKET->src;
        uint8_t i;
        bool found = FALSE;
        
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY RECEIVED \n");

        for (i = 0; i < neighborCount; i++) {
            if (neighbors[i].id == neighborId) {
                neighbors[i].lastHeard = sequenceNumber;
                found = TRUE;
                break;
            }
        }

        if (!found && neighborCount < MAX_NEIGHBORS) {
            neighbors[neighborCount].id = neighborId;
            neighbors[neighborCount].lastHeard = sequenceNumber;
            neighborCount++;
        }
    }

    command bool NeighborDiscovery.isNeighbor(uint16_t nodeId) {
        uint8_t i;
        for (i = 0; i < neighborCount; i++) {
            if (neighbors[i].id == nodeId) {
                return TRUE;
            }
        }
        return FALSE;
    }

    command uint16_t NeighborDiscovery.getLastHeard(uint16_t nodeId) {
        uint8_t i;
        for (i = 0; i < neighborCount; i++) {
            if (neighbors[i].id == nodeId) {
                return neighbors[i].lastHeard;
            }
        }
        return 0;
    }
}