/**
 * 将2个独立的字节，按照"小端序"拼接成一个16位无符号整数。
 *
 * 小端序
 * byte1,byte0 (位数由高到低)
 *
 * @param byte0 第一个字节
 * @param byte1 第二个字节
 * @returns 拼接完成的整数
 */
export function getUint16(byte0: number, byte1: number): number {
  // 1. 把 byte1 的二进制位向左移动 8 位，相当于让这个字节变成"高8位"，右边空出的8位自动补0。
  // 2. 把 byte0 原封不动地放在"低8位"，然后与刚才移好的"高8位"进行按位或（合并），最终得到一个完整的"16位数值"。
  // byte0 和 byte1 只是在 CPU 的临时寄存器中做计算，不会对它们的来源做任何修改，且性能很好。
  return byte0 | (byte1 << 8);
}


/**
 * 将4个独立的字节，按照"小端序"拼接成一个32位无符号整数。
 *
 * 小端序
 * byte3,byte2,byte1,byte0 (位数由高到低)
 *
 * @param byte0 第一个字节
 * @param byte1 第二个字节
 * @param byte2 第三个字节
 * @param byte3 第四个字节
 * @returns 拼接完成的整数
 */
export function getUint32(byte0: number, byte1: number, byte2: number, byte3: number): number {
  // 最终数值有32位，填充的值如下:
  // byte0 没有移位，所以 byte0 在最终数值的 Bit 0-7 位上。
  // byte1 << 8 将 byte1 向左移动了 8 位，相当于把它放在了最终数值的 Bit 8-15 位上。
  // byte2 << 16 将 byte2 向左移动了 16 位，放在了 Bit 16-23 位上。
  // byte3 << 24 将 byte3 移动了 24 位，放在了 Bit 24-31 位上。
  return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24);
}
