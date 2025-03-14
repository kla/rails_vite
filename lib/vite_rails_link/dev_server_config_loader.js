import { loadConfigFromFile } from 'vite'

async function getConfig() {
  const { config } = await loadConfigFromFile({ command: 'build' }, 'vite.config.ts')
  console.log(JSON.stringify(config))
}

getConfig()
