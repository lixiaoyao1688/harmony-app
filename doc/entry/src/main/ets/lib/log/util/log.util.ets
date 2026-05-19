export function printUint8Array(data: Uint8Array): void {
  console.log(Array.from(data).map(byte => byte.toString(16).toUpperCase().padStart(2, '0')).join(' ') + ` (${data.length} 字节)`);
}

export function printUint8Array2(title: string, data: Uint8Array): void {
  console.log(title);
  console.log(Array.from(data).map(byte => byte.toString(16).toUpperCase().padStart(2, '0')).join(' ') + ` (${data.length} 字节)`);
}

export function printStruct<T>(title: string, data: T): void {
  console.log(title);
  console.log(JSON.stringify(data));
}
