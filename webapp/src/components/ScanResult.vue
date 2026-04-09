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
                {{ isSending ? 'Sending...' : messages.scanResult.send }}
            </button>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useWebApp, useWebAppHapticFeedback, useWebAppNavigation } from 'vue-tg';
import { isValidUrl } from '../helpers/url.ts';
import linkIcon from '../assets/link.svg'
import tgIcon from '../assets/telegram.svg'
import { useI18n } from '../composable/useI18n';

const props = defineProps<{ value: string }>();
const isValidLink = computed(() => isValidUrl(props.value))
const isSending = ref(false)
const webhookUrl = import.meta.env.VITE_SCAN_WEBHOOK_URL?.trim()

const { openLink, switchInlineQuery } = useWebAppNavigation()
const { notificationOccurred } = useWebAppHapticFeedback()
const { close, initData } = useWebApp()
const { messages } = useI18n()

function handleOpenLinkButton() {
    openLink(props.value, {
        try_instant_view: true
    })
}

async function handleSendButton() {
    if (!webhookUrl) {
        const inlineSendResultPrefix = "# "
        switchInlineQuery(`${inlineSendResultPrefix}${props.value}`)
        return
    }

    isSending.value = true
    try {
        const payload = {
            scan_result: props.value,
            init_data: initData,
            timestamp: new Date().toISOString()
        }

        const response = await fetch(webhookUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        })

        if (!response.ok) {
            throw new Error(`Webhook request failed: ${response.status}`)
        }

        notificationOccurred('success')
        close()
    } catch (error) {
        console.error('Failed to send scan result webhook:', error)
        notificationOccurred('error')
    } finally {
        isSending.value = false
    }
}
</script>

<style scoped>
.icon {
    height: 20px;
    width: 20px;
}
</style>