import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { MemoModel } from '../model/MemoModel';

const MEMO_DIR = 'WristMemo';

export class FileService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.ensureDirectoryExists();
  }

  private getBasePath(): string {
    return `${this.context.filesDir}/${MEMO_DIR}`;
  }

  private ensureDirectoryExists(): void {
    const dirPath = this.getBasePath();
    try {
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath);
        console.info(`Directory created: ${dirPath}`);
      }
    } catch (err) {
      console.error(`Error creating directory: ${JSON.stringify(err)}`);
    }
  }

  async saveMemoFile(data: ArrayBuffer, durationSec: number): Promise<MemoModel> {
    const timestamp = Date.now();
    const fileName = `${timestamp}_voice.pcm`;
    const filePath = `${this.getBasePath()}/${fileName}`;

    console.info(`Saving memo: duration=${durationSec}s, size=${data.byteLength} bytes, path=${filePath}`);

    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
    try {
      fs.writeSync(file.fd, data);
    } finally {
      fs.closeSync(file);
    }


    const stat = fs.statSync(filePath);
    const memo: MemoModel = {
      id: timestamp.toString(),
      fileName: fileName,
      filePath: filePath,
      durationSec: durationSec,
      createdAt: timestamp,
      fileSizeKB: Math.round(stat.size / 1024)
    };

    console.info(`Memo saved: ${memo.fileName}, durationSec=${memo.durationSec}, sizeKB=${memo.fileSizeKB}`);
    return memo;
  }

  async getAllMemos(): Promise<MemoModel[]> {
    const dirPath = this.getBasePath();
    console.info(`Getting memos from: ${dirPath}`);

    try {
      if (!fs.accessSync(dirPath)) {
        console.info('Directory does not exist');
        return [];
      }

      const files = fs.listFileSync(dirPath);
      console.info(`Found files: ${JSON.stringify(files)}`);

      const memos: MemoModel[] = [];

      for (const file of files) {
        if (!file.endsWith('.pcm')) {
          continue;
        }
        const filePath = `${dirPath}/${file}`;
        const stat = fs.statSync(filePath);
        const timestamp = parseInt(file.split('_')[0]);

        memos.push({
          id: timestamp.toString(),
          fileName: file,
          filePath: filePath,
          durationSec: 0,
          createdAt: timestamp,
          fileSizeKB: Math.round(stat.size / 1024)
        });
      }
      return memos.sort((a, b) => b.createdAt - a.createdAt);
    } catch (err) {
      console.error(`Error getting memos: ${JSON.stringify(err)}`);
      return [];
    }
  }

  async loadMemoFile(filePath: string): Promise<ArrayBuffer> {
    console.info(`Loading memo from: ${filePath}`);
    let buffer = new ArrayBuffer(0);
    try {
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(filePath);
        console.info(`File size: ${stat.size} bytes`);

        buffer = new ArrayBuffer(stat.size);
        const readLen = fs.readSync(file.fd, buffer);
        console.info(`Read ${readLen} bytes from file`);
      } finally {
        fs.closeSync(file);
      }
      return buffer;
    } catch (err) {
      console.error(`Error loading memo: ${JSON.stringify(err)}`);
      return buffer;
    }
  }

  async deleteMemo(memo: MemoModel): Promise<void> {
    try {
      if (fs.accessSync(memo.filePath)) {
        fs.unlinkSync(memo.filePath);
        console.info(`Memo deleted: ${memo.filePath}`);
      }
    } catch (err) {
      console.error(`Error deleting memo: ${JSON.stringify(err)}`);
    }
  }
}