import { spawn } from 'node:child_process';
import readline from 'node:readline';

const CODEX_BIN = 'C:\\Users\\holyx\\AppData\\Roaming\\npm\\node_modules\\@openai\\codex\\bin\\codex.js';

const rl = readline.createInterface({ input: process.stdin, terminal: false });

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

rl.on('line', async (line) => {
  if (!line.trim()) return;
  let req;
  try {
    req = JSON.parse(line);
  } catch {
    return;
  }

  if (req.method === 'initialize') {
    send({
      jsonrpc: '2.0',
      id: req.id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'codex-mcp-bridge', version: '1.0.0' }
      }
    });
  } else if (req.method === 'notifications/initialized') {
    // No response required
  } else if (req.method === 'tools/list') {
    send({
      jsonrpc: '2.0',
      id: req.id,
      result: {
        tools: [
          {
            name: 'codex_exec',
            description: 'Delegate art generation (image_gen), frontend UI design, or coding tasks to OpenAI Codex CLI.',
            inputSchema: {
              type: 'object',
              properties: {
                prompt: { type: 'string', description: 'Task instructions for Codex' },
                workdir: { type: 'string', description: 'Working directory path' }
              },
              required: ['prompt']
            }
          }
        ]
      }
    });
  } else if (req.method === 'tools/call' && req.params?.name === 'codex_exec') {
    const prompt = req.params?.arguments?.prompt ?? '';
    const workdir = req.params?.arguments?.workdir ?? 'c:\\AI\\gemini\\promise-path-next';
    const child = spawn(process.execPath, [
      CODEX_BIN,
      'exec',
      '-C', workdir,
      '--dangerously-bypass-approvals-and-sandbox',
      '-'
    ], { stdio: ['pipe', 'pipe', 'pipe'] });

    let out = '', err = '';
    child.stdout.on('data', d => { out += d.toString(); });
    child.stderr.on('data', d => { err += d.toString(); });
    child.stdin.write(prompt);
    child.stdin.end();

    child.on('close', (code) => {
      send({
        jsonrpc: '2.0',
        id: req.id,
        result: {
          content: [{ type: 'text', text: out || err || `Codex exited with code ${code}` }],
          isError: code !== 0
        }
      });
    });
  } else if (req.id !== undefined) {
    send({ jsonrpc: '2.0', id: req.id, result: {} });
  }
});
