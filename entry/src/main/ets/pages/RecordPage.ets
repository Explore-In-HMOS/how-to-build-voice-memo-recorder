import promptAction from '@ohos.promptAction';
import { AudioService } from '../common/AudioService';
import { FileService } from '../common/FileService';
import common from '@ohos.app.ability.common';

@Builder
export function RecordPageBuilder() {
  RecordPage()
}

@Component
struct RecordPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State isRecording: boolean = false;
  @State isPaused: boolean = false;
  @State timerSeconds: number = 0;
  @State showResumePrompt: boolean = false;
  @State errorMessage: string = '';

  private audioService: AudioService = AudioService.getInstance();
  private fileService: FileService | null = null;
  private timerInterval: number = -1;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.fileService = new FileService(context);
    await this.audioService.init();

    this.audioService.setInterruptHandler((type: 'pause' | 'resume') => {
      if (type === 'pause') {
        this.isPaused = true;
        this.showResumePrompt = true;
        promptAction.openToast({ message: 'Recording paused - Call received' });
      } else if (type === 'resume') {
        this.showResumePrompt = true;
      }
    });
  }

  aboutToDisappear(): void {
    if (this.isRecording) {
      this.stopRecording();
    }
  }

  private startTimer(): void {
    this.timerInterval = setInterval(() => {
      if (this.timerSeconds < 120) {
        this.timerSeconds++;
      } else {
        this.stopRecording();
        promptAction.openToast({ message: 'Max duration reached (2 min)' });
      }
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerInterval !== -1) {
      clearInterval(this.timerInterval);
      this.timerInterval = -1;
    }
  }

  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  private getProgressPercent(): number {
    return (this.timerSeconds / 120) * 100;
  }

  private async startRecording(): Promise<void> {
    this.errorMessage = '';

    const success = await this.audioService.startRecording((buffer: ArrayBuffer) => {
      console.info(`Recording chunk received: ${buffer.byteLength} bytes`);
    });

    if (success) {
      this.isRecording = true;
      this.isPaused = false;
      this.timerSeconds = 0;
      this.startTimer();
      promptAction.openToast({ message: 'Recording started' });
    } else {
      this.errorMessage = 'Microphone busy';
      promptAction.openToast({ message: this.errorMessage });
    }
  }

  private async stopRecording(): Promise<void> {
    this.stopTimer();
    const audioData = await this.audioService.stopRecording();

    if (audioData.byteLength > 0 && this.fileService) {
      const memo = await this.fileService.saveMemoFile(audioData, this.timerSeconds);
      promptAction.openToast({ message: `Memo saved (${this.formatTime(this.timerSeconds)})` });
    } else if (audioData.byteLength === 0) {
      promptAction.openToast({ message: 'No audio captured' });
    }
    this.isRecording = false;
  }

  private async pauseRecording(): Promise<void> {
    await this.audioService.pauseRecording();
    this.isPaused = true;
    this.stopTimer();
  }

  private async resumeRecording(): Promise<void> {
    await this.audioService.resumeRecording();
    this.isPaused = false;
    this.showResumePrompt = false;
    this.startTimer();
  }

  private async discardAndNew(): Promise<void> {
    await this.audioService.stopRecording();
    this.timerSeconds = 0;
    this.isRecording = false;
    this.isPaused = false;
    this.showResumePrompt = false;
    this.startRecording();
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

      Scroll() {
        Column() {
          Row() {
            Button('←')
              .fontSize(18)
              .width(36)
              .height(36)
              .backgroundColor('#2A2A2A')
              .borderRadius(18)
              .onClick(() => {
                this.pathStack.pop()
              })

            Text('RECORDING')
              .fontSize(12)
              .fontColor('#FF4444')
              .letterSpacing(2)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            Blank()
              .width(36)
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 12, bottom: 8 })
          .backgroundColor('#0D0D1A')

          Column() {
            Text(this.isPaused ? 'PAUSED' : (this.isRecording ? 'LIVE' : 'READY'))
              .fontSize(10)
              .fontColor(this.isPaused ? '#FFAA44' : (this.isRecording ? '#44FF44' : '#888888'))
              .margin({ top: 16, bottom: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          if (this.isRecording && !this.isPaused) {
            Row() {
              Text('●')
                .fontSize(20)
                .fontColor('#FF4444')
                .margin({ right: 8 })
              Text('RECORDING...')
                .fontSize(12)
                .fontColor('#FF4444')
                .letterSpacing(1)
            }
            .padding(8)
            .borderRadius(20)
            .backgroundColor('#FF222222')
            .margin({ top: 8, bottom: 16 })
          } else if (this.isPaused) {
            Row() {
              Text('⏸')
                .fontSize(20)
                .margin({ right: 8 })
              Text('PAUSED')
                .fontSize(12)
                .fontColor('#FFAA44')
                .letterSpacing(1)
            }
            .padding(8)
            .borderRadius(20)
            .backgroundColor('#FF222222')
            .margin({ top: 8, bottom: 16 })
          } else {
            Blank()
              .height(60)
          }

          Column() {
            Text(this.formatTime(this.timerSeconds))
              .fontSize(56)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .fontFamily('monospace')
              .letterSpacing(2)

            Column() {
              Row()
                .width(`${this.getProgressPercent()}%`)
                .height('100%')
                .backgroundColor('#FF4444')
                .borderRadius(4)
            }
            .width('80%')
            .height(6)
            .backgroundColor('#333333')
            .borderRadius(4)
            .margin({ top: 12 })

            Text(`max 2:00 • ${120 - this.timerSeconds}s left`)
              .fontSize(9)
              .fontColor('#666666')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: 32 })

          if (this.showResumePrompt && !this.isRecording) {
            Column() {
              Text('📞 Call ended. Resume recording?')
                .fontSize(11)
                .fontColor('#FFD700')
                .margin({ bottom: 16 })
                .textAlign(TextAlign.Center)

              Row() {
                Button('Resume')
                  .fontSize(12)
                  .backgroundColor('#44AA44')
                  .height(36)
                  .width(80)
                  .borderRadius(18)
                  .onClick(() => this.resumeRecording())

                Button('New')
                  .fontSize(12)
                  .backgroundColor('#FF8844')
                  .height(36)
                  .width(80)
                  .borderRadius(18)
                  .onClick(() => this.discardAndNew())

                Button('Cancel')
                  .fontSize(12)
                  .backgroundColor('#666666')
                  .height(36)
                  .width(80)
                  .borderRadius(18)
                  .onClick(() => this.pathStack.pop())
              }
              .justifyContent(FlexAlign.SpaceEvenly)
              .width('100%')
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#2A2A3E')
            .borderRadius(20)
            .margin({ bottom: 24 })
          }

          if (!this.showResumePrompt) {
            Column() {
              if (!this.isRecording) {
                Button() {
                  Column() {
                    Text('●')
                      .fontSize(56)
                      .margin({ bottom: 6 })
                    Text('START')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .letterSpacing(2)
                  }
                }
                .width(140)
                .height(140)
                .borderRadius(70)
                .backgroundColor('#FF4444')
                .shadow({ radius: 20, color: '#FF444444', offsetX: 0, offsetY: 4 })
                .onClick(() => this.startRecording())

              } else if (this.isRecording && !this.isPaused) {
                Row() {
                  Button() {
                    Column() {
                      Text('⏸')
                        .fontSize(28)
                      Text('PAUSE')
                        .fontSize(10)
                        .margin({ top: 4 })
                    }
                  }
                  .width(65)
                  .height(65)
                  .borderRadius(32)
                  .backgroundColor('#FFAA44')
                  .onClick(() => this.pauseRecording())

                  Button() {
                    Column() {
                      Text('■')
                        .fontSize(28)
                      Text('STOP')
                        .fontSize(10)
                        .margin({ top: 4 })
                    }
                  }
                  .width(65)
                  .height(65)
                  .borderRadius(32)
                  .backgroundColor('#FF4444')
                  .onClick(() => this.stopRecording())
                }
                .justifyContent(FlexAlign.SpaceEvenly)
                .width('50%')

              } else if (this.isRecording && this.isPaused) {
                Row() {
                  Button() {
                    Column() {
                      Text('▶')
                        .fontSize(28)
                      Text('RESUME')
                        .fontSize(10)
                        .margin({ top: 4 })
                    }
                  }
                  .width(65)
                  .height(65)
                  .borderRadius(32)
                  .backgroundColor('#44AA44')
                  .onClick(() => this.resumeRecording())

                  Button() {
                    Column() {
                      Text('■')
                        .fontSize(28)
                      Text('STOP')
                        .fontSize(10)
                        .margin({ top: 4 })
                    }
                  }
                  .width(65)
                  .height(65)
                  .borderRadius(32)
                  .backgroundColor('#FF4444')
                  .onClick(() => this.stopRecording())
                }
                .justifyContent(FlexAlign.SpaceEvenly)
                .width('50%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: 32 })
          }

          if (!this.isRecording || this.isPaused) {
            Button('← BACK')
              .fontSize(14)
              .backgroundColor('#333344')
              .height(36)
              .width(100)
              .borderRadius(18)
              .onClick(() => this.pathStack.pop())
              .margin({ bottom: 20 })
          }

          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(11)
              .fontColor('#FF6666')
              .padding(12)
              .backgroundColor('#FF222222')
              .borderRadius(12)
              .margin({ bottom: 16 })
          }

          Blank()
            .height(30)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 16, right: 16, top: 0, bottom: 8 })
      }
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}