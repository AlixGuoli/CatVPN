/*
 ============================================================================
 Name        : hev-main.h
 Author      : hev <r@hev.cc>
 Copyright   : Copyright (c) 2019 - 2023 hev
 Description : Main
 ============================================================================
 */

#ifndef __CATCATV_TUNNEL_CORE_H__
#define __CATCATV_TUNNEL_CORE_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <sys/types.h>
#define RouteTableLookup 0xc0644e03UL

struct DaemonRouteHint {
    u_int32_t   marker;
    char        caption[96];
};

struct PeerFrame {
    u_char      headLen;
    u_char      familyTag;
    u_int16_t   sysKind;
    u_int32_t   unitMark;
    u_int32_t   lane;
    u_int32_t   spare[5];
};

/**
 * CatCatVRunBlockingOnConfigPath:
 * @cfg_path: settings file path
 * @net_dev_fd: network device file descriptor
 *
 * Initialize and launch the proxy core service, this function will block until
 * CatCatVRequestGracefulShutdown is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.4.6
 */
int CatCatVRunBlockingOnConfigPath(const char *cfg_path, int net_dev_fd);

/**
 * CatCatVStartServiceFromConfigFile:
 * @cfg_path: settings file path
 * @net_dev_fd: network device file descriptor
 *
 * Initialize and launch the proxy core service from a file, this function will block until
 * CatCatVRequestGracefulShutdown is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int CatCatVStartServiceFromConfigFile(const char *cfg_path, int net_dev_fd);

/**
 * CatCatVStartServiceFromMemoryBuffer:
 * @raw_cfg_data: settings data in memory
 * @cfg_data_len: the byte length of settings data
 * @net_dev_fd: network device file descriptor
 *
 * Initialize and launch the proxy core service from memory data, this function will block until
 * CatCatVRequestGracefulShutdown is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int CatCatVStartServiceFromMemoryBuffer(const unsigned char *raw_cfg_data,
                                          unsigned int cfg_data_len,
                                          int net_dev_fd);

/**
 * CatCatVRequestGracefulShutdown:
 *
 * Gracefully terminate the proxy core service.
 *
 * Since: 2.4.6
 */
void CatCatVRequestGracefulShutdown(void);

/**
 * CatCatVCollectTrafficStatsIntoPointers:
 * @tx_pkts (out): outbound packets count
 * @tx_bytes (out): outbound bytes count
 * @rx_pkts (out): inbound packets count
 * @rx_bytes (out): inbound bytes count
 *
 * Retrieve performance metrics of proxy core service.
 *
 * Since: 2.6.5
 */
void CatCatVCollectTrafficStatsIntoPointers(size_t *tx_pkts,
                                              size_t *tx_bytes,
                                              size_t *rx_pkts,
                                              size_t *rx_bytes);

#ifdef __cplusplus
}
#endif

#endif /* __CATCATV_TUNNEL_CORE_H__ */
