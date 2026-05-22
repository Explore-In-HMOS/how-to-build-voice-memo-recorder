import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import bundleManager from '@ohos.bundle.bundleManager';
import { RecordPageBuilder } from './RecordPage';
import { MemoListPageBuilder } from './MemoListPage';
import { PlaybackPageBuilder } from './PlaybackPage';

@Builder
export function HomePageBuilder() {
  HomePage()
}

@Component
struct HomePage {
  @Consume('pathStack') pathStack: NavPathStack;
  private scroller: Scroller = new Scroller();

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [['#1A1A2E', 0], ['#16213E', 1]]
        })

      Scroll(this.scroller) {
        Column() {
          Row() {
            Text('🎙️')
              .fontSize(20)
              .margin({ right: 8 })
            Text('WristMemo')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
          }
          .margin({ top: 20, bottom: 24 })

          Button() {
            Column() {
              Text('●')
                .fontSize(44)
                .fontColor('#FF4444')
                .margin({ bottom: 4 })
              Text('RECORD')
                .fontSize(11)
                .fontColor('#DDDDDD')
                .letterSpacing(1)
            }
          }
          .width(110)
          .height(110)
          .borderRadius(55)
          .backgroundColor('#2A2A2A')
          .shadow({ radius: 8, color: '#44000000', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            this.pathStack.pushPathByName('RecordPage', null)
          })
          .margin({ bottom: 24 })

          Button() {
            Row() {
              Text('▶')
                .fontSize(14)
                .fontColor('#44FF44')
                .margin({ right: 8 })
              Text('My Memos')
                .fontSize(12)
                .fontColor('#FFFFFF')
            }
          }
          .width(120)
          .height(36)
          .borderRadius(18)
          .backgroundColor('#2A2A2A')
          .onClick(() => {
            this.pathStack.pushPathByName('MemoListPage', null)
          })

          Text('max 2 min per memo')
            .fontSize(9)
            .fontColor('#555555')
            .margin({ top: 20 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
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

@Entry
@Component
struct Index {
  @State showError: boolean = false;
  @State errorMessage: string = '';
  @State isPermissionsChecked: boolean = false;
  @State hasPermissions: boolean = false;
  @State homePagePushed: boolean = false;
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();

  @Builder
  PagesMap(name: string) {
    if (name === 'HomePage') {
      HomePageBuilder()
    } else if (name === 'RecordPage') {
      RecordPageBuilder()
    } else if (name === 'MemoListPage') {
      MemoListPageBuilder()
    } else if (name === 'PlaybackPage') {
      PlaybackPageBuilder()
    }
  }

  async aboutToAppear(): Promise<void> {
    await this.checkAndRequestPermissions();
  }

  async getTokenId(): Promise<number> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return bundleInfo.appInfo.accessTokenId;
    } catch (err) {
      console.error(`Get token id failed: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  async checkAndRequestPermissions(): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const tokenId = await this.getTokenId();

      const permissions: Array<Permissions> = [
        'ohos.permission.MICROPHONE'
      ];

      let allGranted = true;
      for (const perm of permissions) {
        try {
          const result = await atManager.checkAccessToken(tokenId, perm);
          if (result !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
            allGranted = false;
            break;
          }
        } catch (err) {
          console.error(`Check permission ${perm} failed: ${JSON.stringify(err)}`);
          allGranted = false;
          break;
        }
      }

      if (!allGranted) {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const result = await atManager.requestPermissionsFromUser(context, permissions);

        if (result && result.authResults) {
          allGranted = result.authResults.every(r => r === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
        } else {
          allGranted = false;
        }
      }

      this.hasPermissions = allGranted;
      this.isPermissionsChecked = true;

      if (!this.hasPermissions) {
        this.showError = true;
        this.errorMessage = 'Microphone & Storage\npermissions required';
      } else {
        if (!this.homePagePushed) {
          this.homePagePushed = true;
          setTimeout(() => {
            this.pathStack.pushPathByName('HomePage', null);
          }, 100);
        }
      }
    } catch (err) {
      console.error(`Permission error: ${JSON.stringify(err)}`);
      this.showError = true;
      this.errorMessage = 'Permission error.\nPlease grant permissions';
      this.isPermissionsChecked = true;
    }
  }

  build() {
    Stack() {
      // Navigation always present in background for proper initialization
      Navigation(this.pathStack) {
      }
      .width('100%')
      .height('100%')
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .hideBackButton(false)
      .hideToolBar(true)
      .navDestination(this.PagesMap)

      if (!this.isPermissionsChecked) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 135,
            colors: [['#1A1A2E', 0], ['#16213E', 1]]
          })

        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FFFFFF')
          Text('Loading...')
            .fontSize(12)
            .fontColor('#888888')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.showError) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 135,
            colors: [['#1A1A2E', 0], ['#16213E', 1]]
          })

        Column() {
          Text('⚠️')
            .fontSize(48)
            .margin({ bottom: 16 })

          Text(this.errorMessage)
            .fontSize(12)
            .fontColor('#FF6666')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })
            .width('80%')

          Button('Exit')
            .fontSize(14)
            .height(36)
            .width(100)
            .backgroundColor('#FF4444')
            .borderRadius(18)
            .onClick(() => {
              const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              context.terminateSelf();
            })

          Button('Retry')
            .fontSize(14)
            .height(36)
            .width(100)
            .backgroundColor('#44AA44')
            .borderRadius(18)
            .margin({ top: 12 })
            .onClick(() => {
              this.isPermissionsChecked = false;
              this.showError = false;
              while (this.pathStack.size() > 0) {
                this.pathStack.pop();
              }
              this.checkAndRequestPermissions();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 20, right: 20 })
      }
    }
    .width('100%')
    .height('100%')
  }
}