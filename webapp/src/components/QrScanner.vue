<template>
  <div class="scanner-container">
    <QrcodeStream
      v-if="isScanning"
      :constraints="{ facingMode: 'environment' }"
      :formats="['qr_code', 'code_128', 'ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_39', 'code_93', 'itf', 'codabar']"
      @detect="onDetect"
      @init="onInit"
      :paused="!isScanning"
    />

    <p v-if="loading && isScanning" class="loading-text">
      Loading camera...
    </p>

    <p v-else-if="error" class="error-text">
      ERROR: {{ error }}
    </p>

    <MainButton
      :disabled="false"
      :progress="loading && isScanning"
      :text="isScanning ? 'Scanning... Tap to cancel' : 'Open scanner (QR / Barcode)'"
      :color="themeParams.secondary_bg_color"
      :text-color="themeParams.text_color"
      @click="toggleScanner"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { QrcodeStream } from 'vue-qrcode-reader'
import {
  MainButton,
  useWebAppTheme,
  useWebAppHapticFeedback,
} from 'vue-tg';

defineProps<{ result: string | null }>()
const emit = defineEmits<{
  (event: 'update:result', value: string | null): void
}>()

const loading = ref(false)
const isScanning = ref(false)
const error = ref<string | null>(null)

const { impactOccurred } = useWebAppHapticFeedback()
const { themeParams } = useWebAppTheme()

function toggleScanner() {
  isScanning.value = !isScanning.value
  if (isScanning.value) {
    loading.value = true
    error.value = null
    emit('update:result', null)
  } else {
    loading.value = false
  }
}

function onDetect(detectedCodes: Array<{ rawValue?: string }>) {
  if (!detectedCodes || detectedCodes.length === 0 || !isScanning.value) {
    return
  }

  const detectedValue = detectedCodes[0]?.rawValue
  if (detectedValue && detectedValue.length > 5) {
    impactOccurred('heavy')
    emit('update:result', detectedValue)
    isScanning.value = false
    loading.value = false
  }
}

async function onInit(promise: Promise<void>) {
  try {
    await promise
    loading.value = false
  } catch (caughtError: unknown) {
    loading.value = false
    isScanning.value = false

    let errorMessage = 'Unknown camera error.'
    if (caughtError instanceof Error) {
      if (caughtError.name === 'NotAllowedError') {
        errorMessage = 'Camera permission was denied.'
      } else if (caughtError.name === 'NotReadableError') {
        errorMessage = 'Camera is already used by another app.'
      } else if (caughtError.name === 'NotFoundError') {
        errorMessage = 'No camera found on this device.'
      }
    }

    error.value = errorMessage
  }
}
</script>

<style scoped>
.scanner-container {
  width: 100vw;
  height: 100vh;
  position: fixed;
  top: 0;
  left: 0;
  z-index: 1000;
  background-color: #000;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
}

.scanner-container :deep(video) {
  width: 100%;
  height: 100%;
  object-fit: cover;
  position: absolute;
  top: 0;
  left: 0;
  z-index: 1;
}

.scanner-container :deep(> div) {
  width: 100%;
  height: 100%;
  position: absolute;
  top: 0;
  left: 0;
  z-index: 1;
}

.loading-text,
.error-text {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  color: #fff;
  z-index: 50;
  background-color: rgb(0 0 0 / 70%);
  padding: 10px 20px;
  border-radius: 5px;
  text-align: center;
}

.telegram-web-app-main-button {
  z-index: 100;
  margin-bottom: 20px;
}
</style>
