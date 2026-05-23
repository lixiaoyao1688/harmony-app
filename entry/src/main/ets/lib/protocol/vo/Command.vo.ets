import { getUint16 } from "../../byte/util/byte.util";
import { printUint8Array2 } from "../../log/util/log.util";


/**
 * 命令 VO
 *
 * 来源
 * 泵
 *
 * 参考
 * 胰岛素泵的蓝牙通信协议_loop: encrypted_data解密后的命令格式
 */
export class CommandVO {

  private readonly _paramId: number | null;
  private readonly _serial: number | null;
  private readonly _paramData: Uint8Array | null;

  // e: encrypted_data 解密后的完整数据
  constructor(e: Uint8Array) {
    this._paramId = null;
    this._serial = null;
    this._paramData = null;

    const HEADER_SIZE = 7;  // 2+1+2+2 (头字节长度累加: cmd_len + cmd_op + param_id + serial)
    if (e.length < HEADER_SIZE) {
      console.error('DecryptedStructVO_error', '数据长度不足7字节，无法解析头部');
      return;
    }

    const cmdLen = getUint16(e[0], e[1]);

    // 假设 cmdOp 的二进制表示为 b7 b6 b5 b4 b3 b2 b1 b0 (最高位b7,最低位b0)
    // 1. cmdOp >> 7: 将 cmdOp 的二进制位向右移动 7 位，原来的 b7 被移动到最低位 (b0 的位置);
    // 2. & 1: 和二进制 00000001 做按位与运算，只保留最低位，其余位清零。
    const cmdOp = e[2];
    const cmdOpBit7 = (cmdOp >> 7) & 1;
    const cmdOpBit6 = (cmdOp >> 6) & 1;
    const cmdOpBit1 = (cmdOp >> 1) & 1;
    const cmdOpBit0 = cmdOp & 1;

    this._paramId = getUint16(e[3], e[4]);
    this._serial = getUint16(e[5], e[6]);

    const paramDataLen = cmdLen - 5;  // 1+2+2 (头字节长度累加: cmd_op + param_id + serial)
    if (paramDataLen < 0) {
      console.error('DecryptedStructVO_error', `cmd_len - 5 = ${paramDataLen}，param_data 长度无效`);
      return;
    }
    const remainLen = e.length - HEADER_SIZE;
    if (paramDataLen > remainLen) {
      console.error('DecryptedStructVO_error', `cmd_len - 5 = ${paramDataLen}，即 param_data 需要 ${paramDataLen} 字节，但剩余只有 ${remainLen} 字节`);
      return;
    }

    this._paramData = new Uint8Array(e.buffer, HEADER_SIZE, paramDataLen);
    this._log(cmdLen, cmdOpBit7, cmdOpBit6, cmdOpBit1, cmdOpBit0);
  }

  public get paramId(): number | null {
    return this._paramId;
  }

  public get paramData(): Uint8Array | null {
    return this._paramData;
  }

  private _log(cmdLen: number, cmdOpBit7: number, cmdOpBit6: number, cmdOpBit1: number, cmdOpBit0: number): void {
    console.log('命令(R):');
    console.log(JSON.stringify({
      cmd_len: cmdLen,
      cmd_op_7: cmdOpBit7,
      cmd_op_6: cmdOpBit6,
      cmd_op_1: cmdOpBit1,
      cmd_op_0: cmdOpBit0,
      param_id: this._paramId,
      serial: this._serial,
    }));
    if (this._paramData === null) {
      console.log('param_data:', 'null');
    }
    else {
      printUint8Array2('param_data:', this._paramData);
    }
  }

}
