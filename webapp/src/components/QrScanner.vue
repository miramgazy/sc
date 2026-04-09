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

    <div v-if="isScanning" class="scanner-overlay" aria-hidden="true">
      <div class="scan-window">
        <div class="scan-corners">
          <span class="corner corner-tl" />
          <span class="corner corner-tr" />
          <span class="corner corner-bl" />
          <span class="corner corner-br" />
        </div>
        <span class="scan-line" />
      </div>
      <p class="scan-hint">Align QR or barcode inside the frame</p>
    </div>

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

.scanner-overlay {
  position: absolute;
  inset: 0;
  z-index: 20;
  pointer-events: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 18px;
  padding: 16px;
  background: rgb(0 0 0 / 52%);
}

.scan-window {
  position: relative;
  width: min(78vw, 360px);
  aspect-ratio: 1 / 1;
  max-height: min(55vh, 360px);
  border: 1px solid rgb(255 255 255 / 18%);
  border-radius: 16px;
  box-shadow: 0 0 0 200vmax rgb(0 0 0 / 0%);
  overflow: hidden;
  background: transparent;
}

.scan-corners {
  position: absolute;
  inset: 0;
}

.corner {
  position: absolute;
  width: 34px;
  height: 34px;
  border-color: #effff2;
  border-style: solid;
  border-width: 0;
}

.corner-tl {
  top: 0;
  left: 0;
  border-top-width: 4px;
  border-left-width: 4px;
  border-top-left-radius: 12px;
}

.corner-tr {
  top: 0;
  right: 0;
  border-top-width: 4px;
  border-right-width: 4px;
  border-top-right-radius: 12px;
}

.corner-bl {
  bottom: 0;
  left: 0;
  border-bottom-width: 4px;
  border-left-width: 4px;
  border-bottom-left-radius: 12px;
}

.corner-br {
  right: 0;
  bottom: 0;
  border-right-width: 4px;
  border-bottom-width: 4px;
  border-bottom-right-radius: 12px;
}

.scan-line {
  position: absolute;
  left: 7%;
  width: 86%;
  height: 2px;
  border-radius: 999px;
  background: linear-gradient(90deg, rgb(190 255 208 / 0%), rgb(190 255 208 / 92%), rgb(190 255 208 / 0%));
  animation: scan-move 2.2s ease-in-out infinite;
}

.scan-hint {
  margin: 0;
  max-width: min(88vw, 420px);
  text-align: center;
  color: #fff;
  font-size: 14px;
  line-height: 1.35;
  padding: 8px 12px;
  border-radius: 10px;
  background: rgb(0 0 0 / 38%);
  backdrop-filter: blur(2px);
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

@keyframes scan-move {
  0% {
    top: 10%;
    opacity: 0.4;
  }
  50% {
    top: calc(100% - 12%);
    opacity: 1;
  }
  100% {
    top: 10%;
    opacity: 0.4;
  }
}

@media (max-height: 720px) {
  .scan-window {
    width: min(72vw, 300px);
  }
  .scan-hint {
    font-size: 13px;
  }
}
</style>
