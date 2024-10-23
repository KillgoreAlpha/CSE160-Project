#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/constants.h"


module FloodingP {
    provides interface Flooding;
    uses interface Packet;
    uses interface SimpleSend;
    uses interface Hashmap<uint16_t> as SeenPackets;
}

implementation {
    uint16_t sequence_number = 0;

    command void Flooding.ping(uint16_t TARGET, uint8_t *payload) {
        pack packet;
        dbg(FLOODING_CHANNEL, "PING EVENT \n");
        dbg(FLOODING_CHANNEL, "SENDER %d\n", TOS_NODE_ID);
        dbg(FLOODING_CHANNEL, "DEST %d\n", TARGET);
        makePack(&packet, TOS_NODE_ID, TARGET, MAX_TTL, PROTOCOL_PING, sequence_number, payload, PACKET_MAX_PAYLOAD_SIZE);
        call SimpleSend.send(packet, AM_BROADCAST_ADDR);
        sequence_number++;
    }

    command void Flooding.floodLinkState(uint8_t *payload) {
        pack packet;
        uint32_t packet_key;
        
        makePack(&packet, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_LINKSTATE, 
                sequence_number, payload, PACKET_MAX_PAYLOAD_SIZE);
        
        // Create packet key
        packet_key = (uint32_t)packet.src << 16 | packet.seq;
        
        // Only proceed if we haven't seen this packet
        if (!call SeenPackets.contains(packet_key)) {
            call SeenPackets.insert(packet_key, 1);
            call SimpleSend.send(packet, AM_BROADCAST_ADDR);
            dbg(ROUTING_CHANNEL, "Node %d: Sending link state packet seq %d\n", 
                TOS_NODE_ID, sequence_number);
            sequence_number++;
        }
    }

    command void Flooding.newFlood(uint16_t TARGET, uint8_t *payload) {
        pack packet;
        uint32_t packet_key;

        dbg(FLOODING_CHANNEL, "Initiating new flood to node %d from %d \n", TARGET, TOS_NODE_ID);

        makePack(&packet, TOS_NODE_ID, TARGET, MAX_TTL, PROTOCOL_FLOOD, sequence_number, payload, PACKET_MAX_PAYLOAD_SIZE);
        
        packet_key = (uint32_t)packet.src << 16 | packet.seq;
        call SeenPackets.insert(packet_key, 1);
        
        call Flooding.forwardFlood(&packet);
        sequence_number++;
    }

   command void Flooding.forwardFlood(pack* packet) {
        uint32_t packet_key = (uint32_t)packet->src << 16 | packet->seq;

        if (packet->TTL == 0) {
            dbg(FLOODING_CHANNEL, "Dropping packet, TTL expired\n");
            return;
        }

        if (call SeenPackets.contains(packet_key)) {
            if (packet->protocol == PROTOCOL_LINKSTATE) {
                dbg(ROUTING_CHANNEL, "Node %d: Dropping duplicate link state from %d seq %d\n", 
                    TOS_NODE_ID, packet->src, packet->seq);
            } else {
                dbg(FLOODING_CHANNEL, "Dropping duplicate flood packet at node %d \n", TOS_NODE_ID);
            }
            return;
        }

        call SeenPackets.insert(packet_key, 1);

        if (packet->dest == TOS_NODE_ID && packet->protocol != PROTOCOL_LINKSTATE) {
            dbg(FLOODING_CHANNEL, "Flood packet received from node %d at destination node %d\n", 
                packet->src, TOS_NODE_ID);
        } else {
            packet->TTL--;
            if (packet->protocol == PROTOCOL_LINKSTATE) {
                dbg(ROUTING_CHANNEL, "Node %d: Forwarding link state from %d seq %d\n", 
                    TOS_NODE_ID, packet->src, packet->seq);
            } else {
                dbg(FLOODING_CHANNEL, "Forwarding flood packet from %d to %d, TTL %d\n", 
                    TOS_NODE_ID, packet->dest, packet->TTL);
            }
            call SimpleSend.send(*packet, AM_BROADCAST_ADDR);
        }
    }
}