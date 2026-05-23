import { RecordVO } from "./Record.vo";
import { getUint16 } from "../../../lib/byte/util/byte.util";


/**
 * 历史记录统计数据 VO
 *
 * 参考
 * 协议搜索 s_history_data
 */
export class RecordStatVO {

  private readonly _vos: Array<RecordVO> = [];

  constructor(e?: Uint8Array | null) {
    if (!e) {
      return;
    }
    if (e.length < 5) {
      console.error('RecordStatVO_constructor_error', '数据长度不足 5 字节，无法解析历史记录统计数据');
      return;
    }
    const count = getUint16(e[0], e[1]);  // 总条数 (页数*每页条数)
    const totalPage = e[2];  // 页数
    const curPage = e[3];  // 当前页码 [0,页数)
    const curNum = e[4];  // 每页条数
    this._log(count, totalPage, curPage, curNum);

    console.log(`共 ${count} 条，页码 ${curPage}/${totalPage}，当前页有 ${ this._vos.length } 条历史记录 (s_history_units):`);
    const total = e.length;
    let offset: number = 5;
    while (offset + RecordVO.SIZE <= total) {
      // 创建共享底层 buffer 的视图，不复制数据，更高效
      const recordData = new Uint8Array(e.buffer, offset, RecordVO.SIZE);
      this._vos.push(new RecordVO(recordData));
      offset = offset + RecordVO.SIZE;
    }

    // 只在剩余空间还够完整取出一条记录时进入循环，最后一次进入时，只有两种情况:
    // 1. offset + RECORD_SIZE === total，执行完循环体，offset 加上 RECORD_SIZE 变为 total，跳出循环;
    // 2. offset + RECORD_SIZE < total，执行完循环体，offset 加上 RECORD_SIZE 变为 "小于total的某个数"，重新循环判断时，这个数加上 RECORD_SIZE 后大于 total，所以 offset 作为 "小于total的某个数" 跳出循环。
    // 所以，不会出现跳出循环后 offset > total 的情况。
    if (offset === total) {
      console.log('s_history_data 的字节数刚好用完');
    }
    else if (offset < total) {
      console.error('RecordStatVO_constructor_error', `s_history_data 剩余 ${total - offset} 字节没用完`);
    }
  }

  private _log(count: number, totalPage: number, curPage: number, curNum: number): void {
    console.log('s_history_data:')
    console.log(JSON.stringify({ count, totalPage, curPage, curNum }));
  }

}
