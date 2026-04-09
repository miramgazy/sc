<template>
    <article>{{ props.value }}</article>
    <div>
        <div v-if="isValidLink">
            <button class="outline" @click="handleOpenLinkButton">
                <linkIcon class="icon" />
                {{ messages.scanResult.openLink }}
            </button>
        </div>
        <div>
            <button @click="handleSendButton" :disabled="isSending">
                <tgIcon class="icon" />
                {{ isSending ? 'Отправка...' : messages.scanResult.send }}
            </button>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
// useWebApp должен быть импортирован для initData и close
import { useWebAppNavigation, useWebAppHapticFeedback, useWebApp } from 'vue-tg'; 
import { isValidUrl } from '../helpers/url.ts';
import linkIcon from '../assets/link.svg'
import tgIcon from '../assets/telegram.svg'
import { useI18n } from '../composable/useI18n';

const props = defineProps<{ value: string }>();
const isValidLink = computed(() => isValidUrl(props.value))
const isSending = ref(false); 
const WEBHOOK_URL = 'https://n8n.medinamoda.kz/webhook-test/qr_scan_tool';

const { openLink } = useWebAppNavigation()
// Получаем close и initData. В вашей версии initData, вероятно, не является Ref.
const { close, initData } = useWebApp() 
const { messages } = useI18n()
const { notificationOccurred } = useWebAppHapticFeedback(); 

function handleOpenLinkButton() {
    openLink(props.value, {
        try_instant_view: true
    })
}

async function handleSendButton() {
    isSending.value = true;
    try {
        const payload = {
            scan_result: props.value,
            // ИСПРАВЛЕНИЕ TS2551: initData используется напрямую без .value
            init_data: initData, 
            timestamp: new Date().toISOString()
        };

        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });

        if (response.ok) {
            console.log('Данные успешно отправлены на вебхук!');
            notificationOccurred('success'); 
            // Закрываем Mini App после успешной отправки
            close(); 
        } else {
            console.error('Ошибка HTTP:', response.status, await response.text());
            notificationOccurred('error'); 
        }
    } catch (error) {
        console.error('Ошибка отправки на вебхук:', error);
        notificationOccurred('error'); 
    } finally {
        isSending.value = false;
    }
}
</script>

<style scoped>
.icon {
    height: 20px;
    width: 20px;
}
</style>