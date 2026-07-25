import audio from '@ohos.multimedia.audio'

export class IntercomService {
  private static readonly SILENCE_PEAK_THRESHOLD: number = 160
  private static readonly SILENCE_AVG_THRESHOLD: number = 48
  private capturer: audio.AudioCapturer | null = null
  private readCallback: ((data: ArrayBuffer) => void) | null = null
  private active: boolean = false

  async start(onPcmData: (data: ArrayBuffer) => void): Promise<void> {
    if (this.active) {
      return
    }

    const options: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION,
        capturerFlags: 0
      }
    }

    this.capturer = await audio.createAudioCapturer(options)
    this.readCallback = (data: ArrayBuffer): void => {
      if (!this.active || data.byteLength === 0) {
        return
      }
      onPcmData(this.applyNoiseGate(data))
    }
    this.capturer.on('readData', this.readCallback)
    await this.capturer.start()
    this.active = true
  }

  async stop(): Promise<void> {
    this.active = false

    if (this.capturer == null) {
      return
    }

    try {
      if (this.readCallback) {
        this.capturer.off('readData', this.readCallback)
      }
    } catch (e) {
      console.warn('Intercom off(readData) failed:', JSON.stringify(e))
    }

    try {
      await this.capturer.stop()
    } catch (e) {
      console.warn('Intercom stop failed:', JSON.stringify(e))
    }

    try {
      await this.capturer.release()
    } catch (e) {
      console.warn('Intercom release failed:', JSON.stringify(e))
    }

    this.capturer = null
    this.readCallback = null
  }

  isActive(): boolean {
    return this.active
  }

  private applyNoiseGate(data: ArrayBuffer): ArrayBuffer {
    const source = new Int16Array(data)
    if (source.length === 0) {
      return data
    }

    let peak: number = 0
    let sumAbs: number = 0
    for (let i = 0; i < source.length; i++) {
      let sample = source[i]
      if (sample < 0) {
        sample = -sample
      }
      if (sample > peak) {
        peak = sample
      }
      sumAbs += sample
    }

    const avgAbs: number = Math.floor(sumAbs / source.length)
    if (peak <= IntercomService.SILENCE_PEAK_THRESHOLD && avgAbs <= IntercomService.SILENCE_AVG_THRESHOLD) {
      return new ArrayBuffer(data.byteLength)
    }
    return data
  }
}
