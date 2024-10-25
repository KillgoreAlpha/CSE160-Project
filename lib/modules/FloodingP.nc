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
    uses interface LinkStateRouting;
}

implementation {
    uint16_t sequence_number = 0;
    
    void handleLinkStatePacket(pack* packet) {
        uint32_t packet_key = (uint32_t)packet->src << 16 | packet->seq;
        
        if (call SeenPackets.contains(packet_key)) {
            dbg(ROUTING_CHANNEL, "Node %d: Duplicate link state from %d seq %d\n", 
                TOS_NODE_ID, packet->src, packet->seq);
            return;
        }
        
        // Process the link state packet first
        call LinkStateRouting.handleLinkState(packet);
        
        // Then forward it
        call SeenPackets.insert(packet_key, 1);
        packet->TTL--;
        
        if (packet->TTL > 0) {
            dbg(ROUTING_CHANNEL, "Node %d: Forwarding link state from %d seq %d\n", 
                TOS_NODE_ID, packet->src, packet->seq);
            call SimpleSend.send(*packet, AM_BROADCAST_ADDR);
        }
    }

    command void Flooding.floodLinkState(uint8_t *payload) {
        pack packet;
        
        makePack(&packet, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_LINKSTATE, 
                sequence_number, payload, PACKET_MAX_PAYLOAD_SIZE);
        
        // Process our own link state packet first
        call LinkStateRouting.handleLinkState(&packet);
        
        // Then flood it
        call SimpleSend.send(packet, AM_BROADCAST_ADDR);
        
        dbg(ROUTING_CHANNEL, "Node %d: Initiating link state flood seq %d\n", 
            TOS_NODE_ID, sequence_number);
            
        sequence_number++;
    }

    command void Flooding.forwardFlood(pack* packet) {
        uint32_t packet_key = (uint32_t)packet->src << 16 | packet->seq;

        if (packet->TTL == 0) {
            dbg(FLOODING_CHANNEL, "Dropping packet, TTL expired\n");
            return;
        }

        // Handle link state packets differently
        if (packet->protocol == PROTOCOL_LINKSTATE) {
            handleLinkStatePacket(packet);
            return;
        }

        // Regular flood packet handling
        if (call SeenPackets.contains(packet_key)) {
            dbg(FLOODING_CHANNEL, "Dropping duplicate flood packet at node %d\n", TOS_NODE_ID);
            return;
        }

        call SeenPackets.insert(packet_key, 1);

        if (packet->dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "Flood packet received at destination node %d\n", TOS_NODE_ID);
        } else {
            packet->TTL--;
            if (packet->TTL > 0) {
                dbg(FLOODING_CHANNEL, "Forwarding flood packet to %d, TTL %d\n", 
                    packet->dest, packet->TTL);
                call SimpleSend.send(*packet, AM_BROADCAST_ADDR);
            }
        }
    }

    command void Flooding.ping(uint16_t TARGET, uint8_t *payload) {
        pack packet;
        dbg(FLOODING_CHANNEL, "PING EVENT \n");
        dbg(FLOODING_CHANNEL, "SENDER %d\n", TOS_NODE_ID);
        dbg(FLOODING_CHANNEL, "DEST %d\n", TARGET);
        makePack(&packet, TOS_NODE_ID, TARGET, MAX_TTL, PROTOCOL_PING, sequence_number, payload, PACKET_MAX_PAYLOAD_SIZE);
        call SimpleSend.send(packet, AM_BROADCAST_ADDR);
        sequence_number++;
    }

    command void Flooding.newFlood(uint16_t TARGET, uint8_t *payload) {
        pack packet;
        uint32_t packet_key;

        dbg(FLOODING_CHANNEL, "Initiating new flood to node %d from %d\n", TARGET, TOS_NODE_ID);

        makePack(&packet, TOS_NODE_ID, TARGET, MAX_TTL, PROTOCOL_FLOOD, sequence_number, payload, PACKET_MAX_PAYLOAD_SIZE);
        
        packet_key = (uint32_t)packet.src << 16 | packet.seq;
        call SeenPackets.insert(packet_key, 1);
        
        call Flooding.forwardFlood(&packet);
        sequence_number++;
    }
}