import promptAction from '@ohos.promptAction';
import { FileService } from '../common/FileService';
import { MemoModel } from '../model/MemoModel';
import { ParamService } from '../common/ParamService';
import common from '@ohos.app.ability.common';

@Builder
export function MemoListPageBuilder() {
  MemoListPage();
}

@Component
struct MemoListPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State memos: MemoModel[] = [];
  @State isLoading: boolean = true;
  @State deleteMode: boolean = false;

  private fileService: FileService | null = null;
  private paramService: ParamService = ParamService.getInstance();
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.fileService = new FileService(context);
    await this.loadMemos();
  }

  async loadMemos(): Promise<void> {
    this.isLoading = true;
    this.memos = await this.fileService!.getAllMemos();
    this.isLoading = false;

    console.info(`Loaded ${this.memos.length} memos`);
  }

  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();

    const isToday = date.toDateString() === now.toDateString();

    if (isToday) {
      return `Today ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
    }

    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes()
      .toString()
      .padStart(2, '0')}`;
  }

  formatDuration(sec: number): string {
    if (sec === 0) {
      return '--:--';
    }

    const mins = Math.floor(sec / 60);
    const secs = sec % 60;

    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  async deleteMemo(memo: MemoModel): Promise<void> {
    try {
      await this.fileService!.deleteMemo(memo);

      this.memos = this.memos.filter(
        (m: MemoModel) => m.id !== memo.id
      );

      this.deleteMode = false;

      promptAction.showToast({
        message: 'Memo deleted'
      });
    } catch (err) {
      promptAction.showToast({
        message: 'Delete failed'
      });
    }
  }

  confirmDelete(memo: MemoModel): void {
    promptAction.showDialog({
      title: 'Delete Memo',
      message: `Delete "${this.formatDate(memo.createdAt)}"?`,
      buttons: [
        {
          text: 'Cancel',
          color: '#888888'
        },
        {
          text: 'Delete',
          color: '#FF4444'
        }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteMemo(memo);
      }
    });
  }

  getFileIcon(fileSizeKB: number): string {
    if (fileSizeKB < 50) {
      return '📝';
    }

    if (fileSizeKB < 100) {
      return '📄';
    }

    return '📁';
  }

  private openPlaybackPage(memo: MemoModel): void {
    console.info(
      `Opening playback for memo: ${memo.fileName}, duration: ${memo.durationSec}s`
    );

    this.paramService.setSelectedMemo(JSON.stringify(memo));
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [['#1A1A2E', 0], ['#16213E', 1]]
        });

      Column() {
        Row() {
          Button('←')
            .fontSize(20)
            .width(40)
            .height(40)
            .backgroundColor('#2A2A2A')
            .borderRadius(20)
            .onClick(() => {
              this.pathStack.pop();
            });

          Text('MY MEMOS')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(2)
            .layoutWeight(1)
            .textAlign(TextAlign.Center);

          if (this.memos.length > 0 && !this.isLoading) {
            Button(this.deleteMode ? '✓' : '🗑')
              .fontSize(16)
              .backgroundColor('transparent')
              .width(40)
              .height(40)
              .onClick(() => {
                this.deleteMode = !this.deleteMode;
              });
          } else {
            Blank()
              .width(40);
          }
        }
        .width('100%')
        .padding({
          left: 12,
          right: 12,
          top: 12,
          bottom: 8
        })
        .backgroundColor('#0D0D1A');

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#FFFFFF');

            Text('Loading memos...')
              .fontSize(12)
              .fontColor('#888888')
              .margin({ top: 12 });
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center);

        } else if (this.memos.length === 0) {
          Column() {
            Text('🎙️')
              .fontSize(48)
              .margin({ bottom: 16 });

            Text('No memos yet')
              .fontSize(14)
              .fontColor('#888888')
              .margin({ bottom: 8 });

            Text('Tap RECORD on main screen\nto create your first memo')
              .fontSize(10)
              .fontColor('#666666')
              .textAlign(TextAlign.Center);

            Button('← BACK')
              .fontSize(12)
              .backgroundColor('#333344')
              .height(36)
              .width(100)
              .borderRadius(18)
              .onClick(() => {
                this.pathStack.pop();
              })
              .margin({ top: 24 });
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding(20);

        } else {
          Scroll(this.scroller) {
            Column() {
              Row() {
                Text(`📋 ${this.memos.length} memo${this.memos.length > 1 ? 's' : ''}`)
                  .fontSize(10)
                  .fontColor('#666666');

                Text(
                  `💾 ${Math.round(
                    this.memos.reduce(
                      (sum: number, m: MemoModel) => sum + m.fileSizeKB,
                      0
                    )
                  )} KB`
                )
                  .fontSize(10)
                  .fontColor('#666666');
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({
                left: 16,
                right: 16,
                top: 12,
                bottom: 8
              });

              ForEach(
                this.memos,
                (memo: MemoModel) => {
                  Column() {
                    Row() {
                      Text(this.getFileIcon(memo.fileSizeKB))
                        .fontSize(24)
                        .margin({ right: 12 });

                      Column() {
                        Text(this.formatDate(memo.createdAt))
                          .fontSize(13)
                          .fontColor('#FFFFFF')
                          .fontWeight(FontWeight.Medium);

                        Row() {
                          Text(`⏱ ${this.formatDuration(memo.durationSec)}`)
                            .fontSize(9)
                            .fontColor('#888888')
                            .margin({ right: 12 });

                          Text(`💾 ${memo.fileSizeKB} KB`)
                            .fontSize(9)
                            .fontColor('#888888');
                        }
                        .margin({ top: 4 });
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1);

                      if (this.deleteMode) {
                        Button('🗑')
                          .fontSize(16)
                          .width(36)
                          .height(36)
                          .borderRadius(18)
                          .backgroundColor('#FF4444')
                          .onClick(() => {
                            this.confirmDelete(memo);
                          });

                      } else {
                        Button('▶')
                          .fontSize(14)
                          .width(36)
                          .height(36)
                          .borderRadius(18)
                          .backgroundColor('#44AA44')
                          .onClick(() => {
                            this.openPlaybackPage(memo);
                            this.pathStack.pushPathByName(
                              'PlaybackPage',
                              null
                            );
                          });
                      }
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor('#2A2A3E')
                    .borderRadius(16)
                    .margin({ bottom: 8 });
                  }
                  .width('100%');
                },
                (memo: MemoModel) => memo.id
              );

              Blank()
                .height(20);
            }
            .width('100%')
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            });
          }
          .scrollBar(BarState.Off)
          .scrollable(ScrollDirection.Vertical)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%');
        }
      }
      .width('100%')
      .height('100%');
    }
    .width('100%')
    .height('100%');
  }
}