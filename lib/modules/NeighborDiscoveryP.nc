#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/constants.h"

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;
    uses interface Timer<TMilli> as sendTimer;
    uses interface SimpleSend;
    uses interface Packet;
    uses interface Hashmap<uint16_t> as SeqNoMap;
    uses interface Hashmap<neighbor_t> as NeighborMap;
}

implementation {
    pack NEIGHBOR_DISCOVERY_PACKET;
    pack NEIGHBOR_REPLY_PACKET;
    int SEQUENCE_NUMBER = 0;

    // Define a struct to store neighbor information
    typedef struct neighbor {
        uint16_t id;
        uint16_t lastHeard;
        uint16_t timeDown;

    } neighbor_t;

    command void NeighborDiscovery.start() {
        call sendTimer.startPeriodic(TICKS * 30);
    }

    event void sendTimer.fired() {
        uint8_t* PAYLOAD = "";
        uint8_t TTL = 1;
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERY SENT \n");
        makePack(&NEIGHBOR_DISCOVERY_PACKET, TOS_NODE_ID, AM_BROADCAST_ADDR, TTL, PROTOCOL_NEIGHBOR, SEQUENCE_NUMBER, PAYLOAD, 0);
        call SimpleSend.send(NEIGHBOR_DISCOVERY_PACKET, AM_BROADCAST_ADDR);
        SEQUENCE_NUMBER++;
    }

    command void NeighborDiscovery.reply(pack* NEIGHBOR_DISCOVERY_PACKET) {
        uint8_t* PAYLOAD = "";
        uint8_t TTL = 1;

        // Check if we've seen this sequence number before
        if (!call SeqNoMap.contains(NEIGHBOR_DISCOVERY_PACKET->src)) {
            call SeqNoMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
            
            makePack(&NEIGHBOR_REPLY_PACKET, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, TTL, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, PAYLOAD, 0);
            call SimpleSend.send(NEIGHBOR_REPLY_PACKET, NEIGHBOR_DISCOVERY_PACKET->src);
            dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT \n");
        } else {
            uint16_t lastSeq = call SeqNoMap.get(NEIGHBOR_DISCOVERY_PACKET->src);
            if (NEIGHBOR_DISCOVERY_PACKET->seq > lastSeq) {
                call SeqNoMap.insert(NEIGHBOR_DISCOVERY_PACKET->src, NEIGHBOR_DISCOVERY_PACKET->seq);
                
                makePack(&NEIGHBOR_REPLY_PACKET, TOS_NODE_ID, NEIGHBOR_DISCOVERY_PACKET->src, TTL, PROTOCOL_NEIGHBOR_REPLY, NEIGHBOR_DISCOVERY_PACKET->seq, PAYLOAD, 0);
                call SimpleSend.send(NEIGHBOR_REPLY_PACKET, NEIGHBOR_DISCOVERY_PACKET->src);
                dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY SENT \n");
            }
        }
    }

    command void NeighborDiscovery.readDiscovery(pack* NEIGHBOR_REPLY_PACKET) {
        uint16_t NEIGHBOR_ID = NEIGHBOR_REPLY_PACKET->src;
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR REPLY RECEIVED \n");

        // Update or insert neighbor information
        neighbor_t neighbor;
        neighbor.id = NEIGHBOR_ID;
        neighbor.lastHeard = NEIGHBOR_REPLY_PACKET->seq;

        call NeighborMap.insert(NEIGHBOR_ID, neighbor);
    }

    // Additional helper functions

    command bool NeighborDiscovery.isNeighbor(uint16_t nodeId) {
        return call NeighborMap.contains(nodeId);
    }

    command uint16_t NeighborDiscovery.getLastHeard(uint16_t nodeId) {
        if (call NeighborMap.contains(nodeId)) {
            neighbor_t neighbor = call NeighborMap.get(nodeId);
            return neighbor.lastHeard;
        }
        return 0;
    }
}