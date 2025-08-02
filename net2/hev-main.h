/*
 ============================================================================
 Name        : hev-main.h
 Author      : hev <r@hev.cc>
 Copyright   : Copyright (c) 2019 - 2023 hev
 Description : Main
 ============================================================================
 */

#ifndef __LUXJAG_NETWORK_BRIDGE_MODULE_H__
#define __LUXJAG_NETWORK_BRIDGE_MODULE_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * LuxJagNetworkBridgeActivate:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the luxjag network bridge service, this function will block until
 * LuxJagNetworkBridgeDeactivate is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.4.6
 */
int LuxJagNetworkBridgeActivate(const char *config_file, int interface_fd);

/**
 * LuxJagNetworkBridgeActivateFromFile:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the luxjag network bridge service from a file, this function will block until
 * LuxJagNetworkBridgeDeactivate is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int LuxJagNetworkBridgeActivateFromFile(const char *config_file, int interface_fd);

/**
 * LuxJagNetworkBridgeActivateFromMemory:
 * @config_memory: settings data in memory
 * @memory_size: the byte length of settings data
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the luxjag network bridge service from memory data, this function will block until
 * LuxJagNetworkBridgeDeactivate is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int LuxJagNetworkBridgeActivateFromMemory(const unsigned char *config_memory,
                                         unsigned int memory_size, int interface_fd);

/**
 * LuxJagNetworkBridgeDeactivate:
 *
 * Gracefully terminate the luxjag network bridge service.
 *
 * Since: 2.4.6
 */
void LuxJagNetworkBridgeDeactivate(void);

/**
 * LuxJagNetworkBridgeExtractMetrics:
 * @egress_packets (out): outbound packets count
 * @egress_bytes (out): outbound bytes count
 * @ingress_packets (out): inbound packets count
 * @ingress_bytes (out): inbound bytes count
 *
 * Retrieve performance metrics of luxjag network bridge service.
 *
 * Since: 2.6.5
 */
void LuxJagNetworkBridgeExtractMetrics(size_t *egress_packets, size_t *egress_bytes,
                                       size_t *ingress_packets, size_t *ingress_bytes);

#ifdef __cplusplus
}
#endif

#endif /* __LUXJAG_NETWORK_BRIDGE_MODULE_H__ */
