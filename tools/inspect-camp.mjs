import fs from 'node:fs';
const buf = fs.readFileSync('c:/AI/gemini/promise-path-next/design/runtime-target/camp-scene-v1.png');
console.log('Signature:', buf.subarray(0, 8));
console.log('Width:', buf.readUInt32BE(16), 'Height:', buf.readUInt32BE(20), 'ColorType:', buf[25]);
