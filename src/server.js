const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const os = require('os');
const app = express();

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

function getServicesConfig(ns) {
  const isProd = ns === 'prod';
  const baseDomain = isProd ? 'smartseth.com' : 'smartseth.dev';
  const protocol = 'https://';

  return [
    { id: 'ims-api-gateway', name: 'API Gateway', icon: '🚪', port: 8080, domain: `${protocol}api.${baseDomain}`, type: 'gateway', category: 'Core & Gateway', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-main-backend', name: 'Main Backend', icon: '🏢', port: 8081, domain: `${protocol}api.${baseDomain}`, type: 'core', category: 'Core & Gateway', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-catalog-service', name: 'Catalog Service', icon: '📦', port: 4002, domain: `${protocol}api.${baseDomain}/api/products`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-inventory-service', name: 'Inventory Service', icon: '🏭', port: 4003, domain: `${protocol}api.${baseDomain}/api/inventory`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-sales-service', name: 'Sales & Orders', icon: '🧾', port: 4004, domain: `${protocol}api.${baseDomain}/api/sales-invoices`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-payment-service', name: 'Payment Service', icon: '💳', port: 4006, domain: `${protocol}api.${baseDomain}/api/razorpay`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-logistics-service', name: 'Logistics Service', icon: '🚚', port: 4007, domain: `${protocol}api.${baseDomain}/api/logistics`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-communication-service', name: 'Communication Service', icon: '📬', port: 4008, domain: `${protocol}api.${baseDomain}/api/communication`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-audit-service', name: 'Audit & Telemetry', icon: '🔍', port: 4009, domain: `${protocol}api.${baseDomain}/api/audit`, type: 'microservice', category: 'Microservices', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-redis', name: 'Redis Cache', icon: '⚡', port: 6379, domain: `redis://${isProd ? 'prod' : 'dev'}:6379`, type: 'infrastructure', category: 'Core & Gateway', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-admin-web', name: 'Admin Web', icon: '🖥️', port: 3000, domain: `${protocol}ims.${baseDomain}`, type: 'frontend', category: 'Frontends & UI', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-superadmin-web', name: 'Superadmin Web', icon: '👑', port: 3002, domain: `${protocol}superadmin.${baseDomain}`, type: 'frontend', category: 'Frontends & UI', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-storefront-web', name: 'Storefront Web', icon: '🛍️', port: 3001, domain: isProd ? `${protocol}wififashion.${baseDomain}` : `${protocol}shiromanimart.${baseDomain}`, type: 'frontend', category: 'Frontends & UI', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-generator-backend', name: 'App Gen Backend', icon: '⚙️', port: 8005, domain: `${protocol}generator.${baseDomain}/api`, type: 'generator', category: 'App Generator', env: isProd ? 'PROD' : 'DEV' },
    { id: 'ims-generator-frontend', name: 'App Gen Frontend', icon: '📱', port: 3005, domain: `${protocol}generator.${baseDomain}`, type: 'generator', category: 'App Generator', env: isProd ? 'PROD' : 'DEV' },
    { id: 'jenkins', name: 'Jenkins CI/CD', icon: '🏗️', port: 8080, domain: `${protocol}ci.${baseDomain}`, type: 'cicd', category: 'Shared Infrastructure', isShared: true, env: 'GLOBAL' },
    { id: 'web-log-viewer', name: 'Tracer & CI Logs Hub', icon: '📊', port: 8888, domain: `${protocol}logs.${baseDomain}`, type: 'observability', category: 'Shared Infrastructure', isShared: true, env: 'GLOBAL' }
  ];
}

// Helper to fetch pod resource usage via kubectl top pods
function getPodMetrics(ns, callback) {
  exec(`kubectl top pods -n ${ns} --no-headers 2>/dev/null; kubectl top pods -n dev --no-headers 2>/dev/null`, (err, stdout) => {
    const metricsMap = {};
    if (!err && stdout) {
      const lines = stdout.split('\n').filter(Boolean);
      lines.forEach(line => {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 3) {
          const podName = parts[0];
          const cpu = parts[1]; // e.g. "12m"
          const memory = parts[2]; // e.g. "45Mi"
          metricsMap[podName] = { cpu, memory };
        }
      });
    }
    callback(metricsMap);
  });
}

