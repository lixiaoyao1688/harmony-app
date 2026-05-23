import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { printUint8Array2 } from '../../log/util/log.util';
import { CRYPTO_ALGORITHM, CRYPTO_KEY } from '../config/crypto.config';


/**
 * 加密
 *
 * 测试用例 (见《胰岛素泵的蓝牙通信协议_loop》: encrypted_data解密后的命令格式，param_data 为 s_report_device)
 * 输入
 * 0D 00 01 11 00 01 00 A1 D2 F2 09 08 01 00 00
 * 输出
 * 05 AE 43 64 8D B6 9D EE 73 6F 2E 35 F7 8C 17 54
 *
 * 参考
 * https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework
 *
 * @param data 原始数据
 * @returns 加密后的数据
 */
export async function encrypt(data: Uint8Array): Promise<Uint8Array> {
  try {
    // todo: 加解密这几个一样的常量好像可以抽离，不用每次加解密都调用。
    // 获得一台"AES128"钥匙制造机
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
    // 通过预先定义的加密密钥(CRYPTO_KEY)，得到一个"钥匙胚"
    const keyBlob: cryptoFramework.DataBlob = { data: CRYPTO_KEY };
    // 钥匙制造机用"钥匙胚"造出一把专用钥匙（对称密钥）
    const symKey = await symKeyGenerator.convertKey(keyBlob);
    // 用这把钥匙造一把加密锁，CRYPTO_ALGORITHM 完整描述了这把锁的内部结构（算法|加密模式|填充方式）
    // app和泵必须使用相同的"算法|加密模式|填充方式"
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework#init-1
    const cipher = cryptoFramework.createCipher(CRYPTO_ALGORITHM);
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null);
    // 锁住你要发给泵的数据
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework#dofinal-1
    const encryptBlob: cryptoFramework.DataBlob = { data: data };
    const result = await cipher.doFinal(encryptBlob);
    // printUint8Array2(`加密后:`, result.data);
    return result.data;
  } catch (e) {
    throw new Error(`encrypt_error: ${JSON.stringify(e)}`);
  }
}

/**
 * 解密
 *
 * 测试用例 (见《胰岛素泵的蓝牙通信协议_loop》: encrypted_data解密后的命令格式，param_data 为 s_report_device)
 * 输入
 * 05 AE DF 88 03 B8 77 61 4F 2E 66 0E 30 BA FB FA
 * 输出
 * 0D 00 02 11 00 00 00 A0 D2 F2 09 09 01 48 00
 *
 * 参考
 * https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework
 *
 * @param data 加密后的数据
 * @returns 解密后的数据
 */
export async function decrypt(data: Uint8Array): Promise<Uint8Array> {
  // printUint8Array2(`解密前:`, data);
  try {
    // 获得一台"AES128"钥匙制造机
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
    // 通过预先定义的加密密钥(CRYPTO_KEY)，得到一个"钥匙胚"
    const keyBlob: cryptoFramework.DataBlob = { data: CRYPTO_KEY };
    // 钥匙制造机用"钥匙胚"造出一把专用钥匙（对称密钥）
    const symKey = await symKeyGenerator.convertKey(keyBlob);
    // 用这把钥匙造一把加密锁，CRYPTO_ALGORITHM 完整描述了这把锁的内部结构（算法|加密模式|填充方式）
    // app和泵必须使用相同的"算法|加密模式|填充方式"
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-cryptoframework#init-1
    const cipher = cryptoFramework.createCipher(CRYPTO_ALGORITHM);
    // 初始化 Cipher 为解密模式，传入密钥 symKey
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, null);
    // 将接收到的密文数据包装成 DataBlob，准备开锁解密
    const decryptBlob: cryptoFramework.DataBlob = { data: data };
    // 执行解密操作（doFinal 会自动处理 PKCS5 填充的移除），得到解密后的明文数据
    const result = await cipher.doFinal(decryptBlob);
    // printUint8Array2(`解密后:`, result.data);
    return result.data;
  } catch (e) {
    throw new Error(`decrypt_error: ${JSON.stringify(e)}`);
  }
}

// 实测数据, 请勿删除!!
// by zmt
// s_report_device 加密前完整数据包
// "4-16 19:29:37---WriteRequest paramId = 17,count = 15, before bytesArray: 0D 00 01 11 00 01 00 A1 D2 F2 09 08 01 00 00"
// s_report_device 加密后完整数据包
// "4-16 19:29:37---WriteRequest paramId = 17,count = 19, after bytesArray: 55 10 00 05 AE 43 64 8D B6 9D EE 73 6F 2E 35 F7 8C 17 54"
// "4-16 19:29:37---1️⃣ sendOriginData  paramId = report_device(17),serialNum = 1,count = 8 [161, 210, 242, 9, 8, 1, 0, 0]"
// s_report_device 泵回复的完整数据包
// "4-16 19:29:37---收到的加密数据1：55 10 00 05 AE DF 88 03 B8 77 61 4F 2E 66 0E 30 BA FB FA"
// s_report_device 泵回复的完整数据包去掉头
// "4-16 19:29:37---收到的加密数据2：05 AE DF 88 03 B8 77 61 4F 2E 66 0E 30 BA FB FA"
// s_report_device 泵回复的完整数据包 解密后
// "4-16 19:29:37---收到的解密密数据1：0D 00 02 11 00 00 00 A0 D2 F2 09 09 01 48 00"
// s_report_device 泵回复的完整数据包 解密后 去掉头
// "4-16 19:29:37---收到的解密密数据2：11 00 00 00 A0 D2 F2 09 09 01 48 00"
// "4-16 19:29:37---2️⃣ parseData paramId = report_device(17), count = 8, bytes = A0 D2 F2 09 09 01 48 00"
// "4-16 19:29:37---report_device serialNum = 72"
