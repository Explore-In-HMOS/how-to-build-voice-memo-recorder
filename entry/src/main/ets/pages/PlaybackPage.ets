import promptAction from '@ohos.promptAction';
import { AudioService } from '../common/AudioService';
import { FileService } from '../common/FileService';
import { ParamService } from '../common/ParamService';
import { MemoModel } from '../model/MemoModel';
import common from '@ohos.app.ability.common';

@Builder
export function PlaybackPageBuilder() {
  PlaybackPage()
}

@Component
struct PlaybackPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State mode: string = 'play';
  @State errorMessage: string = '';
  @State currentPosition: number = 0;
  @State totalDuration: number = 0;
  @State progressPercent: number = 0;
  @State isLoading: boolean = true;

  private audioService: AudioService = AudioService.getInstance();
  private fileService: FileService | null = null;
  private paramService: ParamService = ParamService.getInstance();
  private memo: MemoModel | null = null;
  private audioData: ArrayBuffer | null = null;
  private progressInterval: number = -1;
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    console.info('PlaybackPage: aboutToAppear started');

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.fileService = new FileService(context);
    await this.audioService.init();

    await this.loadMemoFromService();
  }

  private async loadMemoFromService(): Promise<void> {
    try {
      this.isLoading = true;

      await this.sleep(100);

      const memoJson = this.paramService.getSelectedMemo();
      console.info(`PlaybackPage: memoJson length: ${memoJson.length}`);

      if (memoJson && memoJson.length > 0) {
        this.memo = JSON.parse(memoJson) as MemoModel;
        console.info(`PlaybackPage: memo loaded - duration: ${this.memo?.durationSec}s, path: ${this.memo?.filePath}`);

        if (this.memo && this.memo.filePath) {
          this.totalDuration = this.memo.durationSec || 0;
          this.audioData = await this.fileService!.loadMemoFile(this.memo.filePath);
          console.info(`PlaybackPage: audioData size: ${this.audioData?.byteLength} bytes`);

          if (this.audioData && this.audioData.byteLength > 0) {
            this.errorMessage = '';
            promptAction.showToast({ message: `Loaded: ${this.totalDuration} sec` });
          } else {
            this.errorMessage = 'Audio file is empty or corrupted';
            console.error('PlaybackPage: audioData is empty');
          }
        } else {
          this.errorMessage = 'Memo file path not found';
          console.error('PlaybackPage: memo or filePath is null');
        }
      } else {
        this.errorMessage = 'No memo data received';
        console.error('PlaybackPage: no memoJson received');
      }

      this.isLoading = false;
    } catch (err) {
      console.error(`PlaybackPage: load error: ${JSON.stringify(err)}`);
      this.errorMessage = 'Failed to load memo';
      this.isLoading = false;
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  aboutToDisappear(): void {
    this.stopProgressTimer();
    this.audioService.stopCurrentPlayback();
    this.paramService.clearSelectedMemo();
  }

  private startProgressTimer(): void {
    this.stopProgressTimer();
    this.progressInterval = setInterval(() => {
      if (this.mode === 'playing') {
        this.currentPosition += 0.1;
        if (this.currentPosition >= this.totalDuration && this.totalDuration > 0) {
          this.currentPosition = this.totalDuration;
          this.progressPercent = 100;
          this.stopProgressTimer();
          this.mode = 'play';
          promptAction.openToast({ message: 'Finished' });
        } else if (this.totalDuration > 0) {
          this.progressPercent = (this.currentPosition / this.totalDuration) * 100;
        }
      }
    }, 100);
  }

  private stopProgressTimer(): void {
    if (this.progressInterval !== -1) {
      clearInterval(this.progressInterval);
      this.progressInterval = -1;
    }
  }

  private resetProgress(): void {
    this.currentPosition = 0;
    this.progressPercent = 0;
    this.stopProgressTimer();
  }

  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  private formatDuration(sec: number): string {
    if (sec === 0) {
      return '0:00';
    }
    const mins = Math.floor(sec / 60);
    const secs = sec % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();

    if (isToday) {
      return `Today ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
    }
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  private async onPlay(): Promise<void> {
    if (!this.audioData) {
      this.errorMessage = 'No audio data';
      promptAction.openToast({ message: this.errorMessage });
      return;
    }

    if (this.audioData.byteLength === 0) {
      this.errorMessage = 'Audio file is empty';
      promptAction.openToast({ message: this.errorMessage });
      return;
    }

    this.errorMessage = '';
    this.resetProgress();
    this.mode = 'playing';

    const success = await this.audioService.startPlayback(
      this.audioData,
      () => {
        this.mode = 'play';
        this.resetProgress();
        promptAction.openToast({ message: 'Finished' });
      }
    );

    if (success) {
      this.startProgressTimer();
    } else {
      this.mode = 'play';
      this.errorMessage = 'Playback failed';
      promptAction.openToast({ message: this.errorMessage });
    }
  }

  private onPause(): void {
    this.mode = 'paused';
    this.audioService.pausePlayback();
    this.stopProgressTimer();
    promptAction.openToast({ message: 'Paused' });
  }

  private onStop(): void {
    this.mode = 'play';
    this.audioService.stopCurrentPlayback();
    this.resetProgress();
    promptAction.openToast({ message: 'Stopped' });
  }

  private onResume(): void {
    this.mode = 'playing';

    this.audioService.startPlayback(
      this.audioData!,
      () => {
        this.mode = 'play';
        this.resetProgress();
        promptAction.openToast({ message: 'Finished' });
      }
    ).then((success: boolean) => {
      if (success) {
        this.startProgressTimer();
      }
    });
  }

  private deleteMemo(): void {
    promptAction.showDialog({
      title: 'Delete Memo',
      message: 'Delete this memo?',
      buttons: [
        { text: 'Cancel', color: '#888888' },
        { text: 'Delete', color: '#FF4444' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1 && this.memo && this.fileService) {
        this.audioService.stopCurrentPlayback();
        this.fileService!.deleteMemo(this.memo);
        promptAction.openToast({ message: 'Deleted' });
      }
    });
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [['#1A1A2E', 0], ['#16213E', 1]]
        })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FFFFFF')
          Text('Loading memo...')
            .fontSize(12)
            .fontColor('#888888')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column() {
            Row() {
              Button('←')
                .fontSize(18)
                .width(36)
                .height(36)
                .backgroundColor('#2A2A2A')
                .borderRadius(18)
                .onClick(() => {
                  this.onStop();
                  this.pathStack.pop();
                })

              Text('PLAYBACK')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .letterSpacing(2)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)

              Button('🗑')
                .fontSize(14)
                .backgroundColor('transparent')
                .width(36)
                .height(36)
                .onClick(() => this.deleteMemo())
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 6 })
            .backgroundColor('#0D0D1A')

            Column() {
              Text('🎙️')
                .fontSize(36)
                .margin({ top: 12, bottom: 6 })

              Text(this.memo ? this.formatDate(this.memo.createdAt) : '--')
                .fontSize(10)
                .fontColor('#888888')

              Text(this.memo ? this.formatDuration(this.memo.durationSec) : '0:00')
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .fontColor('#44FF44')
                .fontFamily('monospace')
                .margin({ top: 8, bottom: 4 })

              Text(this.memo ? `${this.memo.fileSizeKB} KB` : '-- KB')
                .fontSize(9)
                .fontColor('#666666')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: 16 })

            if (this.totalDuration > 0) {
              Column() {
                Row() {
                  Text(this.formatTime(this.currentPosition))
                    .fontSize(9)
                    .fontColor('#888888')
                  Blank()
                  Text(this.formatDuration(this.totalDuration))
                    .fontSize(9)
                    .fontColor('#888888')
                }
                .width('85%')
                .margin({ bottom: 4 })

                Stack() {
                  Row()
                    .width('100%')
                    .height(4)
                    .backgroundColor('#333333')
                    .borderRadius(2)

                  Row()
                    .width(`${this.progressPercent}%`)
                    .height(4)
                    .backgroundColor('#44FF44')
                    .borderRadius(2)
                }
                .width('85%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .margin({ bottom: 20 })
            }

            if (this.mode === 'play') {
              Button() {
                Column() {
                  Text('▶')
                    .fontSize(36)
                    .margin({ bottom: 4 })
                  Text('PLAY')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .letterSpacing(1)
                }
              }
              .width(100)
              .height(100)
              .borderRadius(50)
              .backgroundColor('#44AA44')
              .shadow({ radius: 12, color: '#44AA4444', offsetX: 0, offsetY: 3 })
              .onClick(() => this.onPlay())
              .margin({ bottom: 20 })
              .enabled(!this.isLoading && this.audioData !== null && this.audioData.byteLength > 0)
            }

            if (this.mode === 'playing') {
              Row() {
                Button() {
                  Column() {
                    Text('⏸')
                      .fontSize(22)
                    Text('PAUSE')
                      .fontSize(9)
                      .margin({ top: 2 })
                  }
                }
                .width(55)
                .height(55)
                .borderRadius(27)
                .backgroundColor('#FFAA44')
                .onClick(() => this.onPause())

                Button() {
                  Column() {
                    Text('■')
                      .fontSize(22)
                    Text('STOP')
                      .fontSize(9)
                      .margin({ top: 2 })
                  }
                }
                .width(55)
                .height(55)
                .borderRadius(27)
                .backgroundColor('#FF4444')
                .onClick(() => this.onStop())
              }
              .justifyContent(FlexAlign.SpaceEvenly)
              .width('50%')
              .margin({ bottom: 20 })
            }

            if (this.mode === 'paused') {
              Row() {
                Button() {
                  Column() {
                    Text('▶')
                      .fontSize(22)
                    Text('RESUME')
                      .fontSize(9)
                      .margin({ top: 2 })
                  }
                }
                .width(55)
                .height(55)
                .borderRadius(27)
                .backgroundColor('#44AA44')
                .onClick(() => this.onResume())

                Button() {
                  Column() {
                    Text('■')
                      .fontSize(22)
                    Text('STOP')
                      .fontSize(9)
                      .margin({ top: 2 })
                  }
                }
                .width(55)
                .height(55)
                .borderRadius(27)
                .backgroundColor('#FF4444')
                .onClick(() => this.onStop())
              }
              .justifyContent(FlexAlign.SpaceEvenly)
              .width('50%')
              .margin({ bottom: 20 })
            }

            if (this.mode === 'playing') {
              Text('🔊 PLAYING')
                .fontSize(9)
                .fontColor('#44FF44')
                .margin({ bottom: 12 })
            } else if (this.mode === 'paused') {
              Text('⏸ PAUSED')
                .fontSize(9)
                .fontColor('#FFAA44')
                .margin({ bottom: 12 })
            }

            if (this.errorMessage) {
              Text(this.errorMessage)
                .fontSize(10)
                .fontColor('#FF6666')
                .padding(10)
                .backgroundColor('#FF222222')
                .borderRadius(10)
                .margin({ bottom: 12 })
            }

            Blank()
              .height(30)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 16, right: 16, top: 0, bottom: 0 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}