// 1. Get all services with live pod status and CPU/Memory metrics
app.get('/api/services', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';
  const services = getServicesConfig(ns);
  
  // Fetch pods in target namespace AND dev (for shared infra like jenkins & log viewer)
  exec(`kubectl get pods -n ${ns} -o json; kubectl get pods -n dev -o json`, (err, stdout) => {
    if (err && !stdout) {
      return res.json(services.map(s => ({ ...s, k8s: { status: 'Unknown', ready: false, cpu: '0m', memory: '0Mi' } })));
    }

    try {
      // Parse output streams
      const podStatusMap = {};
      const jsonChunks = stdout.trim().split(/}\s*\{/).map((chunk, idx, arr) => {
        if (arr.length === 1) return chunk;
        if (idx === 0) return chunk + '}';
        if (idx === arr.length - 1) return '{' + chunk;
        return '{' + chunk + '}';
      });

      jsonChunks.forEach(jsonStr => {
        try {
          const k8sData = JSON.parse(jsonStr);
          if (k8sData.items) {
            k8sData.items.forEach(pod => {
              const appLabel = pod.metadata.labels?.app;
              if (appLabel) {
                const podName = pod.metadata.name;
                const ready = pod.status.containerStatuses?.every(c => c.ready) ?? false;
                podStatusMap[appLabel] = {
                  podName,
                  status: pod.status.phase,
                  ready,
                  namespace: pod.metadata.namespace,
                  restarts: pod.status.containerStatuses?.[0]?.restartCount || 0,
                  startTime: pod.status.startTime,
                  cpu: '< 5m',
                  memory: '24Mi'
                };
              }
            });
          }
        } catch (parseErr) {
          // ignore chunk parse error
        }
      });

      getPodMetrics(ns, (metricsMap) => {
        Object.keys(podStatusMap).forEach(appKey => {
          const info = podStatusMap[appKey];
          if (metricsMap[info.podName]) {
            info.cpu = metricsMap[info.podName].cpu;
            info.memory = metricsMap[info.podName].memory;
          }
        });

        const enriched = services.map(s => ({
          ...s,
          k8s: podStatusMap[s.id] || { status: 'Not Deployed', ready: false, restarts: 0, cpu: '0m', memory: '0Mi' }
        }));
        res.json(enriched);
      });
    } catch (e) {
      res.json(services);
    }
  });
});

// 2. Global Cluster & System Metrics API
app.get('/api/metrics', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';

  exec(`kubectl top pods -n ${ns} --no-headers 2>/dev/null`, (err, topOut) => {
    exec(`kubectl get pods -n ${ns} -o json`, (err2, podsOut) => {
      let totalCpuMillicores = 0;
      let totalMemoryMiB = 0;
      let runningPods = 0;
      let totalPods = 0;
      const podList = [];

      try {
        if (topOut) {
          const lines = topOut.split('\n').filter(Boolean);
          lines.forEach(line => {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 3) {
              const name = parts[0];
              const cpuStr = parts[1];
              const memStr = parts[2];
              const cpuVal = parseInt(cpuStr.replace('m', ''), 10) || 0;
              const memVal = parseInt(memStr.replace('Mi', '').replace('Gi', '1024'), 10) || 0;
              totalCpuMillicores += cpuVal;
              totalMemoryMiB += memVal;
            }
          });
        }

        if (podsOut) {
          const parsed = JSON.parse(podsOut);
          totalPods = parsed.items.length;
          parsed.items.forEach(p => {
            const isReady = p.status.containerStatuses?.every(c => c.ready) ?? false;
            if (isReady && p.status.phase === 'Running') runningPods++;
            podList.push({
              name: p.metadata.name,
              app: p.metadata.labels?.app || 'system',
              status: p.status.phase,
              ready: isReady,
              restarts: p.status.containerStatuses?.[0]?.restartCount || 0,
              node: p.spec.nodeName || 'k3s-node',
              ip: p.status.podIP || 'internal'
            });
          });
        }
      } catch (e) {
        // Fallback gracefully
      }

      const totalSystemMem = Math.round(os.totalmem() / (1024 * 1024));
      const freeSystemMem = Math.round(os.freemem() / (1024 * 1024));
      const usedSystemMem = totalSystemMem - freeSystemMem;
      const loadAvg = os.loadavg();

      res.json({
        cluster: {
          namespace: ns,
          runningPods,
          totalPods,
          totalCpuUsage: `${totalCpuMillicores || 45}m`,
          totalMemoryUsage: `${totalMemoryMiB || 420}Mi`,
          totalCpuPercent: Math.min(Math.round(((totalCpuMillicores || 45) / 2000) * 100), 100),
          totalMemoryPercent: Math.min(Math.round(((totalMemoryMiB || 420) / (totalSystemMem || 8000)) * 100), 100)
        },
        system: {
          totalMemoryMB: totalSystemMem,
          usedMemoryMB: usedSystemMem,
          memoryUsagePercent: Math.round((usedSystemMem / totalSystemMem) * 100),
          cpuCores: os.cpus().length,
          load1m: loadAvg[0].toFixed(2),
          load5m: loadAvg[1].toFixed(2),
          uptimeHours: (os.uptime() / 3600).toFixed(1)
        },
        pods: podList
      });
    });
  });
});

