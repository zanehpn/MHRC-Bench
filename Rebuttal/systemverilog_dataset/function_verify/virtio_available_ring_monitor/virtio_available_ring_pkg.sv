`timescale 1ns/1ps

package virtio_available_ring_pkg;
    typedef struct packed {
        logic event_idx;
    } configuration_t;

    typedef enum logic [1:0] {
        REQUEST_READ_RING,
        REQUEST_READ_IDX,
        REQUEST_READ_USED_EVENT
    } request_type_t;

    typedef struct packed {
        logic [15:0] length;
        logic [15:0] offset;
    } request_t;

    typedef enum logic [1:0] {
        RESPONSE_READ_RING,
        RESPONSE_READ_IDX,
        RESPONSE_READ_USED_EVENT
    } response_type_t;

    typedef struct packed {
        logic [15:0] offset;
    } response_t;
endpackage
