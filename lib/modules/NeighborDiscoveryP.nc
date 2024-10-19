#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#define INACTIVE_THRESHOLD 5
#define TICKS 1024
#define MAX_NEIGHBORS 20

typedef struct neighbor {
    uint16_t id;
    bool isActive;
    uint16_t lastHeard;
    uint16_t linkQuality;
} neighbor_t;

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as sendTimer;
    uses interface SimpleSend;
    uses interface Packet;
    uses interface Hashmap<uint16_t> as NeighborMap;
    uses interface LinkStateRouting as LinkState;
}

implementation {
    pack localNeighborDiscoveryPacket;
    pack localNeighborReplyPacket;

    uint16_t sequenceNumber = 0;
    neighbor_t neighbors[MAX_NEIGHBORS];
    uint8_t neighborCount = 0;

    command void NeighborDiscovery.start() {
        call sendTimer.startPeriodic(600 * TICKS);
    }

    event void sendTimer.fired() {
        uint8_t payload[] = {};
        uint8_t ttl = 1;

        makeLinkPack(&localNeighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, ttl, PROTOCOL_NEIGHBOR, sequenceNumber, payload, 0);
        
        call SimpleSend.send(localNeighborDiscoveryPacket, AM_BROADCAST_ADDR);
        
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERY SENT FROM NODE %hhu \n", TOS_NODE_ID);

        sequenceNumber++;
    }

    command void NeighborDiscovery.reply(pack* NEIGHBOR_DISCOVERY_PACKET) {
        uint8_t payload[] = {};
        uint8_t ttl = 1;

        if (!call NeighborMap.contains(NEIGHBOR_DISCOVERY_PACKET->src)) {
            call NeighborMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
            
            makeLinkPack(&localNeighborReplyPacket, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, ttl, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, payload, 0);
            
            call SimpleSend.send(localNeighborReplyPacket, NEIGHBOR_DISCOVERY_PACKET->src);
            
            dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT FROM NODE %hhu TO NODE %hhu \n", TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src);

        } else {
            uint16_t lastSeq = call NeighborMap.get(NEIGHBOR_DISCOVERY_PACKET->src);
            if (NEIGHBOR_DISCOVERY_PACKET->seq > lastSeq) {
                call NeighborMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
                
                makeLinkPack(&localNeighborReplyPacket, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, ttl, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, payload, 0);
                call SimpleSend.send(localNeighborReplyPacket, NEIGHBOR_DISCOVERY_PACKET->src);
                
                dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT FROM NODE %hhu TO NODE %hhu \n", TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src);
            }
        }
    }

    command void NeighborDiscovery.readDiscovery(pack* NEIGHBOR_REPLY_PACKET) {
        uint16_t neighborId = NEIGHBOR_REPLY_PACKET->src;
        uint8_t i;
        bool found = FALSE;
        
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY RECEIVED BY NODE %hhu FROM NODE %hhu \n", TOS_NODE_ID, NEIGHBOR_REPLY_PACKET->src);

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
            neighbors[neighborCount].linkQuality = ;
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

    command void NeighborDiscovery.getLinkQuality(uint16_t nodeId, uint16_t lastSample) {
        uint8_t alpha;
        
        
    }

    command void NeighborDiscovery.printNeighbors() {
        uint16_t i = 0;
        uint32_t* keys = call NeighborMap.getKeys();    
        // Print neighbors
        dbg(NEIGHBOR_CHANNEL, "Printing Neighbors:\n");
        for(; i < call NeighborMap.size(); i++) {
            if(keys[i] != 0) {
                dbg(NEIGHBOR_CHANNEL, "\tNeighbor: %d\n", keys[i]);
            }
        }
    }
}