// 3. Log Streamer Endpoint
app.get('/api/logs', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';
  const service = req.query.service || 'ims-api-gateway';
  const tail = parseInt(req.query.tail, 10) || 150;
  const sanitizedService = service.replace(/[^a-zA-Z0-9_\-]/g, '');

  // Shared infra services live in dev namespace
  const targetNs = (sanitizedService === 'web-log-viewer' || sanitizedService === 'jenkins') ? 'dev' : ns;

  const cmd = `kubectl logs -n ${targetNs} -l app=${sanitizedService} --tail=${tail} --timestamps=true`;
  exec(cmd, { maxBuffer: 1024 * 1024 * 5 }, (err, stdout, stderr) => {
    if (err && !stdout) {
      return res.json({ logs: [`No active logs in ${targetNs} namespace for ${sanitizedService}`] });
    }
    const lines = (stdout || '').split('\n').filter(Boolean);
    res.json({ logs: lines });
  });
});

// 4. Trace & Cross-Service Flow Analyzer
app.get('/api/trace', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';
  const q = req.query.q || '';
  if (!q) return res.json({ flow: [], hops: [], errorSummary: null });

  const sanitized = q.replace(/[^a-zA-Z0-9_\-@.: /]/g, '');
  const services = getServicesConfig(ns);
  const appList = services.map(s => s.id).join(',');
  const cmd = `kubectl logs -n ${ns} -l 'app in (${appList})' --prefix=true --timestamps=true --tail=2000 2>/dev/null | grep -i "${sanitized}" | sort -k 2`;

  exec(cmd, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) => {
    if (!stdout) return res.json({ flow: [], hops: [], errorSummary: null });

    const lines = stdout.split('\n').filter(Boolean);
    const flow = [];
    const touchedServices = new Set();
    let failedService = null;
    let failureReason = null;

    lines.forEach(line => {
      const parts = line.split(' ');
      const podPrefix = parts[0] || '';
      const time = parts[1] || '';
      const log = parts.slice(2).join(' ') || line;
      
      let matchedService = services.find(s => podPrefix.includes(s.id) || podPrefix.includes(s.id.replace('ims-', '')));
      if (!matchedService) {
        matchedService = { id: 'unknown', name: 'Service', icon: '⚙️', port: 0 };
      }

      const isError = /error|fail|exception|fatal|unauthorized|500|401|403|404|rejected|timed\s*out/i.test(log);
      const isWarn = /warn|warning|retry|deprecated/i.test(log);
      const isSuccess = /success|connected|started|listening|200\s*OK|201\s*Created/i.test(log);

      if (isError && !failedService) {
        failedService = matchedService;
        failureReason = log.slice(0, 140);
      }

      touchedServices.add(matchedService.id);

      flow.push({
        serviceId: matchedService.id,
        serviceName: matchedService.name,
        serviceIcon: matchedService.icon,
        time,
        log,
        level: isError ? 'ERROR' : (isWarn ? 'WARN' : (isSuccess ? 'SUCCESS' : 'INFO'))
      });
    });

    const hops = Array.from(touchedServices).map(id => {
      const s = services.find(x => x.id === id) || { id, name: id, icon: '⚙️' };
      return {
        ...s,
        status: (failedService && failedService.id === id) ? 'FAILED' : 'SUCCESS'
      };
    });

    res.json({
      flow,
      hops,
      totalLogs: flow.length,
      failedService: failedService ? failedService.name : null,
      failedServiceId: failedService ? failedService.id : null,
      failureReason,
      hasError: !!failedService
    });
  });
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 8888;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`IMS Observability & Flow Tracer running on port ${PORT}`);
});
