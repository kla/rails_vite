import { loadConfigFromFile } from 'vite'

async function getConfig(viteConfigPath) {
  const { config } = await loadConfigFromFile({ command: 'build' }, viteConfigPath)
  console.log(JSON.stringify(config))
}

getConfig(process.argv[2])
