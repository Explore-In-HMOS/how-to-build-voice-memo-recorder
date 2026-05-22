import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { AbilityConstant } from '@kit.AbilityKit';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    await this.requestPermissions();
  }

  async requestPermissions(): Promise<void> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = [
      'ohos.permission.MICROPHONE',
      'ohos.permission.STORAGE_MANAGER'
    ];

    try {
      await atManager.requestPermissionsFromUser(this.context, permissions);
      console.info('Permissions granted');
    } catch (err) {
      console.error(`Permission error: ${JSON.stringify(err)}`);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err) {
        console.error(`Failed to load content: ${JSON.stringify(err)}`);
        return;
      }
      console.info('Main page loaded');
    });
  }
}