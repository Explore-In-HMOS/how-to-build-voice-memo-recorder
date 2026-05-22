import audio from '@ohos.multimedia.audio';
import { BusinessError } from '@ohos.base';

export type AudioInterruptHandler = (type: 'pause' | 'resume') => void;

export class AudioService {
  private static instance: AudioService;
  private capturer: audio.AudioCapturer | null = null;
  private renderer: audio.AudioRenderer | null = null;
  private interruptHandler: AudioInterruptHandler | null = null;
  private audioManager: audio.AudioManager | null = null;
  private sessionManager: audio.AudioSessionManager | null = null;
  private rendererDeviceChangeHandler: ((event: audio.AudioStreamDeviceChangeInfo) => void) | null = null;
  private sessionDeviceChangeHandler: ((event: audio.CurrentOutputDeviceChangedEvent) => void) | null = null;

  private recordingData: ArrayBuffer[] = [];
  private isRecordingActive: boolean = false;
  private isPaused: boolean = false;
  private readInterval: number = -1;

  private currentAudioData: ArrayBuffer | null = null;
  private isPlayingBack: boolean = false;
  private onPlaybackEndCallback: (() => void) | null = null;

  static getInstance(): AudioService {
    if (!AudioService.instance) {
      AudioService.instance = new AudioService();
    }
    return AudioService.instance;
  }

  async init(): Promise<void> {
    console.info('AudioService initialized');
    try {
      this.audioManager = audio.getAudioManager();
      this.sessionManager = this.audioManager.getSessionManager();
    } catch (err) {
      console.warn('Unable to initialize audio manager or session manager', err);
      this.audioManager = null;
      this.sessionManager = null;
    }
  }

  private setupPlaybackDeviceChangeHandlers(): void {
    this.rendererDeviceChangeHandler = (event: audio.AudioStreamDeviceChangeInfo): void => {
      console.info('Renderer audio output device changed', event);
      void this.stopCurrentPlayback();
    };
    this.sessionDeviceChangeHandler = (_event: audio.CurrentOutputDeviceChangedEvent): void => {
      console.info('Current output device changed');
      void this.stopCurrentPlayback();
    };
  }

  private attachPlaybackDeviceChangeListeners(): void {
    try {
      if (!this.audioManager) {
        this.audioManager = audio.getAudioManager();
      }
      if (!this.sessionManager && this.audioManager) {
        this.sessionManager = this.audioManager.getSessionManager();
      }
      if (this.sessionManager && this.sessionDeviceChangeHandler) {
        this.sessionManager.on('currentOutputDeviceChanged', this.sessionDeviceChangeHandler);
      }
    } catch (err) {
      console.warn('Failed to attach session device change listener', err);
    }
    try {
      if (this.renderer && this.rendererDeviceChangeHandler) {
        this.renderer.on('outputDeviceChangeWithInfo', this.rendererDeviceChangeHandler);
      }
    } catch (err) {
      console.warn('Failed to attach renderer device change listener', err);
    }
  }

  private detachPlaybackDeviceChangeListeners(): void {
    try {
      if (this.sessionManager && this.sessionDeviceChangeHandler) {
        this.sessionManager.off('currentOutputDeviceChanged', this.sessionDeviceChangeHandler);
      }
    } catch (err) {
      console.warn('Failed to detach session device change listener', err);
    }
    try {
      if (this.renderer && this.rendererDeviceChangeHandler) {
        this.renderer.off('outputDeviceChangeWithInfo', this.rendererDeviceChangeHandler);
      }
    } catch (err) {
      console.warn('Failed to detach renderer device change listener', err);
    }
  }

  async startRecording(onDataAvailable: (buffer: ArrayBuffer) => void): Promise<boolean> {
    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };

