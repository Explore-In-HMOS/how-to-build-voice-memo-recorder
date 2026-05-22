export interface MemoModel {
  id: string;           // timestamp as unique ID
  fileName: string;     // e.g., 1704123456789_voice.m4a
  filePath: string;     // full path
  durationSec: number;  // recording duration in seconds
  createdAt: number;    // timestamp
  fileSizeKB: number;
}