import { useEffect, useRef, useState } from 'react'
import { useLocation } from 'react-router-dom'
import { Loader2, Menu, Plus, Send, Trash2 } from 'lucide-react'
import { Markdown } from '../components/Markdown'
import { api } from '../lib/api'
import { backendUrl } from '../lib/config'
import { useI18n } from '../lib/i18n'
import { useSettings } from '../lib/settings'
import type { Device } from '../lib/types'

interface ChatRow {
  id: string
  title: string
  messages: { role: string; content: string }[]
}
type Msg = { role: string; content: string }

interface NavState {
  hostId?: string
  apiUrl?: string
  initialChatId?: string
  initialMessages?: Msg[]
}

export default function Chat() {
  const { t, lang } = useI18n()
  const { config } = useSettings()
  const nav = (useLocation().state ?? {}) as NavState

  const [host, setHost] = useState({
    id: nav.hostId ?? 'default',
    apiUrl: nav.apiUrl ?? backendUrl,
  })
  const [chats, setChats] = useState<ChatRow[]>([])
  const [currentId, setCurrentId] = useState<string | null>(nav.initialChatId ?? null)
  const [messages, setMessages] = useState<Msg[]>(nav.initialMessages ?? [])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [panel, setPanel] = useState(false)
  const scrollRef = useRef<HTMLDivElement>(null)

  // Resolve the host once from devices (unless provided via navigation state).
  useEffect(() => {
    if (nav.hostId) return
    api
      .getDevices()
      .then((ds: Device[]) => {
        if (ds.length)
          setHost({ id: ds[0].host_id, apiUrl: ds[0].api_url || backendUrl })
      })
      .catch(() => {})
  }, [nav.hostId])

  useEffect(() => {
    let ignore = false
    api
      .getChats(host.id)
      .then((rows) => {
        if (ignore) return
        const list = rows as unknown as ChatRow[]
        setChats(list)
        if (!currentId && nav.initialChatId) {
          const m = list.find((c) => c.id === nav.initialChatId)
          if (m) {
            setCurrentId(m.id)
            setMessages(m.messages)
            return
          }
        }
        if (!currentId && messages.length === 0 && list.length > 0) setPanel(true)
      })
      .catch(() => {})
    return () => {
      ignore = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [host.id])

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight })
  }, [messages, loading])

  async function reloadChats() {
    try {
      setChats((await api.getChats(host.id)) as unknown as ChatRow[])
    } catch {
      /* ignore */
    }
  }

  function openChat(c: ChatRow) {
    setCurrentId(c.id)
    setMessages(c.messages)
    setPanel(false)
    setError(null)
  }
  function newChat() {
    setCurrentId(null)
    setMessages([])
    setPanel(false)
    setError(null)
  }
  async function removeChat(id: string) {
    try {
      await api.deleteChat(id)
      if (id === currentId) newChat()
      reloadChats()
    } catch {
      /* ignore */
    }
  }

  async function send() {
    const q = input.trim()
    if (!q || loading) return
    if (!config || !config.model_name) {
      setError(t('askConfigureFirst'))
      return
    }
    const history = [...messages]
    setMessages([...messages, { role: 'user', content: q }])
    setInput('')
    setLoading(true)
    setError(null)
    try {
      const res = await api.ask({
        question: q,
        aiConfig: config,
        history,
        baseUrl: host.apiUrl,
        lang,
      })
      const next: Msg[] = [
        ...history,
        { role: 'user', content: q },
        { role: 'assistant', content: res.answer },
      ]
      setMessages(next)
      const title = q.length > 40 ? q.slice(0, 40) : q
      const id = await api.upsertChat({
        id: currentId,
        host_id: host.id,
        title,
        messages: next,
      })
      setCurrentId(id)
      reloadChats()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex h-full">
      {/* Conversations panel */}
      <aside
        className={`${
          panel ? 'flex' : 'hidden'
        } absolute inset-y-0 z-20 w-72 flex-col border-e border-line/70 bg-surface md:static md:flex`}
      >
        <div className="p-3">
          <button
            onClick={newChat}
            className="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-2 text-sm font-medium text-white hover:opacity-90"
          >
            <Plus size={16} /> {t('newChat')}
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-2 pb-2">
          {chats.length === 0 ? (
            <div className="px-3 py-6 text-center text-xs text-text-secondary">
              {t('noChats')}
            </div>
          ) : (
            chats.map((c) => (
              <div
                key={c.id}
                className={`group flex items-center gap-1 rounded-lg px-2 ${
                  c.id === currentId ? 'bg-elevated' : 'hover:bg-elevated'
                }`}
              >
                <button
                  onClick={() => openChat(c)}
                  className="flex-1 truncate py-2 text-start text-sm text-text-primary"
                >
                  {c.title || 'Chat'}
                </button>
                <button
                  onClick={() => removeChat(c.id)}
                  className="rounded p-1 text-text-secondary opacity-0 transition hover:text-danger group-hover:opacity-100"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))
          )}
        </div>
      </aside>

      {/* Messages */}
      <div className="relative flex min-w-0 flex-1 flex-col">
        <div className="flex items-center gap-2 border-b border-line/70 px-4 py-2.5">
          <button className="btn-ghost md:hidden" onClick={() => setPanel((p) => !p)}>
            <Menu size={18} />
          </button>
          <span className="font-semibold text-text-primary">{t('chatTitle')}</span>
        </div>

        <div ref={scrollRef} className="flex-1 space-y-3 overflow-y-auto p-4">
          {messages.length === 0 && !loading ? (
            <div className="grid h-full place-items-center text-sm text-text-secondary">
              {t('askEmpty')}
            </div>
          ) : (
            messages.map((m, i) => (
              <div
                key={i}
                className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-[85%] rounded-2xl px-3.5 py-2.5 ${
                    m.role === 'user'
                      ? 'bg-primary/15 text-text-primary'
                      : 'card'
                  }`}
                >
                  {m.role === 'user' ? (
                    <span className="whitespace-pre-wrap text-sm">{m.content}</span>
                  ) : (
                    <Markdown text={m.content} />
                  )}
                </div>
              </div>
            ))
          )}
          {loading && (
            <div className="flex items-center gap-2 text-sm text-text-secondary">
              <Loader2 className="animate-spin" size={16} /> {t('askThinking')}
            </div>
          )}
        </div>

        {error && (
          <div className="px-4 pb-1 text-xs text-danger">{error}</div>
        )}

        <div className="flex items-end gap-2 border-t border-line/70 p-3">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault()
                send()
              }
            }}
            rows={1}
            placeholder={t('chatHint')}
            className="max-h-32 flex-1 resize-none rounded-xl border border-line bg-bg px-3.5 py-2.5 text-sm text-text-primary outline-none focus:border-primary"
          />
          <button
            onClick={send}
            disabled={loading}
            className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary text-white hover:opacity-90 disabled:opacity-50"
          >
            <Send size={18} />
          </button>
        </div>
      </div>
    </div>
  )
}
