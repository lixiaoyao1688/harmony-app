import { encrypt } from "./crypto.util";
import { printUint8Array2 } from "../../log/util/log.util";
import { packEncryptedData, packParamData } from "./pack.util";

/**
 * 获取能写给泵的命令
 *
 * 参考
 * 协议搜索: encrypted_data解密后的命令格式 && 数据加密
 *
 * @param paramData 参数的数据
 * @param paramId 参数的id
 * @param serial 序号。该值需要比前一次的命令加一；只针对 app 向泵发送时判断数据的有效性，泵发送时该字段无效。
 * @param structName 参数结构的名称，如: 's_report_newest_history'
 * @returns 完成的命令（密文）
 */
export async function getCommandToWriteToPump(paramData: Uint8Array, paramId: number, serial: number, structName: string): Promise<ArrayBuffer> {
  printUint8Array2(`${structName} param_data:`, paramData);
  return packEncryptedData(await encrypt(packParamData(paramData, paramId, serial)));
}
