// 见《胰岛素泵的蓝牙通信协议_loop》: 数据加密
// https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework#convertkey-1
// https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework#datablob
export const CRYPTO_KEY = new Uint8Array([
  'A'.charCodeAt(0), 'a'.charCodeAt(0), 'r'.charCodeAt(0), 'u'.charCodeAt(0),
  'y'.charCodeAt(0), 'y'.charCodeAt(0), 'i'.charCodeAt(0),
  'l'.charCodeAt(0), 'i'.charCodeAt(0), 'a'.charCodeAt(0),
  'o'.charCodeAt(0), '1'.charCodeAt(0), '2'.charCodeAt(0),
  '3'.charCodeAt(0), '4'.charCodeAt(0), '5'.charCodeAt(0)
]);

// encrypted_len 长度为 2 Byte 且必须是 16 的倍数，所以最大值为 0xFFF0 即 65520，所以密文最长为 65520 字节 (约64KB)
// 分组加密，每组128位(16字节)，末尾补足1组，所以加密后的密文字节数一定是 16 的倍数
// https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework#cryptoframeworkcreatecipher
export const CRYPTO_ALGORITHM = 'AES128|ECB|PKCS5';
// 密文头部首个数据
export const CRYPTO_HEADER = 0x55;
