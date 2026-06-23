import type { Plugin } from "@opencode-ai/plugin"

export const DBusNotifyPlugin: Plugin = async ({ $, worktree }) => {
    return {
        event: async ({ event }) => {
            if (event.type === "session.idle") {
                const message = `<u>worktree:</u> ${worktree}`
                await ($`notify-send -e -t 3000 -h STRING:sound-name:message-new-instant -a opencode 'opencode is IDLE now' '${message}'`).catch(console.error)
            }
        },
    }
}
