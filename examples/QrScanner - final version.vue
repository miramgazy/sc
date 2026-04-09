<template>
  <div class="scanner-container">
    <QrcodeStream
      v-if="isScanning"
      :constraints="{ facingMode: 'environment' }"
      :formats="['qr_code', 'code_128']"
      @detect="onDetect"
      @init="onInit"
      :paused="!isScanning"
    />

    <p v-if="loading && isScanning" class="loading-text">
      Загрузка камеры...
    </p>

    <p v-else-if="error" class="error-text">
      ОШИБКА: {{ error }}
    </p>

    <MainButton
      :disabled="false"
      :progress="loading && isScanning"
      :text="isScanning ? 'Идет сканирование (Нажмите для отмены)' : 'Открыть сканер (QR / ШК)'"
      :color="themeParams.secondary_bg_color"
      :text-color="themeParams.text_color"
      @click="toggleScanner"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { QrcodeStream } from 'vue-qrcode-reader'
import {
  MainButton,
  useWebAppTheme,
  useWebAppHapticFeedback,
} from 'vue-tg'

// ✅ 1. Регистрируем пропс, но не присваиваем его переменной
defineProps<{ result: string | null }>(); 
const emit = defineEmits(['update:result']); 

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
    emit('update:result', null); 
  } else {
    loading.value = false
  }
}

function onDetect(detectedCodes: any[]) {
  if (detectedCodes && detectedCodes.length > 0) {
    const detected = detectedCodes[0]

    if (detected.rawValue && detected.rawValue.length > 5 && isScanning.value) { 
      impactOccurred('heavy')
      
      // ✅ 2. Явный вызов emit для обновления App.vue
      emit('update:result', detected.rawValue); 
      
      isScanning.value = false
      loading.value = false
    }
  }
}

async function onInit(promise: Promise<void>) {
    try {
        await promise
        loading.value = false
    } catch (err: any) {
        loading.value = false
        isScanning.value = false

        let errorMessage = 'Неизвестная ошибка камеры.'
        if (err.name === 'NotAllowedError') {
            errorMessage = 'Доступ к камере запрещен пользователем.'
        } else if (err.name === 'NotReadableError') {
            errorMessage = 'Камера уже используется другим приложением.'
        } else if (err.name === 'NotFoundError') {
            errorMessage = 'Камера не найдена на устройстве.'
        }
        error.value = errorMessage
    }
}
</script>

<style scoped>
/* Стили остаются прежними */
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
  background-color: rgba(0, 0, 0, 0.7);
  padding: 10px 20px;
  border-radius: 5px;
  text-align: center;
}

.telegram-web-app-main-button {
  z-index: 100;
  margin-bottom: 20px;
}
</style>