import { copyText } from './clipboard'
import { useI18n } from './i18n'
import { useToast } from './toast'

/** Returns a copy(text) function that copies (HTTP-safe) and toasts the result. */
export function useCopy() {
  const toast = useToast()
  const { t } = useI18n()
  return (text: string) => toast(copyText(text) ? t('copied') : t('copyFailed'))
}
