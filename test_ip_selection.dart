#!/usr/bin/env dart
//
// 测试IP地址选择逻辑
// 验证智能地址选择算法是否按预期工作
//
// 使用方法: dart test_ip_selection.dart
//

import 'dart:io';

/// 模拟的IP地址选择逻辑（与WebSocketCardController中的逻辑相同）
String selectBestAvailableAddress(List<String> addresses) {
  if (addresses.isEmpty) {
    return '127.0.0.1'; // 最后的fallback
  }

  // 优先选择局域网地址
  for (final ip in addresses) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
      return ip;
    }
  }

  // 其次选择其他非回环地址
  for (final ip in addresses) {
    if (ip != '127.0.0.1') {
      return ip;
    }
  }

  // 最后选择回环地址
  return addresses.first;
}

/// 获取本地IP地址列表（与WebSocketCardController中的逻辑相同）
Future<List<String>> getAvailableIpAddresses() async {
  final List<String> ipList = <String>[]; // 不包含默认的0.0.0.0

  try {
    // 获取网络接口列表
    List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: true, // 是否包含回环接口
      includeLinkLocal: true, // 是否包含链路本地接口（例如IPv6的自动配置地址）。
      type: InternetAddressType.any,
    );

    // 筛选IPv4地址，并按优先级排序
    final List<String> localAreaNetworkIps = <String>[];
    final List<String> otherIps = <String>[];
    final List<String> loopbackIps = <String>[];

    for (NetworkInterface interface in interfaces) {
      for (InternetAddress address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          final ip = address.address;
          if (ip == '127.0.0.1') {
            // 回环地址优先级最低
            if (!loopbackIps.contains(ip)) {
              loopbackIps.add(ip);
            }
          } else if (ip.startsWith('192.168.') || 
                     ip.startsWith('10.') || 
                     ip.startsWith('172.')) {
            // 局域网地址优先级较高
            if (!localAreaNetworkIps.contains(ip)) {
              localAreaNetworkIps.add(ip);
            }
          } else {
            // 其他地址（可能是公网地址）
            if (!otherIps.contains(ip)) {
              otherIps.add(ip);
            }
          }
        }
      }
    }

    // 按优先级顺序添加：局域网地址 > 其他地址 > 回环地址
    ipList.addAll(localAreaNetworkIps);
    ipList.addAll(otherIps);
    ipList.addAll(loopbackIps);

    return ipList;
  } catch (e) {
    print('获取IP地址失败: $e');
    return ['127.0.0.1']; // fallback
  }
}

void main() async {
  print('🔍 测试WebSocket IP地址选择逻辑');
  print('=' * 50);
  
  // 获取实际的IP地址列表
  print('📡 正在获取本地IP地址...');
  final availableIps = await getAvailableIpAddresses();
  
  print('✅ 发现 ${availableIps.length} 个IPv4地址:');
  for (int i = 0; i < availableIps.length; i++) {
    final ip = availableIps[i];
    String type = '';
    if (ip == '127.0.0.1') {
      type = '(本地回环)';
    } else if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
      type = '(局域网)';
    } else {
      type = '(公网)';
    }
    print('  ${i + 1}. $ip $type');
  }
  
  print('');
  
  // 测试最佳地址选择
  print('🎯 测试最佳地址选择算法:');
  final bestAddress = selectBestAvailableAddress(availableIps);
  print('   推荐地址: $bestAddress');
  
  // 测试各种场景
  print('');
  print('🧪 测试各种场景:');
  
  // 场景1：只有回环地址
  final loopbackOnly = ['127.0.0.1'];
  print('   仅回环地址: ${selectBestAvailableAddress(loopbackOnly)}');
  
  // 场景2：包含局域网地址
  final withLAN = ['127.0.0.1', '192.168.1.100'];
  print('   包含局域网: ${selectBestAvailableAddress(withLAN)}');
  
  // 场景3：包含公网地址
  final withPublic = ['127.0.0.1', '8.8.8.8'];
  print('   包含公网: ${selectBestAvailableAddress(withPublic)}');
  
  // 场景4：空列表
  final empty = <String>[];
  print('   空列表: ${selectBestAvailableAddress(empty)}');
  
  // 场景5：复杂混合
  final mixed = ['127.0.0.1', '192.168.1.100', '10.0.0.50', '8.8.8.8'];
  print('   复杂混合: ${selectBestAvailableAddress(mixed)}');
  
  print('');
  print('✅ 测试完成！');
  
  // 验证不包含0.0.0.0
  if (availableIps.contains('0.0.0.0')) {
    print('❌ 错误：IP列表中不应包含 0.0.0.0');
  } else {
    print('✅ 正确：IP列表中不包含 0.0.0.0');
  }
}