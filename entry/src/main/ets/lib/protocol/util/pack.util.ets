import { getUint16 } from "../../byte/util/byte.util";
import { CRYPTO_HEADER } from "../config/crypto.config";
import { printUint8Array2 } from "../../log/util/log.util";


/**
 * 打包 encrypted_data
 *
 * 参考
 * 胰岛素泵的蓝牙通信协议_loop: 数据加密
 *
 * @param data 原始密文 encrypted_data
 * @returns 打包完成的完整密文
 */
export function packEncryptedData(data: Uint8Array): ArrayBuffer {
  // encrypted_data 的长度 (2 Byte)
  const encryptedLen = data.length;
  // 头部字节数: 1 + 2 = 3 (Byte)
  const headerLength = 3;

  // 申请一个底层二进制数据缓冲区
  const buffer = new ArrayBuffer(headerLength + encryptedLen);
  const view = new DataView(buffer);

  // 写入头部数据
  view.setUint8(0, CRYPTO_HEADER);  // 1 Byte
  view.setUint16(1, encryptedLen, true);

  // 使用该 ArrayBuffer 创建一个"8位无符号整型"的类数组视图。
  const completedData = new Uint8Array(buffer);
  // 复制原始数据到头部字节之后
  // https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/TypedArray/set
  completedData.set(data, headerLength);

  printUint8Array2('加入密文头(3 字节):', completedData);

  return buffer;
}


/**
 * 解包得到 encrypted_data
 *
 * 参考
 * 胰岛素泵的蓝牙通信协议_loop: 数据加密
 *
 * @param data 泵发送的完整密文
 * @returns encrypted_data
 */
export function unpackToGetEncryptedData(data: Uint8Array): Uint8Array | null {
  if (data.length < 3) {
    console.error('getEncryptedData_error', '数据长度不足3字节，无法解析长度字段');
    printUint8Array2(`getEncryptedData_error_data:`, data);
    return null;
  }

  const encryptedLen = getUint16(data[1], data[2]);
  if (encryptedLen % 16 !== 0) {
    console.error('getEncryptedData_error', `encrypted_len(${encryptedLen})不是16的倍数`);
    return null;
  }

  const encryptedDataOffset = 3;
  const remainLen = data.length - encryptedDataOffset;
  // 检查是否有足够的数据
  if (encryptedLen > remainLen) {
    console.error('getEncryptedData_error', `encrypted_len 的值(${encryptedLen}) 大于 encrypted_data 部分的长度(${remainLen})`);
    printUint8Array2(`getEncryptedData_error_data:`, data);
    return null;
  }

  // 基于 data 底层共享的 ArrayBuffer，从某个偏移量开始截取一段数据，并以新的 Uint8Array 形式返回。
  // 它不会复制数据，而是创建一个新的“视图”。
  // 优点: 从完整数据包中切出有效载荷后，继续用 Uint8Array 的方式读，不会产生额外的内存开销。
  return new Uint8Array(data.buffer, encryptedDataOffset, encryptedLen);
}


/**
 * 打包 param_data
 *
 * 参考
 * 胰岛素泵的蓝牙通信协议_loop: encrypted_data解密后的命令格式
 *
 * @param paramData 参数的数据，例如 A1 D2 F2 09 08 01 00 00
 * @param paramId 参数id (2 Byte) 见协议中的: 胰岛素泵（AA_XXXXXX）参数表
 * @param serial 序列号 (2 Byte), 该值需要比前一次的命令加一 (针对 Central 向 Peripheral 发送时判断数据的有效性)
 *
 * @returns 组装完成的数据
 */
export function packParamData(paramData: Uint8Array, paramId: number, serial: number): Uint8Array {
  const dataLen = paramData.length;

  const cmdOp = 1;  // 1 Byte: 0000_0001  (bit7:0, bit6:0, bit1:0, bit0:1)
  const cmdLen = 5 + dataLen;  // 命令的长度, 不包括自身: 1+2+2+原始数据长度

  // 头部长度 (Byte)
  const headerLength = 7;

  // 申请一个底层二进制数据缓冲区
  const buffer = new ArrayBuffer(headerLength + dataLen);
  const view = new DataView(buffer);

  // 写入头部字段
  view.setUint16(0, cmdLen, true);
  view.setUint8(2, cmdOp);
  view.setUint16(3, paramId, true);
  view.setUint16(5, serial, true);

  // 使用该 ArrayBuffer 创建一个"8位无符号整型"的类数组视图。
  const completedData = new Uint8Array(buffer);
  // 复制原始数据到头部字节之后
  // https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/TypedArray/set
  completedData.set(paramData, headerLength);

  console.log('命令(W):');
  console.log(JSON.stringify({
    cmd_len: cmdLen,
    cmd_op_7: 0,
    cmd_op_6: 0,
    cmd_op_1: 0,
    cmd_op_0: 1,
    param_id: paramId,
    serial: serial
  }));
  printUint8Array2('param_data', paramData);
  printUint8Array2('加入头(7 字节):', completedData);

  return completedData;
}

// 注意:
// 解包得到 param_data 的逻辑位于 src\main\ets\lib\protocol\vo\Command.vo.ets: constructor
