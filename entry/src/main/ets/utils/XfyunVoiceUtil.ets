export interface XfyunVoiceOption {
  label: string
  voice: string
  supportedSampleRates: number[]
}

export const DEFAULT_XFYUN_VOICE: string = 'x4_lingxiaoxuan_em_v2'

export const FALLBACK_XFYUN_VOICE_OPTIONS: XfyunVoiceOption[] = [
  { label: '聆小璇', voice: 'x4_lingxiaoxuan_em_v2', supportedSampleRates: [16000] },
  { label: '小露', voice: 'x4_yezi', supportedSampleRates: [16000] },
  { label: '聆小璎', voice: 'x4_lingxiaoying_em_v2', supportedSampleRates: [16000] },
  { label: '聆小瑶', voice: 'x4_lingxiaoyao_em', supportedSampleRates: [16000] },
  { label: '反派老人', voice: 'x4_lingbosong_bad_talk', supportedSampleRates: [16000] }
]

export function getXfyunVoiceLabel(option: XfyunVoiceOption): string {
  if (option.label && option.label.trim().length > 0) {
    return option.label
  }
  return option.voice
}

export function getXfyunVoiceOptions(options: XfyunVoiceOption[]): XfyunVoiceOption[] {
  return options.length > 0 ? options : FALLBACK_XFYUN_VOICE_OPTIONS
}

export function normalizeXfyunVoiceId(
  voiceId?: string,
  options: XfyunVoiceOption[] = FALLBACK_XFYUN_VOICE_OPTIONS
): string {
  if (!voiceId) {
    return DEFAULT_XFYUN_VOICE
  }

  const normalized: string = voiceId.trim()
  if (normalized.length === 0 || normalized === 'undefined' || normalized === 'null' || /^\d+$/.test(normalized)) {
    return DEFAULT_XFYUN_VOICE
  }

  const availableOptions: XfyunVoiceOption[] = getXfyunVoiceOptions(options)
  for (let i = 0; i < availableOptions.length; i++) {
    const option: XfyunVoiceOption = availableOptions[i]
    if (option.voice.toLowerCase() === normalized.toLowerCase() || option.label === normalized) {
      return option.voice
    }
  }

  const aliasVoice: string = getLegacyVoiceAlias(normalized)
  if (aliasVoice.length > 0) {
    for (let i = 0; i < availableOptions.length; i++) {
      if (availableOptions[i].voice === aliasVoice) {
        return aliasVoice
      }
    }
    return DEFAULT_XFYUN_VOICE
  }

  return DEFAULT_XFYUN_VOICE
}

function getLegacyVoiceAlias(voiceId: string): string {
  switch (voiceId) {
    case 'zhiqi':
    case 'zhiwei':
    case 'sitong':
    case 'zhiqian':
    case 'zhixiaoxia':
    case '知琪':
    case '知薇':
    case '思彤':
    case '知倩':
    case '知小夏':
    case 'zhifeng_emo':
    case 'zhibing_emo':
    case '知锋_多情感':
    case '知冰_多情感':
    case 'xiaoyan':
    case '小燕':
    case 'aisjiuxu':
    case '许久':
    case 'aisxping':
    case '小萍':
    case 'xiaofeng':
    case '小峰':
      return DEFAULT_XFYUN_VOICE
    case 'sicheng':
    case '思诚':
    case 'zhixiaomei':
    case 'ninger':
    case 'ruoxi':
    case '知小妹':
    case '宁儿':
    case '若兮':
    case 'xiaobei':
    case '小北':
      return DEFAULT_XFYUN_VOICE
    default:
      return ''
  }
}
