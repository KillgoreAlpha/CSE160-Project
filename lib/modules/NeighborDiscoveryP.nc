#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/constants.h"
#include "../../includes/structs.h"

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as sendTimer;
    uses interface SimpleSend;
    uses interface Packet;
    uses interface Hashmap<uint16_t> as NeighborMap;
    uses interface LinkStateRouting; // NEW: Added LinkStateRouting interface
}

implementation {
    pack localNeighborDiscoveryPacket;
    pack localNeighborReplyPacket;

    uint16_t sequenceNumber = 0;
    neighbor_t neighbors[MAX_NEIGHBORS];
    uint8_t neighborCount = 0;

    float getLinkQuality(uint16_t nodeId, float newSample, float lastSample) {
        float alpha = 0.1;
        float link_quality = (alpha * newSample) + ((1 - alpha) * lastSample);
        return link_quality;
    }

    command void NeighborDiscovery.start() {
        call sendTimer.startPeriodic(30 * TICKS);
    }

    event void sendTimer.fired() {
        uint8_t payload[] = {};
        uint8_t ttl = 1;
        uint8_t i;

        makePack(&localNeighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, ttl, PROTOCOL_NEIGHBOR, sequenceNumber, payload, 0);
        
        call SimpleSend.send(localNeighborDiscoveryPacket, AM_BROADCAST_ADDR);
        
        // dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERY SENT FROM NODE %hhu \n", TOS_NODE_ID);

        for (i = 0; i < neighborCount; i++) {
        float oldQuality = neighbors[i].linkQuality;
        float newQuality;
        
        if ((sequenceNumber - neighbors[i].lastHeard) > 1) {
            newQuality = getLinkQuality(neighbors[i].id, 0.0, oldQuality);
            
            // Only update if quality change is significant
            if (fabs(newQuality - oldQuality) > NEIGHBOR_QUALITY_THRESHOLD) {
                neighbors[i].linkQuality = newQuality;
                call LinkStateRouting.handleNeighborFound(neighbors[i].id, newQuality);
            }
        }

        if ((sequenceNumber - neighbors[i].lastHeard) > INACTIVE_THRESHOLD && 
            neighbors[i].isActive == TRUE) {
            neighbors[i].isActive = FALSE;
            call LinkStateRouting.handleNeighborLost(neighbors[i].id);
        }
    }

    sequenceNumber++;
}

    command void NeighborDiscovery.reply(pack* NEIGHBOR_DISCOVERY_PACKET) {
        uint8_t payload[] = {};
        uint8_t ttl = 1;

        if (!call NeighborMap.contains(NEIGHBOR_DISCOVERY_PACKET->src)) {
            call NeighborMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
            
            makePack(&localNeighborReplyPacket, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, ttl, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, payload, 0);
            
            call SimpleSend.send(localNeighborReplyPacket, NEIGHBOR_DISCOVERY_PACKET->src);
            
            // dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT FROM NODE %hhu TO NODE %hhu \n", TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src);

        } else {
            uint16_t lastSeq = call NeighborMap.get(NEIGHBOR_DISCOVERY_PACKET->src);
            if (NEIGHBOR_DISCOVERY_PACKET->seq > lastSeq) {
                call NeighborMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
                
                makePack(&localNeighborReplyPacket, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, ttl, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, payload, 0);
                call SimpleSend.send(localNeighborReplyPacket, NEIGHBOR_DISCOVERY_PACKET->src);
                
                // dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT FROM NODE %hhu TO NODE %hhu \n", TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src);
            }
        }
    }

    command void NeighborDiscovery.readDiscovery(pack* NEIGHBOR_REPLY_PACKET) {
        uint16_t neighborId = NEIGHBOR_REPLY_PACKET->src;
        uint8_t i;
        bool found = FALSE;
        float oldQuality, newQuality;
        
        for (i = 0; i < neighborCount; i++) {
            if (neighbors[i].id == neighborId) {
                oldQuality = neighbors[i].linkQuality;
                neighbors[i].lastHeard = sequenceNumber;
                neighbors[i].isActive = TRUE;
                
                // Calculate new quality
                newQuality = getLinkQuality(neighborId, 1.0, oldQuality);
                
                // Only update if quality change is significant
                if (fabs(newQuality - oldQuality) > NEIGHBOR_QUALITY_THRESHOLD) {
                    neighbors[i].linkQuality = newQuality;
                    // Notify LinkStateRouting about significant quality change
                    call LinkStateRouting.handleNeighborFound(neighborId, newQuality);
                }
                
                found = TRUE;
                break;
            }
        }

        if (!found && neighborCount < MAX_NEIGHBORS) {
            neighbors[neighborCount].id = neighborId;
            neighbors[neighborCount].lastHeard = sequenceNumber;
            neighbors[neighborCount].linkQuality = 1.0;
            neighborCount++;
            // Always notify about new neighbors
            call LinkStateRouting.handleNeighborFound(neighborId, 1.0);
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

    command float NeighborDiscovery.neighborQuality(uint16_t nodeId) {
        uint8_t i;
        for (i = 0; i < neighborCount; i++) {
            if (neighbors[i].id == nodeId) {
                return neighbors[i].linkQuality;
            }
        }
        return 0;
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

    command void NeighborDiscovery.printNeighbors() {
        uint16_t i = 0;
        uint32_t* keys = call NeighborMap.getKeys();    
        // Print neighbors
        dbg(NEIGHBOR_CHANNEL, "Printing Neighbors:\n");
        dbg(ROUTING_CHANNEL, "NODE  ACTV  LSTHRD  LINKQUAL\n");
        for(; i < call NeighborMap.size(); i++) {
            if(keys[i] != 0) {
                dbg(NEIGHBOR_CHANNEL, "%2d%6d%6d%10.2f\n", neighbors[i].id, neighbors[i].isActive, neighbors[i].lastHeard, neighbors[i].linkQuality);
            }
        }
    }

    command uint32_t* NeighborDiscovery.getNeighbors() {
        return call NeighborMap.getKeys();
    }

    command uint16_t NeighborDiscovery.getNeighborListSize() {
        return call NeighborMap.size();
    }
}