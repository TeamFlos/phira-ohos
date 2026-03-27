import { hapTasks, OhosHapContext, OhosPluginId, Target } from '@ohos/hvigor-ohos-plugin';
import { getNode, HvigorNode, hvigor } from '@ohos/hvigor';
import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

function loadProperties(filePath: string): Record<string, string> {
  if (!fs.existsSync(filePath)) throw new Error(`Config file not found: ${filePath}`);
  const result: Record<string, string> = {};
  for (const line of fs.readFileSync(filePath, 'utf-8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const sep = trimmed.indexOf('=');
    if (sep !== -1) result[trimmed.slice(0, sep).trim()] = trimmed.slice(sep + 1).trim();
  }
  return result;
}

function requireConfig(config: Record<string, string>, key: string): string {
  if (!(key in config)) throw new Error(`Missing required config: ${key}`);
  return config[key];
}

const localConfig = loadProperties(path.resolve(__dirname, '..', 'local.properties'));
const COPY_ENABLED = requireConfig(localConfig, 'copyLibphira.enabled').toLowerCase() === 'true';
const LIBPHIRA_SRC = requireConfig(localConfig, 'libphira.src');
const WSL_DISTRO = requireConfig(localConfig, 'wsl.distro');

function ensureWslFile(src: string, timeout = 60000, interval = 2000): void {
  if (fs.existsSync(src)) return;
  const wslRoot = `\\\\wsl.localhost\\${WSL_DISTRO}`;
  console.log(`[copyLibphira] not available, starting WSL (${wslRoot})...`);
  try { fs.readdirSync(wslRoot); } catch {
    try { execSync(`wsl -d ${WSL_DISTRO} echo "wsl ready"`, { timeout: 15000 }); } catch (e) {
      console.warn(`[copyLibphira] wsl command failed: ${e}`);
    }
  }
  const deadline = Date.now() + timeout;
  while (!fs.existsSync(src)) {
    if (Date.now() >= deadline) throw new Error(`[copyLibphira] timeout (${timeout / 1000}s), not found: ${src}`);
    console.log(`[copyLibphira] waiting for wsl...`);
    const end = Date.now() + interval; while (Date.now() < end) {}
  }
}

export default { system: hapTasks, plugins: [] }

const node: HvigorNode = getNode(__filename);
hvigor.nodesEvaluated(() => {
  const hapContext = node.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext;
  hapContext?.targets((target: Target) => {
    node.registerTask({
      name: `${target.getTargetName()}@copyLibphira`,
      run() {
        if (!COPY_ENABLED) { console.log('[copyLibphira] disabled, skipping.'); return; }
        const dest = path.resolve(__dirname, 'libs', 'arm64-v8a', 'libphira.so');
        console.log(`[copyLibphira] src: ${LIBPHIRA_SRC}`);
        console.log(`[copyLibphira] dest: ${dest}`);
        ensureWslFile(LIBPHIRA_SRC);
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.copyFileSync(LIBPHIRA_SRC, dest);
      },
      postDependencies: [`${target.getTargetName()}@PackageHap`]
    });
  });
});