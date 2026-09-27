const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const app = express();

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

const SERVICES = [
  { id: 'ims-api-gateway', name: 'API Gateway', icon: '🚪', port: 8080, type: 'gateway' },
  { id: 'ims-main-backend', name: 'Main Backend', icon: '🏢', port: 8081, type: 'core' },
  { id: 'ims-catalog-service', name: 'Catalog Service', icon: '📦', port: 4002, type: 'microservice' },
  { id: 'ims-inventory-service', name: 'Inventory Service', icon: '🏭', port: 4003, type: 'microservice' },
  { id: 'ims-sales-service', name: 'Sales & Orders', icon: '🧾', port: 4004, type: 'microservice' },
  { id: 'ims-payment-service', name: 'Payment Service', icon: '💳', port: 4006, type: 'microservice' },
  { id: 'ims-logistics-service', name: 'Logistics Service', icon: '🚚', port: 4007, type: 'microservice' },
  { id: 'ims-communication-service', name: 'Communication Service', icon: '📬', port: 4008, type: 'microservice' },
  { id: 'ims-audit-service', name: 'Audit & Telemetry', icon: '🔍', port: 4009, type: 'microservice' },
  { id: 'ims-generator-backend', name: 'App Gen Backend', icon: '⚙️', port: 8000, type: 'generator' },
  { id: 'ims-generator-frontend', name: 'App Gen Frontend', icon: '📱', port: 3005, type: 'generator' },
  { id: 'ims-admin-web', name: 'Admin Web', icon: '🖥️', port: 3000, type: 'frontend' },
  { id: 'ims-superadmin-web', name: 'Superadmin Web', icon: '👑', port: 3002, type: 'frontend' },
  { id: 'ims-storefront-web', name: 'Storefront Web', icon: '🛍️', port: 3001, type: 'frontend' },
  { id: 'ims-redis', name: 'Redis Cache', icon: '⚡', port: 6379, type: 'infrastructure' }
];

app.get('/api/services', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';
  exec(`kubectl get pods -n ${ns} -o json`, (err, stdout) => {
    if (err) return res.json(SERVICES);
    try {
      const k8sData = JSON.parse(stdout);
      const podStatusMap = {};
      k8sData.items.forEach(pod => {
        const appLabel = pod.metadata.labels?.app;
        if (appLabel) {
          const ready = pod.status.containerStatuses?.every(c => c.ready) ?? false;
          podStatusMap[appLabel] = {
            podName: pod.metadata.name,
            status: pod.status.phase,
            ready,
            restarts: pod.status.containerStatuses?.[0]?.restartCount || 0,
            startTime: pod.status.startTime
          };
        }
      });
      const enriched = SERVICES.map(s => ({
        ...s,
        k8s: podStatusMap[s.id] || { status: 'Not Deployed', ready: false, restarts: 0 }
      }));
      res.json(enriched);
    } catch (e) {
      res.json(SERVICES);
    }
  });
});

app.get('/api/logs', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';
  const service = req.query.service || 'ims-api-gateway';
  const tail = parseInt(req.query.tail, 10) || 150;
  const sanitizedService = service.replace(/[^a-zA-Z0-9_\-]/g, '');

  const cmd = `kubectl logs -n ${ns} -l app=${sanitizedService} --tail=${tail} --timestamps=true`;
  exec(cmd, { maxBuffer: 1024 * 1024 * 5 }, (err, stdout, stderr) => {
    if (err && !stdout) {
      return res.json({ logs: [`No active logs in ${ns} namespace for ${sanitizedService}`] });
    }
    const lines = (stdout || '').split('\n').filter(Boolean);
    res.json({ logs: lines });
  });
});

app.get('/api/trace', (req, res) => {
  const ns = req.query.ns === 'prod' ? 'prod' : 'dev';
  const q = req.query.q || '';
  if (!q) return res.json({ flow: [], hops: [], errorSummary: null });

  const sanitized = q.replace(/[^a-zA-Z0-9_\-@.: /]/g, '');
  const appList = SERVICES.map(s => s.id).join(',');
  const cmd = `kubectl logs -n ${ns} -l 'app in (${appList})' --prefix=true --timestamps=true --tail=2000 | grep -i "${sanitized}" | sort -k 2`;

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
      
      let matchedService = SERVICES.find(s => podPrefix.includes(s.id) || podPrefix.includes(s.id.replace('ims-', '')));
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
      const s = SERVICES.find(x => x.id === id) || { id, name: id, icon: '⚙️' };
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
