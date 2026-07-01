<template>
  <div class="digit-scanner-container">
    <!-- Image Loader / Camera Capture -->
    <div v-if="!imageSrc" class="loader-view">
      <div class="upload-card">
        <div class="card-icon">🔢</div>
        <h3>{{ messages.digitScanner.title }}</h3>
        <p>{{ messages.digitScanner.instructions }}</p>
        
        <button class="upload-btn" @click="triggerFileInput">
          {{ messages.digitScanner.captureButton }}
        </button>
        <input 
          type="file" 
          ref="fileInput" 
          accept="image/*" 
          capture="environment" 
          class="hidden-input" 
          @change="onFileChange" 
        />
      </div>
      
      <button class="outline secondary back-btn" @click="$emit('back')">
        {{ messages.digitScanner.backButton }}
      </button>
    </div>

    <!-- Image Editor & OCR View -->
    <div v-else class="editor-view">
      <!-- Toolbar Header -->
      <div class="editor-header">
        <button class="outline secondary compact-btn" @click="resetImage">
          ← {{ messages.digitScanner.backButton }}
        </button>
        <div class="tool-tabs">
          <button 
            :class="['tab-btn', activeTool === 'crop' ? 'active' : 'outline']"
            @click="setTool('crop')"
          >
            {{ messages.digitScanner.toolCrop }}
          </button>
          <button 
            :class="['tab-btn', activeTool === 'brush' ? 'active' : 'outline']"
            @click="setTool('brush')"
          >
            {{ messages.digitScanner.toolBrush }}
          </button>
        </div>
      </div>

      <!-- Main Viewport -->
      <div class="viewport-container">
        <!-- Crop Tool -->
        <div v-show="activeTool === 'crop'" class="cropper-wrapper">
          <Cropper
            ref="cropperRef"
            class="image-cropper"
            :src="imageSrc"
            :stencil-props="{
              aspectRatio: undefined
            }"
          />
        </div>

        <!-- Brush Tool -->
        <div v-show="activeTool === 'brush'" class="brush-wrapper">
          <canvas
            ref="brushCanvas"
            class="brush-canvas"
            @pointerdown="onPointerDown"
            @pointermove="onPointerMove"
            @pointerup="onPointerUp"
            @pointercancel="onPointerUp"
          ></canvas>

          <!-- Floating D-Pad Arrows for Navigation -->
          <div class="d-pad" v-if="scale > 1.0">
            <button class="d-pad-btn up" @click="pan(0, 80)">▲</button>
            <button class="d-pad-btn left" @click="pan(80, 0)">◀</button>
            <button class="d-pad-btn right" @click="pan(-80, 0)">▶</button>
            <button class="d-pad-btn down" @click="pan(0, -80)">▼</button>
          </div>

          <!-- Floating Zoom Controls -->
          <div class="zoom-controls">
            <button class="zoom-btn" @click="zoom(0.25)">+</button>
            <button class="zoom-btn" @click="zoom(-0.25)">-</button>
            <span class="zoom-label">{{ Math.round(scale * 100) }}%</span>
          </div>
        </div>
      </div>

      <!-- Brush Sub-controls -->
      <div v-if="activeTool === 'brush'" class="brush-settings">
        <label>
          {{ messages.digitScanner.brushSizeLabel }} {{ brushSize }}px
          <input 
            type="range" 
            min="5" 
            max="60" 
            v-model.number="brushSize" 
            class="brush-slider"
          />
        </label>
      </div>

      <!-- Action Buttons -->
      <div class="editor-actions">
        <button class="outline secondary" @click="clearWorkspace">
          {{ messages.digitScanner.clearButton }}
        </button>
        <button class="primary" :disabled="isProcessing" @click="processOCR">
          <span v-if="isProcessing">
            {{ messages.digitScanner.recognizing }}
            <span v-if="ocrProgress > 0">{{ ocrProgress }}%</span>
          </span>
          <span v-else>
            {{ messages.digitScanner.recognizeButton }}
          </span>
        </button>
      </div>
    </div>

    <!-- Error message display -->
    <div v-if="errorMessage" class="error-toast">
      {{ errorMessage }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue';
import { Cropper } from 'vue-advanced-cropper';
import 'vue-advanced-cropper/dist/style.css';
import { createWorker } from 'tesseract.js';
import { useWebAppHapticFeedback } from 'vue-tg';
import { useI18n } from '../composable/useI18n';

const emit = defineEmits<{
  (event: 'back'): void;
  (event: 'update:result', value: string | null): void;
}>();

const { messages } = useI18n();
const { impactOccurred, notificationOccurred } = useWebAppHapticFeedback();

// Image and Upload State
const imageSrc = ref<string | null>(null);
const fileInput = ref<HTMLInputElement | null>(null);
const errorMessage = ref<string | null>(null);

// Editor Setup
const activeTool = ref<'crop' | 'brush'>('crop');
const isProcessing = ref(false);
const ocrProgress = ref(0);

// Cropper reference
const cropperRef = ref<any>(null);

// Brush state
const brushCanvas = ref<HTMLCanvasElement | null>(null);
const brushSize = ref(20);
const scale = ref(1.0);
const offsetX = ref(0);
const offsetY = ref(0);
const isDrawing = ref(false);

interface Point {
  x: number;
  y: number;
}
interface Line {
  points: Point[];
  size: number;
}
const lines = ref<Line[]>([]);
const currentLine = ref<Line | null>(null);

// Original image dimension storage
let imgElement: HTMLImageElement | null = null;
let containerWidth = 0;
let containerHeight = 0;

function triggerFileInput() {
  fileInput.value?.click();
}

function onFileChange(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = (e) => {
    imageSrc.value = e.target?.result as string;
    errorMessage.value = null;
    impactOccurred('light');
    
    // Load image into HTMLImageElement to know dimensions for custom brush canvas
    imgElement = new Image();
    imgElement.onload = () => {
      resetBrushState();
      if (activeTool.value === 'brush') {
        nextTick(() => {
          initBrushCanvas();
        });
      }
    };
    imgElement.src = imageSrc.value;
  };
  reader.readAsDataURL(file);
}

function resetImage() {
  imageSrc.value = null;
  resetBrushState();
  if (fileInput.value) {
    fileInput.value.value = '';
  }
}

function setTool(tool: 'crop' | 'brush') {
  activeTool.value = tool;
  impactOccurred('light');
  if (tool === 'brush') {
    nextTick(() => {
      initBrushCanvas();
    });
  }
}

function resetBrushState() {
  scale.value = 1.0;
  offsetX.value = 0;
  offsetY.value = 0;
  lines.value = [];
  currentLine.value = null;
  isDrawing.value = false;
}

function clearWorkspace() {
  impactOccurred('medium');
  if (activeTool.value === 'crop') {
    cropperRef.value?.reset();
  } else {
    lines.value = [];
    redrawBrushCanvas();
  }
}

// Custom Brush Canvas Logic
function initBrushCanvas() {
  const canvas = brushCanvas.value;
  if (!canvas || !imgElement) return;

  // Set canvas visual size matching parent container
  const parent = canvas.parentElement;
  if (!parent) return;

  containerWidth = parent.clientWidth;
  containerHeight = parent.clientHeight;

  // Adjust canvas buffer resolution to screen resolution to look crisp
  const dpr = window.devicePixelRatio || 1;
  canvas.width = containerWidth * dpr;
  canvas.height = containerHeight * dpr;
  
  // Set default offsets to center the image within the container
  const imgAspect = imgElement.width / imgElement.height;
  const containerAspect = containerWidth / containerHeight;

  let startScale = 1;
  if (imgAspect > containerAspect) {
    // Width limited
    startScale = containerWidth / imgElement.width;
  } else {
    // Height limited
    startScale = containerHeight / imgElement.height;
  }

  scale.value = startScale;
  offsetX.value = (containerWidth - imgElement.width * startScale) / 2;
  offsetY.value = (containerHeight - imgElement.height * startScale) / 2;

  redrawBrushCanvas();
}

function redrawBrushCanvas() {
  const canvas = brushCanvas.value;
  if (!canvas || !imgElement) return;

  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const dpr = window.devicePixelRatio || 1;

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  ctx.save();
  // Apply DPR scaling
  ctx.scale(dpr, dpr);
  // Apply viewport zoom & pan transformations
  ctx.translate(offsetX.value, offsetY.value);
  ctx.scale(scale.value, scale.value);

  // 1. Draw photo
  ctx.drawImage(imgElement, 0, 0);

  // 2. Draw brush mask overlay
  ctx.strokeStyle = 'rgba(0, 230, 118, 0.45)'; // Semi-transparent neon green
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  for (const line of lines.value) {
    if (line.points.length === 0) continue;
    ctx.lineWidth = line.size;
    ctx.beginPath();
    ctx.moveTo(line.points[0].x, line.points[0].y);
    for (let i = 1; i < line.points.length; i++) {
      ctx.lineTo(line.points[i].x, line.points[i].y);
    }
    ctx.stroke();
  }

  ctx.restore();
}

// Convert screen coordinates to original image space coordinates
function getPhotoCoordinates(event: PointerEvent): Point {
  const canvas = brushCanvas.value;
  if (!canvas) return { x: 0, y: 0 };

  const rect = canvas.getBoundingClientRect();
  const screenX = event.clientX - rect.left;
  const screenY = event.clientY - rect.top;

  // Map to container coordinates
  const canvasX = (screenX / rect.width) * containerWidth;
  const canvasY = (screenY / rect.height) * containerHeight;

  // Translate based on scale and offset
  return {
    x: (canvasX - offsetX.value) / scale.value,
    y: (canvasY - offsetY.value) / scale.value
  };
}

function onPointerDown(event: PointerEvent) {
  if (isProcessing.value) return;
  const canvas = brushCanvas.value;
  if (!canvas) return;
  canvas.setPointerCapture(event.pointerId);

  isDrawing.value = true;
  const pt = getPhotoCoordinates(event);
  
  // Store line size in "original photo pixel units" so it resizes correctly with scale
  const originalSize = brushSize.value / scale.value;

  currentLine.value = {
    points: [pt],
    size: originalSize
  };
  lines.value.push(currentLine.value);
  redrawBrushCanvas();
}

function onPointerMove(event: PointerEvent) {
  if (!isDrawing.value || !currentLine.value) return;
  const pt = getPhotoCoordinates(event);
  currentLine.value.points.push(pt);
  redrawBrushCanvas();
}

function onPointerUp(event: PointerEvent) {
  if (!isDrawing.value) return;
  const canvas = brushCanvas.value;
  if (canvas) {
    try {
      canvas.releasePointerCapture(event.pointerId);
    } catch {}
  }
  isDrawing.value = false;
  currentLine.value = null;
  impactOccurred('light');
}

// Zoom & Pan Operations
function zoom(change: number) {
  const oldScale = scale.value;
  const newScale = Math.max(0.1, Math.min(6.0, oldScale + change));
  
  // Zoom relative to the center of the container
  const centerX = containerWidth / 2;
  const centerY = containerHeight / 2;

  offsetX.value = centerX - ((centerX - offsetX.value) * newScale) / oldScale;
  offsetY.value = centerY - ((centerY - offsetY.value) * newScale) / oldScale;
  scale.value = newScale;

  redrawBrushCanvas();
  impactOccurred('light');
}

function pan(dx: number, dy: number) {
  offsetX.value += dx;
  offsetY.value += dy;
  redrawBrushCanvas();
  impactOccurred('light');
}

// Execute OCR Recognition
async function processOCR() {
  if (!imgElement) return;
  isProcessing.value = true;
  ocrProgress.value = 0;
  errorMessage.value = null;
  impactOccurred('medium');

  let ocrCanvas: HTMLCanvasElement;

  try {
    if (activeTool.value === 'crop') {
      // 1. Get canvas from the cropper
      const cropResult = cropperRef.value?.getResult();
      if (!cropResult || !cropResult.canvas) {
        throw new Error('Please select a valid region.');
      }
      ocrCanvas = cropResult.canvas;
    } else {
      // 2. Perform Brush masking logic
      if (lines.value.length === 0) {
        throw new Error('Please highlight digits using the brush first.');
      }

      ocrCanvas = document.createElement('canvas');
      ocrCanvas.width = imgElement.width;
      ocrCanvas.height = imgElement.height;
      const ctx = ocrCanvas.getContext('2d');
      if (!ctx) throw new Error('Could not initialize canvas context.');

      // Solid white background
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, ocrCanvas.width, ocrCanvas.height);

      // Create a temporary canvas for the brush mask
      const maskCanvas = document.createElement('canvas');
      maskCanvas.width = imgElement.width;
      maskCanvas.height = imgElement.height;
      const maskCtx = maskCanvas.getContext('2d');
      if (!maskCtx) throw new Error('Could not create mask canvas.');

      // Clear mask to fully transparent
      maskCtx.clearRect(0, 0, maskCanvas.width, maskCanvas.height);
      maskCtx.strokeStyle = '#ffffff';
      maskCtx.lineCap = 'round';
      maskCtx.lineJoin = 'round';

      // Draw all lines onto mask
      for (const line of lines.value) {
        if (line.points.length === 0) continue;
        maskCtx.lineWidth = line.size;
        maskCtx.beginPath();
        maskCtx.moveTo(line.points[0].x, line.points[0].y);
        for (let i = 1; i < line.points.length; i++) {
          maskCtx.lineTo(line.points[i].x, line.points[i].y);
        }
        maskCtx.stroke();
      }

      // Draw original image on temp canvas
      const tempCanvas = document.createElement('canvas');
      tempCanvas.width = imgElement.width;
      tempCanvas.height = imgElement.height;
      const tempCtx = tempCanvas.getContext('2d');
      if (!tempCtx) throw new Error('Could not create temp canvas.');
      tempCtx.drawImage(imgElement, 0, 0);

      // Destination-in keeps original pixels only where mask is drawn (opaque white)
      tempCtx.globalCompositeOperation = 'destination-in';
      tempCtx.drawImage(maskCanvas, 0, 0);

      // Draw transparent cutout onto final white canvas
      ctx.drawImage(tempCanvas, 0, 0);
    }

    // Initialize Tesseract.js Worker
    const worker = await createWorker('eng', 1, {
      logger: (m) => {
        if (m.status === 'recognizing text') {
          ocrProgress.value = Math.round(m.progress * 100);
        }
      }
    });

    await worker.setParameters({
      tessedit_char_whitelist: '0123456789 \n',
    });

    const { data: { text } } = await worker.recognize(ocrCanvas);
    await worker.terminate();

    // Parse output digits and combine with commas
    const matchedDigits = text.match(/\d+/g);
    if (!matchedDigits || matchedDigits.length === 0) {
      throw new Error(messages.digitScanner.noDigitsFound);
    }

    const commaSeparatedResult = matchedDigits.join(', ');
    
    // Fire haptic success feedback
    notificationOccurred('success');
    
    // Return final result
    emit('update:result', commaSeparatedResult);

  } catch (error: any) {
    console.error('OCR recognition failed:', error);
    errorMessage.value = error.message || 'Error occurred during recognition.';
    notificationOccurred('error');
  } finally {
    isProcessing.value = false;
    ocrProgress.value = 0;
  }
}

