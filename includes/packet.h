//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H

#include "protocol.h"
#include "channels.h"
#include "constants.h"

enum{
    // ints represent number of bytes
    // FRAME_HEADER_LENGTH = 8,
    // FRAME_MAX_PAYLOAD_SIZE = MTU - FRAME_HEADER_LENGTH,
    // PACKET_HEADER_LENGTH = 22,
    // PACKET_MAX_PAYLOAD_SIZE = FRAME_MAX_PAYLOAD_SIZE - PACKET_HEADER_LENGTH

	PACKET_HEADER_LENGTH = 8,
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
};

typedef nx_struct pack{
    nx_uint16_t dest;
    nx_uint16_t src;
    nx_uint16_t seq;        //Sequence Number
    nx_uint8_t TTL;         //Time to Live
    nx_uint8_t protocol;
    nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;

typedef nx_struct frame{
    nx_uint16_t dest;
    nx_uint16_t src;
    nx_uint16_t seq;
    nx_uint8_t TTL;
    nx_uint8_t protocol;
    nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}frame;

typedef nx_struct IPpacket{
    nx_uint8_t version;
    nx_uint8_t header_length;
    nx_uint8_t service;
    nx_uint16_t total_length;
    nx_uint16_t id;
    nx_uint8_t flags;
    nx_uint16_t offset;
    nx_uint8_t TTL;
    nx_uint8_t protocol;
    nx_uint16_t checksum;
    nx_uint32_t src;
    nx_uint32_t dest;
    nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}IPpacket;

typedef nx_struct TCPpacket{
    nx_uint16_t src;
    nx_uint16_t dest;
    nx_uint32_t seq;
    nx_uint32_t ack;
    nx_uint8_t offset;
    nx_uint16_t flags;
    nx_uint16_t window;
    nx_uint16_t checksum;
    nx_uint16_t urgentptr;
    nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}TCPpacket;

typedef nx_struct LinkState {
    nx_uint16_t node;
    nx_uint16_t neighbors[MAX_NEIGHBORS];
    nx_uint8_t neighborCount;
} LinkState;

/*
 * logPack
 *     Sends packet information to the general channel.
 * @param:
 *     pack *input = pack to be printed.
 */
void logPack(pack *input){
    dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
    input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
};

enum{
    AM_PACK=6
};

void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, void* payload, uint8_t length){
    Package->src = src;
    Package->dest = dest;
    Package->TTL = TTL;
    Package->protocol = protocol;
    Package->seq = seq;
    memcpy(Package->payload, payload, length);
}

void makeLinkPack(frame *Frame, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
    Frame->src = src;
    Frame->dest = dest;
    Frame->TTL = TTL;
    Frame->protocol = protocol;
    Frame->seq = seq;
    memcpy(Frame->payload, payload, length);
}

void makeIPPack(IPpacket *Packet, uint8_t version, uint8_t header_length, uint8_t service, uint16_t total_length, uint16_t id, uint8_t flags, uint16_t offset, uint8_t TTL, uint8_t protocol, uint16_t checksum, uint32_t src, uint32_t dest, uint8_t* payload){
    Packet->version = version;
    Packet->header_length = header_length;
    Packet->service = service;
    Packet->total_length = total_length;
    Packet->id = id;
    Packet->flags = flags;
    Packet->offset = offset;
    Packet->TTL = TTL;
    Packet->protocol = protocol;
    Packet->checksum = checksum;
    Packet->src = src;
    Packet->dest = dest;
    memcpy(Packet->payload, payload, total_length);
}

void makeTCPPack(TCPpacket *Packet, uint16_t src, uint16_t dest, uint32_t seq, uint32_t ack, uint8_t offset, uint16_t flags, uint16_t window, uint16_t checksum, uint16_t urgentptr, uint8_t* payload, uint8_t length){
    Packet->src = src;
    Packet->dest = dest;
    Packet->seq = seq;
    Packet->ack = ack;
    Packet->offset = offset;
    Packet->flags = flags;
    Packet->window = window;
    Packet->checksum = checksum;
    Packet->urgentptr = urgentptr;
    memcpy(Packet->payload, payload, length);
}

// Added for Project 2: Function to create a LinkState packet
void makeLinkStatePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, LinkState *linkState) {
    Package->src = src;
    Package->dest = dest;
    Package->TTL = TTL;
    Package->protocol = PROTOCOL_LINKSTATE;
    Package->seq = 0;  // You might want to use a sequence number for link state updates
    memcpy(Package->payload, linkState, sizeof(LinkState));
}

#endif