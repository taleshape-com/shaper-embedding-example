import http from 'http'
import fs from 'fs'
import { URL } from 'url'

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:5454'
const ANALYTICS_PROXY = 'http://localhost:5454'
const PORT = 3001
const DASHBOARD_ID = process.env.DASHBOARD_ID ?? 'demo-dashboard';
const API_KEY = process.env.API_KEY;
const VARIABLES = JSON.parse(process.env.VARIABLES ?? '{"insurance_id": "medicare"}');

const server = http.createServer((req, res) => {
  // Proxy /analytics to localhost:5454
  if (req.url.startsWith('/analytics')) {
    const targetPath = req.url.replace(/^\/analytics/, '') || '/'
    const targetUrl = new URL(targetPath, ANALYTICS_PROXY)

    const headers = { ...req.headers }
    delete headers.host

    const proxyReq = http.request(targetUrl.toString(), {
      method: req.method,
      headers,
    }, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers)
      proxyRes.pipe(res)
    })

    proxyReq.on('error', (err) => {
      console.error('Proxy error:', err)
      res.writeHead(502)
      res.end('Proxy error')
    })

    req.pipe(proxyReq)
    return
  }

  // Get JWT from Shaper API
  if (req.url === '/api/jwt' && req.method === 'POST') {
    // In production you would need to authenticate the users first
    let body = ''
    req.on('data', chunk => {
      body += chunk.toString()
    })
    req.on('end', async () => {
      try {
        let variables = { ...VARIABLES };
        if (body) {
          try {
            const parsed = JSON.parse(body);
            if (parsed.insurance_id) {
              variables.insurance_id = parsed.insurance_id;
            } else if (parsed.variables) {
              variables = { ...variables, ...parsed.variables };
            }
          } catch (e) {
            console.error('Error parsing request body:', e);
          }
        }

        // Here we send a request to the Shaper API to get a JWT token
        const r = await fetch(`${BASE_URL}/api/auth/token`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            token: API_KEY,
            dashboardId: DASHBOARD_ID,
            variables,
          }),
        })
        if (r.status !== 200) {
          console.error('failed fetching token:', await r.text())
          res.writeHead(500, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ error: 'Fail to get JWT' }))
          return
        }
        const { jwt } = await r.json()
        res.writeHead(200, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify(jwt))
      } catch (error) {
        console.error(error)
        res.writeHead(400, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ error: 'Invalid JSON or missing baseUrl' }))
      }
    })
    return
  }

  // Serve index.html
  fs.readFile('index.html', (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404)
        res.end('File not found')
        return
      }
      res.writeHead(500)
      res.end('Sorry, there was an error loading the page')
      return
    }
    res.writeHead(200, { 'Content-Type': 'text/html' })
    let html = content.toString();
    html = html.replaceAll('$BASE_URL', BASE_URL);
    html = html.replaceAll('$DASHBOARD_ID', DASHBOARD_ID);
    html = html.replaceAll('$VARIABLES', JSON.stringify(VARIABLES));
    res.end(html)
  })
})

server.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}/`)
})

