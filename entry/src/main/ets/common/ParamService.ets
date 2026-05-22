export class ParamService {
  private static instance: ParamService;
  private selectedMemo: string = '';

  static getInstance(): ParamService {
    if (!ParamService.instance) {
      ParamService.instance = new ParamService();
    }
    return ParamService.instance;
  }

  setSelectedMemo(memoJson: string): void {
    console.info(`ParamService: setSelectedMemo called with: ${memoJson.substring(0, 100)}...`);
    this.selectedMemo = memoJson;
  }

  getSelectedMemo(): string {
    console.info(`ParamService: getSelectedMemo called, length: ${this.selectedMemo.length}`);
    return this.selectedMemo;
  }

  hasSelectedMemo(): boolean {
    return this.selectedMemo.length > 0;
  }

  clearSelectedMemo(): void {
    console.info('ParamService: clearSelectedMemo called');
    this.selectedMemo = '';
  }
}