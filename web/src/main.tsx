import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import './index.css'
import App from './App'
import { AuthProvider } from './lib/auth'
import { I18nProvider } from './lib/i18n'
import { ThemeProvider } from './lib/theme'
import { ToastProvider } from './lib/toast'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ThemeProvider>
      <I18nProvider>
        <ToastProvider>
          <AuthProvider>
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </AuthProvider>
        </ToastProvider>
      </I18nProvider>
    </ThemeProvider>
  </StrictMode>,
)
