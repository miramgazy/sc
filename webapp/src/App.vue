<template>
  <main class="container-fluid app-main">
    <div v-if="!result" class="full-width">
      <!-- Mode Selection Screen -->
      <div v-if="scanMode === 'none'" class="selection-container">
        <header class="selection-header">
          <h1>{{ messages.modeSelection.title }}</h1>
        </header>
        
        <div class="modes-grid">
          <article class="mode-card" @click="selectMode('barcode')">
            <div class="mode-icon">📷</div>
            <h2>{{ messages.modeSelection.barcodeMode }}</h2>
          </article>

          <article class="mode-card" @click="selectMode('digits')">
            <div class="mode-icon">🔢</div>
            <h2>{{ messages.modeSelection.digitMode }}</h2>
          </article>
        </div>
      </div>

      <!-- Barcode / QR Scanner Mode -->
      <div v-else-if="scanMode === 'barcode'" class="scanner-wrapper">
        <div class="back-floating-header">
          <button class="outline secondary back-icon-btn" @click="scanMode = 'none'">
            ← {{ messages.digitScanner.backButton }}
          </button>
        </div>
        <QrScanner v-model:result="result" />
      </div>

      <!-- Digit Recognition Mode -->
      <div v-else-if="scanMode === 'digits'">
        <DigitScanner v-model:result="result" @back="scanMode = 'none'" />
      </div>
    </div>

    <!-- Scan Result View -->
    <div v-else class="result-container">
      <ScanResult :value="result" />
    </div>
  </main>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { useWebApp, useWebAppTheme, useWebAppClosingConfirmation, useWebAppHapticFeedback } from 'vue-tg';
import QrScanner from './components/QrScanner.vue'
import DigitScanner from './components/DigitScanner.vue'
import ScanResult from './components/ScanResult.vue'
import { useI18n } from './composable/useI18n.ts'

const result = ref<string | null>(null)
const scanMode = ref<'none' | 'barcode' | 'digits'>('none')

const { ready } = useWebApp()
const { onThemeChanged, colorScheme } = useWebAppTheme()
const { enableClosingConfirmation } = useWebAppClosingConfirmation()
const { changeLocale, messages } = useI18n()
const { impactOccurred } = useWebAppHapticFeedback()

function setLocale() {
  const browserLanguageCode = navigator.language.slice(0, 2).toLowerCase()
  changeLocale(browserLanguageCode)
}

function updateTheme() {
  document.documentElement.setAttribute('data-theme', colorScheme.value)
}

function selectMode(mode: 'barcode' | 'digits') {
  scanMode.value = mode
  impactOccurred('medium')
}

watch(result, (newVal) => {
  if (newVal) {
    enableClosingConfirmation()
  } else {
    scanMode.value = 'none'
  }
})
onThemeChanged(updateTheme)

setLocale()
updateTheme()
ready()
</script>

<style scoped>
.app-main {
  padding: 16px;
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  justify-content: center;
  align-items: center;
  box-sizing: border-box;
}

.full-width {
  width: 100%;
}

.selection-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 24px;
  width: 100%;
  max-width: 500px;
  margin: 0 auto;
}

.selection-header {
  text-align: center;
  margin-bottom: 12px;
}

.selection-header h1 {
  font-size: 24px;
  font-weight: 700;
  margin: 0;
  color: var(--tg-theme-text-color, #333);
}

.modes-grid {
  display: flex;
  flex-direction: column;
  gap: 16px;
  width: 100%;
}

.mode-card {
  cursor: pointer;
  padding: 24px;
  border-radius: 16px;
  background: var(--tg-theme-secondary-bg-color, #f4f4f4);
  border: 1px solid var(--tg-theme-hint-color, rgba(0, 0, 0, 0.08));
  text-align: center;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  margin: 0;
}

.mode-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
}

.mode-card:active {
  transform: scale(0.98);
}

.mode-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.mode-card h2 {
  font-size: 18px;
  margin: 0;
  color: var(--tg-theme-text-color, #333);
}

.scanner-wrapper {
  position: fixed;
  inset: 0;
  width: 100vw;
  height: 100vh;
  z-index: 1000;
}

.back-floating-header {
  position: absolute;
  top: max(16px, env(safe-area-inset-top));
  left: 16px;
  z-index: 1100;
}

.back-icon-btn {
  margin: 0;
  padding: 8px 16px;
  font-size: 14px;
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.6);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.25);
  backdrop-filter: blur(4px);
  cursor: pointer;
}

.back-icon-btn:active {
  background: rgba(36, 129, 204, 0.9);
}

.result-container {
  width: 100%;
  max-width: 500px;
  margin: 0 auto;
}
</style>