// Redraw canvas if window resizes (only in brush mode)
function onResize() {
  if (activeTool.value === 'brush' && imageSrc.value) {
    initBrushCanvas();
  }
}

onMounted(() => {
  window.addEventListener('resize', onResize);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize);
  imgElement = null;
});
</script>

<style scoped>
.digit-scanner-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  width: 100%;
  min-height: 80vh;
  box-sizing: border-box;
  color: var(--tg-theme-text-color, #333);
  padding-top: 16px;
}

/* Photo Selection Screen */
.loader-view {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  width: 100%;
  max-width: 420px;
  padding: 16px;
}

.upload-card {
  width: 100%;
  padding: 24px 16px;
  border-radius: 12px;
  border: 1px solid var(--tg-theme-hint-color, rgba(0, 0, 0, 0.1));
  background-color: var(--tg-theme-bg-color, #fff);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  backdrop-filter: blur(10px);
}

.upload-card h3 {
  font-size: 18px;
  margin: 0;
}

.upload-card p {
  font-size: 13px;
  margin: 0 0 8px 0;
}

.card-icon {
  font-size: 36px;
  margin-bottom: 4px;
  animation: bounce 2s infinite alternate;
}

.upload-btn {
  width: 100%;
  padding: 10px 16px;
  font-size: 14px;
  font-weight: 600;
  border-radius: 8px;
  border: none;
  background-color: var(--tg-theme-button-color, #2481cc);
  color: var(--tg-theme-button-text-color, #fff);
  cursor: pointer;
  transition: opacity 0.2s ease;
}

.upload-btn:hover {
  opacity: 0.9;
}

.hidden-input {
  display: none;
}

.back-btn {
  margin-top: 5px;
}

/* Editor View Layout */
.editor-view {
  display: flex;
  flex-direction: column;
  width: 100%;
  max-width: 500px;
  height: 85vh;
  padding: 10px;
  box-sizing: border-box;
  gap: 10px;
}

.editor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.compact-btn {
  padding: 5px 10px;
  font-size: 13px;
  border-radius: 6px;
  margin: 0;
}

.tool-tabs {
  display: flex;
  gap: 6px;
}

.tab-btn {
  padding: 5px 12px;
  font-size: 13px;
  border-radius: 6px;
  margin: 0;
  cursor: pointer;
}

.tab-btn.active {
  background-color: var(--tg-theme-button-color, #2481cc);
  color: var(--tg-theme-button-text-color, #fff);
  border: 1px solid var(--tg-theme-button-color, #2481cc);
}

/* Viewport area */
.viewport-container {
  flex: 1;
  width: 100%;
  border-radius: 12px;
  background-color: #121212;
  border: 1px solid #2d2d2d;
  overflow: hidden;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.cropper-wrapper, 
.brush-wrapper {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.image-cropper {
  width: 100%;
  height: 100%;
}

.brush-canvas {
  width: 100%;
  height: 100%;
  touch-action: none;
  cursor: crosshair;
}

/* D-Pad Floating controls */
.d-pad {
  position: absolute;
  bottom: 12px;
  right: 12px;
  width: 80px;
  height: 80px;
  display: grid;
  grid-template-areas:
    ".    up    ."
    "left .     right"
    ".    down  .";
  gap: 2px;
  z-index: 50;
}

.d-pad-btn {
  background: rgba(30, 30, 30, 0.75);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.25);
  padding: 0;
  margin: 0;
  border-radius: 50%;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  backdrop-filter: blur(4px);
  width: 24px;
  height: 24px;
}

.d-pad-btn:active {
  background: rgba(36, 129, 204, 0.9);
  border-color: #2481cc;
}

.d-pad-btn.up { grid-area: up; justify-self: center; }
.d-pad-btn.down { grid-area: down; justify-self: center; }
.d-pad-btn.left { grid-area: left; align-self: center; }
.d-pad-btn.right { grid-area: right; align-self: center; }

/* Floating Zoom Controls */
.zoom-controls {
  position: absolute;
  top: 12px;
  right: 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  align-items: center;
  z-index: 50;
}

.zoom-btn {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgba(30, 30, 30, 0.75);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.25);
  font-size: 14px;
  font-weight: bold;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0;
  padding: 0;
  cursor: pointer;
  backdrop-filter: blur(4px);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.zoom-btn:active {
  background: rgba(36, 129, 204, 0.9);
}

.zoom-label {
  font-size: 11px;
  color: #e0e0e0;
  background: rgba(0, 0, 0, 0.6);
  padding: 2px 6px;
  border-radius: 4px;
}

/* Brush Subsettings */
.brush-settings {
  padding: 4px 8px;
  background-color: var(--tg-theme-bg-color, #fff);
  border: 1px solid var(--tg-theme-hint-color, rgba(0, 0, 0, 0.1));
  border-radius: 8px;
}

.brush-settings label {
  font-size: 13px;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.brush-slider {
  margin: 0;
}

/* Bottom Action Buttons */
.editor-actions {
  display: flex;
  gap: 12px;
  width: 100%;
}

.editor-actions button {
  flex: 1;
  margin: 0;
  padding: 10px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
}

/* Error Toast Alert */
.error-toast {
  position: fixed;
  bottom: 80px;
  left: 50%;
  transform: translateX(-50%);
  background-color: #d32f2f;
  color: #fff;
  padding: 10px 20px;
  border-radius: 8px;
  font-size: 14px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
  z-index: 1000;
  text-align: center;
  max-width: 90%;
  animation: fadeInOut 4s ease forwards;
}

@keyframes bounce {
  0% { transform: translateY(0); }
  100% { transform: translateY(-8px); }
}

@keyframes fadeInOut {
  0% { opacity: 0; transform: translate(-50%, 10px); }
  10% { opacity: 1; transform: translate(-50%, 0); }
  90% { opacity: 1; transform: translate(-50%, 0); }
  100% { opacity: 0; transform: translate(-50%, -10px); }
}
</style>
