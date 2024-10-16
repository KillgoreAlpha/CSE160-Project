#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module FloodingP {
    provides interface Flooding;
    uses interface Packet;
    uses interface SimpleSend;
    uses interface Hashmap<uint16_t> as SeenPackets;
}

implementation {
    uint16_t sequence_number = 0;

    command void Flooding.ping(uint16_t destination, uint8_t *payload) {
        dbg(FLOODING_CHANNEL, "PING EVENT \n");
        dbg(FLOODING_CHANNEL, "SENDER %d\n", TOS_NODE_ID);
        dbg(FLOODING_CHANNEL, "DEST %d\n", destination);
        makePack(&sendPackage, TOS_NODE_ID, destination, 22, PROTOCOL_PING, sequenceNum, payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        sequenceNum++;
    }

    command void Flooding.newFlood(uint16_t TARGET, uint8_t *payload) {
        pack packet;
        uint8_t TTL = MAX_TTL;

        dbg(FLOODING_CHANNEL, "Initiating new flood to node %d from %d \n", TARGET, TOS_NODE_ID);

        makePack(&packet, TOS_NODE_ID, TARGET, TTL, PROTOCOL_FLOOD, sequence_number++, payload, PACKET_MAX_PAYLOAD_SIZE);
        
        call Flooding.forwardFlood(&packet);
    }

    command void Flooding.forwardFlood(pack* packet) {
        uint32_t packet_key = (uint32_t)packet->src << 16 | packet->seq;

        if (packet->TTL == 0) {
            dbg(FLOODING_CHANNEL, "Dropping packet, TTL expired\n");
            return;
        }

        if (call SeenPackets.contains(packet_key)) {
            dbg(FLOODING_CHANNEL, "Dropping duplicate flood packet at node %d \n", TOS_NODE_ID);
            return;
        }

        call SeenPackets.insert(packet_key, 1);

        if (packet->dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "Flood packet received from node %d at destination node %d\n", packet->src, TOS_NODE_ID);
            // Process the packet here
        } else {
            packet->TTL--;
            dbg(FLOODING_CHANNEL, "Forwarding flood packet from %d to %d, TTL %d\n", TOS_NODE_ID, packet->dest, packet->TTL);
            call SimpleSend.send(*packet, AM_BROADCAST_ADDR);
        }
    }

    command void Flooding.floodLSP(pack* myMsg) {
        myMsg->seq = sequenceNum++;
        call SimpleSend.send(sendPackage, AM_BROADCAST_ADDR);
    }
}