      const capturerOptions: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: capturerInfo
      };

      this.capturer = await audio.createAudioCapturer(capturerOptions);
      if (this.capturer !== undefined) {
        this.capturer.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
          if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
            console.info('Audio interruption: Recording is stopping...');
          } else {
            console.info('Audio interruption: Shared or temporary condition.');
          }
        });
      }

      await this.capturer.start();

      this.recordingData = [];
      this.isRecordingActive = true;
      this.isPaused = false;

      const bufferSize = 4096;
      this.readInterval = setInterval(async () => {
        if (this.isRecordingActive && !this.isPaused && this.capturer) {
          try {
            const buffer: ArrayBuffer = await this.capturer.read(bufferSize, true);
            if (buffer !== null && buffer.byteLength > 0) {
              this.recordingData.push(buffer);
              onDataAvailable(buffer);
              console.info(`Recorded chunk: ${buffer.byteLength} bytes`);
            }
          } catch (err) {
            console.error(`Read error: ${JSON.stringify(err)}`);
          }
        }
      }, 100);

      console.info('Recording started successfully');
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Start recording failed: ${error.code} - ${error.message}`);
      return false;
    }
  }

  private pauseRecordingInternal(): void {
    if (this.capturer && this.isRecordingActive && !this.isPaused) {
      this.isPaused = true;
      this.capturer.stop().catch((err: BusinessError) => {
        console.error(`Pause failed: ${err.code} - ${err.message}`);
      });
    }
  }

  async pauseRecording(): Promise<void> {
    this.pauseRecordingInternal();
  }

  async resumeRecording(): Promise<boolean> {
    if (this.capturer && this.isRecordingActive && this.isPaused) {
      try {
        await this.capturer.start();
        this.isPaused = false;
        return true;
      } catch (err) {
        const error = err as BusinessError;
        console.error(`Resume failed: ${error.code} - ${error.message}`);
        return false;
      }
    }
    return false;
  }

  async stopRecording(): Promise<ArrayBuffer> {
    if (!this.capturer) {
      return new ArrayBuffer(0);
    }

    if (this.readInterval !== -1) {
      clearInterval(this.readInterval);
      this.readInterval = -1;
    }

    try {
      await this.capturer.stop();
      await this.capturer.release();
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Stop/release error: ${error.code} - ${error.message}`);
    }

    this.capturer = null;
    this.isRecordingActive = false;
    this.isPaused = false;

    const totalLength = this.recordingData.reduce((sum: number, buf: ArrayBuffer) => sum + buf.byteLength, 0);
    console.info(`Total recorded data: ${totalLength} bytes`);

    if (totalLength === 0) {
      console.warn('No data recorded');
      return new ArrayBuffer(0);
    }

    const combined = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of this.recordingData) {
      const chunkArray = new Uint8Array(chunk);
      combined.set(chunkArray, offset);
      offset += chunkArray.length;
    }
    this.recordingData = [];
    return combined.buffer as ArrayBuffer;
  }

  async startPlayback(
    audioData: ArrayBuffer,
    onPlaybackEnd: () => void
  ): Promise<boolean> {
    await this.stopCurrentPlayback();

    this.currentAudioData = audioData;
    this.onPlaybackEndCallback = onPlaybackEnd;

    console.info(`Starting playback with data size: ${audioData.byteLength} bytes`);

    if (audioData.byteLength === 0) {
      console.error('No audio data to play');
      return false;
    }

    this.playback();
    return true;
  }

  private async playback(): Promise<void> {
    if (this.isPlayingBack) {
      return;
    }

    this.isPlayingBack = true;

    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      const rendererInfo: audio.AudioRendererInfo = {
        content: audio.ContentType.CONTENT_TYPE_SPEECH,
        usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION,
        rendererFlags: 0
      };

      const rendererOptions: audio.AudioRendererOptions = {
        streamInfo: audioStreamInfo,
        rendererInfo: rendererInfo
      };

      this.renderer = await audio.createAudioRenderer(rendererOptions);
      if (this.renderer !== undefined) {
        this.renderer.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
          if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
            console.info('Audio interruption: Recording is stopping...');
          } else {
            console.info('Audio interruption: Shared or temporary condition.');
          }
        });
        this.setupPlaybackDeviceChangeHandlers();
        this.attachPlaybackDeviceChangeListeners();
      }

      await this.renderer.start();
      console.info('AudioRenderer started');

      if (this.currentAudioData) {
        await this.renderer.write(this.currentAudioData);
      }

      console.info('Playback write completed');

      await this.renderer.stop();
      await this.renderer.release();
      this.renderer = null;

      this.isPlayingBack = false;

      if (this.onPlaybackEndCallback) {
        this.onPlaybackEndCallback();
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Playback failed: ${error.code} - ${error.message}`);
      this.isPlayingBack = false;
    }
  }

  async stopCurrentPlayback(): Promise<void> {
    if (this.isPlayingBack) {
      this.isPlayingBack = false;
    }

    if (this.renderer) {
      this.detachPlaybackDeviceChangeListeners();
      try {
        await this.renderer.stop();
        await this.renderer.release();
      } catch (err) {
        console.error(`Stop renderer error: ${JSON.stringify(err)}`);
      }
      this.renderer = null;
    }
  }

  async pausePlayback(): Promise<void> {
    if (this.renderer && this.isPlayingBack) {
      try {
        await this.renderer.stop();
        this.isPlayingBack = false;
        console.info('Playback paused');
      } catch (err) {
        console.error(`Pause playback error: ${JSON.stringify(err)}`);
      }
    }
  }

  async resumePlayback(): Promise<boolean> {
    if (this.renderer === null && this.currentAudioData && !this.isPlayingBack) {
      this.playback();
      return true;
    }
    return false;
  }

  async startPlaybackWithFade(
    audioData: ArrayBuffer,
    onPlaybackEnd: () => void,
  ): Promise<boolean> {
    return this.startPlayback(audioData, onPlaybackEnd);
  }

  async getOutputDevices(): Promise<audio.AudioDeviceDescriptor[]> {
    try {
      const audioManager = audio.getAudioManager();
      const devices = await audioManager.getDevices(audio.DeviceFlag.OUTPUT_DEVICES_FLAG);
      if (devices !== null && devices !== undefined) {
        return devices;
      }
      return [];
    } catch (err) {
      console.error(`Get devices failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  setInterruptHandler(handler: AudioInterruptHandler | null): void {
    this.interruptHandler = handler;
  }

  notifyCallInterrupt(isPause: boolean): void {
    if (isPause) {
      if (this.isRecordingActive && !this.isPaused) {
        this.pauseRecordingInternal();
        this.interruptHandler?.('pause');
      }
      if (this.renderer !== null && this.isPlayingBack) {
        this.pausePlayback();
        this.interruptHandler?.('pause');
      }
    } else {
      this.interruptHandler?.('resume');
    }
  }

  release(): void {
    if (this.readInterval !== -1) {
      clearInterval(this.readInterval);
      this.readInterval = -1;
    }

    if (this.capturer !== null) {
      try {
        this.capturer.release();
      } catch (err) {}
      this.capturer = null;
    }

    if (this.renderer !== null) {
      this.detachPlaybackDeviceChangeListeners();
      try {
        this.renderer.release();
      } catch (err) {}
      this.renderer = null;
    }

    this.isRecordingActive = false;
    this.isPaused = false;
    this.isPlayingBack = false;
  }
}