import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

// Representa un kit en la red local.
class DiscoveredDevice {
  final String name;
  final String ip;
  final int? port;

  const DiscoveredDevice({required this.name, required this.ip, this.port});
}

// Servicio encargado del encontrar kits en la red Wi-Fi local mediante el protocolo estándar mDNS (Multicast DNS / Zeroconf).
class NetworkDiscoveryService {
  static const String _serviceType = '_aquasteward._tcp.local';
  static const String _defaultHost = 'aquasteward-kit.local';

  // Escanea la red local en busca de kits anunciados vía mDNS.
  static Future<List<DiscoveredDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final List<DiscoveredDevice> devices = [];
    final MDnsClient client = MDnsClient();

    try {
      await client.start();

      // Consulta PTR  para el tipo de servicio _aquasteward._tcp.local
      final ptrStream = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType),
      );

      final ptrFuture = () async {
        await for (final PtrResourceRecord ptr in ptrStream) {
          final srvStream = client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          );

          await for (final SrvResourceRecord srv in srvStream) {
            final ipStream = client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            );

            await for (final IPAddressResourceRecord ip in ipStream) {
              final cleanIp = ip.address.address;
              if (!devices.any((d) => d.ip == cleanIp)) {
                devices.add(
                  DiscoveredDevice(
                    name: 'AquaSteward Kit',
                    ip: cleanIp,
                    port: srv.port,
                  ),
                );
              }
            }
          }
        }
      }();

      // 2. Consulta A directa al hostname estándar aquasteward-kit.local
      final hostFuture = () async {
        final hostStream = client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(_defaultHost),
        );

        await for (final IPAddressResourceRecord ip in hostStream) {
          final cleanIp = ip.address.address;
          if (!devices.any((d) => d.ip == cleanIp)) {
            devices.add(
              DiscoveredDevice(name: 'AquaSteward Kit', ip: cleanIp, port: 80),
            );
          }
        }
      }();

      // Esperar los descubrimientos o agotar el tiempo límite
      await Future.any([
        Future.wait([ptrFuture, hostFuture]),
        Future.delayed(timeout),
      ]);
    } catch (_) {
      // Retorna los dispositivos encontrados hasta el momento
    } finally {
      client.stop();
    }

    return devices;
  }
}
